#if DEBUG
import Foundation
import SwiftData

/// Development-only test data. Launch a debug build with `-seedSampleData` on an empty install to
/// get 30 favorites and ~7 weeks of logged meals (some days skipped), for trying search and the
/// monthly summary. Not compiled into release builds.
enum SampleData {
    static func seedIfRequested(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleData"),
              (try? context.fetchCount(FetchDescriptor<FavoriteMeal>())) == 0,
              (try? context.fetchCount(FetchDescriptor<Meal>())) == 0 else { return }

        let samples: [(String, String, Macros)] = [
            ("Greek Yogurt Parfait", "greek yogurt with granola and blueberries", .init(calories: 420, protein: 20, carbs: 58, fat: 12, fiber: 6)),
            ("Scrambled Eggs and Toast", "2 scrambled eggs, slice of buttered toast", .init(calories: 330, protein: 16, carbs: 22, fat: 20, fiber: 1)),
            ("Oatmeal with Banana", "oatmeal, banana, drizzle of honey", .init(calories: 350, protein: 9, carbs: 68, fat: 6, fiber: 8)),
            ("Black Coffee and a Banana", "black coffee and a banana", .init(calories: 105, protein: 1, carbs: 27, fat: 0, fiber: 3)),
            ("Protein Shake", "whey protein with almond milk", .init(calories: 180, protein: 27, carbs: 6, fat: 5, fiber: 1)),
            ("Avocado Toast", "sourdough, half an avocado, chili flakes", .init(calories: 310, protein: 8, carbs: 34, fat: 17, fiber: 8)),
            ("Breakfast Burrito", "eggs, chorizo, cheese, flour tortilla", .init(calories: 620, protein: 30, carbs: 45, fat: 35, fiber: 3)),
            ("Bagel with Cream Cheese", "everything bagel with cream cheese", .init(calories: 430, protein: 13, carbs: 60, fat: 15, fiber: 2)),
            ("Chicken Burrito Bowl", "chicken burrito bowl with rice, black beans, and guac", .init(calories: 750, protein: 45, carbs: 80, fat: 25, fiber: 12)),
            ("Turkey Sandwich", "turkey, swiss, lettuce, tomato on wheat", .init(calories: 450, protein: 32, carbs: 42, fat: 16, fiber: 5)),
            ("Caesar Salad with Chicken", "chicken caesar salad", .init(calories: 520, protein: 38, carbs: 18, fat: 33, fiber: 4)),
            ("Pepperoni Pizza (2 slices)", "two slices of pepperoni pizza", .init(calories: 600, protein: 24, carbs: 66, fat: 26, fiber: 4)),
            ("Cheeseburger and Fries", "cheeseburger with medium fries", .init(calories: 980, protein: 38, carbs: 95, fat: 49, fiber: 7)),
            ("Spaghetti Bolognese", "spaghetti with meat sauce", .init(calories: 680, protein: 32, carbs: 85, fat: 22, fiber: 7)),
            ("Salmon, Rice and Broccoli", "baked salmon with white rice and broccoli", .init(calories: 610, protein: 40, carbs: 55, fat: 23, fiber: 5)),
            ("Chicken Stir Fry", "chicken and vegetable stir fry with rice", .init(calories: 560, protein: 35, carbs: 62, fat: 17, fiber: 5)),
            ("Steak and Potatoes", "8oz sirloin with roasted potatoes", .init(calories: 720, protein: 55, carbs: 45, fat: 34, fiber: 5)),
            ("Tacos (3)", "three ground beef tacos", .init(calories: 570, protein: 28, carbs: 42, fat: 32, fiber: 6)),
            ("Ramen", "tonkotsu ramen with egg", .init(calories: 780, protein: 30, carbs: 85, fat: 34, fiber: 4)),
            ("Sushi Combo", "california roll and salmon nigiri", .init(calories: 540, protein: 26, carbs: 82, fat: 11, fiber: 4)),
            ("Chili", "bowl of beef and bean chili", .init(calories: 450, protein: 30, carbs: 35, fat: 20, fiber: 11)),
            ("Mac and Cheese", "bowl of mac and cheese", .init(calories: 550, protein: 20, carbs: 60, fat: 25, fiber: 2)),
            ("Apple and Peanut Butter", "apple with 2 tbsp peanut butter", .init(calories: 290, protein: 8, carbs: 30, fat: 16, fiber: 6)),
            ("Trail Mix", "handful of trail mix", .init(calories: 250, protein: 7, carbs: 22, fat: 16, fiber: 3)),
            ("Protein Bar", "chocolate protein bar", .init(calories: 210, protein: 20, carbs: 23, fat: 7, fiber: 5)),
            ("Hummus and Carrots", "hummus with baby carrots", .init(calories: 180, protein: 6, carbs: 20, fat: 9, fiber: 6)),
            ("String Cheese", "two string cheese sticks", .init(calories: 160, protein: 14, carbs: 2, fat: 12, fiber: 0)),
            ("Ice Cream", "bowl of vanilla ice cream", .init(calories: 290, protein: 5, carbs: 32, fat: 16, fiber: 1)),
            ("Crème Brûlée", "creme brulee", .init(calories: 330, protein: 5, carbs: 30, fat: 21, fiber: 0)),
            ("Beer (2)", "two pints of IPA", .init(calories: 400, protein: 4, carbs: 30, fat: 0, fiber: 0)),
        ]

        var favorites: [FavoriteMeal] = []
        for (index, sample) in samples.enumerated() {
            let favorite = FavoriteMeal(name: sample.0, macros: sample.2, originalDescription: sample.1)
            favorite.lastUsedAt = Date.now.addingTimeInterval(Double(-index) * 3600)
            context.insert(favorite)
            favorites.append(favorite)
        }

        // Past 50 days (not today), skipping every 5th day and a couple of others, 2-3 meals each.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for daysAgo in 1...50 where daysAgo % 5 != 0 && daysAgo != 13 && daysAgo != 22 {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            favorites[daysAgo % 8].log(in: context, block: .morning, day: day)
            favorites[8 + daysAgo % 12].log(in: context, block: .afternoon, day: day)
            if daysAgo % 3 != 0 {
                favorites[20 + daysAgo % 10].log(in: context, block: .evening, day: day)
            }
        }
    }
}
#endif
