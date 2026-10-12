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
    @Query private var favorites: [FavoriteMeal]
    @State private var addingTo: TimeBlock?
    @State private var editing: Meal?

    init(day: Date) {
        self.day = day
        _meals = Query(filter: #Predicate<Meal> { $0.day == day }, sort: \Meal.createdAt)
    }

    private var totals: Macros { meals.reduce(.zero) { $0 + $1.macros } }
    private var favoriteNames: Set<String> { Set(favorites.map(\.name)) }

    var body: some View {
        List {
            ForEach(TimeBlock.allCases) { block in
                let blockMeals = meals.filter { $0.timeBlock == block }
                Section {
                    ForEach(blockMeals) { meal in
                        Button { editing = meal } label: {
                            MealRow(meal: meal, isFavorite: favoriteNames.contains(meal.name))
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { context.delete(meal) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            let isFavorite = favoriteNames.contains(meal.name)
                            Button { toggleFavorite(meal) } label: {
                                Label(isFavorite ? "Unfavorite" : "Favorite",
                                      systemImage: isFavorite ? "star.slash" : "star")
                            }
                            .tint(.yellow)
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
        .sheet(item: $addingTo) { block in
            AddMealSheet(day: day, block: block)
        }
        .sheet(item: $editing) { meal in
            EditMealSheet(meal: meal)
        }
    }

    private func toggleFavorite(_ meal: Meal) {
        let matches = favorites.filter { $0.name == meal.name }
        if matches.isEmpty {
            context.insert(FavoriteMeal(from: meal))
        } else {
            matches.forEach(context.delete)
        }
    }
}
