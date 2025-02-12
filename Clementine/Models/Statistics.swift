import Foundation

struct Statistics: Equatable {
    let totalAmount: Double
    let averageAmount: Double
    let transactionCount: Int
    let dateRange: String
    
    static let empty = Statistics(
        totalAmount: 0,
        averageAmount: 0,
        transactionCount: 0,
        dateRange: "No transactions"
    )
    
    static func == (lhs: Statistics, rhs: Statistics) -> Bool {
        lhs.totalAmount == rhs.totalAmount &&
        lhs.averageAmount == rhs.averageAmount &&
        lhs.transactionCount == rhs.transactionCount &&
        lhs.dateRange == rhs.dateRange
    }
} 