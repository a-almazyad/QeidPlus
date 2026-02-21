import SwiftUI

struct SubmitTicketView: View {
    @Environment(\.dismiss) private var dismiss

    private let types = ["support", "suggestion", "feature_request"]
    @State private var selectedType = "support"
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $selectedType) {
                        Text(LocalizedStringKey("support_type_support")).tag("support")
                        Text(LocalizedStringKey("support_type_suggestion")).tag("suggestion")
                        Text(LocalizedStringKey("support_type_feature")).tag("feature_request")
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                        .overlay(alignment: .topLeading) {
                            if message.isEmpty {
                                Text(LocalizedStringKey("support_message_placeholder"))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("support_contact_us"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(LocalizedStringKey("support_submit"))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 || isSubmitting)
                }
            }
            .alert(NSLocalizedString("support_submitted_title", comment: ""), isPresented: $submitted) {
                Button(NSLocalizedString("settings_done", comment: "")) { dismiss() }
            } message: {
                Text(LocalizedStringKey("support_submitted_message"))
            }
        }
    }

    private func submit() {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await MobileBackendManager.shared.submitSupportTicket(type: selectedType, message: trimmed)
                submitted = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    SubmitTicketView()
}
