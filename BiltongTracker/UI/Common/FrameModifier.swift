//
//  FrameModifier.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 03/03/2024.
//

import Foundation
import SwiftUI

struct OuterFrame: ViewModifier {
    let background: Color
    let outline: Color
    let shadow: Color
    let cornerRadius: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(background)
                    .shadow(color: shadow, radius: 5, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(outline, lineWidth: 1)
                    )
            )
    }
    
    init(background: Color, outline: Color, shadow: Color, cornerRadius: Double) {
        self.background = background
        self.outline = outline
        self.shadow = shadow
        self.cornerRadius = cornerRadius
    }
}

extension View {
    func enframed(
        background: Color = .white,
        outline: Color = Color.gray.opacity(0.1),
        shadow: Color = Color.gray.opacity(0.3),
        cornerRadius: Double = 20.0
    ) -> some View {
        modifier(OuterFrame(background: background, outline: outline, shadow: shadow, cornerRadius: cornerRadius))
    }
}
