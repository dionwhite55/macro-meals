import SwiftUI
import SwiftData

@main
struct AverageManMacroApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Meal.self, FavoriteMeal.self])
    }
}

struct ContentView: View {
    enum Tab { case log, summary, favorites, settings }

    @Environment(\.modelContext) private var context
    @State private var tab = Tab.log
    @State private var day = Calendar.current.startOfDay(for: .now)

    var body: some View {
        TabView(selection: $tab) {
            DailyLogView(day: $day)
                .tabItem { Label("Log", systemImage: "fork.knife") }
                .tag(Tab.log)

            SummaryView { selected in
                day = selected
                tab = .log
            }
            .tabItem { Label("Summary", systemImage: "calendar") }
            .tag(Tab.summary)

            FavoritesView(day: day) { tab = .log }
                .tabItem { Label("Favorites", systemImage: "star") }
                .tag(Tab.favorites)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        #if DEBUG
        .task { SampleData.seedIfRequested(in: context) }
        #endif
    }
}
