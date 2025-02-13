import SwiftUI

struct TransactionRow: View {
    @ObservedObject var viewModel: TransactionViewModel
    let transaction: Transaction
    @State private var showingEditSheet = false
    
    var body: some View {
        Button(action: { showingEditSheet = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.merchantName ?? "Unknown Merchant")
                        .font(.headline)
                    
                    if let category = transaction.category {
                        Text(category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let description = transaction.desc, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatAmount(transaction.amount, currency: transaction.currency ?? "CAD"))
                        .font(.headline)
                    
                    if let date = transaction.timestamp {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let location = transaction.location, !location.isEmpty {
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditSheet) {
            EditTransactionView(viewModel: viewModel, transaction: transaction)
        }
    }
    
    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CategoryPill: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .cornerRadius(8)
    }
}
