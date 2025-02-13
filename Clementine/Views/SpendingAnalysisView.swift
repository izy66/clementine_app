import SwiftUI
import Charts

struct SpendingAnalysisView: View {
    @ObservedObject var viewModel: TransactionViewModel
    
    private var categoryData: [(category: String, amount: Double)] {
        let expenseTransactions = viewModel.transactions.filter { $0.amount < 0 }
        var categoryAmounts: [String: Double] = [:]
        
        for transaction in expenseTransactions {
            let category = transaction.category ?? "Uncategorized"
            categoryAmounts[category, default: 0] += abs(transaction.amount)
        }
        
        return categoryAmounts.map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
    
    private var totalSpending: Double {
        categoryData.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        List {
            Section {
                Chart(categoryData, id: \.category) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Category", item.category))
                }
                .frame(height: 300)
                .chartLegend(position: .bottom, spacing: 20)
            } header: {
                Text("Spending by Category")
            }
            
            Section {
                ForEach(categoryData, id: \.category) { item in
                    HStack {
                        Text(item.category)
                            .font(.headline)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(formatAmount(item.amount))
                                .font(.subheadline)
                            Text("\(Int((item.amount / totalSpending) * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Breakdown")
            }
        }
        .navigationTitle("Spending Analysis")
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CAD"
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
} 