//
//  FluidBackgroundView.swift
//  Mac Controller
//
//  Created by Rishi Jansari on 29/07/2026.
//

import SwiftUI

struct FluidBackgroundView: View {
    let colors: [Color]
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base background fill using primary extracted color
            (colors.first ?? .black)
                .ignoresSafeArea()
            
            GeometryReader { proxy in
                let size = proxy.size
                
                // Layered liquid color orbs
                ZStack {
                    Circle()
                        .fill(colors.indices.contains(1) ? colors[1] : .purple)
                        .frame(width: size.width * 0.8)
                        .offset(x: animate ? -size.width * 0.2 : size.width * 0.2,
                                y: animate ? -size.height * 0.2 : size.height * 0.1)
                    
                    Circle()
                        .fill(colors.indices.contains(2) ? colors[2] : .blue)
                        .frame(width: size.width * 0.9)
                        .offset(x: animate ? size.width * 0.25 : -size.width * 0.15,
                                y: animate ? size.height * 0.25 : -size.height * 0.1)
                    
                    Circle()
                        .fill(colors.indices.contains(3) ? colors[3] : .teal)
                        .frame(width: size.width * 0.7)
                        .offset(x: animate ? -size.width * 0.1 : size.width * 0.3,
                                y: animate ? size.height * 0.1 : size.height * 0.3)
                }
                .blur(radius: 70) // Softens color blending across entire display
                .scaleEffect(1.2) // Overbleeds screen bounds to prevent edge gaps
            }
            
            // Dark vignette overlay to ensure text remains crisp
            Color.black.opacity(0.35)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
