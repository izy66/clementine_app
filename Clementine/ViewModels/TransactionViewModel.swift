import Foundation
import CoreData
import SwiftUI

@MainActor
class TransactionViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var statistics: Statistics = .empty
    @Published var error: TransactionError?
    @Published var isLoading = false
    @Published var searchText = "" {
        didSet {
            searchWorkItem?.cancel()
            
            guard !searchText.isEmpty else {
                loadTransactions()
                return
            }
            
            // Create a new work item for the search
            let workItem = DispatchWorkItem { [weak self] in
                self?.performSearch()
            }
            searchWorkItem = workItem
            
            // Schedule the search after a 1-second delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        }
    }
    
    private let context: NSManagedObjectContext
    private let persistenceController: PersistenceController
    private var searchWorkItem: DispatchWorkItem?
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
         persistenceController: PersistenceController = .shared) {
        self.context = context
        self.persistenceController = persistenceController
        
        // Purge history on launch
        persistenceController.purgeHistory()
        
        loadTransactions()
    }
    
    func addTransaction(merchantName: String, amount: Double,
                       timestamp: Date = Date(), currency: String = "CAD",
                       location: String? = nil, category: String? = nil,
                       description: String? = nil) {
        Task {
            do {
                let transaction = Transaction(context: context)
                transaction.id = UUID()
                transaction.merchantName = merchantName.trimmingCharacters(in: .whitespaces)
                transaction.timestamp = timestamp
                transaction.currency = currency
                transaction.amount = amount
                transaction.location = location?.trimmingCharacters(in: .whitespaces)
                transaction.category = category?.trimmingCharacters(in: .whitespaces)
                transaction.desc = description?.trimmingCharacters(in: .whitespaces)
                
                try await context.perform {
                    try self.context.save()
                }
                
                // Index the transaction for semantic search
                persistenceController.indexTransaction(transaction)
                
                loadTransactions()
            } catch {
                self.error = TransactionError.saveFailed(error.localizedDescription)
            }
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        do {
            context.delete(transaction)
            try context.save()
            loadTransactions()
        } catch let error as NSError {
            // Handle specific Core Data errors
            switch error.code {
            case NSManagedObjectContextLockingError:
                self.error = TransactionError.deleteFailed("Transaction is being modified by another process")
            case NSManagedObjectReferentialIntegrityError:
                self.error = TransactionError.deleteFailed("Cannot delete transaction due to existing references")
            case NSManagedObjectConstraintValidationError:
                self.error = TransactionError.deleteFailed("Cannot delete transaction due to validation constraints")
            default:
                self.error = TransactionError.deleteFailed(error.localizedDescription)
            }
            
            // Refresh the context to ensure consistency
            context.rollback()
            loadTransactions()
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
        do {
            try persistenceController.updateTransaction(
                transaction,
                merchantName: merchantName,
                amount: amount,
                timestamp: timestamp,
                currency: currency,
                location: location,
                category: category,
                description: description
            )
            loadTransactions()
        } catch {
            throw TransactionError.updateFailed(error.localizedDescription)
        }
    }
    
    func loadTransactions() {
        let request = NSFetchRequest<Transaction>(entityName: "Transaction")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)]
        
        do {
            transactions = try context.fetch(request)
            updateStatistics(for: transactions)
        } catch {
            self.error = TransactionError.loadFailed(error.localizedDescription)
            transactions = []
            statistics = .empty
        }
    }
    
    private func performSearch() {
        Task { @MainActor in
            isLoading = true
            persistenceController.searchTransactions(searchText) { [weak self] results in
                guard let self = self else { return }
                self.transactions = results
                self.updateStatistics(for: results)
                self.isLoading = false
            }
        }
    }
    
    private func updateStatistics(for transactions: [Transaction]) {
        guard !transactions.isEmpty else {
            statistics = .empty
            return
        }
        
        let totalAmount = transactions.reduce(0) { $0 + $1.amount }
        let averageAmount = totalAmount / Double(transactions.count)
        
        let sortedTransactions = transactions.sorted {
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let startDate = sortedTransactions.first?.timestamp ?? Date()
        let endDate = sortedTransactions.last?.timestamp ?? Date()
        let dateRange = "\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
        
        statistics = Statistics(
            totalAmount: totalAmount,
            averageAmount: averageAmount,
            transactionCount: transactions.count,
            dateRange: dateRange
        )
    }
    
    deinit {
        searchWorkItem?.cancel()
    }
} 
