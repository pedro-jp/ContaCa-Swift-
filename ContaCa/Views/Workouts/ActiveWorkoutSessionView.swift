//
//  ActiveWorkoutSessionView.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import SwiftUI
import SwiftData
import Combine

/// Tela imersiva de auxílio durante o treino: cronômetro ao vivo, checklist interativo de séries e timer de descanso para hipertrofia
struct ActiveWorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let title: String
    let workoutType: WorkoutType
    let targetMuscles: String
    let hypertrophyFocus: String
    let baseCalories: Double
    let baseDurationMinutes: Int
    let initialRestSeconds: Int
    let routineToUpdate: WorkoutRoutine?
    
    @State private var exercises: [WorkoutExerciseItem]
    
    // Início da Sessão para a Ilha Dinâmica (Base comum de contagem)
    @State private var sessionStartDate: Date = Date()
    @State private var currentExerciseIndex: Int = 0
    
    // Cronômetro da Sessão
    @State private var elapsedSeconds: Int = 0
    @State private var isSessionRunning: Bool = true
    
    // Cronômetro de Descanso (Rest Timer com referência de datas)
    @State private var restStartDate: Date? = nil
    @State private var restEndDate: Date? = nil
    @State private var restTimeRemaining: Int = 0
    @State private var restTimeTotal: Int = 90
    @State private var isRestTimerActive: Bool = false
    
    // Feedback de Finalização
    @State private var showFinishConfirmation: Bool = false
    @State private var showCancelConfirmation: Bool = false
    @State private var isCompletedAndSaved: Bool = false
    @State private var expandedExerciseTipId: UUID? = nil
    
    // Catálogo de Execução & GIFs
    @State private var selectedCatalogItemForDetail: ExerciseCatalogItem? = nil
    @State private var showCatalogSheet: Bool = false
    @State private var exerciseIndexToLink: Int? = nil
    
    init(
        title: String,
        workoutType: WorkoutType = .bodybuilding,
        targetMuscles: String = "",
        hypertrophyFocus: String = "",
        baseCalories: Double = 350,
        baseDurationMinutes: Int = 50,
        initialRestSeconds: Int = 90,
        exercises: [WorkoutExerciseItem],
        routineToUpdate: WorkoutRoutine? = nil
    ) {
        self.title = title
        self.workoutType = workoutType
        self.targetMuscles = targetMuscles
        self.hypertrophyFocus = hypertrophyFocus
        self.baseCalories = baseCalories
        self.baseDurationMinutes = baseDurationMinutes
        self.initialRestSeconds = initialRestSeconds > 0 ? initialRestSeconds : 90
        self.routineToUpdate = routineToUpdate
        _exercises = State(initialValue: exercises)
        _restTimeTotal = State(initialValue: initialRestSeconds > 0 ? initialRestSeconds : 90)
    }
    
    // Totais do Checklist
    private var totalSetsCount: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }
    
    private var completedSetsCount: Int {
        exercises.reduce(0) { $0 + $1.completedCount }
    }
    
    private var progressPercentage: Double {
        guard totalSetsCount > 0 else { return 0.0 }
        return Double(completedSetsCount) / Double(totalSetsCount)
    }
    
    // Estimativa de queima calórica dinâmica conforme tempo decorrido
    private var liveEstimatedCalories: Double {
        let minutes = max(1.0, Double(elapsedSeconds) / 60.0)
        let ratePerMinute = baseCalories / max(10.0, Double(baseDurationMinutes))
        return (minutes * ratePerMinute).rounded()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Barra de Progresso e Métricas no Topo
                    sessionHeaderView
                    
                    // Card Flutuante de Descanso de Hipertrofia (Rest Timer)
                    if isRestTimerActive {
                        restTimerCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Lista de Exercícios e Séries (Checklist)
                    ScrollView {
                        VStack(spacing: 16) {
                            // Foco de Hipertrofia
                            if !hypertrophyFocus.isEmpty || !targetMuscles.isEmpty {
                                hypertrophyInfoBanner
                            }
                            
                            // Exercícios
                            ForEach(exercises.indices, id: \.self) { exIndex in
                                exerciseCard(exerciseIndex: exIndex)
                            }
                            
                            // Botão de Conclusão no final da lista
                            finishWorkoutButton
                                .padding(.top, 10)
                                .padding(.bottom, 40)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Treino em Andamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sair") {
                        showCancelConfirmation = true
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finalizar") {
                        showFinishConfirmation = true
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color("AccentColor"))
                }
            }
            .confirmationDialog(
                "Finalizar Treino?",
                isPresented: $showFinishConfirmation,
                titleVisibility: .visible
            ) {
                Button("Concluir e Salvar no App", role: .none) {
                    finishAndSaveWorkout()
                }
                Button("Continuar Treinando", role: .cancel) {}
            } message: {
                Text("Você completou \(completedSetsCount) de \(totalSetsCount) séries em \(formatTime(elapsedSeconds)). O gasto de ~\(Int(liveEstimatedCalories)) kcal será registrado no seu histórico e no app Saúde.")
            }
            .confirmationDialog(
                "Deseja descartar este treino?",
                isPresented: $showCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Descartar Treino", role: .destructive) {
                    stopAllTimers()
                    dismiss()
                }
                Button("Continuar Treinando", role: .cancel) {}
            } message: {
                Text("O progresso desta sessão não será salvo no histórico.")
            }
            .sheet(item: $selectedCatalogItemForDetail) { item in
                ExerciseDetailView(item: item)
            }
            .sheet(isPresented: $showCatalogSheet) {
                ExerciseCatalogSheet { selectedItem in
                    if let idx = exerciseIndexToLink, idx < exercises.count {
                        exercises[idx].animationId = selectedItem.id
                        saveCurrentStateToShared()
                    }
                    showCatalogSheet = false
                }
            }
            .onAppear {
                if let shared = SharedWorkoutSessionManager.shared.loadSession(), !shared.isFinished, shared.title == title {
                    syncFromSharedSession()
                } else {
                    startNewSession()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                syncFromSharedSession()
            }
            .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                self.elapsedSeconds = max(0, Int(Date().timeIntervalSince(sessionStartDate)))
                
                // Sincroniza se houve alteração na Ilha Dinâmica (séries feitas, descanso alterado, etc)
                if let shared = SharedWorkoutSessionManager.shared.loadSession() {
                    if shared.isFinished {
                        finishAndSaveWorkout()
                        return
                    }
                    if shared.completedSetsCount != completedSetsCount || shared.isResting != isRestTimerActive {
                        syncFromSharedSession()
                    }
                }
                
                // Conclui o descanso se o tempo expirou
                if isRestTimerActive, let end = restEndDate {
                    let remaining = Int(end.timeIntervalSinceNow)
                    if remaining <= 0 {
                        stopRestTimer()
                        WorkoutNotificationManager.shared.triggerRestFinishedHapticsAndSound()
                    } else {
                        self.restTimeRemaining = remaining
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var sessionHeaderView: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color("FontNormal"))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Label(workoutType.rawValue, systemImage: workoutType.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color("AccentColor"))
                        
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text("\(completedSetsCount)/\(totalSetsCount) séries feitas")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Cronômetro da Sessão (100% idêntico à Ilha Dinâmica, via Text style: .timer)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color("AccentGreen"))
                        .frame(width: 8, height: 8)
                    
                    Text(sessionStartDate, style: .timer)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Color("FontNormal"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
            }
            
            // Barra de Progresso do Checklist
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(Color("AccentColor"))
                        .frame(width: max(0, geo.size.width * progressPercentage), height: 6)
                        .animation(.spring(duration: 0.3), value: progressPercentage)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color("CardBackground"))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
    
    // Banner de Hipertrofia
    private var hypertrophyInfoBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !targetMuscles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 12))
                        .foregroundColor(Color("AccentColor"))
                    Text(targetMuscles)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color("FontNormal"))
                }
            }
            
            if !hypertrophyFocus.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(hypertrophyFocus)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color("AccentColor").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // Card de Descanso Inteligente (Rest Timer)
    private var restTimerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .trim(from: 0, to: restTimeTotal > 0 ? CGFloat(restTimeRemaining) / CGFloat(restTimeTotal) : 0)
                    .stroke(Color("AccentGreen"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: restTimeRemaining)
                
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("AccentGreen"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Descanso de Hipertrofia")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color("FontNormal"))
                
                if let start = restStartDate, let end = restEndDate {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Color("AccentGreen"))
                } else {
                    Text(formatRestTime(restTimeRemaining))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Color("AccentGreen"))
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Button("+30s") {
                    addRestSeconds(30)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color("FontNormal"))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.12))
                .clipShape(Capsule())
                
                Button("Pular") {
                    stopRestTimer()
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.red.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // Cartão de Exercício com Séries Interativas
    private func exerciseCard(exerciseIndex: Int) -> some View {
        let exercise = exercises[exerciseIndex]
        let isTipExpanded = expandedExerciseTipId == exercise.id
        
        return VStack(alignment: .leading, spacing: 12) {
            // Header do Exercício
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color("FontNormal"))
                    
                    HStack(spacing: 6) {
                        if !exercise.targetMuscle.isEmpty {
                            Text(exercise.targetMuscle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color("AccentColor"))
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(exercise.sets) séries")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text("\(exercise.reps) reps")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        if !exercise.suggestedWeight.isEmpty {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(exercise.suggestedWeight)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color("FontNormal"))
                        }
                    }
                }
                
                Spacer()
                
                // Botão de Info do Exercício (Abre GIF em alta resolução e biomecânica)
                Button {
                    let catalogItem = ExerciseCatalog.shared.item(withId: exercise.animationId) ?? ExerciseCatalog.shared.findBestMatch(for: exercise.name)
                    if let item = catalogItem {
                        selectedCatalogItemForDetail = item
                    } else {
                        exerciseIndexToLink = exerciseIndex
                        showCatalogSheet = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 15))
                        Text("Info")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Color("AccentColor"))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color("AccentColor").opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .background(Color.primary.opacity(0.06))
            
            // Checklist de Séries
            VStack(spacing: 8) {
                ForEach(0..<exercise.sets, id: \.self) { setIndex in
                    let isDone = setIndex < exercise.completedSets.count ? exercise.completedSets[setIndex] : false
                    
                    HStack {
                        // Número da Série
                        Text("Série \(setIndex + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDone ? .secondary : Color("FontNormal"))
                            .frame(width: 60, alignment: .leading)
                        
                        // Meta de Repetições
                        Text(exercise.reps)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Descanso sugerido
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(exercise.restSeconds)s")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                        
                        // Checkmark Interativo
                        Button {
                            toggleSetCompletion(exerciseIndex: exerciseIndex, setIndex: setIndex)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isDone ? Color("AccentColor") : Color.gray.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                
                                if isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 16, height: 16)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isDone ? Color("AccentColor").opacity(0.06) : Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(exercise.isAllSetsCompleted ? Color("AccentColor").opacity(0.3) : Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
    
    // Botão Concluir Treino
    private var finishWorkoutButton: some View {
        Button {
            showFinishConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Concluir Treino (\(completedSetsCount)/\(totalSetsCount) séries)")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color("AccentColor"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color("AccentColor").opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Ações e Lógica
    
    private func toggleSetCompletion(exerciseIndex: Int, setIndex: Int) {
        guard exerciseIndex < exercises.count else { return }
        currentExerciseIndex = exerciseIndex
        var currentSets = exercises[exerciseIndex].completedSets
        while currentSets.count < exercises[exerciseIndex].sets {
            currentSets.append(false)
        }
        
        let willBeDone = !currentSets[setIndex]
        currentSets[setIndex] = willBeDone
        exercises[exerciseIndex].completedSets = currentSets
        
        if willBeDone {
            // Haptic de sucesso ao completar a série
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
            
            // Determina a próxima série a ser realizada (corrige o bug da série anterior)
            let nextSetForRest: Int
            let nextExerciseNameForRest: String
            let nextTotalSetsForRest: Int

            if setIndex + 1 < exercises[exerciseIndex].sets {
                nextSetForRest = setIndex + 2
                nextExerciseNameForRest = exercises[exerciseIndex].name
                nextTotalSetsForRest = exercises[exerciseIndex].sets
            } else if exerciseIndex + 1 < exercises.count {
                nextSetForRest = 1
                nextExerciseNameForRest = exercises[exerciseIndex + 1].name
                nextTotalSetsForRest = exercises[exerciseIndex + 1].sets
            } else {
                nextSetForRest = exercises[exerciseIndex].sets
                nextExerciseNameForRest = exercises[exerciseIndex].name
                nextTotalSetsForRest = exercises[exerciseIndex].sets
            }
            
            // Inicia o Rest Timer com a próxima série correta
            let targetRest = exercises[exerciseIndex].restSeconds > 0 ? exercises[exerciseIndex].restSeconds : initialRestSeconds
            startRestTimer(seconds: targetRest, exerciseName: nextExerciseNameForRest, currentSet: nextSetForRest, totalSets: nextTotalSetsForRest)
        } else {
            updateLiveActivity(isResting: false)
        }
        
        saveCurrentStateToShared()
    }
    
    private func saveCurrentStateToShared() {
        let isAllDone = exercises.allSatisfy { $0.isAllSetsCompleted }
        let sharedState = SharedWorkoutState(
            title: title,
            workoutTypeRaw: workoutType.rawValue,
            exercises: exercises,
            currentExerciseIndex: currentExerciseIndex,
            currentSetIndex: max(0, exercises[currentExerciseIndex].completedCount),
            sessionStartDate: sessionStartDate,
            baseCalories: baseCalories,
            baseDurationMinutes: baseDurationMinutes,
            isResting: isRestTimerActive,
            restStartDate: isRestTimerActive ? restStartDate : nil,
            restEndDate: isRestTimerActive ? restEndDate : nil,
            restDurationSeconds: restTimeTotal,
            isAllCompleted: isAllDone
        )
        SharedWorkoutSessionManager.shared.saveSession(sharedState)
    }
    
    private func syncFromSharedSession() {
        guard let shared = SharedWorkoutSessionManager.shared.loadSession() else { return }
        self.exercises = shared.exercises
        self.currentExerciseIndex = shared.currentExerciseIndex
        self.sessionStartDate = shared.sessionStartDate
        self.elapsedSeconds = max(0, Int(Date().timeIntervalSince(shared.sessionStartDate)))
        if shared.isResting, let end = shared.restEndDate {
            let rem = Int(end.timeIntervalSinceNow)
            if rem > 0 {
                self.restStartDate = shared.restStartDate
                self.restEndDate = shared.restEndDate
                self.restTimeRemaining = rem
                self.restTimeTotal = shared.restDurationSeconds
                withAnimation { self.isRestTimerActive = true }
            } else {
                withAnimation { self.isRestTimerActive = false }
                self.restStartDate = nil
                self.restEndDate = nil
            }
        } else {
            withAnimation { self.isRestTimerActive = false }
            self.restStartDate = nil
            self.restEndDate = nil
        }
    }
    
    private func startNewSession() {
        sessionStartDate = Date()
        elapsedSeconds = 0
        
        saveCurrentStateToShared()
        
        // Inicia na Ilha Dinâmica com a exata sessionStartDate
        let firstExName = exercises.first?.name ?? "Treino"
        let firstSets = exercises.first?.sets ?? 3
        LiveActivityManager.shared.startWorkoutActivity(
            workoutTitle: title,
            currentExerciseName: firstExName,
            currentSetNumber: 1,
            totalSetsForExercise: firstSets,
            completedSetsTotal: completedSetsCount,
            totalSetsTotal: totalSetsCount,
            caloriesBurned: liveEstimatedCalories,
            workoutStartDate: sessionStartDate,
            isResting: false,
            restDurationSeconds: initialRestSeconds,
            isAllCompleted: false
        )
    }
    
    private func startRestTimer(seconds: Int, exerciseName: String, currentSet: Int, totalSets: Int) {
        let now = Date()
        let end = now.addingTimeInterval(Double(seconds))
        restStartDate = now
        restEndDate = end
        restTimeTotal = seconds
        restTimeRemaining = seconds
        withAnimation(.spring(duration: 0.3)) {
            isRestTimerActive = true
        }
        
        saveCurrentStateToShared()
        
        // Agenda notificação Time-Sensitive que vibra e acende a tela mesmo com o celular desligado/bloqueado
        WorkoutNotificationManager.shared.scheduleRestNotification(
            seconds: seconds,
            exerciseName: exerciseName,
            nextSet: currentSet
        )
        
        // Atualiza na Ilha Dinâmica com o exato mesmo intervalo regressivo
        LiveActivityManager.shared.updateWorkoutActivity(
            workoutTitle: title,
            currentExerciseName: exerciseName,
            currentSetNumber: currentSet,
            totalSetsForExercise: totalSets,
            completedSetsTotal: completedSetsCount,
            totalSetsTotal: totalSetsCount,
            caloriesBurned: liveEstimatedCalories,
            workoutStartDate: sessionStartDate,
            isResting: true,
            restStartDate: now,
            restEndDate: end,
            restDurationSeconds: seconds
        )
    }
    
    private func stopRestTimer() {
        withAnimation(.spring(duration: 0.3)) {
            isRestTimerActive = false
        }
        restStartDate = nil
        restEndDate = nil
        WorkoutNotificationManager.shared.cancelRestNotification()
        saveCurrentStateToShared()
        updateLiveActivity(isResting: false)
    }
    
    private func addRestSeconds(_ seconds: Int) {
        guard isRestTimerActive else { return }
        let currentEnd = restEndDate ?? Date()
        let newEnd = currentEnd.addingTimeInterval(Double(seconds))
        restEndDate = newEnd
        restTimeTotal += seconds
        let remaining = max(0, Int(newEnd.timeIntervalSinceNow))
        restTimeRemaining = remaining
        saveCurrentStateToShared()
        
        let currentEx = currentExerciseIndex < exercises.count ? exercises[currentExerciseIndex] : (exercises.first ?? WorkoutExerciseItem(name: "Treino"))
        let activeSetNumber = min(currentEx.sets, max(1, currentEx.completedCount + 1))
        WorkoutNotificationManager.shared.scheduleRestNotification(
            seconds: remaining,
            exerciseName: currentEx.name,
            nextSet: activeSetNumber
        )
        
        LiveActivityManager.shared.updateWorkoutActivity(
            workoutTitle: title,
            currentExerciseName: currentEx.name,
            currentSetNumber: activeSetNumber,
            totalSetsForExercise: currentEx.sets,
            completedSetsTotal: completedSetsCount,
            totalSetsTotal: totalSetsCount,
            caloriesBurned: liveEstimatedCalories,
            workoutStartDate: sessionStartDate,
            isResting: true,
            restStartDate: restStartDate,
            restEndDate: newEnd,
            restDurationSeconds: restTimeTotal
        )
    }
    
    private func updateLiveActivity(isResting: Bool) {
        let currentEx = currentExerciseIndex < exercises.count ? exercises[currentExerciseIndex] : (exercises.first ?? WorkoutExerciseItem(name: "Treino"))
        let activeSetNumber = min(currentEx.sets, max(1, currentEx.completedCount + 1))
        LiveActivityManager.shared.updateWorkoutActivity(
            workoutTitle: title,
            currentExerciseName: currentEx.name,
            currentSetNumber: activeSetNumber,
            totalSetsForExercise: currentEx.sets,
            completedSetsTotal: completedSetsCount,
            totalSetsTotal: totalSetsCount,
            caloriesBurned: liveEstimatedCalories,
            workoutStartDate: sessionStartDate,
            isResting: isResting,
            restStartDate: isResting ? restStartDate : nil,
            restEndDate: isResting ? restEndDate : nil,
            restDurationSeconds: restTimeTotal
        )
    }
    
    private func stopAllTimers() {
        isRestTimerActive = false
        restStartDate = nil
        restEndDate = nil
        WorkoutNotificationManager.shared.cancelRestNotification()
        SharedWorkoutSessionManager.shared.clearSession()
        LiveActivityManager.shared.endWorkoutActivity()
    }
    
    private func finishAndSaveWorkout() {
        stopAllTimers()
        
        let finalSeconds = max(0, Int(Date().timeIntervalSince(sessionStartDate)))
        let finalDuration = max(1, finalSeconds / 60)
        let finalCalories = liveEstimatedCalories
        let workoutNotes = "Checklist: \(completedSetsCount) de \(totalSetsCount) séries concluídas em \(formatTime(finalSeconds))."
        
        let entry = WorkoutEntry(
            title: title,
            workoutType: workoutType,
            durationMinutes: finalDuration,
            caloriesBurned: finalCalories,
            date: Date(),
            notes: workoutNotes
        )
        
        // 1. Salva no SwiftData e sincroniza com Apple Health
        try? ContaCaDataStore.shared.insertWorkoutEntry(entry)
        
        // 2. Atualiza data da rotina se aplicável
        if let routine = routineToUpdate {
            routine.lastTrainedAt = Date()
            try? modelContext.save()
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        dismiss()
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func formatRestTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        } else {
            return "\(secs)s"
        }
    }
}
