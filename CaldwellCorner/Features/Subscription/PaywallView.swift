import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selected: UUID?

    private let perks: [(String, String)] = [
        ("sparkles", "Unlimited AI Fantasy Assistant"),
        ("chart.bar.fill", "Advanced projections & metrics"),
        ("building.columns.fill", "Full Dynasty Hub & pick values"),
        ("dollarsign.circle.fill", "Betting tools, EV & edges"),
        ("book.fill", "2025 Draft Guide included"),
        ("bubble.left.and.bubble.right.fill", "Premium Discord & exclusive content"),
        ("nosign", "No ads, ever"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 44)).foregroundStyle(Theme.Colors.accentSecondary)
                    Text("Caldwell Corner Premium")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("The ultimate fantasy football operating system")
                        .font(.system(size: 14)).foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.top, Theme.Spacing.xl)

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(perks, id: \.1) { perk in
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: perk.0).foregroundStyle(Theme.Colors.accent).frame(width: 24)
                            Text(perk.1).font(.system(size: 15)).foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark").foregroundStyle(Theme.Colors.positive)
                        }
                    }
                }
                .card()

                VStack(spacing: Theme.Spacing.md) {
                    ForEach(state.plans) { plan in
                        planCard(plan)
                    }
                }

                PrimaryButton(title: "Start Premium", systemImage: "crown.fill") {
                    state.upgradeToPremium()
                    dismiss()
                }

                Text("Auto-renews. Cancel anytime. Billed via Apple In-App Purchase.")
                    .font(.system(size: 11)).foregroundStyle(Theme.Colors.textTertiary)
                    .multilineTextAlignment(.center)

                Button("Restore Purchases") { }
                    .font(.system(size: 13)).foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28)).foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.lg)
        }
        .onAppear { if selected == nil { selected = state.plans.first(where: { $0.isFeatured })?.id } }
    }

    private func planCard(_ plan: PlanOption) -> some View {
        Button { selected = plan.id } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(plan.title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(plan.price).font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundStyle(Theme.Colors.accent)
                        Text(plan.period).font(.system(size: 12)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                if let badge = plan.badge {
                    Text(badge).font(.system(size: 10, weight: .heavy)).foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.Colors.accentSecondary).clipShape(Capsule())
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(selected == plan.id ? Theme.Colors.accent : Theme.Colors.stroke, lineWidth: selected == plan.id ? 2 : 1))
        }
    }
}
