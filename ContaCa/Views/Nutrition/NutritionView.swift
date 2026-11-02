//
//  NutritionView.swift
//  ContaCa
//
//  Created by João Pedro on 10/27/26.
//

import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allFoodEntries: [FoodEntry]
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var allWorkouts: [WorkoutEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var allWaterEntries: [WaterEntry]
    @Query private var profiles: [Profile]
    @Query private var healthRecords: [Health]
    
    @State private var selectedDate: Date = Date()
    @State private var showVoiceFoodSheet: Bool = false
    @State private var mealToAdd: MealType = .lunch
    
    private var profile: Profile? {
        profiles.first
    }
    
    // Dias da semana atual (Segunda a Domingo em ordem cronológica)
    private var currentWeekDays: [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Segunda-feira
        let now = Date()
        let startOfWeek: Date
        if let interval = calendar.dateInterval(of: .weekOfYear, for: now) {
            startOfWeek = interval.start
        } else {
            startOfWeek = calendar.startOfDay(for: now)
        }
        return (0..<7).compactMap { dayIndex in
            calendar.date(byAdding: .day, value: dayIndex, to: startOfWeek)
        }
    }
    
    // Alimentos filtrados para a data selecionada
    private var foodsForSelectedDate: [FoodEntry] {
        let calendar = Calendar.current
        let targetStart = calendar.startOfDay(for: selectedDate)
        return allFoodEntries.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDate) ||
            calendar.startOfDay(for: $0.date) == targetStart
        }
    }
    
    // Treinos na data selecionada
    private var workoutsForSelectedDate: [WorkoutEntry] {
        let calendar = Calendar.current
        let targetStart = calendar.startOfDay(for: selectedDate)
        return allWorkouts.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDate) ||
            calendar.startOfDay(for: $0.date) == targetStart
        }
    }
    
    // Calorias gastas em treinos na data selecionada
    private var workoutCaloriesForSelectedDate: Double {
        workoutsForSelectedDate.reduce(0.0) { $0 + $1.caloriesBurned }
    }
    
    // Ingestão de Água na data selecionada
    private var waterForSelectedDate: [WaterEntry] {
        let calendar = Calendar.current
        let targetStart = calendar.startOfDay(for: selectedDate)
        return allWaterEntries.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDate) ||
            calendar.startOfDay(for: $0.date) == targetStart
        }
    }
    
    private var totalWaterMl: Int {
        waterForSelectedDate.reduce(0) { $0 + $1.milliliters }
    }
    
    private var targetWaterMl: Int {
        profile?.targetWaterMilliliters ?? 2500
    }
    
    private func addWater(milliliters: Int) {
        let entry = WaterEntry(milliliters: milliliters, date: selectedDate)
        try? ContaCaDataStore.shared.insertWaterEntry(entry)
    }
    
    // Totais consumidos calculados
    private var totalCalories: Double {
        foodsForSelectedDate.reduce(0.0) { $0 + $1.calories }
    }
    
    private var totalProtein: Double {
        foodsForSelectedDate.reduce(0.0) { $0 + $1.protein }
    }
    
    private var totalCarbs: Double {
        foodsForSelectedDate.reduce(0.0) { $0 + $1.carbohydrates }
    }
    
    private var totalFat: Double {
        foodsForSelectedDate.reduce(0.0) { $0 + $1.fat }
    }
    
    private var targetCaloriesBase: Double {
        profile?.targetCalorieIntake ?? 2800.0
    }
    
    // Meta ajustada: Meta base + Calorias gastas em treino (somando no consumo diário)
    private var targetCaloriesAdjusted: Double {
        targetCaloriesBase + workoutCaloriesForSelectedDate
    }
    
    private var targetProtein: Double {
        if let p = profile, p.targetProtein > 0 { return p.targetProtein }
        return healthRecords.first?.protein ?? 160.0
    }
    
    private var targetCarbs: Double {
        if let p = profile, p.targetCarbohydrates > 0 { return p.targetCarbohydrates }
        return healthRecords.first?.carbohydrates ?? 380.0
    }
    
    private var targetFat: Double {
        if let p = profile, p.targetFat > 0 { return p.targetFat }
        return healthRecords.first?.fat ?? 70.0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Estilo Apple / Airbnb
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Diário Alimentar")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Color("FontNormal"))
                            Text("Controle diário de nutrientes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            mealToAdd = currentSuggestedMeal()
                            showVoiceFoodSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Refeição")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color("AccentColor"))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Seletor Semanal Organizado (Segunda a Domingo)
                    weeklyCalendarStrip
                        .padding(.horizontal, 20)
                    
                    // Card Principal de Calorias com Exercício Somado
                    calorieBalanceCard
                        .padding(.horizontal, 20)
                    
                    // Card de Ingestão de Água com Gráfico Redondo
                    waterIntakeCard
                        .padding(.horizontal, 20)
                    
                    // Seções por Refeição (Café, Almoço, Jantar, Lanches)
                    VStack(spacing: 16) {
                        ForEach(MealType.allCases) { meal in
                            MealSectionCard(
                                mealType: meal,
                                entries: foodsForSelectedDate.filter { $0.mealType == meal },
                                onAddTap: {
                                    mealToAdd = meal
                                    showVoiceFoodSheet = true
                                },
                                onDeleteEntry: { entry in
                                    modelContext.delete(entry)
                                    try? modelContext.save()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .id(allFoodEntries.count)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVoiceFoodSheet) {
                VoiceAddFoodView(preselectedMeal: mealToAdd) { newEntry in
                    // Sincroniza widgets e ilha
                    ContaCaDataStore.shared.syncTodayData(lastFoodName: newEntry.name, lastFoodCalories: newEntry.calories)
                }
                .environment(\.modelContext, modelContext)
            }
        }
    }
    
    // MARK: - Faixa Semanal (Segunda a Domingo em Ordem)
    
    private var weeklyCalendarStrip: some View {
        HStack(spacing: 6) {
            let calendar = Calendar.current
            ForEach(currentWeekDays, id: \.self) { day in
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(day)
                let dayLetter = day.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "pt_BR")))
                    .replacingOccurrences(of: ".", with: "")
                    .capitalized
                let dayNumber = day.formatted(.dateTime.day())
                
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        selectedDate = day
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(dayLetter)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? Color("AccentColor") : .secondary)
                        
                        Text(dayNumber)
                            .font(.system(size: 13, weight: isSelected || isToday ? .bold : .regular, design: .rounded))
                            .foregroundColor(isSelected ? .white : (isToday ? Color("AccentColor") : Color("FontNormal")))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color("AccentColor") : (isToday ? Color("AccentMinor") : Color.clear))
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color("CardBackground") : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    // MARK: - Card de Balanço Nutricional e Exercício
    
    private var calorieBalanceCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Consumo do Dia")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(totalCalories))")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(Color("FontNormal"))
                        Text("/ \(Int(targetCaloriesAdjusted)) kcal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    
                    let dailyTmb = profile?.tmb ?? 1800.0
                    let totalBurned = dailyTmb + workoutCaloriesForSelectedDate
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color("AccentGreen"))
                        Text("Gasto Total: \(Int(totalBurned)) kcal (TMB \(Int(dailyTmb))\(workoutCaloriesForSelectedDate > 0 ? " + \(Int(workoutCaloriesForSelectedDate)) treino" : ""))")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color("AccentGreen"))
                    }
                    .padding(.top, 2)
                }
                
                Spacer()
                
                // Badge de Restante
                let remaining = targetCaloriesAdjusted - totalCalories
                VStack(alignment: .trailing, spacing: 2) {
                    Text(remaining >= 0 ? "Disponível" : "Superávit")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                    Text("\(abs(Int(remaining))) kcal")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(remaining >= 0 ? Color("AccentColor") : Color("AccentGreen"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color("AccentMinor"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            // Barra de Progresso Fina no Padrão Apple
            GeometryReader { geo in
                let ratio = targetCaloriesAdjusted > 0 ? min(totalCalories / targetCaloriesAdjusted, 1.0) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(Color("AccentColor"))
                        .frame(width: max(0, geo.size.width * ratio))
                }
            }
            .frame(height: 7)
            
            Divider()
                .background(Color.primary.opacity(0.06))
            
            // Macronutrientes
            HStack(spacing: 10) {
                MacroNutrientItem(
                    title: "Proteínas",
                    current: totalProtein,
                    target: targetProtein,
                    color: Color("AccentGreen")
                )
                MacroNutrientItem(
                    title: "Carboidratos",
                    current: totalCarbs,
                    target: targetCarbs,
                    color: Color("AccentColor")
                )
                MacroNutrientItem(
                    title: "Gorduras",
                    current: totalFat,
                    target: targetFat,
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    // MARK: - Card de Ingestão de Água com Gráfico Redondo
    
    private var waterIntakeCard: some View {
        let progress = targetWaterMl > 0 ? min(1.0, Double(totalWaterMl) / Double(targetWaterMl)) : 0.0
        let remaining = max(0, targetWaterMl - totalWaterMl)
        
        return HStack(spacing: 14) {
            // Gráfico Redondo de Progresso (Circular Ring com Ícone Centralizado)
            ZStack {
                Circle()
                    .stroke(Color.cyan.opacity(0.18), lineWidth: 5)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.cyan,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.35), value: progress)
                
                Image(systemName: "drop.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cyan)
            }
            .frame(width: 48, height: 48)
            
            // Informações de Consumo e Meta
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Água")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color("FontNormal"))
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(totalWaterMl)")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(Color("FontNormal"))
                    Text("/ \(targetWaterMl) ml")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(remaining > 0 ? "Faltam \(remaining) ml para a meta" : "Meta de água atingida! 💧")
                    .font(.caption2)
                    .foregroundColor(remaining > 0 ? .secondary : .cyan)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // Botão Único de +250ml
            Button {
                addWater(milliliters: 250)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("250ml")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.cyan)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    private func currentSuggestedMeal() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<19: return .snacks
        default: return .dinner
        }
    }
}

// MARK: - Card de cada Refeição (Apple & Airbnb Design)

struct MealSectionCard: View {
    let mealType: MealType
    let entries: [FoodEntry]
    let onAddTap: () -> Void
    let onDeleteEntry: (FoodEntry) -> Void
    
    private var mealCalories: Double {
        entries.reduce(0.0) { $0 + $1.calories }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header da refeição
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: mealType.icon)
                        .foregroundColor(Color("AccentColor"))
                        .font(.system(size: 15))
                    Text(mealType.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color("FontNormal"))
                }
                
                Spacer()
                
                if mealCalories > 0 {
                    Text("\(Int(mealCalories)) kcal")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Button(action: onAddTap) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color("AccentColor"))
                }
                .buttonStyle(.plain)
            }
            
            if entries.isEmpty {
                HStack {
                    Text("Nenhum item registrado ainda.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Adicionar por voz ou texto", action: onAddTap)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color("AccentColor"))
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color("FontNormal"))
                                
                                HStack(spacing: 6) {
                                    Text("\(Int(entry.portionGrams))g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("P: \(Int(entry.protein))g  C: \(Int(entry.carbohydrates))g  G: \(Int(entry.fat))g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text("\(Int(entry.calories)) kcal")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Color("FontNormal"))
                            
                            Button {
                                onDeleteEntry(entry)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.6))
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
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Componente de Item de Macronutriente

struct MacroNutrientItem: View {
    let title: String
    let current: Double
    let target: Double
    let color: Color
    
    private var progress: Double {
        target > 0 ? min(current / target, 1.0) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(current))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color("FontNormal"))
                Text("/\(Int(target))g")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * progress))
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NutritionView()
        .modelContainer(PreviewContainer.shared)
}
