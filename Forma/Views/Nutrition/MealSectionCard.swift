//
//  MealSectionCard.swift
//  Forma
//
//  Card expansível de refeição diária (Café da Manhã, Almoço, Jantar, Lanches) na aba Alimentação.
//

import SwiftUI

struct MealSectionCard: View {
    let mealType: MealType
    let entries: [FoodEntry]
    let onAddTap: () -> Void
    var onCameraTap: (() -> Void)? = nil
    let onDeleteEntry: (FoodEntry) -> Void

    private var mealCalories: Double {
        entries.reduce(0.0) { $0 + $1.calories }
    }

    var body: some View {
        FormaCard(padding: 16, cornerRadius: 18) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(FormaTheme.Colors.brandSoft)
                            .frame(width: 32, height: 32)
                        Image(systemName: mealType.icon)
                            .foregroundStyle(FormaTheme.Colors.brand)
                            .font(.system(size: 14, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(mealType.rawValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(FormaTheme.Colors.primaryText)
                            .lineLimit(1)
                        if !entries.isEmpty {
                            Text("\(entries.count) \(entries.count == 1 ? "item" : "itens")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 6)

                    if mealCalories > 0 {
                        Text("\(Int(mealCalories.rounded())) kcal")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(FormaTheme.Colors.primaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    if let onCameraTap {
                        Button(action: onCameraTap) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FormaTheme.Colors.brand)
                                .frame(width: 28, height: 28)
                                .background(FormaTheme.Colors.brandSoft)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onAddTap) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 23))
                            .foregroundStyle(FormaTheme.Colors.brand)
                    }
                    .buttonStyle(.plain)
                }

                if entries.isEmpty {
                    HStack {
                        Text("Nenhum item registrado ainda.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Registrar", action: onAddTap)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FormaTheme.Colors.brand)
                    }
                    .padding(.vertical, 2)
                } else {
                    VStack(spacing: 8) {
                        ForEach(entries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(FormaTheme.Colors.primaryText)
                                        .lineLimit(2)

                                    let unitLabel = entry.brand.lowercased().contains("ml") ? "ml" : "g"
                                    Text("\(Int(entry.portionGrams))\(unitLabel) • P \(Int(entry.protein))g  C \(Int(entry.carbohydrates))g  G \(Int(entry.fat))g")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                }

                                Spacer(minLength: 6)

                                Text("\(Int(entry.calories.rounded())) kcal")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(FormaTheme.Colors.primaryText)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                Button {
                                    onDeleteEntry(entry)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(FormaTheme.Colors.danger.opacity(0.65))
                                        .padding(.leading, 6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 3)

                            if entry.id != entries.last?.id {
                                Divider()
                                    .background(Color.primary.opacity(0.05))
                            }
                        }
                    }
                }
            }
        }
    }
}
