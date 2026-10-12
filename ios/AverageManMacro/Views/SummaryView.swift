import SwiftUI
import SwiftData

/// Month view: daily averages, a calendar of logged days, and a tap-to-see breakdown per day.
struct SummaryView: View {
    /// Jumps to a day in the Log tab.
    var onOpenDay: (Date) -> Void

    @State private var month = SummaryView.startOfMonth(.now)
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: .now)

    private var isCurrentMonth: Bool { month == SummaryView.startOfMonth(.now) }

    var body: some View {
        NavigationStack {
            MonthContent(month: month, selectedDay: $selectedDay, onOpenDay: onOpenDay)
                .navigationTitle(month.formatted(.dateTime.month(.wide).year()))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous month")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { shift(1) } label: { Image(systemName: "chevron.right") }
                            .disabled(isCurrentMonth)
                            .accessibilityLabel("Next month")
                    }
                }
        }
    }

    private func shift(_ months: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: months, to: month) else { return }
        withAnimation {
            month = next
            // Keep today selected when coming back to this month; otherwise start with nothing selected.
            selectedDay = SummaryView.startOfMonth(.now) == next ? Calendar.current.startOfDay(for: .now) : nil
        }
    }

    static func startOfMonth(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? Calendar.current.startOfDay(for: date)
    }
}

private struct MonthContent: View {
    let month: Date
    @Binding var selectedDay: Date?
    var onOpenDay: (Date) -> Void

    @Query private var meals: [Meal]

    init(month: Date, selectedDay: Binding<Date?>, onOpenDay: @escaping (Date) -> Void) {
        self.month = month
        _selectedDay = selectedDay
        self.onOpenDay = onOpenDay
        let end = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
        _meals = Query(filter: #Predicate<Meal> { $0.day >= month && $0.day < end }, sort: \Meal.createdAt)
    }

    private var totalsByDay: [Date: Macros] {
        Dictionary(grouping: meals, by: \.day).mapValues { $0.reduce(.zero) { $0 + $1.macros } }
    }

    var body: some View {
        let totals = totalsByDay
        ScrollView {
            VStack(spacing: 16) {
                AverageCard(totalsByDay: totals)
                CalendarGrid(month: month, totalsByDay: totals, selectedDay: $selectedDay)
                if let day = selectedDay {
                    DayDetailCard(day: day,
                                  meals: meals.filter { $0.day == day },
                                  onOpen: { onOpenDay(day) })
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

/// "Daily average" across the days that have something logged.
private struct AverageCard: View {
    let totalsByDay: [Date: Macros]

    private var average: Macros {
        let days = Double(totalsByDay.count)
        guard days > 0 else { return .zero }
        let sum = totalsByDay.values.reduce(Macros.zero, +)
        return Macros(calories: sum.calories / days, protein: sum.protein / days, carbs: sum.carbs / days,
                      fat: sum.fat / days, fiber: sum.fiber / days)
    }

    var body: some View {
        Card {
            HStack {
                Text("Daily average").font(.headline)
                Spacer()
                Text(totalsByDay.isEmpty ? "No days logged"
                     : "\(totalsByDay.count) day\(totalsByDay.count == 1 ? "" : "s") logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            SummaryBar(totals: average)
        }
    }
}

private struct CalendarGrid: View {
    let month: Date
    let totalsByDay: [Date: Macros]
    @Binding var selectedDay: Date?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// Each cell's date, with nil padding before the 1st so it lands on the right weekday.
    private var cells: [Date?] {
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let leading = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        let days = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: month) }
        return Array(repeating: nil, count: leading) + days
    }

    /// Weekday initials starting from the user's first day of the week.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        Card {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(date: date,
                                calories: totalsByDay[date]?.calories,
                                isSelected: selectedDay == date) {
                            withAnimation(.snappy) { selectedDay = selectedDay == date ? nil : date }
                        }
                    } else {
                        Color.clear.frame(height: 46)
                    }
                }
            }
        }
    }
}

private struct DayCell: View {
    let date: Date
    let calories: Double?
    let isSelected: Bool
    let action: () -> Void

    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var isFuture: Bool { date > Calendar.current.startOfDay(for: .now) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.day()))
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                Text(calories.map(rounded) ?? " ")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : MacroKind.calories.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(isSelected ? Color.white : isFuture ? Color.secondary.opacity(0.5) : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor
                          : calories != nil ? Color.accentColor.opacity(0.1) : Color.clear)
            }
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let day = date.formatted(date: .complete, time: .omitted)
        guard let calories else { return "\(day), nothing logged" }
        return "\(day), \(rounded(calories)) calories"
    }
}

/// The tapped day's totals and meals.
private struct DayDetailCard: View {
    let day: Date
    let meals: [Meal]
    let onOpen: () -> Void

    private var totals: Macros { meals.reduce(.zero) { $0 + $1.macros } }

    var body: some View {
        Card {
            HStack {
                Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.headline)
                Spacer()
                Button("Open in Log", action: onOpen)
                    .font(.subheadline.weight(.semibold))
            }
            if meals.isEmpty {
                Text("Nothing logged this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                SummaryBar(totals: totals)
                Divider()
                ForEach(TimeBlock.allCases) { block in
                    let blockMeals = meals.filter { $0.timeBlock == block }
                    if !blockMeals.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(block.title, systemImage: block.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(block.color)
                            ForEach(blockMeals) { meal in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(meal.name).font(.subheadline)
                                    Spacer()
                                    Text("\(rounded(meal.calories)) cal")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

/// Rounded white card on the grouped background.
private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 12) { content }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}
