import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Amount and merchant name
                Text(transaction.merchantName ?? "Unknown Merchant")
                    .font(.headline)
                Spacer()
                Text(formattedAmount)
                    .bold()
                    .foregroundColor(amountColor)
            }
            
            HStack {
                // Category
                if let category = transaction.category {
                    CategoryPill(name: category)
                }
                
                Spacer()
                
                // Date and location
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let location = transaction.location {
                        Text(location)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let description = transaction.desc {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency ?? "CAD"
        return formatter.string(from: NSNumber(value: transaction.amount)) ?? String(format: "%.2f", transaction.amount)
    }
    
    private var formattedDate: String {
        guard let date = transaction.timestamp else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var amountColor: Color {
        transaction.amount < 0 ? .red : .green
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
