import SwiftUI

struct FoodMenuView: View {
    @Environment(GameState.self) private var gs
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.15).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Coin balance
                    HStack {
                        Text("🪙 \(gs.coins)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                        Spacer()
                        Text("Hunger: \(Int(gs.hunger))%")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(allFoods) { food in
                                FoodRow(food: food)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Feed \(gs.petName)")
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
}

private struct FoodRow: View {
    let food: FoodItem
    @Environment(GameState.self) private var gs
    @State private var isAnimating = false

    private var canAfford: Bool { gs.coins >= food.cost }
    private var isFull: Bool { gs.hunger >= 95 }
    private var isDisabled: Bool { !canAfford || isFull || gs.isSleeping || gs.isDead }

    var body: some View {
        Button {
            guard !isDisabled else { return }
            gs.feed(food)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isAnimating = false
            }
        } label: {
            HStack(spacing: 14) {
                // Food emoji
                ZStack {
                    Circle()
                        .fill(food.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Text(food.emoji)
                        .font(.system(size: 30))
                        .scaleEffect(isAnimating ? 1.4 : 1.0)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(isDisabled ? .white.opacity(0.35) : .white)

                    HStack(spacing: 10) {
                        StatChip(icon: "🍖", value: food.hungerBoost, color: .orange)
                        StatChip(icon: "😊", value: food.happinessBoost, color: .pink)
                        StatChip(icon: "❤️", value: food.healthEffect, color: .red)
                    }
                }

                Spacer()

                // Cost
                VStack(spacing: 4) {
                    Text("🪙 \(food.cost)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(canAfford ? .yellow : .red.opacity(0.7))
                    if isFull {
                        Text("FULL")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.green.opacity(0.7))
                    } else if !canAfford {
                        Text("TOO\nEXP.")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(.red.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isDisabled
                        ? Color.white.opacity(0.04)
                        : food.color.opacity(0.10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isDisabled
                                ? Color.white.opacity(0.08)
                                : food.color.opacity(0.35),
                                lineWidth: 1
                            )
                    )
            )
        }
        .disabled(isDisabled)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isAnimating)
    }
}

private struct StatChip: View {
    let icon: String
    let value: Double
    let color: Color

    private var sign: String { value >= 0 ? "+" : "" }

    var body: some View {
        HStack(spacing: 2) {
            Text(icon).font(.system(size: 11))
            Text("\(sign)\(Int(value))")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(value >= 0 ? color : .red)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
