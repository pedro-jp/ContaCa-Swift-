//
//  ExerciseDetailView.swift
//  ContaCa
//
//  Created by João Pedro on 10/30/26.
//

import SwiftUI

/// Tela detalhada com GIF animado, anatomia hipertrofiada e instruções completas de execução biomecânica
public struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    public let item: ExerciseCatalogItem
    public var onSelect: (() -> Void)? = nil
    
    public init(item: ExerciseCatalogItem, onSelect: (() -> Void)? = nil) {
        self.item = item
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // GIF Animado com Anatomia e Músculo Iluminado
                    VStack(spacing: 8) {
                        GIFPlayerView(gifName: item.gifName, cornerRadius: 18, showControls: true)
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                        
                        Text("Demonstração em loop do movimento completo")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Card Principal de Músculos & Ênfase
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            Text(item.name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Color("FontNormal"))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer(minLength: 8)
                            
                            Text(item.muscleGroup)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color("AccentColor"))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color("AccentColor").opacity(0.1))
                                .clipShape(Capsule())
                        }
                        
                        // Destaque de Ênfase Muscular (Sarado & Hipertrofiado)
                        HStack(spacing: 10) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Color("AccentGreen"))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ÊNFASE MUSCULAR ATIVA")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(item.emphasisMuscle)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color("AccentGreen"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("AccentGreen").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        // Músculos Recrutados
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MÚSCULOS RECRUTADOS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(item.targetMuscles)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("FontNormal"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    
                    // Passo a Passo de Execução
                    VStack(alignment: .leading, spacing: 16) {
                        Text("COMO EXECUTAR CORRETAMENTE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        instructionRow(
                            stepNumber: "1",
                            title: "Postura & Posição Inicial",
                            description: item.setupInstruction,
                            icon: "figure.walk",
                            accentColor: .blue
                        )
                        
                        instructionRow(
                            stepNumber: "2",
                            title: "Descida Controlada",
                            description: item.eccentricInstruction,
                            icon: "arrow.down.circle.fill",
                            accentColor: .orange
                        )
                        
                        instructionRow(
                            stepNumber: "3",
                            title: "Subida & Contração",
                            description: item.concentricInstruction,
                            icon: "arrow.up.circle.fill",
                            accentColor: Color("AccentGreen")
                        )
                        
                        instructionRow(
                            stepNumber: "4",
                            title: "Respiração & Firmeza do Abdômen",
                            description: item.breathingInstruction,
                            icon: "lungs.fill",
                            accentColor: .teal
                        )
                        
                        instructionRow(
                            stepNumber: "5",
                            title: "Erro Comum a Evitar",
                            description: item.commonMistake,
                            icon: "exclamationmark.triangle.fill",
                            accentColor: .red
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    
                    if let onSelect = onSelect {
                        Button {
                            onSelect()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Vincular Este GIF ao Exercício")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("AccentColor"))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Como Executar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func instructionRow(
        stepNumber: String,
        title: String,
        description: String,
        icon: String,
        accentColor: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
            }
            .fixedSize()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color("FontNormal"))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
