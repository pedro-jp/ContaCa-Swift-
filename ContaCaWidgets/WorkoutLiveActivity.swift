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

public struct WorkoutLiveActivity: Widget {
    public init() {}
    
    private let accentEmerald = Color(red: 0.32, green: 0.80, blue: 0.55)
    private let restOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // MARK: - Banner Interativo na Tela de Bloqueio (Lock Screen)
            WorkoutLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.88))
                .activitySystemActionForegroundColor(accentEmerald)
        } dynamicIsland: { context in
            // MARK: - Ilha Dinâmica Interativa (Dynamic Island)
            DynamicIsland {
                // Top Leading (Canto Superior Esquerdo da Ilha)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(context.state.isResting ? restOrange : accentEmerald)
                        
                        Text(context.state.isResting ? "DESCANSO" : "TREINO")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(context.state.isResting ? restOrange : accentEmerald)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                    .padding(.top, 2)
                }
                
                // Top Trailing (Canto Superior Direito da Ilha - Full Direita)
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        if context.state.isResting, let start = context.state.restStartDate, let end = context.state.restEndDate {
                            Text(timerInterval: start...end, countsDown: true)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(restOrange)
                        } else {
                            Text(context.state.workoutStartDate, style: .timer)
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
                                Text(context.state.currentExerciseName.isEmpty ? context.state.workoutTitle : context.state.currentExerciseName)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                if context.state.isAllCompleted {
                                    Text("Todas as séries finalizadas com sucesso!")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(accentEmerald)
                                } else if context.state.isResting {
                                    Text("Próxima: Série \(context.state.currentSetNumber) de \(context.state.totalSetsForExercise)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(restOrange.opacity(0.9))
                                } else {
                                    Text("Série \(context.state.currentSetNumber) de \(context.state.totalSetsForExercise) • ~\(Int(context.state.caloriesBurned)) kcal")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Pílula com progresso geral de séries
                            Text("\(context.state.completedSetsTotal)/\(context.state.totalSetsTotal)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        // Linha 2: Botões Interativos (Operação 100% autônoma pela Ilha sem fundo azul)
                        HStack(spacing: 8) {
                            if context.state.isAllCompleted {
                                // Finalizar Treino
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
                            } else if context.state.isResting {
                                // Durante o Descanso: +30s e Iniciar Série
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
                                        Text("Iniciar Série \(context.state.currentSetNumber)")
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
                                // Durante a Execução: Concluir Série com 1 toque
                                Button(intent: CompleteSetLiveIntent()) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13, weight: .bold))
                                        Text("Concluir Série (\(context.state.currentSetNumber)/\(context.state.totalSetsForExercise))")
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
                Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(context.state.isResting ? restOrange : accentEmerald)
                    .frame(width: 16, alignment: .leading)
            } compactTrailing: {
                HStack(spacing: 0) {
                    if context.state.isResting, let start = context.state.restStartDate, let end = context.state.restEndDate {
                        Text(timerInterval: start...end, countsDown: true)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(restOrange)
                    } else {
                        Text(context.state.workoutStartDate, style: .timer)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(accentEmerald)
                    }
                }
                .minimumScaleFactor(0.8)
                .frame(width: 42, alignment: .trailing)
            } minimal: {
                if context.state.isResting, let start = context.state.restStartDate, let end = context.state.restEndDate {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(restOrange)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                } else {
                    Text(context.state.workoutStartDate, style: .timer)
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
    let state: WorkoutActivityAttributes.ContentState
    
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
                        Text(state.workoutTitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(state.currentExerciseName.isEmpty ? "Treino em Execução" : state.currentExerciseName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Cronômetro Regressivo ou Tempo Total
                VStack(alignment: .trailing, spacing: 2) {
                    if state.isResting, let start = state.restStartDate, let end = state.restEndDate {
                        Text(timerInterval: start...end, countsDown: true)
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
