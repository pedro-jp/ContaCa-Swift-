//
//  ContaCaWaterWidget.swift
//  ContaCaWidgets
//
//  Created by João Pedro on 11/01/26.
//

import WidgetKit
import SwiftUI
import AppIntents

public struct ContaCaWaterWidget: Widget {
    public let kind: String = "ContaCaWaterWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalorieTimelineProvider()) { entry in
            ContaCaWaterWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Meta de Água")
        .description("Acompanhe seu consumo diário de água com gráfico redondo e adicione +250ml com 1 toque.")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct ContaCaWaterWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CalorieEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWaterWidgetView(entry: entry)
        case .accessoryCircular:
            LockScreenWaterCircularView(entry: entry)
        case .accessoryRectangular:
            LockScreenWaterRectangularView(entry: entry)
        default:
            SmallWaterWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Water Widget

struct SmallWaterWidgetView: View {
    let entry: CalorieEntry
    
    private var progress: Double {
        entry.data.waterProgressRatio
    }
    
    private let waterColor = Color.cyan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(waterColor)
                    Text("Hidratação")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(waterColor)
            }
            
            // Gráfico Redondo de Água e Valores
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(waterColor.opacity(0.18), lineWidth: 6)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            waterColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "drop.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(waterColor)
                }
                .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.data.waterConsumed)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("de \(entry.data.waterTarget) ml")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer(minLength: 0)
            
            // Botão Interativo +250ml
            Button(intent: AddWaterWidgetIntent(milliliters: 250)) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("250ml de Água")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(waterColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }
}

// MARK: - Lock Screen Water Widgets

struct LockScreenWaterCircularView: View {
    let entry: CalorieEntry
    
    var body: some View {
        Gauge(value: Double(entry.data.waterConsumed), in: 0...max(Double(entry.data.waterTarget), 1.0)) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text("\(entry.data.waterConsumed)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct LockScreenWaterRectangularView: View {
    let entry: CalorieEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                Text("Água Diária")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("\(Int(entry.data.waterProgressRatio * 100))%")
                    .font(.system(size: 10, weight: .bold))
            }
            
            Text("\(entry.data.waterConsumed) / \(entry.data.waterTarget) ml")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            
            ProgressView(value: entry.data.waterProgressRatio)
                .tint(.cyan)
        }
    }
}
