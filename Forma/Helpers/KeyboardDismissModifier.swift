//
//  KeyboardDismissModifier.swift
//  Forma
//
//  Created by João Pedro on 10/29/26.
//

import SwiftUI
import UIKit

public extension View {
    /// Fecha o teclado ao tocar fora de campos de texto e controles interativos, sem roubar o foco de TextFields
    func dismissKeyboardOnTap() -> some View {
        self.background(NonIntrusiveKeyboardDismissInstaller())
    }
    
    /// Adiciona barra superior no teclado com botão 'OK' para fechar rapidamente
    func withDoneKeyboardToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color("AccentColor"))
            }
        }
    }
}

/// Instala um UITapGestureRecognizer na janela/superview que ignora toques dentro de UITextField, UITextView e UIControl,
/// permitindo focar e editar campos normalmente e dispensando o teclado apenas ao tocar em áreas vazias.
private struct NonIntrusiveKeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = PassthroughInstallerView()
        view.coordinator = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    final class PassthroughInstallerView: UIView {
        weak var coordinator: Coordinator?
        private weak var attachedWindow: UIWindow?
        
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window = self.window, attachedWindow !== window, let coordinator else { return }
            attachedWindow = window
            
            // Evita instalar duplicado na mesma UIWindow
            let alreadyInstalled = (window.gestureRecognizers ?? []).contains { $0.name == "FormaNonIntrusiveKeyboardDismiss" }
            if !alreadyInstalled {
                let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleBackgroundTap))
                tap.name = "FormaNonIntrusiveKeyboardDismiss"
                tap.cancelsTouchesInView = false
                tap.delaysTouchesBegan = false
                tap.delaysTouchesEnded = false
                tap.delegate = coordinator
                window.addGestureRecognizer(tap)
            }
        }
    }
    
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @objc func handleBackgroundTap() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var current: UIView? = touch.view
            while let view = current {
                if view is UITextField || view is UITextView || view is UIControl {
                    return false
                }
                // Evita dispensar o teclado ao tocar na própria barra do teclado ("OK" ou teclas)
                let typeName = String(describing: type(of: view))
                if typeName.contains("Keyboard") || typeName.contains("InputSet") {
                    return false
                }
                current = view.superview
            }
            return true
        }
        
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            return true
        }
    }
}
