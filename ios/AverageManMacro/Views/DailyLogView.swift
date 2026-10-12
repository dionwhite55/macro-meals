import SwiftUI
import SwiftData

struct DailyLogView: View {
    @Binding var day: Date

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var body: some View {
        NavigationStack {
            DayContent(day: day)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous day")
                    }
                    ToolbarItem(placement: .principal) {
                        Button { day = Calendar.current.startOfDay(for: .now) } label: {
                            Text(title).font(.headline).foregroundStyle(.primary)
                        }
                        .disabled(isToday)
                        .accessibilityHint("Jump to today")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { shift(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Next day")
                    }
                }
        }
    }

    private func shift(_ days: Int) {
        withAnimation {
            day = Calendar.current.date(byAdding: .day, value: days, to: day) ?? day
        }
    }
}

private struct DayContent: View {
    let day: Date

    @Environment(\.modelContext) private var context
    @Query private var meals: [Meal]
    @State private var addingTo: TimeBlock?
    @State private var editing: Meal?
    @State private var recentlyDeleted: DeletedMeal?
    @State private var favoriteTaps = 0

    init(day: Date) {
        self.day = day
        _meals = Query(filter: #Predicate<Meal> { $0.day == day }, sort: \Meal.createdAt)
    }

    private var totals: Macros { meals.reduce(.zero) { $0 + $1.macros } }

    var body: some View {
        List {
            ForEach(TimeBlock.allCases) { block in
                let blockMeals = meals.filter { $0.timeBlock == block }
                Section {
                    ForEach(blockMeals) { meal in
                        Button { editing = meal } label: {
                            MealRow(meal: meal)
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(meal) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { toggleFavorite(meal) } label: {
                                Label(meal.isFavorite ? "Unfavorite" : "Favorite",
                                      systemImage: meal.isFavorite ? "star.slash" : "star")
                            }
                            .tint(.yellow)
                        }
                        .contextMenu {
                            Button { toggleFavorite(meal) } label: {
                                Label(meal.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                      systemImage: meal.isFavorite ? "star.slash" : "star")
                            }
                            Button { meal.logAgain(in: context, on: day) } label: {
                                Label("Log Again", systemImage: "plus.square.on.square")
                            }
                            Divider()
                            Button(role: .destructive) { delete(meal) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    Button { addingTo = block } label: {
                        Label("Add meal", systemImage: "plus")
                            .font(.subheadline.weight(.medium))
                    }
                } header: {
                    HStack {
                        Label(block.title, systemImage: block.symbol)
                            .foregroundStyle(block.color)
                        Spacer()
                        if !blockMeals.isEmpty {
                            Text("\(rounded(blockMeals.reduce(0) { $0 + $1.calories })) cal")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SummaryBar(totals: totals)
                .background(.bar)
                .overlay(alignment: .bottom) { Divider() }
        }
        .safeAreaInset(edge: .bottom) {
            if let deleted = recentlyDeleted {
                UndoBanner(text: "Deleted \(deleted.name)") {
                    deleted.restore(in: context)
                    withAnimation { recentlyDeleted = nil }
                }
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: deleted.id) {
                    try? await Task.sleep(for: .seconds(8))
                    withAnimation { if recentlyDeleted?.id == deleted.id { recentlyDeleted = nil } }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: favoriteTaps)
        .sheet(item: $addingTo) { block in
            AddMealSheet(day: day, block: block)
        }
        .sheet(item: $editing) { meal in
            EditMealSheet(meal: meal)
        }
    }

    private func toggleFavorite(_ meal: Meal) {
        meal.toggleFavorite(in: context)
        favoriteTaps += 1
    }

    private func delete(_ meal: Meal) {
        let snapshot = DeletedMeal(meal)
        context.delete(meal)
        withAnimation { recentlyDeleted = snapshot }
    }
}
