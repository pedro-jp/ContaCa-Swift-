//
//  ContentView.swift
//  ContaCa
//
//  Created by João Pedro on 10/13/26.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HealthViewModel()
    @State private var metaCalorias: Double = 800.0
    @State private var metaPassos: Double = 7500
    private var percentualCalorias: Int {
        guard metaCalorias > 0 else { return 0 }
        return Int(viewModel.calories / metaCalorias * 100)
    }
    
    func saudacao(nome: String) -> String {
        let hora = Calendar.current.component(.hour, from: .now)
        
        let cumprimento: String
        
        switch hora {
        case 5..<12:
            cumprimento = "Bom dia"
        case 12..<18:
            cumprimento = "Boa tarde"
        default:
            cumprimento = "Boa noite"
        }
        
        return "\(cumprimento), \(nome)"
    }
    
    var body: some View {
        ScrollView{
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 20){
                    Image("profile")
                        .resizable()
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 100))
                    VStack(alignment: .leading){
                        Text("MACROLENS IA")
                            .font(.system(size: 12))
                            .foregroundStyle(Color("AccentColor"))
                            .fontWeight(.heavy)
                        Text(saudacao(nome: "João"))
                            .font(.system(size: 23))
                            .foregroundStyle(Color("FontNormal"))
                            .bold()
                    }
                    Spacer()
                    Image(systemName: "bell")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(.gray))
                }
                .foregroundStyle(.blue)
                
                VStack(alignment: .leading){
                    Text("Seu balanço diário")
                        .font(.system(size: 34))
                    Text(
                        Date.now.formatted(
                            .dateTime
                                .weekday(.wide)
                                .day()
                                .month(.wide)
                                .locale(Locale(identifier: "pt_BR"))
                        )
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(.gray)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    HStack{
                        Text("Calorias de Hoje")
                        Spacer()
                        Text("\(percentualCalorias)% da meta")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundColor(Color("AccentColor"))
                            .fontWeight(.bold)
                            .font(.system(size: 10))
                            .background{
                                RoundedRectangle(cornerRadius:12)
                                    .fill(Color("AccentMinor"))
                            }
                    }
                    
                    .font(.system(size: 17))
                    .bold()
                    
                    HStack(alignment: .center){
                        CircularProgress(
                            count: viewModel.calories,
                            meta: metaCalorias,
                            color: Color("AccentColor"),
                            lineWidth: 10
                        )
                        .frame(width: 150, height: 150)
                    }
                    .frame(maxWidth: .infinity)
                    
                    HStack{
                        Macro(count: 145, meta: 500, color: Color("AccentColor"), type: "Carboidratos")
                        Macro(count: 120, meta: 200, color: Color("Green"), type: "Proteinas")
                        Macro(count: 60, meta: 160, color: Color(.gray), type: "Gorduras")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background{
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("CardBackground"))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.gray)
                    
                }
                VStack{
                    HStack{
                        Image(systemName: "figure.walk")
                            .frame(width: 50, height: 50)
                            .foregroundColor(Color("AccentColor"))
                            .background{
                                RoundedRectangle(cornerRadius:12)
                                    .fill(Color("AccentMinor"))
                            }
                        
                        VStack(alignment: .leading, spacing: 0) {
                            HStack{
                                Text("Passos de hoje")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12, weight: .regular))
                                Spacer()
                                Text("/ \(Int(metaPassos))")
                                
                                    .foregroundColor(.gray)
                                    .fontWeight(.bold)
                                    .font(.system(size: 10))
                            }
                            
                            .font(.system(size: 17))
                            .bold()
                            Text("\(Int(viewModel.steps))")
                                .font(.system(size: 32, weight: .bold))
                        }
                        
                    }
                    
                    HorizontalProgress(count: viewModel.steps, meta: metaPassos)
                    
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background{
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("CardBackground"))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.gray)
                    
                }
            }
            .padding(20)
            .padding(.vertical, 30)
            .frame(maxHeight: .infinity, alignment: .top)
            .onAppear {
                viewModel.loadHealthData()
            }
        }
    }
}

#Preview{
    HomeView()
}


struct CircularProgress: View {
    var count: Double
    var meta: Double
    var color: Color = Color(red: 84/255, green: 225/255, blue: 195/255)
    var lineWidth: CGFloat = 10
    
    var progress: Double {
        guard meta > 0 else { return 0 }
        return count / meta
    }
    
    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }
    
    var body: some View {
        ZStack {
            // Fundo: círculo completo de 360°
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            // Progresso atual
            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            
            VStack{
                Text("\(Int(count))")
                    .font(.system(size: 34, weight: .regular))
                Text("de \(Int(meta)) kcal")
                    .foregroundColor(.gray)
                    .font(.system(size: 11, weight: .light))
                Text("Restam \(Int(meta - count))")
                    .foregroundColor(Color("Green"))
                    .font(.system(size: 11))
            }
        }
    }
}

struct HorizontalProgress: View {
    var count: Double
    var meta: Double
    var color: Color = Color(red: 84/255, green: 225/255, blue: 195/255)
    var height: CGFloat = 5
    
    private var progress: Double {
        guard meta > 0 else { return 0 }
        return min(max(count / meta, 0), 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.2))
                
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: height)
    }
}


struct Macro: View {
    var count: Double
    var meta: Double
    var color: Color
    var type: String
    
    
    var body: some View{
        VStack(alignment: .leading, spacing: 5){
            Text(type)
                .foregroundColor(.gray)
                .font(.system(size: 11, weight: .regular))
            HStack(spacing: 4){
                Text("\(Int(count))")
                    .font(.system(size: 18, weight: .semibold))
                Text("g")
                    .foregroundColor(.gray)
                    .font(.system(size: 11, weight: .regular))
                    .offset(y: 2)
            }
            HorizontalProgress(
                count: count,
                meta: meta,
                color: color
            )
            .frame(maxWidth: .infinity)
            
        }
        .frame(width: 100)
    }
}

