//
//  WorkoutsView.swift
//  ContaCa
//
//  Created by João Pedro on 10/27/26.
//

import SwiftUI
import SwiftData

struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var workouts: [WorkoutEntry]
    @Query(sort: \WorkoutRoutine.createdAt, order: .reverse) private var routines: [WorkoutRoutine]
    @StateObject private var healthVM = HealthViewModel()
    
    @State private var showAddWorkout: Bool = false
    @State private var showAIWorkout: Bool = false
    @State private var selectedExerciseForDetail: ExerciseCatalogItem? = nil
    @State private var activeRoutineToTrain: WorkoutRoutine? = nil
    
    // Treinos favoritados e normais
    private var favoriteRoutines: [WorkoutRoutine] {
        routines.filter { $0.isFavorite }
    }
    
    private var otherRoutines: [WorkoutRoutine] {
        routines.filter { !$0.isFavorite }
    }
    
    // Treinos na semana atual
    private var workoutsThisWeek: [WorkoutEntry] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return workouts.filter { $0.date >= weekInterval.start && $0.date <= weekInterval.end }
    }
    
    // Dias da semana atual em ordem cronológica (Segunda a Domingo)
    private var currentWeekDays: [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Segunda-feira como início da semana (padrão Brasil)
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
    
    private var totalMinutesWeek: Int {
        workoutsThisWeek.reduce(0) { $0 + $1.durationMinutes }
    }
    
    private var totalCaloriesBurnedWeek: Double {
        workoutsThisWeek.reduce(0.0) { $0 + $1.caloriesBurned }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Superior
                    headerView
                    
                    // Calendário Semanal no Topo (Segunda a Domingo)
                    weeklyConsistencyCard
                    
                    // Banner Assistente de Treino & Hipertrofia (IA)
                    aiAssistantBanner
                    
                    // Seção de Fichas de Treino & Favoritos
                    routinesSection
                    
                    // Lista de Histórico de Sessões Realizadas
                    historySection
                }
                .padding(.bottom, 36)
            }
            .id("\(workouts.count)_\(routines.count)")
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                healthVM.loadHealthData()
                seedInitialRoutinesIfNeeded()
            }
            .sheet(isPresented: $showAddWorkout) {
                AddWorkoutView()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showAIWorkout) {
                AIWorkoutLoggerView()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(item: $selectedExerciseForDetail) { item in
                ExerciseDetailView(item: item)
            }
            .fullScreenCover(item: $activeRoutineToTrain) { routine in
                ActiveWorkoutSessionView(
                    title: routine.title,
                    workoutType: routine.workoutType,
                    targetMuscles: routine.targetMuscles,
                    hypertrophyFocus: routine.hypertrophyFocus,
                    baseCalories: routine.estimatedCalories,
                    baseDurationMinutes: routine.estimatedDurationMinutes,
                    initialRestSeconds: routine.recommendedRestSeconds,
                    exercises: routine.exercises,
                    routineToUpdate: routine
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Atividade & Treinos")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Color("FontNormal"))
                Text("Rotinas, hipertrofia e consistência")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                showAddWorkout = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Manual")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color("FontNormal"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color("CardBackground"))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Banner do Assistente de IA
    
    private var aiAssistantBanner: some View {
        Button {
            showAIWorkout = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color("AccentColor"))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Criar ou Calcular Treino")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color("FontNormal"))
                    Text("Descreva seu treino para calcular calorias, biomecânica e criar rotinas com checklist")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color("CardBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color("AccentColor").opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Seção de Fichas de Treino & Favoritos
    
    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Minhas Fichas de Treino")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color("FontNormal"))
                    Text("Treine com checklist e timer de descanso")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    showAIWorkout = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Nova Ficha")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(Color("AccentColor"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color("AccentColor").opacity(0.08))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            
            if routines.isEmpty {
                emptyRoutinesCard
                    .padding(.horizontal, 20)
            } else {
                // Se houver treinos favoritos, destaca primeiro
                VStack(spacing: 12) {
                    ForEach(routines) { routine in
                        RoutineCard(
                            routine: routine,
                            onStart: {
                                activeRoutineToTrain = routine
                            },
                            onToggleFavorite: {
                                try? ContaCaDataStore.shared.toggleFavoriteRoutine(routine)
                            },
                            onDelete: {
                                try? ContaCaDataStore.shared.deleteWorkoutRoutine(routine)
                            },
                            onShowExerciseDetail: { ex in
                                selectedExerciseForDetail = ExerciseCatalog.shared.item(withId: ex.animationId) ?? ExerciseCatalog.shared.findBestMatch(for: ex.name)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var emptyRoutinesCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 34))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("Nenhuma ficha salva")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color("FontNormal"))
            
            Text("Crie sua primeira ficha com o Assistente para acompanhar repetições, descanso e biomecânica.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showAIWorkout = true
            } label: {
                Text("Criar ou Calcular Treino")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color("AccentColor"))
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Consistência Semanal
    
    private var weeklyConsistencyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Semana Atual")
                        .font(.headline)
                        .foregroundColor(Color("FontNormal"))
                    Text("De Segunda a Domingo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color("AccentColor"))
                    Text("\(workoutsThisWeek.count) treinos")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color("AccentColor"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color("AccentMinor"))
                .clipShape(Capsule())
            }
            
            // Indicadores dos 7 dias da semana (Seg a Dom)
            HStack(spacing: 8) {
                let calendar = Calendar.current
                ForEach(currentWeekDays, id: \.self) { day in
                    let hasTrained = workouts.contains { calendar.isDate($0.date, inSameDayAs: day) }
                    let isToday = calendar.isDateInToday(day)
                    let isFuture = day > Date() && !isToday
                    let dayLetter = day.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "pt_BR")))
                        .replacingOccurrences(of: ".", with: "")
                        .capitalized
                    let dayNumber = day.formatted(.dateTime.day())
                    
                    VStack(spacing: 6) {
                        Text(dayLetter)
                            .font(.system(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundColor(isToday ? Color("AccentColor") : .secondary)
                        
                        ZStack {
                            Circle()
                                .fill(hasTrained ? Color("AccentColor") : (isToday ? Color("AccentMinor") : Color.gray.opacity(0.12)))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(isToday ? Color("AccentColor") : Color.clear, lineWidth: 1.5)
                                )
                            
                            if hasTrained {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text(dayNumber)
                                    .font(.system(size: 12, weight: isToday ? .bold : .medium))
                                    .foregroundColor(isFuture ? .secondary.opacity(0.35) : (isToday ? Color("AccentColor") : .secondary))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            Divider()
                .background(Color.primary.opacity(0.08))
            
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tempo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(totalMinutesWeek) min")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color("FontNormal"))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 3) {
                    Text("Gasto em Treinos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(totalCaloriesBurnedWeek)) kcal")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color("AccentGreen"))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ativas no Saúde")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(healthVM.activeCalories)) kcal")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color("AccentColor"))
                }
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
        .padding(.horizontal, 20)
    }
    
    // MARK: - Histórico de Sessões
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Histórico de Sessões")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color("FontNormal"))
                .padding(.horizontal, 20)
            
            if workouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Nenhum treino registrado ainda")
                        .font(.headline)
                    Text("Inicie uma ficha ou descreva o que treinou para registrar.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color("CardBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(workouts) { workout in
                        WorkoutCard(workout: workout) {
                            modelContext.delete(workout)
                            try? modelContext.save()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Seed Inicial de Rotinas
    
    private func seedInitialRoutinesIfNeeded() {
        guard routines.isEmpty else { return }
        
        let routinePeito = WorkoutRoutine(
            title: "Peitoral & Tríceps - Hipertrofia",
            workoutType: .bodybuilding,
            targetMuscles: "Peitoral Maior, Tríceps Braquial, Deltoide Anterior",
            hypertrophyFocus: "Tensão mecânica máxima, amplitude completa e cadência 3-0-1-0 na excêntrica",
            estimatedDurationMinutes: 55,
            estimatedCalories: 380,
            recommendedRestSeconds: 90,
            isFavorite: true,
            exercises: [
                WorkoutExerciseItem(name: "Supino Reto com Barra", sets: 4, reps: "8-10", suggestedWeight: "30kg/lado", targetMuscle: "Peitoral Maior", executionTip: "Escápulas aduzidas e cotovelos a 45º", restSeconds: 90, animationId: "supino_reto"),
                WorkoutExerciseItem(name: "Supino Inclinado com Halteres", sets: 3, reps: "10-12", suggestedWeight: "24kg/halter", targetMuscle: "Peitoral Clavicular", executionTip: "Controle firme na descida profunda", restSeconds: 90, animationId: "supino_inclinado"),
                WorkoutExerciseItem(name: "Crossover na Polia Média", sets: 3, reps: "12-15", suggestedWeight: "15kg/lado", targetMuscle: "Esterno-costal", executionTip: "Pico de contração de 1s no centro", restSeconds: 60, animationId: "crossover_polia"),
                WorkoutExerciseItem(name: "Tríceps Corda na Polia", sets: 4, reps: "10-12", suggestedWeight: "25kg", targetMuscle: "Tríceps Lateral", executionTip: "Abra a corda no final estendendo o cotovelo", restSeconds: 60, animationId: "triceps_corda")
            ]
        )
        try? ContaCaDataStore.shared.insertWorkoutRoutine(routinePeito)
        
        let routinePernas = WorkoutRoutine(
            title: "Pernas Completo - Foco Quadríceps",
            workoutType: .bodybuilding,
            targetMuscles: "Quadríceps, Glúteos, Posteriores",
            hypertrophyFocus: "Alto estresse metabólico e sobrecarga progressiva com alta intensidade",
            estimatedDurationMinutes: 60,
            estimatedCalories: 450,
            recommendedRestSeconds: 120,
            isFavorite: true,
            exercises: [
                WorkoutExerciseItem(name: "Agachamento Livre com Barra", sets: 4, reps: "8-10", suggestedWeight: "40kg/lado", targetMuscle: "Quadríceps & Glúteos", executionTip: "Profundidade abaixo de 90 graus mantendo a coluna neutra", restSeconds: 120, animationId: "agachamento_livre"),
                WorkoutExerciseItem(name: "Leg Press 45°", sets: 4, reps: "10-12", suggestedWeight: "200kg total", targetMuscle: "Quadríceps", executionTip: "Pés na largura dos ombros, não hiperestenda os joelhos no topo", restSeconds: 90, animationId: "leg_press"),
                WorkoutExerciseItem(name: "Cadeira Extensora", sets: 3, reps: "12-15", suggestedWeight: "50kg", targetMuscle: "Reto Femoral", executionTip: "Segure 1 segundo no pico de contração em cima", restSeconds: 60, animationId: "cadeira_extensora"),
                WorkoutExerciseItem(name: "Mesa Flexora", sets: 4, reps: "10-12", suggestedWeight: "45kg", targetMuscle: "Isquiotibiais", executionTip: "Controle a volta excêntrica sem levantar o quadril", restSeconds: 60, animationId: "mesa_flexora")
            ]
        )
        try? ContaCaDataStore.shared.insertWorkoutRoutine(routinePernas)
    }
}

// MARK: - Cartão de Ficha / Rotina Salva

struct RoutineCard: View {
    let routine: WorkoutRoutine
    let onStart: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    var onShowExerciseDetail: ((WorkoutExerciseItem) -> Void)? = nil
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color("AccentColor").opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: routine.workoutType.icon)
                        .font(.system(size: 20))
                        .foregroundColor(Color("AccentColor"))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    if routine.notes.contains("Gerado por Análise de IA") || routine.notes.contains("Análise de IA") {
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
                    }
                    
                    Text(routine.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color("FontNormal"))
                        .lineLimit(1)
                    
                    if !routine.targetMuscles.isEmpty {
                        Text(routine.targetMuscles)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Botão de Favoritar com Toque Direto
                Button(action: onToggleFavorite) {
                    Image(systemName: routine.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 18))
                        .foregroundColor(routine.isFavorite ? .orange : .gray.opacity(0.4))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            
            // Pílulas de Informações
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color("AccentGreen"))
                    Text("~\(Int(routine.estimatedCalories)) kcal")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color("FontNormal"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(routine.estimatedDurationMinutes) min")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
                
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 11))
                        Text("\(routine.exercises.count) exercícios")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Color("AccentColor"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color("AccentColor").opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // Lista Expansível de Exercícios com Acesso ao Info/GIF
            if isExpanded && !routine.exercises.isEmpty {
                VStack(spacing: 6) {
                    ForEach(routine.exercises) { ex in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color("FontNormal"))
                                Text("\(ex.sets)x \(ex.reps) • \(ex.suggestedWeight)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                onShowExerciseDetail?(ex)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 13))
                                    Text("Info")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(Color("AccentColor"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color("AccentColor").opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            
            Divider()
                .background(Color.primary.opacity(0.06))
            
            // Botão Iniciar Treino e Menu
            HStack {
                Button(action: onStart) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Iniciar Treino com Checklist")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color("AccentColor"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Excluir Ficha", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(routine.isFavorite ? Color.orange.opacity(0.3) : Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Card de cada sessão de treino realizada
struct WorkoutCard: View {
    let workout: WorkoutEntry
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("AccentMinor"))
                    .frame(width: 48, height: 48)
                Image(systemName: workout.workoutType.icon)
                    .font(.system(size: 22))
                    .foregroundColor(Color("AccentColor"))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color("FontNormal"))
                
                HStack(spacing: 6) {
                    Text(workout.workoutType.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(Color("AccentColor"))
                    Text("•")
                        .foregroundColor(.gray)
                    Text("\(workout.durationMinutes) min")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text("•")
                        .foregroundColor(.gray)
                    Text("\(Int(workout.caloriesBurned)) kcal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color("AccentGreen"))
                }
                
                if !workout.notes.isEmpty {
                    Text(workout.notes)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(workout.date.formatted(.dateTime.day().month()))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.6))
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

#Preview {
    WorkoutsView()
        .modelContainer(PreviewContainer.shared)
}
