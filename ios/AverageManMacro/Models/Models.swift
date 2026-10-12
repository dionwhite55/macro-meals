import Foundation
import SwiftData

enum TimeBlock: String, Codable, CaseIterable, Identifiable {
    case morning, afternoon, evening

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// Best guess at which block a meal logged right now belongs to.
    static func guess(for date: Date = .now) -> TimeBlock {
        switch Calendar.current.component(.hour, from: date) {
        case ..<11: .morning
        case ..<17: .afternoon
        default: .evening
        }
    }
}

struct Macros: Codable, Hashable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0

    static let zero = Macros()

    static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat,
            fiber: lhs.fiber + rhs.fiber
        )
    }
}

struct ChatMessage: Codable, Hashable, Identifiable {
    enum Role: String, Codable { case user, assistant }

    var id = UUID()
    var role: Role
    var content: String
}

@Model
final class Meal {
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var originalDescription: String
    var notes: String
    var timeBlockRaw: String
    /// Start of the local calendar day this meal was logged on.
    var day: Date
    var createdAt: Date
    var chatHistory: [ChatMessage]
    /// The favorite this meal was saved as or logged from; the meal shows a star while set.
    @Relationship(deleteRule: .nullify) var favorite: FavoriteMeal?

    init(name: String, macros: Macros, originalDescription: String, timeBlock: TimeBlock, day: Date) {
        self.name = name
        self.calories = macros.calories
        self.protein = macros.protein
        self.carbs = macros.carbs
        self.fat = macros.fat
        self.fiber = macros.fiber
        self.originalDescription = originalDescription
        self.notes = ""
        self.timeBlockRaw = timeBlock.rawValue
        self.day = Calendar.current.startOfDay(for: day)
        self.createdAt = .now
        self.chatHistory = []
    }

    var timeBlock: TimeBlock {
        get { TimeBlock(rawValue: timeBlockRaw) ?? .morning }
        set { timeBlockRaw = newValue.rawValue }
    }

    var macros: Macros {
        get { Macros(calories: calories, protein: protein, carbs: carbs, fat: fat, fiber: fiber) }
        set {
            calories = newValue.calories
            protein = newValue.protein
            carbs = newValue.carbs
            fat = newValue.fat
            fiber = newValue.fiber
        }
    }
}

@Model
final class FavoriteMeal {
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var originalDescription: String
    var createdAt: Date
    /// Last time this favorite was saved or logged; the Favorites list sorts by it.
    var lastUsedAt: Date = Date.now
    @Relationship(deleteRule: .nullify, inverse: \Meal.favorite) var meals: [Meal] = []

    init(from meal: Meal) {
        self.name = meal.name
        self.calories = meal.calories
        self.protein = meal.protein
        self.carbs = meal.carbs
        self.fat = meal.fat
        self.fiber = meal.fiber
        self.originalDescription = meal.originalDescription
        self.createdAt = .now
        self.lastUsedAt = .now
    }

    var macros: Macros {
        get { Macros(calories: calories, protein: protein, carbs: carbs, fat: fat, fiber: fiber) }
        set {
            calories = newValue.calories
            protein = newValue.protein
            carbs = newValue.carbs
            fat = newValue.fat
            fiber = newValue.fiber
        }
    }
}
