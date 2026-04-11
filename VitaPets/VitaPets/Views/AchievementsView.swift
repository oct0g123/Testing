import SwiftUI

struct AchievementsView: View {
    @Environment(GameState.self) private var gs
    @Environment(\.dismiss) private var dismiss

    private var unlocked: Set<String> { Set(gs.achievements) }
    private var unlockedCount: Int { unlocked.count }
    private let total = allAchievements.count

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress header
                    progressHeader
                    Divider().background(Color.white.opacity(0.1))

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(allAchievements) { ach in
                                AchievementRow(ach: ach, isUnlocked: unlocked.contains(ach.id))
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.purple)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(unlockedCount) / \(total) Unlocked")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(Int(Double(unlockedCount) / Double(total) * 100))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * CGFloat(unlockedCount) / CGFloat(total),
                            height: 8
                        )
                        .animation(.spring(response: 0.6), value: unlockedCount)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
    }
}

private struct AchievementRow: View {
    let ach: AchievementDef
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Badge
            ZStack {
                Circle()
                    .fill(
                        isUnlocked
                        ? LinearGradient(colors: [.yellow.opacity(0.8), .orange.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [.white.opacity(0.06), .white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)

                if isUnlocked {
                    Circle()
                        .strokeBorder(Color.yellow.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 52, height: 52)
                }

                Text(isUnlocked ? ach.emoji : "🔒")
                    .font(.system(size: isUnlocked ? 26 : 22))
                    .opacity(isUnlocked ? 1 : 0.4)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(ach.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(isUnlocked ? .white : .white.opacity(0.35))

                Text(ach.description)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(isUnlocked ? .white.opacity(0.55) : .white.opacity(0.2))
                    .lineLimit(2)
            }

            Spacer()

            // Status
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 20))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isUnlocked
                    ? Color.yellow.opacity(0.07)
                    : Color.white.opacity(0.03)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isUnlocked ? Color.yellow.opacity(0.3) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }
}
