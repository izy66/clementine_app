import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TransactionViewModel
    
    @State private var merchantName = ""
    @State private var amount = ""
    @State private var isExpense = true
    @State private var timestamp = Date()
    @State private var currency = "CAD"
    @State private var location = ""
    @State private var category = ""
    @State private var description = ""
    
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
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
                
                // Additional Details
                Section(header: Text("Additional Details")) {
                    Picker("Currency", selection: $currency) {
                        ForEach(["CAD", "USD", "EUR", "GBP"], id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    
                    TextField("Location", text: $location)
                    
                    TextField("Category", text: $category)
                        .autocapitalization(.words)
                }
                
                // Notes
                Section(header: Text("Notes")) {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { 
                    saveTransaction()
                }
                .disabled(isSaving)
            )
            .overlay {
                if isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK") { }
            } message: {
                Text(validationMessage)
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                if let error = viewModel.error {
                    Text([error.errorDescription, error.recoverySuggestion]
                        .compactMap { $0 }
                        .joined(separator: "\n\n"))
                }
            }
            .disabled(isSaving)
        }
    }
    
    private func validateInput() -> Bool {
        if merchantName.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Please enter a merchant name"
            showingValidationAlert = true
            return false
        }
        
        guard let amountDouble = Double(amount),
              amountDouble > 0 else {
            validationMessage = "Please enter a valid amount"
            showingValidationAlert = true
            return false
        }
        
        return true
    }
    
    private func saveTransaction() {
        guard validateInput() else { return }
        guard let amountDouble = Double(amount) else { return }
        
        isSaving = true
        
        // Convert amount to negative if it's an expense
        let finalAmount = isExpense ? -abs(amountDouble) : abs(amountDouble)
        
        viewModel.addTransaction(
            merchantName: merchantName.trimmingCharacters(in: .whitespaces),
            amount: finalAmount,
            timestamp: timestamp,
            currency: currency,
            location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespaces),
            category: category.isEmpty ? nil : category.trimmingCharacters(in: .whitespaces),
            description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces)
        )
        
        // Dismiss if no error occurred
        if viewModel.error == nil {
            dismiss()
        }
        
        isSaving = false
    }
} 
