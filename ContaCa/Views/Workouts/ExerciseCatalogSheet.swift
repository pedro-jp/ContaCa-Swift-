//
//  ExerciseCatalogSheet.swift
//  ContaCa
//
//  Created by João Pedro on 10/30/26.
//

import SwiftUI

/// Modal interativo para explorar o catálogo completo de GIFs e execuções de exercícios
public struct ExerciseCatalogSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public var onSelectExercise: ((ExerciseCatalogItem) -> Void)? = nil
    
    @State private var searchText: String = ""
    @State private var selectedGroup: String = "Todos"
    @State private var itemForDetail: ExerciseCatalogItem? = nil
    
    private let catalog = ExerciseCatalog.shared
    
    public init(onSelectExercise: ((ExerciseCatalogItem) -> Void)? = nil) {
        self.onSelectExercise = onSelectExercise
    }
    
    private var filteredItems: [ExerciseCatalogItem] {
        catalog.items.filter { item in
            let matchesGroup = selectedGroup == "Todos" || item.muscleGroup.lowercased().contains(selectedGroup.lowercased())
            let matchesSearch = searchText.isEmpty ||
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.emphasisMuscle.localizedCaseInsensitiveContains(searchText) ||
                item.targetMuscles.localizedCaseInsensitiveContains(searchText) ||
                item.synonyms.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesGroup && matchesSearch
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Barra de Busca
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Buscar exercício, músculo ou máquina...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Chips de Filtro por Grupo Muscular
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(catalog.muscleGroups, id: \.self) { group in
                            Button {
                                selectedGroup = group
                            } label: {
                                Text(group)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(selectedGroup == group ? .white : Color("FontNormal"))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedGroup == group ? Color("AccentColor") : Color("CardBackground"))
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                
                // Grid de Cards com GIFs e Músculo Iluminado
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(filteredItems) { item in
                            exerciseCard(item: item)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Catálogo de Execuções")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $itemForDetail) { item in
                ExerciseDetailView(item: item) {
                    if let onSelect = onSelectExercise {
                        onSelect(item)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exerciseCard(item: ExerciseCatalogItem) -> some View {
        Button {
            if let onSelect = onSelectExercise {
                onSelect(item)
                dismiss()
            } else {
                itemForDetail = item
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // GIF Preview animado
                ZStack(alignment: .topTrailing) {
                    GIFPlayerView(gifName: item.gifName, cornerRadius: 14, showControls: false)
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 110)
                        .clipped()
                    
                    Text(item.muscleGroup)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Capsule())
                        .padding(6)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color("FontNormal"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color("AccentGreen"))
                            .frame(width: 6, height: 6)
                        Text(item.emphasisMuscle)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color("AccentGreen"))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
            .background(Color("CardBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
