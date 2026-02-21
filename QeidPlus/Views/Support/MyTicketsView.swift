import SwiftUI

struct MyTicketsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var tickets: [SupportTicket] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if tickets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text(LocalizedStringKey("support_no_tickets"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(tickets) { ticket in
                        TicketRowView(ticket: ticket)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(LocalizedStringKey("support_my_tickets"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("settings_done", comment: "")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task { await loadTickets() }
        }
    }

    private func loadTickets() async {
        isLoading = true
        errorMessage = nil
        do {
            tickets = try await MobileBackendManager.shared.fetchMyTickets()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Ticket Row

private struct TicketRowView: View {
    let ticket: SupportTicket

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(typeLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(typeColor.opacity(0.15))
                    .foregroundStyle(typeColor)
                    .clipShape(Capsule())

                Spacer()

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(ticket.status == "closed" ? .secondary : .orange)
            }

            Text(ticket.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)

            if let reply = ticket.adminReply, !reply.isEmpty {
                Divider()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text(reply)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var typeLabel: LocalizedStringKey {
        switch ticket.type {
        case "support":          return "support_type_support"
        case "suggestion":       return "support_type_suggestion"
        case "feature_request":  return "support_type_feature"
        default:                 return LocalizedStringKey(ticket.type)
        }
    }

    private var typeColor: Color {
        switch ticket.type {
        case "support":         return .red
        case "suggestion":      return .blue
        case "feature_request": return .purple
        default:                return .gray
        }
    }

    private var statusLabel: LocalizedStringKey {
        ticket.status == "closed" ? "support_status_closed" : "support_status_open"
    }
}

#Preview {
    MyTicketsView()
}
