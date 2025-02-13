import SwiftUI

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TransactionViewModel
    let transaction: Transaction
    
    @State private var merchantName: String
    @State private var amount: String
    @State private var isExpense: Bool
    @State private var timestamp: Date
    @State private var currency: String
    @State private var location: String
    @State private var category: String
    @State private var description: String
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    private let categories = ["Food", "Coffee", "Shopping", "Transportation", 
                            "Entertainment", "Groceries", "Bills", "Other"]
    
    init(viewModel: TransactionViewModel, transaction: Transaction) {
        self.viewModel = viewModel
        self.transaction = transaction
        
        // Initialize state with current transaction values
        _merchantName = State(initialValue: transaction.merchantName ?? "")
        _amount = State(initialValue: String(format: "%.2f", abs(transaction.amount)))
        _isExpense = State(initialValue: transaction.amount < 0)
        _timestamp = State(initialValue: transaction.timestamp ?? Date())
        _currency = State(initialValue: transaction.currency ?? "CAD")
        _location = State(initialValue: transaction.location ?? "")
        _category = State(initialValue: transaction.category ?? "")
        _description = State(initialValue: transaction.desc ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Merchant Name", text: $merchantName)
                        .autocapitalization(.words)
                    
                    HStack {
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                        
                        Picker("Type", selection: $isExpense) {
                            Text("Expense").tag(true)
                            Text("Income").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    DatePicker("Date", selection: $timestamp)
                }
                
                Section(header: Text("Additional Details")) {
                    Picker("Currency", selection: $currency) {
                        ForEach(["CAD", "USD", "EUR", "GBP"], id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    
                    Picker("Category", selection: $category) {
                        Text("None").tag("")
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    TextField("Location", text: $location)
                }
                
                Section(header: Text("Notes")) {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                }
            }
        }
    }
    
    private func saveChanges() {
        // Validate input
        guard !merchantName.isEmpty else {
            showingError = true
            errorMessage = "Please enter a merchant name"
            return
        }
        
        guard let amountDouble = Double(amount),
              amountDouble > 0 else {
            showingError = true
            errorMessage = "Please enter a valid amount"
            return
        }
        
        isSaving = true
        
        // Convert amount to negative if it's an expense
        let finalAmount = isExpense ? -abs(amountDouble) : abs(amountDouble)
        
        do {
            try viewModel.updateTransaction(
                transaction,
                merchantName: merchantName.trimmingCharacters(in: .whitespaces),
                amount: finalAmount,
                timestamp: timestamp,
                currency: currency,
                location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespaces),
                category: category.isEmpty ? nil : category.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces)
            )
            dismiss()
        } catch {
            showingError = true
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
    }
} 