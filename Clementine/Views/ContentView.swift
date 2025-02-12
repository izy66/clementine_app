import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @State private var showingAddTransaction = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !viewModel.transactions.isEmpty {
                    StatisticsView(statistics: viewModel.statistics)
                        .padding()
                }
                
                List {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Searching...")
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else if viewModel.transactions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            
                            Text(searchText.isEmpty ? "No transactions yet" : "No matching transactions")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            if searchText.isEmpty {
                                Button(action: { showingAddTransaction = true }) {
                                    Text("Add Transaction")
                                        .font(.body.bold())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                        .padding()
                    } else {
                        ForEach(viewModel.transactions) { transaction in
                            TransactionRow(transaction: transaction)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteTransaction(transaction)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search by merchant, category, or description")
            .onChange(of: searchText) { newValue in
                viewModel.searchText = newValue
            }
            .navigationTitle("Transactions")
            .navigationBarItems(
                trailing: Button(action: { showingAddTransaction = true }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView(viewModel: viewModel)
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
        }
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        withAnimation {
            viewModel.deleteTransaction(transaction)
        }
    }
}

struct StatisticsView: View {
    let statistics: Statistics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatBox(title: "Total", value: formatAmount(statistics.totalAmount))
                StatBox(title: "Average", value: formatAmount(statistics.averageAmount))
            }
            
            HStack(spacing: 16) {
                StatBox(title: "Count", value: "\(statistics.transactionCount)")
                StatBox(title: "Period", value: statistics.dateRange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
} 
