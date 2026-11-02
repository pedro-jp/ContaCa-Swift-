//
//  EvolutionView.swift
//  ContaCa
//
//  Created by João Pedro on 10/27/26.
//

import SwiftUI
import SwiftData
import HealthKit

enum EvolutionSection: String, CaseIterable, Identifiable {
    case overview = "Visão Geral"
    case aiAnalysis = "Análise com IA"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .overview: return "chart.bar.xaxis"
        case .aiAnalysis: return "sparkles"
        }
    }
}

struct DayCalorieSummary: Identifiable {
    let id = UUID()
    let date: Date
    let dayName: String
    let consumed: Double
    let burned: Double
}

struct EvolutionView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query(sort: \FoodEntry.date, order: .reverse) private var foodEntries: [FoodEntry]
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var workoutEntries: [WorkoutEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var waterEntries: [WaterEntry]
    @Query private var profiles: [Profile]
    
    @State private var selectedSection: EvolutionSection = .overview
    
    @State private var showLogWeight: Bool = false
    @State private var showAddWaterSheet: Bool = false
    @State private var customWaterMl: String = ""
    @State private var toastMessage: String? = nil
    
    // Sincronização Strava / Saúde
    @State private var isSyncingHealth: Bool = false
    @State private var syncStatusMessage: String? = nil
    
    // Análise IA
    @State private var isAnalyzingAI: Bool = false
    @State private var aiAnalysis: EvolutionAIAnalysis? = nil
    @State private var aiErrorMessage: String? = nil
    @State private var savedRoutineSuccessfully: Bool = false
    @State private var appliedTargetsSuccessfully: Bool = false
    
    private var profile: Profile? {
        profiles.first
    }
    
    private var currentWeight: Double {
        weightEntries.first?.weight ?? (profile?.currentWeight ?? 72.0)
    }
    
    private var targetWeight: Double {
        profile?.targetWeight ?? 80.0
    }
    
    private var height: Double {
        profile?.height ?? 1.78
    }
    
    private var goal: FitnessGoal {
        profile?.goal ?? .gain
    }
    
    private var stats: EvolutionStats {
        EvolutionCalculator.calculate(
            weight: currentWeight,
            height: height,
            goal: goal,
            targetWeight: targetWeight
        )
    }
    
    // MARK: - Resumo Semanal (Últimos 7 Dias)
    
    private var weeklySummaries: [DayCalorieSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var summaries: [DayCalorieSummary] = []
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE" // Seg, Ter, Qua...
        
        for i in (0..<7).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -i, to: today),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            
            let consumed = foodEntries
                .filter { $0.date >= dayStart && $0.date < dayEnd }
                .reduce(0.0) { $0 + $1.calories }
            
            let burned = stats.tmb + workoutEntries
                .filter { $0.date >= dayStart && $0.date < dayEnd }
                .reduce(0.0) { $0 + $1.caloriesBurned }
            
            let dayName = i == 0 ? "Hoje" : formatter.string(from: dayStart).capitalized.replacingOccurrences(of: ".", with: "")
            
            summaries.append(DayCalorieSummary(
                date: dayStart,
                dayName: dayName,
                consumed: consumed,
                burned: burned
            ))
        }
        
        return summaries
    }
    
    private var totalWeeklyConsumed: Double {
        weeklySummaries.reduce(0.0) { $0 + $1.consumed }
    }
    
    private var totalWeeklyBurned: Double {
        weeklySummaries.reduce(0.0) { $0 + $1.burned }
    }
    
    private var weeklyNetBalance: Double {
        totalWeeklyConsumed - totalWeeklyBurned
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toast de Notificação
                if let toast = toastMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text(toast)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color("AccentGreen"))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Header e Seletor de Seções
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Evolução & Análise")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Color("FontNormal"))
                            Text("Log de entradas, saídas e inteligência artificial")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Botão Peso
                        Button {
                            showLogWeight = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Peso")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color("AccentColor"))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Segmented Control de Abas
                    HStack(spacing: 4) {
                        ForEach(EvolutionSection.allCases) { section in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedSection = section
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: section.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(section.rawValue)
                                        .font(.system(size: 12.5, weight: selectedSection == section ? .bold : .medium))
                                }
                                .foregroundColor(selectedSection == section ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    selectedSection == section
                                    ? Color("AccentColor")
                                    : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(3)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)
                .background(Color("CardBackground"))
                
                Divider()
                    .background(Color.primary.opacity(0.08))
                
                // Conteúdo da Aba Selecionada
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedSection {
                        case .overview:
                            overviewSectionView
                        case .aiAnalysis:
                            aiAnalysisSectionView
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showLogWeight) {
                LogWeightView()
                    .environment(\.modelContext, modelContext)
            }
            .onAppear {
                if aiAnalysis == nil {
                    aiAnalysis = EvolutionAnalysisStore.shared.latestAnalysis ?? EvolutionAnalysisStore.shared.loadLatest()
                }
            }
        }
    }
    
    // MARK: - 1. Visão Geral (Resumo Semanal, Meta, Peso e Strava)
    
    private var overviewSectionView: some View {
        VStack(spacing: 20) {
            // Card Principal de Peso e Meta
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: goal.icon)
                                .font(.system(size: 12))
                                .foregroundColor(Color("AccentColor"))
                            Text(goal.rawValue)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Color("AccentColor"))
                        }
                        Text(goal.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(stats.isGoalAchieved ? "Meta Batida!" : "Faltam")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f kg", stats.remainingWeightToGoal))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(stats.isGoalAchieved ? Color("AccentGreen") : Color("AccentColor"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color("AccentMinor"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                Divider()
                    .background(Color.primary.opacity(0.06))
                
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Peso Atual")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", currentWeight))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Color("FontNormal"))
                            Text("kg")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Peso Alvo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", targetWeight))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Color("AccentColor"))
                            Text("kg")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(20)
            .background(Color("CardBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
            .padding(.horizontal, 20)
            
            // CARD NOVO: Balanço Semanal de Calorias (Consumidas vs Gastas)
            weeklyCalorieBalanceCard
            
            // Métricas IMC & TMB
            VStack(alignment: .leading, spacing: 14) {
                Text("Saúde & Metabolismo")
                    .font(.headline)
                    .foregroundColor(Color("FontNormal"))
                
                HStack(spacing: 12) {
                    // Card IMC
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Índice de Massa (IMC)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(String(format: "%.1f", stats.imc))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color("FontNormal"))
                            Text("IMC")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(stats.imcClassification)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(Color("AccentGreen"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color("AccentGreen").opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 2)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                    
                    // Card TMB
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Taxa Basal (TMB)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(Int(stats.tmb))")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color("FontNormal"))
                            Text("kcal")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text("Gasto em repouso")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 2)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 20)
            
            // Histórico de Pesagens
            weightsHistorySection
        }
    }
    
    // MARK: - Card Balanço Semanal de Calorias (Entradas vs Saídas)
    
    private var weeklyCalorieBalanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Balanço Semanal de Calorias")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color("FontNormal"))
                    Text("Comparativo dos últimos 7 dias (Entrou vs Saiu)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Badge de saldo líquido
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Saldo Semanal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(weeklyNetBalance >= 0 ? "+" : "")\(Int(weeklyNetBalance)) kcal")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(weeklyNetBalance >= 0 ? Color.green : Color.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((weeklyNetBalance >= 0 ? Color.green : Color.orange).opacity(0.12))
                .clipShape(Capsule())
            }
            
            // Gráfico de Barras Comparativo Dia a Dia
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklySummaries) { day in
                    VStack(spacing: 6) {
                        // Barras lado a lado (Entrou verde vs Saiu vermelho/laranja)
                        HStack(alignment: .bottom, spacing: 3) {
                            // Barra Consumidas
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color("AccentGreen"))
                                .frame(width: 14, height: max(6, CGFloat(min(120, (day.consumed / 3500.0) * 100))))
                            
                            // Barra Gastas
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.orange)
                                .frame(width: 14, height: max(6, CGFloat(min(120, (day.burned / 3500.0) * 100))))
                        }
                        .frame(height: 100, alignment: .bottom)
                        
                        Text(day.dayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)
            
            // Legenda e Totais
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color("AccentGreen")).frame(width: 8, height: 8)
                    Text("Consumidas:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(totalWeeklyConsumed)) kcal")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color("FontNormal"))
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                    Text("Gastas:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(totalWeeklyBurned)) kcal")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color("FontNormal"))
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 20)
    }
    
    // MARK: - 3. Área de Análise Inteligente com IA (Gemini)
    
    private var aiAnalysisSectionView: some View {
        VStack(spacing: 18) {
            // Header do Treinador IA
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color("AccentColor"))
                        Text("Treinador & Nutricionista IA")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color("FontNormal"))
                    }
                    Spacer()
                }
                Text("A IA analisa todo o seu histórico real dos últimos 7 dias (o que entrou, saiu, horários das refeições e treinos, água e metas) para diagnosticar e propor o melhor plano.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            // Botão Principal de Geração
            Button {
                generateAIAnalysis()
            } label: {
                HStack(spacing: 8) {
                    if isAnalyzingAI {
                        ProgressView()
                            .tint(.white)
                        Text("Analisando todos os seus dados...")
                            .font(.system(size: 14, weight: .bold))
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14, weight: .bold))
                        Text(aiAnalysis == nil ? "Gerar Diagnóstico Completo com IA" : "Atualizar Análise com IA")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color("AccentColor"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color("AccentColor").opacity(0.3), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(isAnalyzingAI)
            .padding(.horizontal, 20)
            
            if let err = aiErrorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
            }
            
            // Resultados da Análise da IA
            if let analysis = aiAnalysis {
                VStack(spacing: 16) {
                    // Card 1: Diagnóstico e Status Geral
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "target")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color("AccentColor"))
                            Text("Diagnóstico de Balanço Calórico")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color("FontNormal"))
                        }
                        
                        Text(analysis.statusSummary)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(Color("AccentGreen"))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)
                            .background(Color("AccentGreen").opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        Text(analysis.calorieDiagnostic)
                            .font(.subheadline)
                            .foregroundColor(Color("FontNormal").opacity(0.9))
                            .lineSpacing(3)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text(analysis.macroDiagnostic)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(18)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                    
                    // CARD NOVO: Metas Diárias Sugeridas pela IA (Calorias, Macros e Água)
                    if let targets = analysis.suggestedTargets {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.heart.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Color("AccentColor"))
                                    Text("Metas Diárias Sugeridas pela IA")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color("FontNormal"))
                                }
                                Spacer()
                                
                                Text("Recomendado")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color("AccentColor"))
                                    .clipShape(Capsule())
                            }
                            
                            Text(targets.explanation)
                                .font(.subheadline)
                                .foregroundColor(Color("FontNormal").opacity(0.9))
                                .lineSpacing(2)
                            
                            // Grade de Metas Calculadas
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Calorias Alvo")
                                            .font(.caption2.weight(.medium))
                                            .foregroundColor(.secondary)
                                        Text("\(Int(targets.dailyCalories)) kcal")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(Color("FontNormal"))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Meta de Água")
                                            .font(.caption2.weight(.medium))
                                            .foregroundColor(.secondary)
                                        Text("\(targets.waterMilliliters) ml")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(.cyan)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color.cyan.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Proteína")
                                            .font(.caption2.weight(.medium))
                                            .foregroundColor(.secondary)
                                        Text("\(Int(targets.proteinGrams))g")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(Color("AccentGreen"))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color("AccentGreen").opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Carboidrato")
                                            .font(.caption2.weight(.medium))
                                            .foregroundColor(.secondary)
                                        Text("\(Int(targets.carbsGrams))g")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(Color("AccentColor"))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color("AccentColor").opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Gordura")
                                            .font(.caption2.weight(.medium))
                                            .foregroundColor(.secondary)
                                        Text("\(Int(targets.fatGrams))g")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.orange)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color.orange.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                            
                            // Botão de Aplicar Metas ao Perfil
                            Button {
                                applySuggestedTargets(targets)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: appliedTargetsSuccessfully ? "checkmark.circle.fill" : "slider.horizontal.3")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(appliedTargetsSuccessfully ? "Metas Aplicadas ao Perfil!" : "Aplicar Novas Metas ao Perfil")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(appliedTargetsSuccessfully ? Color("AccentGreen") : Color("AccentColor"))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color("AccentColor").opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 20)
                    }
                    
                    // CARD NOVO: Treino Recomendado pela IA (Montado para a Aba de Treinos)
                    if let routine = analysis.recommendedRoutine {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 9, weight: .bold))
                                        Text("Gerado por Análise de IA")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundColor(Color("AccentColor"))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2.5)
                                    .background(Color("AccentColor").opacity(0.12))
                                    .clipShape(Capsule())
                                    
                                    Text(routine.title)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(Color("FontNormal"))
                                    
                                    if !routine.targetMuscles.isEmpty {
                                        Text(routine.targetMuscles)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            if !routine.hypertrophyFocus.isEmpty {
                                Text("Foco: \(routine.hypertrophyFocus)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)
                            }
                            
                            // Pílulas de resumo
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color("AccentGreen"))
                                    Text("~\(Int(routine.estimatedCalories)) kcal")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(Capsule())
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text("\(routine.estimatedDurationMinutes) min")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(Capsule())
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange)
                                    Text("\(routine.exercises.count) exercícios")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(Capsule())
                            }
                            
                            Divider()
                            
                            // Lista Resumida de Exercícios
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Exercícios da Ficha")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.secondary)
                                
                                ForEach(routine.exercises.prefix(5)) { ex in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ex.name)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Color("FontNormal"))
                                            Text("\(ex.sets)x \(ex.reps) • \(ex.suggestedWeight.isEmpty ? "\(ex.restSeconds)s descanso" : ex.suggestedWeight)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if ex.animationId != nil {
                                            Image(systemName: "play.circle.fill")
                                                .foregroundColor(Color("AccentColor").opacity(0.7))
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                            
                            // Botão de Salvar na Aba de Treinos
                            Button {
                                saveRecommendedRoutine(routine)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: savedRoutineSuccessfully ? "checkmark.circle.fill" : "plus.circle.fill")
                                        .font(.system(size: 13, weight: .bold))
                                    Text(savedRoutineSuccessfully ? "Treino Salvo na Aba de Treinos!" : "Adicionar à Minha Aba de Treinos")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(savedRoutineSuccessfully ? Color("AccentGreen") : Color.orange)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 20)
                    }
                    
                    // Card 4: Sugestões de Alimentação & Horários
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                            Text("Sugestões de Alimentação & Horários")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color("FontNormal"))
                        }
                        
                        ForEach(analysis.nutritionSuggestions, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color("AccentGreen"))
                                    .padding(.top, 2)
                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundColor(Color("FontNormal"))
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                    
                    // Card 3: Sugestões de Treinos & Recuperação
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                            Text("Sugestões de Treinos Personalizados")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color("FontNormal"))
                        }
                        
                        ForEach(analysis.workoutSuggestions, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                    .padding(.top, 2)
                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundColor(Color("FontNormal"))
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                    
                    // Card 4: Hidratação
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.cyan)
                            Text("Consumo de Água & Hidratação")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color("FontNormal"))
                        }
                        
                        Text(analysis.hydrationDiagnostic)
                            .font(.subheadline)
                            .foregroundColor(Color("FontNormal"))
                            .lineSpacing(2)
                    }
                    .padding(18)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                    
                    // Card 5: Plano de Ação Semanal
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color("AccentColor"))
                            Text("Plano de Ação para os Próximos 7 Dias")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color("FontNormal"))
                        }
                        
                        Text(analysis.weeklyActionPlan)
                            .font(.subheadline)
                            .foregroundColor(Color("FontNormal"))
                            .lineSpacing(3)
                    }
                    .padding(18)
                    .background(Color("AccentMinor"))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 20)
                }
            } else if !isAnalyzingAI {
                // Estado Vazio
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 44))
                        .foregroundColor(Color("AccentColor").opacity(0.5))
                    Text("Nenhum diagnóstico gerado ainda")
                        .font(.headline)
                        .foregroundColor(Color("FontNormal"))
                    Text("Toque no botão acima para que a inteligência artificial analise suas calorias que entraram e saíram, seus treinos, horários e água, gerando recomendações sob medida.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color("CardBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Histórico de Pesagens
    
    private var weightsHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Histórico de Pesagens")
                .font(.headline)
                .foregroundColor(Color("FontNormal"))
                .padding(.horizontal, 20)
            
            if weightEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Nenhuma pesagem registrada")
                        .font(.subheadline.weight(.semibold))
                    Text("Toque em '+ Peso' para registrar seu peso ao longo dos dias.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(Color("CardBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(weightEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.date.formatted(.dateTime.day().month().year().hour().minute().locale(Locale(identifier: "pt_BR"))))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color("FontNormal"))
                                if !entry.notes.isEmpty {
                                    Text(entry.notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text(String(format: "%.1f kg", entry.weight))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Color("FontNormal"))
                            
                            Button {
                                modelContext.delete(entry)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.6))
                                    .padding(.leading, 8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Funções Auxiliares
    
    private func quickAddWater(milliliters: Int) {
        let entry = WaterEntry(milliliters: milliliters, date: Date())
        try? ContaCaDataStore.shared.insertWaterEntry(entry)
    }
    
    private func generateAIAnalysis() {
        isAnalyzingAI = true
        aiErrorMessage = nil
        appliedTargetsSuccessfully = false
        savedRoutineSuccessfully = false
        
        // Garante que todo o histórico esteja consolidado no arquivo físico antes do envio para o Gemini
        AppActivityLogManager.shared.syncFromDatabase(
            foods: foodEntries,
            workouts: workoutEntries,
            waters: waterEntries,
            weights: weightEntries
        )
        
        Task {
            do {
                let result = try await GeminiAIService.shared.analyzeEvolution(
                    foods: foodEntries,
                    workouts: workoutEntries,
                    waters: waterEntries,
                    weights: weightEntries,
                    profile: profile
                )
                await MainActor.run {
                    self.aiAnalysis = result
                    EvolutionAnalysisStore.shared.save(result)
                    self.isAnalyzingAI = false
                    Task {
                        await BackendSyncManager.shared.sync(context: modelContext)
                    }
                }
            } catch {
                await MainActor.run {
                    self.aiErrorMessage = "Erro ao gerar diagnóstico: \(error.localizedDescription)"
                    self.isAnalyzingAI = false
                }
            }
        }
    }
    
    private func applySuggestedTargets(_ targets: SuggestedNutritionTargets) {
        guard let p = profile else { return }
        p.targetCalorieIntake = targets.dailyCalories
        p.targetProtein = targets.proteinGrams
        p.targetCarbohydrates = targets.carbsGrams
        p.targetFat = targets.fatGrams
        p.targetWaterMilliliters = targets.waterMilliliters
        
        try? modelContext.save()
        ContaCaDataStore.shared.syncTodayData()
        
        withAnimation(.spring(duration: 0.35)) {
            appliedTargetsSuccessfully = true
            toastMessage = "Metas de \(Int(targets.dailyCalories)) kcal, macros e \(targets.waterMilliliters)ml de água aplicadas ao perfil!"
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation {
                self.toastMessage = nil
            }
        }
    }
    
    private func saveRecommendedRoutine(_ routineData: AIRecommendedRoutine) {
        let newRoutine = WorkoutRoutine(
            title: routineData.title,
            workoutType: WorkoutType(rawValue: routineData.workoutType) ?? .bodybuilding,
            targetMuscles: routineData.targetMuscles,
            hypertrophyFocus: routineData.hypertrophyFocus,
            estimatedDurationMinutes: routineData.estimatedDurationMinutes,
            estimatedCalories: routineData.estimatedCalories,
            recommendedRestSeconds: routineData.recommendedRestSeconds,
            exercises: routineData.exercises,
            notes: "✨ Gerado por Análise de IA"
        )
        
        try? ContaCaDataStore.shared.insertWorkoutRoutine(newRoutine)
        
        withAnimation(.spring(duration: 0.35)) {
            savedRoutineSuccessfully = true
            toastMessage = "Treino salvo na aba de Treinos com a tag 'Gerado por Análise de IA'!"
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation {
                self.toastMessage = nil
            }
        }
    }
    
    private func syncFromHealthKit() {
        isSyncingHealth = true
        syncStatusMessage = nil
        
        HealthManager.shared.requestAuthorization { success, _ in
            guard success else {
                DispatchQueue.main.async {
                    self.isSyncingHealth = false
                    self.syncStatusMessage = "Permissão do Apple Saúde necessária."
                }
                return
            }
            
            HealthManager.shared.fetchExternalWorkouts(days: 7) { workouts in
                DispatchQueue.main.async {
                    var importedCount = 0
                    let existingIds = Set(workoutEntries.map { "\($0.title)_\($0.date.timeIntervalSince1970)" })
                    
                    for hkWorkout in workouts {
                        let durationMinutes = Int(hkWorkout.duration / 60.0)
                        let caloriesBurned = hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? Double(durationMinutes * 8)
                        let sourceName = hkWorkout.sourceRevision.source.name
                        
                        let workoutType: WorkoutType
                        let title: String
                        switch hkWorkout.workoutActivityType {
                        case .cycling:
                            workoutType = .cycling
                            title = "Pedalada / Bike (\(sourceName))"
                        case .running:
                            workoutType = .running
                            title = "Corrida (\(sourceName))"
                        case .walking:
                            workoutType = .walking
                            title = "Caminhada (\(sourceName))"
                        case .swimming:
                            workoutType = .swimming
                            title = "Natação (\(sourceName))"
                        case .traditionalStrengthTraining:
                            workoutType = .bodybuilding
                            title = "Musculação (\(sourceName))"
                        default:
                            workoutType = .other
                            title = "Treino (\(sourceName))"
                        }
                        
                        let uniqueKey = "\(title)_\(hkWorkout.startDate.timeIntervalSince1970)"
                        if !existingIds.contains(uniqueKey) {
                            let entry = WorkoutEntry(
                                title: title,
                                workoutType: workoutType,
                                durationMinutes: max(1, durationMinutes),
                                caloriesBurned: caloriesBurned,
                                date: hkWorkout.startDate,
                                notes: "Sincronizado via Apple Saúde (\(sourceName))"
                            )
                            modelContext.insert(entry)
                            importedCount += 1
                        }
                    }
                    
                    try? modelContext.save()
                    self.isSyncingHealth = false
                    if importedCount > 0 {
                        self.syncStatusMessage = "✅ \(importedCount) novos treinos (Strava / Saúde) sincronizados!"
                    } else {
                        self.syncStatusMessage = "Tudo atualizado! Nenhum novo treino pendente."
                    }
                }
            }
        }
    }
}

#Preview {
    EvolutionView()
        .modelContainer(PreviewContainer.shared)
}
