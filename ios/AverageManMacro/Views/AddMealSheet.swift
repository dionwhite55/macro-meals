import SwiftUI
import SwiftData

struct AddMealSheet: View {
    let day: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 2 scrambled eggs, spinach, toast with butter",
                              text: $description, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focused)
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
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isWorking)
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
