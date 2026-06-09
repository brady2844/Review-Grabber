//
//  HHG_ReviewsApp.swift
//  HHG-Reviews
//
//  Created by Brady Cook on 6/9/26.
//

import SwiftUI
import SwiftData

@main
struct HHG_ReviewsApp: App {

    let container: ModelContainer

    init() {
        let schema = Schema([
            Organization.self,
            Location.self,
            Employee.self,
            Review.self,
            Rule.self,
            Contest.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .task {
                    SampleData.seedIfNeeded(container.mainContext)
                }
        }
        .modelContainer(container)
    }
}
