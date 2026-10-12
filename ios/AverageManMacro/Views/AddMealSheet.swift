import SwiftUI
import SwiftData

struct AddMealSheet: View {
    let day: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FavoriteMeal.lastUsedAt, order: .reverse) private var favorites: [FavoriteMeal]
    @State private var block: TimeBlock
    @State private var description = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    init(day: Date, block: TimeBlock) {
        self.day = day
        _block = State(initialValue: block)
    }

    private var trimmed: String { description.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Favorites matching what's been typed so far (all of them when nothing is typed).
    private var matchingFavorites: [FavoriteMeal] {
        guard !trimmed.isEmpty else { return favorites }
        return favorites.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 2 scrambled eggs, spinach, toast with butter",
                              text: $description, axis: .vertical)
                        .lineLimit(2...8)
                        .focused($focused)
                        .onChange(of: description) { _, newValue in
                            if newValue.count > MacroService.maxDescriptionLength {
                                description = String(newValue.prefix(MacroService.maxDescriptionLength))
                            }
                        }
                } header: {
                    Text("What did you eat?")
                } footer: {
                    Text("Rough is fine. You'll get a ballpark estimate you can tweak later.")
                }

                Section {
                    Picker("When", selection: $block) {
                        ForEach(TimeBlock.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if !matchingFavorites.isEmpty {
                    Section {
                        ForEach(matchingFavorites) { favorite in
                            Button { logFavorite(favorite) } label: {
                                FavoriteRow(favorite: favorite) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .tint(.primary)
                            .accessibilityHint("Adds to \(block.title.lowercased()) without an estimate")
                        }
                    } header: {
                        Text(trimmed.isEmpty ? "Or pick a favorite" : "Matching favorites")
                    } footer: {
                        Text("Tap to log it instantly in \(block.title.lowercased()).")
                    }
                }
            }
            .disabled(isWorking)
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Estimate") { Task { await estimate() } }
                            .disabled(trimmed.isEmpty)
                    }
                }
            }
            .alert("Couldn't estimate", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            // With favorites to pick from, don't cover them with the keyboard straight away.
            .onAppear { focused = favorites.isEmpty }
        }
        .presentationDetents(favorites.isEmpty ? [.medium, .large] : [.large])
        .interactiveDismissDisabled(isWorking)
    }

    private func logFavorite(_ favorite: FavoriteMeal) {
        favorite.log(in: context, block: block, day: day)
        dismiss()
    }

    private func estimate() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await MacroService.estimate(trimmed)
            let meal = Meal(
                name: result.name ?? trimmed,
                macros: result.macros,
                originalDescription: trimmed,
                timeBlock: block,
                day: day
            )
            context.insert(meal)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
