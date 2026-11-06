//
//  PreviewContainer.swift
//  Forma
//
//  Created by João Pedro on 10/27/26.
//

import Foundation
import SwiftData

@MainActor
public struct PreviewContainer {
    public static let shared: ModelContainer = {
        let schema = Schema([
            Profile.self,
            Health.self,
            FoodEntry.self,
            WorkoutEntry.self,
            WeightEntry.self,
            WorkoutRoutine.self,
            WaterEntry.self
        ])
        
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            
            // Popula perfil padrão
            let profile = Profile()
            context.insert(profile)
            
            let health = Health()
            context.insert(health)
            
            context.insert(WaterEntry(milliliters: 500, date: Date()))
            context.insert(WaterEntry(milliliters: 300, date: Date()))
            
            // Popula alimentos de exemplo consumidos hoje para os previews
            let f1 = FoodEntry(
                name: "Peito de Frango Grelhado",
                brand: "Proteína",
                mealType: .lunch,
                portionGrams: 150,
                calories: 248,
                protein: 46.5,
                carbohydrates: 0,
                fat: 5.4,
                date: Date()
            )
            let f2 = FoodEntry(
                name: "Arroz Branco Cozido",
                brand: "Carboidrato",
                mealType: .lunch,
                portionGrams: 200,
                calories: 260,
                protein: 5.4,
                carbohydrates: 56.4,
                fat: 0.6,
                date: Date()
            )
            let f3 = FoodEntry(
                name: "Banana Prata com Aveia",
                brand: "Café da Manhã",
                mealType: .breakfast,
                portionGrams: 120,
                calories: 190,
                protein: 5.2,
                carbohydrates: 38.0,
                fat: 2.5,
                date: Date()
            )
            context.insert(f1)
            context.insert(f2)
            context.insert(f3)
            
            // Treino de exemplo
            let workout = WorkoutEntry(
                title: "Treino A - Peito e Tríceps",
                workoutType: .bodybuilding,
                durationMinutes: 55,
                caloriesBurned: 380,
                date: Date()
            )
            context.insert(workout)
            
            // Peso de exemplo
            let weight = WeightEntry(weight: 72.5, date: Date(), notes: "Em jejum")
            context.insert(weight)
            
            // Fichas de Treino de Exemplo (Favoritas)
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
                    WorkoutExerciseItem(name: "Supino Reto com Barra", sets: 4, reps: "8-10", suggestedWeight: "30kg/lado", targetMuscle: "Peitoral Maior", executionTip: "Escápulas aduzidas e cotovelos a 45º", restSeconds: 90),
                    WorkoutExerciseItem(name: "Supino Inclinado com Halteres", sets: 3, reps: "10-12", suggestedWeight: "24kg/halter", targetMuscle: "Peitoral Clavicular", executionTip: "Controle firme na descida profunda", restSeconds: 90),
                    WorkoutExerciseItem(name: "Crossover na Polia Média", sets: 3, reps: "12-15", suggestedWeight: "15kg/lado", targetMuscle: "Esterno-costal", executionTip: "Pico de contração de 1s no centro", restSeconds: 60),
                    WorkoutExerciseItem(name: "Tríceps Corda na Polia", sets: 4, reps: "10-12", suggestedWeight: "25kg", targetMuscle: "Tríceps Lateral", executionTip: "Abra a corda no final estendendo o cotovelo", restSeconds: 60)
                ]
            )
            context.insert(routinePeito)
            
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
                    WorkoutExerciseItem(name: "Agachamento Livre com Barra", sets: 4, reps: "8-10", suggestedWeight: "40kg/lado", targetMuscle: "Quadríceps & Glúteos", executionTip: "Profundidade abaixo de 90 graus mantendo a coluna neutra", restSeconds: 120),
                    WorkoutExerciseItem(name: "Leg Press 45°", sets: 4, reps: "10-12", suggestedWeight: "200kg total", targetMuscle: "Quadríceps", executionTip: "Pés na largura dos ombros, não hiperestenda os joelhos no topo", restSeconds: 90),
                    WorkoutExerciseItem(name: "Cadeira Extensora", sets: 3, reps: "12-15", suggestedWeight: "50kg", targetMuscle: "Reto Femoral", executionTip: "Segure 1 segundo no pico de contração em cima", restSeconds: 60),
                    WorkoutExerciseItem(name: "Mesa Flexora", sets: 4, reps: "10-12", suggestedWeight: "45kg", targetMuscle: "Isquiotibiais", executionTip: "Controle a volta excêntrica sem levantar o quadril", restSeconds: 60)
                ]
            )
            context.insert(routinePernas)
            
            try? context.save()
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
}
