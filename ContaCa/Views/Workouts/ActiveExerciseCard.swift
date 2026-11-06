//
//  ActiveExerciseCard.swift
//  ContaCa
//
//  Componentes visuais da Sessão de Treino Ativa: checklist de séries por exercício e timer de descanso (-15s / +30s / Pular).
//

import SwiftUI

struct ActiveRestTimerBanner: View {
    let restStartDate: Date?
    let restEndDate: Date?
    let restTimeRemaining: Int
    let restTimeTotal: Int
    let onAdjustSeconds: (Int) -> Void
    let onSkip: () -> Void

    private var ringProgress: CGFloat {
        guard restTimeTotal > 0 else { return 0 }
        return min(1.0, max(0.0, CGFloat(restTimeRemaining) / CGFloat(restTimeTotal)))
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(FormaTheme.Colors.energyGreen.opacity(0.20), lineWidth: 3.5)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(FormaTheme.Colors.energyGreen, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: restTimeRemaining)

                Image(systemName: "timer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FormaTheme.Colors.energyGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Tempo de Descanso")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                if let start = restStartDate, let end = restEndDate {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(FormaTheme.Colors.energyGreen)
                } else {
                    Text(formatRestTime(restTimeRemaining))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(FormaTheme.Colors.energyGreen)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Button("-15s") {
                    onAdjustSeconds(-15)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(FormaTheme.Colors.primaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.07))
                .clipShape(Capsule())
                .buttonStyle(.plain)

                Button("+30s") {
                    onAdjustSeconds(30)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(FormaTheme.Colors.primaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.07))
                .clipShape(Capsule())
                .buttonStyle(.plain)

                Button("Pular", action: onSkip)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(FormaTheme.Colors.danger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(FormaTheme.Colors.danger.opacity(0.10))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(FormaTheme.Colors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FormaTheme.Colors.energyGreen.opacity(0.25), lineWidth: 0.8)
        )
    }

    private func formatRestTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return mins > 0 ? String(format: "%d:%02d", mins, secs) : "\(secs)s"
    }
}

struct ActiveExerciseCard: View {
    let exercise: WorkoutExerciseItem
    let onOpenInfo: () -> Void
    let onToggleSet: (Int) -> Void

    @State private var showTip: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(FormaTheme.Colors.primaryText)

                    HStack(spacing: 6) {
                        if !exercise.targetMuscle.isEmpty {
                            Text(exercise.targetMuscle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FormaTheme.Colors.brand)
                            Text("•").font(.system(size: 11)).foregroundStyle(.secondary)
                        }

                        Text("\(exercise.sets) séries • \(exercise.reps) reps")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        if !exercise.suggestedWeight.isEmpty {
                            Text("• \(exercise.suggestedWeight)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FormaTheme.Colors.primaryText)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    if !exercise.executionTip.isEmpty {
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                showTip.toggle()
                            }
                        } label: {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(FormaTheme.Colors.warning)
                                .frame(width: 28, height: 28)
                                .background(FormaTheme.Colors.warning.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onOpenInfo) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                            Text("GIF")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(FormaTheme.Colors.brand)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(FormaTheme.Colors.brandSoft)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if showTip && !exercise.executionTip.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(FormaTheme.Colors.warning)
                    Text(exercise.executionTip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FormaTheme.Colors.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Divider().background(Color.primary.opacity(0.06))

            VStack(spacing: 8) {
                ForEach(0..<exercise.sets, id: \.self) { setIndex in
                    let isDone = setIndex < exercise.completedSets.count ? exercise.completedSets[setIndex] : false

                    HStack {
                        Text("Série \(setIndex + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isDone ? .secondary : FormaTheme.Colors.primaryText)
                            .frame(width: 64, alignment: .leading)

                        Text(exercise.reps)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(exercise.restSeconds)s")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)

                        Button {
                            onToggleSet(setIndex)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isDone ? FormaTheme.Colors.brand : Color.primary.opacity(0.08))
                                    .frame(width: 36, height: 36)

                                if isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1.5)
                                        .frame(width: 16, height: 16)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isDone ? FormaTheme.Colors.brand.opacity(0.07) : Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(FormaTheme.Colors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(exercise.isAllSetsCompleted ? FormaTheme.Colors.brand.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
