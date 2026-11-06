//
//  WorkoutLiveActivity.swift
//  ContaCaWidgets
//
//  Created by João Pedro on 10/29/26.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Estado Unificado e Reativo em Tempo Real para a Ilha Dinâmica e Tela Bloqueada
struct ResolvedWorkoutLiveState {
    let title: String
    let exerciseName: String
    let currentSetNumber: Int
    let totalSetsForExercise: Int
    let completedSetsTotal: Int
    let totalSetsTotal: Int
    let caloriesBurned: Double
    let workoutStartDate: Date
    let isResting: Bool
    let restStartDate: Date?
    let restEndDate: Date?
    let restDurationSeconds: Int
    let isAllCompleted: Bool
    
    var overallProgress: Double {
        guard totalSetsTotal > 0 else { return 0 }
        return min(1.0, max(0.0, Double(completedSetsTotal) / Double(totalSetsTotal)))
    }
    
    init(context: ActivityViewContext<WorkoutActivityAttributes>) {
        if let shared = SharedWorkoutSessionManager.shared.loadSession() {
            self.title = shared.title
            self.exerciseName = shared.currentExercise?.name ?? (context.state.currentExerciseName.isEmpty ? "Treino" : context.state.currentExerciseName)
            let maxSets = shared.currentExercise?.sets ?? context.state.totalSetsForExercise
            // Série ativa correta: currentSetIndex + 1 (evita mostrar a série anterior)
            self.currentSetNumber = min(maxSets, max(1, shared.currentSetIndex + 1))
            self.totalSetsForExercise = maxSets
            self.completedSetsTotal = shared.completedSetsCount
            self.totalSetsTotal = shared.totalSetsCount
            self.caloriesBurned = shared.liveCalories
            self.workoutStartDate = shared.sessionStartDate
            self.isResting = shared.isResting
            self.restStartDate = shared.restStartDate
            self.restEndDate = shared.restEndDate
            self.restDurationSeconds = shared.restDurationSeconds
            self.isAllCompleted = shared.isAllCompleted
        } else {
            self.title = context.state.workoutTitle
            self.exerciseName = context.state.currentExerciseName.isEmpty ? "Treino" : context.state.currentExerciseName
            self.currentSetNumber = context.state.currentSetNumber
            self.totalSetsForExercise = context.state.totalSetsForExercise
            self.completedSetsTotal = context.state.completedSetsTotal
            self.totalSetsTotal = context.state.totalSetsTotal
            self.caloriesBurned = context.state.caloriesBurned
            self.workoutStartDate = context.state.workoutStartDate
            self.isResting = context.state.isResting
            self.restStartDate = context.state.restStartDate
            self.restEndDate = context.state.restEndDate
            self.restDurationSeconds = context.state.restDurationSeconds
            self.isAllCompleted = context.state.isAllCompleted
        }
    }
}

public struct WorkoutLiveActivity: Widget {
    public init() {}
    
    private let accentEmerald = Color(red: 0.32, green: 0.80, blue: 0.55)
    private let restOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // MARK: - Banner Interativo na Tela de Bloqueio (Lock Screen)
            let state = ResolvedWorkoutLiveState(context: context)
            WorkoutLockScreenView(state: state)
                .activityBackgroundTint(Color.black.opacity(0.88))
                .activitySystemActionForegroundColor(accentEmerald)
        } dynamicIsland: { context in
            // MARK: - Ilha Dinâmica Interativa (Dynamic Island)
            let state = ResolvedWorkoutLiveState(context: context)
            
            return DynamicIsland {
                // Top Leading (Canto Superior Esquerdo da Ilha)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: state.isResting ? "timer" : "dumbbell.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(state.isResting ? restOrange : accentEmerald)
                        
                        Text(state.isResting ? "DESCANSO" : "TREINO")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(state.isResting ? restOrange : accentEmerald)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                    .padding(.top, 2)
                }
                
                // Top Trailing (Canto Superior Direito da Ilha - Cronômetro Ativo)
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        if state.isResting, let start = state.restStartDate, let end = state.restEndDate, end > Date() {
                            Text(timerInterval: start...end, countsDown: true)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(restOrange)
                        } else if state.isResting {
                            Text("0:00")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(restOrange)
                        } else {
                            Text(state.workoutStartDate, style: .timer)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(accentEmerald)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 2)
                    .padding(.top, 2)
                }
                
                // Bottom: CONTEÚDO PRINCIPAL E BOTÕES INTERATIVOS
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Linha 1: Exercício Atual e Série
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.exerciseName.isEmpty ? state.title : state.exerciseName)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                if state.isAllCompleted {
                                    Text("Todas as séries finalizadas com sucesso!")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(accentEmerald)
                                } else if state.isResting {
                                    Text("Próxima: Série \(state.currentSetNumber) de \(state.totalSetsForExercise)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(restOrange.opacity(0.9))
                                } else {
                                    Text("Série \(state.currentSetNumber) de \(state.totalSetsForExercise) • ~\(Int(state.caloriesBurned)) kcal")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Pílula com progresso geral de séries
                            Text("\(state.completedSetsTotal)/\(state.totalSetsTotal)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        // Linha 2: Botões Interativos (Operação 100% autônoma pela Ilha sem abrir o app)
                        HStack(spacing: 8) {
                            if state.isAllCompleted {
                                Button(intent: FinishWorkoutLiveIntent()) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13, weight: .bold))
                                        Text("Finalizar e Salvar Treino")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(accentEmerald)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .tint(accentEmerald)
                            } else if state.isResting {
                                // Durante o Descanso: +30s e Iniciar Próxima Série
                                Button(intent: AddRestTimeLiveIntent()) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("30s")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color(white: 0.22))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .tint(Color(white: 0.22))
                                
                                Button(intent: SkipRestLiveIntent()) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("Iniciar Série \(state.currentSetNumber)")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(accentEmerald)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .tint(accentEmerald)
                            } else {
                                // Durante a Execução: Concluir Série Atual com 1 toque
                                Button(intent: CompleteSetLiveIntent()) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13, weight: .bold))
                                        Text("Concluir Série (\(state.currentSetNumber)/\(state.totalSetsForExercise))")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(accentEmerald)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .tint(accentEmerald)
                                
                                Button(intent: FinishWorkoutLiveIntent()) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white.opacity(0.85))
                                        .frame(width: 34, height: 34)
                                        .background(Color(white: 0.20))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .tint(Color(white: 0.20))
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                Image(systemName: state.isResting ? "timer" : "dumbbell.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(state.isResting ? restOrange : accentEmerald)
                    .frame(width: 16, alignment: .leading)
            } compactTrailing: {
                HStack(spacing: 0) {
                    if state.isResting, let start = state.restStartDate, let end = state.restEndDate, end > Date() {
                        Text(timerInterval: start...end, countsDown: true)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(restOrange)
                    } else if state.isResting {
                        Text("0:00")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(restOrange)
                    } else {
                        Text(state.workoutStartDate, style: .timer)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(accentEmerald)
                    }
                }
                .minimumScaleFactor(0.8)
                .frame(width: 42, alignment: .trailing)
            } minimal: {
                if state.isResting, let start = state.restStartDate, let end = state.restEndDate, end > Date() {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(restOrange)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                } else if state.isResting {
                    Text("0:00")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(restOrange)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                } else {
                    Text(state.workoutStartDate, style: .timer)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(accentEmerald)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Banner Interativo na Tela Bloqueada
struct WorkoutLockScreenView: View {
    let state: ResolvedWorkoutLiveState
    
    private let accentEmerald = Color(red: 0.32, green: 0.80, blue: 0.55)
    private let restOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(state.isResting ? restOrange.opacity(0.2) : accentEmerald.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: state.isResting ? "timer" : "dumbbell.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(state.isResting ? restOrange : accentEmerald)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(state.exerciseName.isEmpty ? "Treino em Execução" : state.exerciseName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Cronômetro Regressivo ou Tempo Total
                VStack(alignment: .trailing, spacing: 2) {
                    if state.isResting, let start = state.restStartDate, let end = state.restEndDate, end > Date() {
                        Text(timerInterval: start...end, countsDown: true)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(restOrange)
                        Text("Descanso")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else if state.isResting {
                        Text("0:00")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(restOrange)
                        Text("Descanso")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text(state.workoutStartDate, style: .timer)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(accentEmerald)
                        Text("Duração")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Barra de Progresso
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(state.isResting ? restOrange : accentEmerald)
                        .frame(width: max(0, geo.size.width * state.overallProgress), height: 6)
                }
            }
            .frame(height: 6)
            
            // CONTROLES INTERATIVOS NA TELA BLOQUEADA
            HStack(spacing: 10) {
                if state.isAllCompleted {
                    Button(intent: FinishWorkoutLiveIntent()) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Salvar Treino")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(accentEmerald)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .tint(accentEmerald)
                } else if state.isResting {
                    Button(intent: AddRestTimeLiveIntent()) {
                        Text("+30s")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color(white: 0.22))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .tint(Color(white: 0.22))
                    
                    Button(intent: SkipRestLiveIntent()) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                            Text("Iniciar Série \(state.currentSetNumber)")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(accentEmerald)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .tint(accentEmerald)
                } else {
                    Button(intent: CompleteSetLiveIntent()) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Concluir Série (\(state.currentSetNumber)/\(state.totalSetsForExercise))")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(accentEmerald)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .tint(accentEmerald)
                }
            }
        }
        .padding(16)
    }
}
