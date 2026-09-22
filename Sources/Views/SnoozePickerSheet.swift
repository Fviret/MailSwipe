import SwiftUI

/// Feuille présentée sur le swipe vers le bas — la fonctionnalité innovante :
/// mettre un mail en pause et le refaire apparaître en haut de la pile plus tard.
struct SnoozePickerSheet: View {
    let onPick: (SnoozeDuration) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Choisis quand ce mail doit revenir")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                List(SnoozeDuration.allCases) { duration in
                    Button {
                        onPick(duration)
                    } label: {
                        HStack {
                            Image(systemName: duration.symbolName)
                                .frame(width: 28)
                                .foregroundStyle(Color.purple)
                            Text(duration.label)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Snoozer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
