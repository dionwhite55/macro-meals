import SwiftUI
import SwiftData

struct EditMealSheet: View {
    @Bindable var meal: Meal

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var chatInput = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var confirmingDelete = false

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
                            Text(kind.fieldLabel)
                                .foregroundStyle(kind.color)
                        }
                    }
                }

                if meal.differsFromFavorite, let favorite = meal.favorite {
                    Section {
                        Button("Update Favorite to Match") {
                            withAnimation { favorite.update(from: meal) }
                        }
                    } footer: {
                        Text("Your saved favorite still has its original name and numbers. Next time you log it, it'll use those unless you update it.")
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
                            .onChange(of: chatInput) { _, newValue in
                                if newValue.count > MacroService.maxRequestLength {
                                    chatInput = String(newValue.prefix(MacroService.maxRequestLength))
                                }
                            }
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

                Section {
                    Button("Delete Meal", role: .destructive) { confirmingDelete = true }
                        .frame(maxWidth: .infinity)
                        .confirmationDialog("Delete \(meal.name)?", isPresented: $confirmingDelete,
                                            titleVisibility: .visible) {
                            Button("Delete Meal", role: .destructive) {
                                dismiss()
                                context.delete(meal)
                            }
                        }
                }
            }
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: meal.isFavorite)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { meal.toggleFavorite(in: context) } label: {
                        Image(systemName: meal.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(meal.isFavorite ? .yellow : .secondary)
                    }
                    .accessibilityLabel(meal.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                }
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
