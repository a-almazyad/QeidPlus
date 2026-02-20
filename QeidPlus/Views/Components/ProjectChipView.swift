import SwiftUI

struct ProjectChipView: View {
    let project: ProjectType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(project.localizedKey))
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    HStack {
        ProjectChipView(project: .p50, isSelected: false, action: {})
        ProjectChipView(project: .baloot, isSelected: true, action: {})
    }
    .padding()
}
