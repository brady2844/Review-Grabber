//
//  ContentView.swift
//  HHG-Reviews
//
//  Root navigation scaffold. The app's home location is resolved here and
//  passed down to each feature tab.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Query(sort: \Location.createdAt) private var locations: [Location]
    @State private var selection: AppTab = .leaderboard

    enum AppTab: Hashable { case leaderboard, reviews, rules, settings }

    var body: some View {
        ZStack {
            AppBackground()

            if let location = locations.first {
                TabView(selection: $selection) {
                    Tab("Board", systemImage: "trophy.fill", value: AppTab.leaderboard) {
                        LeaderboardView(location: location)
                    }
                    Tab("Reviews", systemImage: "text.bubble.fill", value: AppTab.reviews) {
                        ReviewsView(location: location)
                    }
                    Tab("Rules", systemImage: "slider.horizontal.3", value: AppTab.rules) {
                        RulesView(location: location)
                    }
                    Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                        SettingsView(location: location)
                    }
                }
                .tint(Palette.aqua)
            } else {
                ProgressView().tint(Palette.aqua)
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [
            Organization.self, Location.self, Employee.self,
            Review.self, Rule.self, Contest.self,
        ], inMemory: true)
}
