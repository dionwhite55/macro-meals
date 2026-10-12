import SwiftUI
import SwiftData

struct FavoritesView: View {
    let day: Date
    var onAdded: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \FavoriteMeal.lastUsedAt, order: .reverse) private var favorites: [FavoriteMeal]
    @State private var editing: FavoriteMeal?
    @State private var searchText = ""

    private var dayLabel: String {
        Calendar.current.isDateInToday(day)
            ? "today"
            : day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var shown: [FavoriteMeal] { favorites.filter { $0.matches(query) } }

    var body: some View {
        NavigationStack {
            List {
                if !shown.isEmpty {
                    Section {
                        ForEach(shown) { favorite in
                            Button { editing = favorite } label: {
                                FavoriteRow(favorite: favorite) {
                                    Menu {
                                        Section("Add to \(dayLabel)") {
                                            ForEach(TimeBlock.allCases) { block in
                                                Button(block.title, systemImage: block.symbol) {
                                                    add(favorite, to: block)
                                                }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    .accessibilityLabel("Add \(favorite.name) to \(dayLabel)")
                                }
                            }
                            .tint(.primary)
                        }
                        .onDelete { offsets in
                            let visible = shown
                            offsets.map { visible[$0] }.forEach(context.delete)
                        }
                    } header: {
                        if !query.isEmpty {
                            Text("\(shown.count) of \(favorites.count)")
                        }
                    } footer: {
                        Text("Tap + to add a favorite to \(dayLabel)'s log. Tap a favorite to edit it.")
                    }
                }
            }
            .overlay {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "star",
                        description: Text("Open a meal in your log and tap the star, or press and hold a meal and choose Add to Favorites.")
                    )
                } else if shown.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search favorites")
            .navigationTitle("Favorites")
            .sheet(item: $editing) { favorite in
                EditFavoriteSheet(favorite: favorite)
            }
        }
    }

    private func add(_ favorite: FavoriteMeal, to block: TimeBlock) {
        favorite.log(in: context, block: block, day: day)
        searchText = ""
        onAdded()
    }
}

private struct EditFavoriteSheet: View {
    @Bindable var favorite: FavoriteMeal

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $favorite.name)
                }

                Section {
                    ForEach(MacroKind.allCases) { kind in
                        LabeledContent {
                            TextField(kind.label,
                                      value: $favorite[dynamicMember: kind.favoriteKeyPath],
                                      format: .number.precision(.fractionLength(0...1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Text(kind.fieldLabel).foregroundStyle(kind.color)
                        }
                    }
                } header: {
                    Text("Macros")
                } footer: {
                    Text("Changes apply the next time you log this favorite. Meals already in your log keep their numbers.")
                }

                Section {
                    Button("Remove from Favorites", role: .destructive) { confirmingDelete = true }
                        .frame(maxWidth: .infinity)
                        .confirmationDialog("Remove \(favorite.name) from Favorites?", isPresented: $confirmingDelete,
                                            titleVisibility: .visible) {
                            Button("Remove", role: .destructive) {
                                dismiss()
                                context.delete(favorite)
                            }
                        } message: {
                            Text("Meals already in your log stay there.")
                        }
                }
            }
            .navigationTitle("Edit Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
