import Foundation
import SwiftData

extension Meal {
    var isFavorite: Bool { favorite != nil }

    /// Saves this meal as a favorite, or removes its favorite (which unstars every meal logged from it).
    /// Starring a meal whose name is already a favorite links to that one instead of adding a duplicate;
    /// if the numbers differ, the edit screen offers to update it.
    func toggleFavorite(in context: ModelContext) {
        if let favorite {
            for meal in favorite.meals { meal.favorite = nil }
            self.favorite = nil
            context.delete(favorite)
            return
        }
        let name = self.name
        let existing = try? context.fetch(FetchDescriptor<FavoriteMeal>(predicate: #Predicate { $0.name == name })).first
        if let existing {
            favorite = existing
            existing.lastUsedAt = .now
        } else {
            let favorite = FavoriteMeal(from: self)
            context.insert(favorite)
            self.favorite = favorite
        }
    }

    /// Logs a copy of this meal in the same time block on `day`, keeping its favorite link.
    @discardableResult
    func logAgain(in context: ModelContext, on day: Date) -> Meal {
        let copy = Meal(name: name, macros: macros, originalDescription: originalDescription,
                        timeBlock: timeBlock, day: day)
        context.insert(copy)
        copy.favorite = favorite
        favorite?.lastUsedAt = .now
        return copy
    }

    /// Whether this meal's name or numbers have drifted from the favorite it's linked to.
    var differsFromFavorite: Bool {
        guard let favorite else { return false }
        return favorite.name != name || favorite.macros != macros
    }
}

extension FavoriteMeal {
    /// Adds this favorite to the log. No estimate needed, so it's instant.
    @discardableResult
    func log(in context: ModelContext, block: TimeBlock, day: Date) -> Meal {
        let meal = Meal(name: name, macros: macros, originalDescription: originalDescription,
                        timeBlock: block, day: day)
        context.insert(meal)
        meal.favorite = self
        lastUsedAt = .now
        return meal
    }

    /// Overwrites the saved favorite with a meal's current name and numbers.
    func update(from meal: Meal) {
        name = meal.name
        macros = meal.macros
    }

    /// True when every word of `query` appears in the name or what was originally typed,
    /// in any order, ignoring case and accents. An empty query matches everything.
    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        let text = name + " " + originalDescription
        return words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}

/// Enough of a deleted meal to put it back if the user taps Undo.
struct DeletedMeal: Identifiable {
    let id = UUID()
    let name: String
    let macros: Macros
    let originalDescription: String
    let notes: String
    let timeBlock: TimeBlock
    let day: Date
    let createdAt: Date
    let chatHistory: [ChatMessage]
    let favorite: FavoriteMeal?

    init(_ meal: Meal) {
        name = meal.name
        macros = meal.macros
        originalDescription = meal.originalDescription
        notes = meal.notes
        timeBlock = meal.timeBlock
        day = meal.day
        createdAt = meal.createdAt
        chatHistory = meal.chatHistory
        favorite = meal.favorite
    }

    func restore(in context: ModelContext) {
        let meal = Meal(name: name, macros: macros, originalDescription: originalDescription,
                        timeBlock: timeBlock, day: day)
        meal.notes = notes
        meal.createdAt = createdAt
        meal.chatHistory = chatHistory
        context.insert(meal)
        if let favorite, !favorite.isDeleted { meal.favorite = favorite }
    }
}
