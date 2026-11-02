//
//  KeyboardDismissModifier.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import SwiftUI
import UIKit

public extension View {
    /// Fecha o teclado ao tocar em qualquer área externa ou ao rolar
    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardOnTapModifier())
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

public struct DismissKeyboardOnTapModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )
    }
}
