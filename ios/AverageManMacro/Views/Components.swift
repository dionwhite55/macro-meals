import SwiftUI

enum MacroKind: CaseIterable, Identifiable {
    case calories, protein, carbs, fat, fiber

    var id: Self { self }

    var label: String {
        switch self {
        case .calories: "Calories"
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .fat: "Fat"
        case .fiber: "Fiber"
        }
    }

    var short: String {
        switch self {
        case .calories: "Cal"
        case .protein: "P"
        case .carbs: "C"
        case .fat: "F"
        case .fiber: "Fib"
        }
    }

    var unit: String { self == .calories ? "" : "g" }

    var color: Color {
        switch self {
        case .calories: .red
        case .protein: .blue
        case .carbs: .orange
        case .fat: .green
        case .fiber: .brown
        }
    }

    func value(in macros: Macros) -> Double {
        switch self {
        case .calories: macros.calories
        case .protein: macros.protein
        case .carbs: macros.carbs
        case .fat: macros.fat
        case .fiber: macros.fiber
        }
    }

    var keyPath: ReferenceWritableKeyPath<Meal, Double> {
        switch self {
        case .calories: \.calories
        case .protein: \.protein
        case .carbs: \.carbs
        case .fat: \.fat
        case .fiber: \.fiber
        }
    }
}

extension TimeBlock {
    var symbol: String {
        switch self {
        case .morning: "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .evening: "moon.stars.fill"
        }
    }

    var color: Color {
        switch self {
        case .morning: .orange
        case .afternoon: .cyan
        case .evening: .purple
        }
    }
}

func rounded(_ value: Double) -> String {
    Int(value.rounded()).formatted()
}

/// The day's totals across the top of the log.
struct SummaryBar: View {
    let totals: Macros

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MacroKind.allCases) { kind in
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(rounded(kind.value(in: totals)))
                            .font(.title3.weight(.bold))
                            .contentTransition(.numericText())
                        Text(kind.unit)
                            .font(.caption.weight(.medium))
                            .opacity(0.65)
                    }
                    .foregroundStyle(kind.color)
                    Text(kind.label.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .animation(.default, value: totals)
    }
}

/// One-line macro readout, e.g. "520 cal · P 32g · C 40g · F 22g · Fib 6g".
struct MacroLine: View {
    let macros: Macros

    var body: some View {
        HStack(spacing: 10) {
            ForEach(MacroKind.allCases) { kind in
                HStack(spacing: 3) {
                    Text(kind.short).foregroundStyle(.tertiary)
                    Text(rounded(kind.value(in: macros)) + kind.unit)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                }
            }
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

struct MealRow: View {
    let meal: Meal
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                Text(meal.name)
                    .font(.body.weight(.semibold))
            }
            MacroLine(macros: meal.macros)
            if !meal.notes.isEmpty {
                Text(meal.notes)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
