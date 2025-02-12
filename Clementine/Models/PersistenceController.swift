import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    private var searchWorkItem: DispatchWorkItem?
    
    init(inMemory: Bool = false) {
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
        // Use a background queue for the search
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
                    // Convert to main context objects
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
    
    deinit {
        searchWorkItem?.cancel()
    }
} 
