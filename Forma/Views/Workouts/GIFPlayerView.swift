//
//  GIFPlayerView.swift
//  Forma
//
//  Created by João Pedro on 10/30/26.
//

import SwiftUI
import ImageIO
import UIKit

/// Componente SwiftUI de alta performance para reproduzir GIFs animados de exercícios
public struct GIFPlayerView: View {
    public let gifName: String
    public var cornerRadius: CGFloat = 16
    public var showControls: Bool = false
    
    @State private var frames: [UIImage] = []
    @State private var totalDuration: TimeInterval = 1.2
    @State private var isPlaying: Bool = true
    @State private var playbackSpeed: Double = 1.0
    
    public init(gifName: String, cornerRadius: CGFloat = 16, showControls: Bool = false) {
        self.gifName = gifName
        self.cornerRadius = cornerRadius
        self.showControls = showControls
    }
    
    public var body: some View {
        ZStack {
            if !frames.isEmpty {
                UIAnimatedImageView(
                    images: frames,
                    duration: totalDuration / playbackSpeed,
                    isPlaying: isPlaying
                )
                .aspectRatio(16/9, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                
                // Controles Opcionais (Play/Pause e Velocidade)
                if showControls {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                playbackSpeed = playbackSpeed == 1.0 ? 0.5 : 1.0
                            } label: {
                                Text(playbackSpeed == 1.0 ? "1.0x" : "0.5x")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Capsule())
                            }
                            .padding(8)
                        }
                        
                        Spacer()
                        
                        HStack {
                            Button {
                                isPlaying.toggle()
                            } label: {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(8)
                            
                            Spacer()
                        }
                    }
                }
            } else {
                // Placeholder elegante de carregamento ou fallback
                ZStack {
                    Color(red: 0.05, green: 0.07, blue: 0.12)
                    VStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 32))
                            .foregroundColor(Color("AccentGreen"))
                        Text("Demonstração de Execução")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .onAppear {
            loadGIF()
        }
        .onChange(of: gifName) { _, _ in
            loadGIF()
        }
    }
    
    private func loadGIF() {
        // Tenta encontrar o arquivo .gif no Bundle principal
        let cleanName = gifName.replacingOccurrences(of: ".gif", with: "")
        
        var fileURL = Bundle.main.url(forResource: cleanName, withExtension: "gif")
        if fileURL == nil {
            fileURL = Bundle.main.url(forResource: cleanName, withExtension: "gif", subdirectory: "ExerciseGIFs")
        }
        
        guard let url = fileURL, let data = try? Data(contentsOf: url) else {
            return
        }
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return
        }
        
        let count = CGImageSourceGetCount(source)
        var extracted: [UIImage] = []
        var calculatedDuration: TimeInterval = 0.0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                extracted.append(UIImage(cgImage: cgImage))
            }
            
            // Extrai a duração do frame
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let gifDict = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                let delay = (gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval)
                    ?? (gifDict[kCGImagePropertyGIFDelayTime] as? TimeInterval)
                    ?? 0.1
                calculatedDuration += max(delay, 0.05)
            } else {
                calculatedDuration += 0.1
            }
        }
        
        self.frames = extracted
        self.totalDuration = max(0.5, calculatedDuration)
    }
}

/// UIViewRepresentable encapsulando um UIImageView nativo para playback otimizado a 60fps
struct UIAnimatedImageView: UIViewRepresentable {
    let images: [UIImage]
    let duration: TimeInterval
    let isPlaying: Bool
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard !images.isEmpty else { return }
        
        if uiView.animationImages != images || uiView.animationDuration != duration {
            uiView.animationImages = images
            uiView.animationDuration = duration
            uiView.image = images.first
            uiView.startAnimating()
        }
        
        if isPlaying {
            if !uiView.isAnimating {
                uiView.startAnimating()
            }
        } else {
            if uiView.isAnimating {
                uiView.stopAnimating()
            }
        }
    }
}
