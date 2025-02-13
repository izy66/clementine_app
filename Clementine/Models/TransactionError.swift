import Foundation
import CoreData
import CoreSpotlight

enum TransactionError: LocalizedError {
    case searchFailed(String)
    case spotlightError(CSSearchQueryError)
    case saveFailed(String)
    case deleteFailed(String)
    case loadFailed(String)
    case invalidData(String)
    case unknown(String)
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .spotlightError(let error):
            switch error.code {
            case .cancelled:
                return "Search was cancelled"
            case .indexUnreachable:
                return "Search index is currently unavailable"
            case .invalidQuery:
                return "Invalid search query"
            @unknown default:
                return "Spotlight search error: \(error.localizedDescription)"
            }
        case .saveFailed(let message):
            return "Failed to save transaction: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete transaction: \(message)"
        case .loadFailed(let message):
            return "Failed to load transactions: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        case .updateFailed(let message):
            return "Failed to update transaction: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .searchFailed:
            return "Please try your search again with different terms"
        case .spotlightError:
            return "Please try again later"
        case .saveFailed:
            return "Please check your input and try again"
        case .deleteFailed:
            return "The transaction may have already been deleted or modified. Please refresh and try again"
        case .loadFailed:
            return "Please try refreshing the transactions list"
        case .invalidData:
            return "Please check your input and try again"
        case .unknown:
            return "Please try again or contact support if the problem persists"
        case .updateFailed:
            return "Please check your input and try again. The transaction may have been modified by another process"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .searchFailed(let message):
            return message
        case .spotlightError:
            return "The search service encountered an error"
        case .saveFailed(let message):
            return message
        case .deleteFailed(let message):
            return message
        case .loadFailed(let message):
            return message
        case .invalidData(let message):
            return message
        case .unknown(let message):
            return message
        case .updateFailed(let message):
            return message
        }
    }
} 
