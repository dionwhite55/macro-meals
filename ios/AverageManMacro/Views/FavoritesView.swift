import SwiftUI
import SwiftData

struct FavoritesView: View {
    let day: Date
    var onAdded: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \FavoriteMeal.name) private var favorites: [FavoriteMeal]
    @State private var picking: FavoriteMeal?

    private var dayLabel: String {
        Calendar.current.isDateInToday(day)
            ? "today"
            : day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(favorites) { favorite in
                    Button { picking = favorite } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(favorite.name).font(.body.weight(.semibold))
                            MacroLine(macros: favorite.macros)
                        }
                        .padding(.vertical, 2)
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    offsets.map { favorites[$0] }.forEach(context.delete)
                }
            }
            .overlay {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "star",
                        description: Text("Swipe right on a meal in your log to save it here.")
                    )
                }
            }
            .navigationTitle("Favorites")
            .confirmationDialog(
                "Add to \(dayLabel)",
                isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
                titleVisibility: .visible,
                presenting: picking
            ) { favorite in
                ForEach(TimeBlock.allCases) { block in
                    Button(block.title) { add(favorite, to: block) }
                }
            }
        }
    }

    private func add(_ favorite: FavoriteMeal, to block: TimeBlock) {
        let meal = Meal(
            name: favorite.name,
            macros: favorite.macros,
            originalDescription: favorite.originalDescription,
            timeBlock: block,
            day: day
        )
        context.insert(meal)
        onAdded()
    }
}
