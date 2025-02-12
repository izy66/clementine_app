import SwiftUI
import CoreSpotlight

@main
struct ClementineApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // Prepare Core Spotlight search functionality
        CSUserQuery.prepare()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
} 
