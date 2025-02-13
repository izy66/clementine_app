import CoreData
import CoreSpotlight

class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    private var searchWorkItem: DispatchWorkItem?
    private var currentQuery: CSUserQuery?
    private let queryContext: CSUserQueryContext
    private let searchableIndex: CSSearchableIndex
    
    init(inMemory: Bool = false) {
        // Initialize query context for semantic search
        let context = CSUserQueryContext()
        // Only fetch attributes needed for UI display
        context.fetchAttributes = ["title", "textContent", "displayName"]
        context.enableRankedResults = true
        context.maxResultCount = 50
        self.queryContext = context
        
        // Create a secure searchable index with batch support
        self.searchableIndex = CSSearchableIndex(name: "ClementineTransactions", 
                                               protectionClass: .completeUnlessOpen)
        
        container = NSPersistentContainer(name: "Clementine")
        
        if let storeDescription = container.persistentStoreDescriptions.first {
            // Configure automatic migration
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            // Enable persistent history tracking
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Error loading store: \(error.localizedDescription)")
                
                // Handle store migration error
                if let url = description.url {
                    try? FileManager.default.removeItem(at: url)
                }
                
                // Try to recreate the store
                do {
                    try self.container.persistentStoreCoordinator.addPersistentStore(
                        ofType: NSSQLiteStoreType,
                        configurationName: nil,
                        at: description.url,
                        options: description.options
                    )
                } catch {
                    print("Failed to recreate store: \(error.localizedDescription)")
                }
                return
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // Add method to purge history if needed
    func purgeHistory() {
        let backgroundContext = container.newBackgroundContext()
        
        backgroundContext.performAndWait {
            let deleteHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(
                before: Date()
            )
            
            do {
                try backgroundContext.execute(deleteHistoryRequest)
            } catch {
                print("Error purging history: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Core Data Operations
    
    func save() throws {
        let context = container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
    
    func updateTransaction(_ transaction: Transaction,
                         merchantName: String,
                         amount: Double,
                         timestamp: Date,
                         currency: String,
                         location: String?,
                         category: String?,
                         description: String?) throws {
        let context = container.viewContext
        
        // Update all fields
        transaction.merchantName = merchantName.trimmingCharacters(in: .whitespaces)
        transaction.amount = amount
        transaction.timestamp = timestamp
        transaction.currency = currency
        transaction.location = location?.trimmingCharacters(in: .whitespaces)
        transaction.category = category?.trimmingCharacters(in: .whitespaces)
        transaction.desc = description?.trimmingCharacters(in: .whitespaces)
        
        // Save changes
        try save()
        
        // Re-index for search
        indexTransaction(transaction)
    }
    
    func delete(_ object: NSManagedObject) throws {
        let context = container.viewContext
        context.delete(object)
        try save()
    }
    
    func createBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Search
    
    func searchTransactions(_ searchText: String, completion: @escaping ([Transaction]) -> Void) {
        // Cancel any pending search
        searchWorkItem?.cancel()
        currentQuery?.cancel()
        
        // Create a new work item for debouncing
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedText.isEmpty {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            // Create and configure user query with semantic search enabled
            let query = CSUserQuery(userQueryString: trimmedText, userQueryContext: self.queryContext)
            self.currentQuery = query
            
            Task {
                do {
                    var foundItems: [CSSearchableItem] = []
                    
                    // Process query responses
                    for try await response in query.responses {
                        switch response {
                        case .item(let itemResponse):
                            foundItems.append(itemResponse.item)
                        case .suggestion:
                            break
                        }
                    }
                    
                    // If no results found, fall back to direct search
                    if foundItems.isEmpty {
                        self.fallbackSearch(searchText, completion: completion)
                        return
                    }
                    
                    // Extract identifiers and convert them to UUIDs
                    let uuids = foundItems.compactMap { UUID(uuidString: $0.uniqueIdentifier) }
                    
                    // Fetch transactions with matching UUIDs
                    let context = self.createBackgroundContext()
                    let request = Transaction.fetchRequest()
                    request.predicate = NSPredicate(format: "id IN %@", uuids)
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)]
                    
                    let results = try context.fetch(request)
                    let objectIDs = results.map { $0.objectID }
                    
                    DispatchQueue.main.async {
                        let mainContext = self.container.viewContext
                        let transactions = objectIDs.compactMap { mainContext.object(with: $0) as? Transaction }
                        completion(transactions)
                    }
                } catch {
                    print("Search error: \(error.localizedDescription)")
                    self.fallbackSearch(searchText, completion: completion)
                }
            }
        }
        
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    private func fallbackSearch(_ searchText: String, completion: @escaping ([Transaction]) -> Void) {
        // Use a background queue for the direct search
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let context = self.createBackgroundContext()
            let request = Transaction.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)]
            
            // Create predicates for each searchable field
            let predicates = [
                NSPredicate(format: "merchantName CONTAINS[cd] %@", searchText),
                NSPredicate(format: "desc CONTAINS[cd] %@", searchText),
                NSPredicate(format: "category CONTAINS[cd] %@", searchText),
                NSPredicate(format: "location CONTAINS[cd] %@", searchText)
            ]
            
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            
            do {
                let results = try context.fetch(request)
                let objectIDs = results.map { $0.objectID }
                
                DispatchQueue.main.async {
                    let mainContext = self.container.viewContext
                    let transactions = objectIDs.compactMap { mainContext.object(with: $0) as? Transaction }
                    completion(transactions)
                }
            } catch {
                print("Search error: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    // Add method to index a transaction for semantic search
    func indexTransaction(_ transaction: Transaction) {
        guard let merchantName = transaction.merchantName,
              let id = transaction.id else {
            return
        }
        
        // Create an attribute set to describe the transaction
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        
        // Set both title and textContent for better semantic search
        attributeSet.title = merchantName
        attributeSet.textContent = [
            merchantName,
            transaction.category,
            transaction.location,
            transaction.desc
        ].compactMap { $0 }.joined(separator: " ")
        
        // Set display name for UI
        attributeSet.displayName = merchantName
        
        // Set last used date for ranking
        attributeSet.lastUsedDate = transaction.timestamp
        
        // Create searchable item with a unique identifier
        let item = CSSearchableItem(
            uniqueIdentifier: id.uuidString,
            domainIdentifier: "com.clementine.transactions",
            attributeSet: attributeSet
        )
        
        // Set expiration date to ensure item persists
        item.expirationDate = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year
        
        // Begin batch indexing
        searchableIndex.beginBatch()
        
        // Add to secure index
        searchableIndex.indexSearchableItems([item]) { error in
            if let error = error {
                print("Indexing error for transaction \(id): \(error.localizedDescription)")
            }
        }
        
        // End batch indexing with client state
        searchableIndex.endBatch(withClientState: Data()) { error in
            if let error = error {
                print("Error ending batch: \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        searchWorkItem?.cancel()
        currentQuery?.cancel()
    }
} 
