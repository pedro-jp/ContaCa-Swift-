//
//  FoodImagePicker.swift
//  Forma
//
//  Utilitário de captura por câmera e compressão otimizada de imagens para o Gemini Vision.
//

import SwiftUI
import UIKit

/// Seletor nativo da câmera / biblioteca para fotografar pratos ou rótulos nutricionais
struct FoodCameraPicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .camera
    var onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: FoodCameraPicker

        init(parent: FoodCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

extension UIImage {
    /// Redimensiona (escala 1x real) e comprime em JPEG otimizado para envio rápido ao Gemini Vision
    func compressedForGemini(maxDimension: CGFloat = 1024, quality: CGFloat = 0.72) -> Data? {
        let currentWidth = size.width
        let currentHeight = size.height
        guard currentWidth > 0, currentHeight > 0 else {
            return jpegData(compressionQuality: quality)
        }

        let longestSide = max(currentWidth, currentHeight)
        let ratio = longestSide > maxDimension ? (maxDimension / longestSide) : 1.0
        let targetSize = CGSize(
            width: (currentWidth * ratio).rounded(),
            height: (currentHeight * ratio).rounded()
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resizedImage.jpegData(compressionQuality: quality)
    }
}
