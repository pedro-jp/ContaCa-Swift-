//
//  ContaCaCalorieWidget.swift
//  ContaCaWidgets
//
//  Created by João Pedro on 10/29/26.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct CalorieTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieEntry {
        CalorieEntry(date: Date(), data: WidgetCalorieData(
            caloriesConsumed: 1850,
            caloriesTarget: 2800,
            caloriesBurned: 450,
            proteinConsumed: 140,
            proteinTarget: 180,
            carbsConsumed: 220,
            carbsTarget: 350,
            fatConsumed: 55,
            fatTarget: 75,
            goalRaw: "gain"
        ))
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CalorieEntry) -> Void) {
        let data = WidgetDataManager.shared.loadWidgetData()
        let entry = CalorieEntry(date: Date(), data: data)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieEntry>) -> Void) {
        let data = WidgetDataManager.shared.loadWidgetData()
        let entry = CalorieEntry(date: Date(), data: data)
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct CalorieEntry: TimelineEntry {
    let date: Date
    let data: WidgetCalorieData
}

// MARK: - Widget Definition

struct ContaCaCalorieWidget: Widget {
    let kind: String = "ContaCaCalorieWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalorieTimelineProvider()) { entry in
            ContaCaCalorieWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Meta de Calorias")
        .description("Acompanhe suas calorias consumidas, metas e adicione refeições rapidamente.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Main Widget View Switcher

struct ContaCaCalorieWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CalorieEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallCalorieWidgetView(entry: entry)
        case .systemMedium:
            MediumCalorieWidgetView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularWidgetView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularWidgetView(entry: entry)
        case .accessoryInline:
            LockScreenInlineWidgetView(entry: entry)
        default:
            SmallCalorieWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (Estilo Apple / Airbnb Clean)

struct SmallCalorieWidgetView: View {
    let entry: CalorieEntry
    
    private var progress: Double {
        entry.data.progressRatio
    }
    
    private let accentColor = Color(red: 0.32, green: 0.80, blue: 0.55)
    
    var body: some View {
        Link(destination: URL(string: "contaca://voice")!) {
            VStack(alignment: .leading, spacing: 6) {
                // Header sutil
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accentColor)
                        Text("Calorias")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                }
                
                Spacer()
                
                // Ring Central e Números
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 7)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                accentColor,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: "fork.knife")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                    .frame(width: 48, height: 48)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(entry.data.caloriesConsumed))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        
                        Text("de \(Int(entry.data.caloriesTarget)) kcal")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Footer
                HStack {
                    Text(entry.data.remainingCalories > 0 ? "Faltam \(Int(entry.data.remainingCalories)) kcal" : "Meta atingida!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(entry.data.remainingCalories > 0 ? .secondary : accentColor)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Medium Widget (338x158) Estilo Airbnb / Apple

struct MediumCalorieWidgetView: View {
    let entry: CalorieEntry
    
    private var progress: Double {
        entry.data.progressRatio
    }
    
    private let accentColor = Color(red: 0.32, green: 0.80, blue: 0.55)
    
    var body: some View {
        HStack(spacing: 16) {
            // Lado Esquerdo: Balanço de Calorias
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accentColor)
                    Text("Balanço Diário")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(entry.data.caloriesConsumed))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("/ \(Int(entry.data.caloriesTarget)) kcal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Barra de Progresso Fina
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 6)
                        Capsule()
                            .fill(accentColor)
                            .frame(width: max(0, geo.size.width * progress), height: 6)
                    }
                }
                .frame(height: 6)
                
                Text(entry.data.remainingCalories > 0 ? "Faltam \(Int(entry.data.remainingCalories)) kcal" : "Meta batida com sucesso!")
                    .font(.system(size: 11))
                    .foregroundColor(entry.data.remainingCalories > 0 ? .secondary : accentColor)
                
                Spacer()
                
                // Botão Rápido para Adicionar Refeição (Voz / Digitação)
                Link(destination: URL(string: "contaca://voice")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11))
                        Text("Adicionar Refeição")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(accentColor)
                    .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .padding(.vertical, 4)
            
            // Lado Direito: Barras de Macros Limpas
            VStack(alignment: .leading, spacing: 8) {
                Text("Macronutrientes")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                WidgetMacroRow(
                    label: "Proteínas",
                    current: entry.data.proteinConsumed,
                    target: entry.data.proteinTarget,
                    color: Color(red: 0.32, green: 0.80, blue: 0.55)
                )
                
                WidgetMacroRow(
                    label: "Carboidratos",
                    current: entry.data.carbsConsumed,
                    target: entry.data.carbsTarget,
                    color: Color(red: 0.98, green: 0.65, blue: 0.22)
                )
                
                WidgetMacroRow(
                    label: "Gorduras",
                    current: entry.data.fatConsumed,
                    target: entry.data.fatTarget,
                    color: Color(red: 0.95, green: 0.45, blue: 0.32)
                )
                
                Spacer()
            }
            .frame(width: 125)
        }
        .padding(14)
    }
}

// MARK: - Linha de Macro para Widget

struct WidgetMacroRow: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color
    
    private var ratio: Double {
        guard target > 0 else { return 0 }
        return min(1.0, max(0.0, current / target))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(current))g")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * ratio), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Lock Screen Widgets

struct LockScreenCircularWidgetView: View {
    let entry: CalorieEntry
    
    var body: some View {
        Gauge(value: entry.data.caloriesConsumed, in: 0...max(entry.data.caloriesTarget, 1)) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(Int(entry.data.caloriesConsumed))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct LockScreenRectangularWidgetView: View {
    let entry: CalorieEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("ContaCa")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("\(Int(entry.data.progressRatio * 100))%")
                    .font(.system(size: 10, weight: .bold))
            }
            
            Text("\(Int(entry.data.caloriesConsumed)) / \(Int(entry.data.caloriesTarget)) kcal")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            
            ProgressView(value: entry.data.progressRatio)
            
            Text("Restam \(Int(entry.data.remainingCalories)) kcal")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

struct LockScreenInlineWidgetView: View {
    let entry: CalorieEntry
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text("\(Int(entry.data.caloriesConsumed))/\(Int(entry.data.caloriesTarget)) kcal")
        }
    }
}
