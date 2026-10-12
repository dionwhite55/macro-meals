import SwiftUI
import SwiftData

struct EditMealSheet: View {
    @Bindable var meal: Meal

    @Environment(\.dismiss) private var dismiss
    @State private var chatInput = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name", text: $meal.name)
                    Picker("When", selection: $meal.timeBlock) {
                        ForEach(TimeBlock.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("Macros") {
                    ForEach(MacroKind.allCases) { kind in
                        LabeledContent {
                            TextField(kind.label,
                                      value: $meal[dynamicMember: kind.keyPath],
                                      format: .number.precision(.fractionLength(0...1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Text(kind.unit.isEmpty ? kind.label : "\(kind.label) (g)")
                                .foregroundStyle(kind.color)
                        }
                    }
                }

                Section {
                    ForEach(meal.chatHistory) { message in
                        ChatBubble(message: message)
                            .listRowSeparator(.hidden)
                    }
                    HStack {
                        TextField("e.g. I only ate half", text: $chatInput)
                            .onSubmit { send() }
                            .submitLabel(.send)
                        if isWorking {
                            ProgressView()
                        } else {
                            Button(action: send) {
                                Image(systemName: "arrow.up.circle.fill").font(.title2)
                            }
                            .disabled(chatInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityLabel("Send")
                        }
                    }
                } header: {
                    Text("Chat to adjust")
                } footer: {
                    Text("Tell it what was different, like \"add 1 tbsp olive oil\" or \"it was a large\".")
                }

                if !meal.originalDescription.isEmpty {
                    Section("What you logged") {
                        Text(meal.originalDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Couldn't adjust", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func send() {
        let request = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, !isWorking else { return }
        chatInput = ""
        meal.chatHistory.append(ChatMessage(role: .user, content: request))
        isWorking = true

        Task {
            defer { isWorking = false }
            do {
                let result = try await MacroService.adjust(name: meal.name, macros: meal.macros, request: request)
                withAnimation { meal.macros = result.macros }
                meal.notes = request
                meal.chatHistory.append(ChatMessage(role: .assistant, content: result.explanation ?? "Updated."))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.content)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.accentColor : Color(.secondarySystemFill),
                            in: .rect(cornerRadius: 12))
                .foregroundStyle(isUser ? .white : .primary)
            if !isUser { Spacer(minLength: 40) }
        }
    }
}
