//
//  AutoScrollingText.swift
//  Mac Controller
//
//  Created by Rishi Jansari on 29/07/2026.
//

import SwiftUI

struct AutoScrollingText: View {
    let text: String
    let font: Font
    let fontWeight: Font.Weight
    let foregroundColor: Color
    
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var scrollToPosition: String = "START"
    
    private var isOverflowing: Bool {
        textWidth > containerWidth && containerWidth > 0
    }
    
    var body: some View {
        GeometryReader { proxy in
            let hostWidth = proxy.size.width
            
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        // Start marker
                        Color.clear.frame(width: 0, height: 0).id("START")
                        
                        Text(text)
                            .font(font)
                            .fontWeight(fontWeight)
                            .foregroundColor(foregroundColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .background(
                                GeometryReader { textProxy in
                                    Color.clear
                                        .onAppear {
                                            updateSizes(textW: textProxy.size.width, hostW: hostWidth)
                                        }
                                        .onChange(of: text) { _, _ in
                                            scrollToPosition = "START"
                                            scrollProxy.scrollTo("START", anchor: .leading)
                                            updateSizes(textW: textProxy.size.width, hostW: hostWidth)
                                        }
                                }
                            )
                        
                        // End marker
                        Color.clear.frame(width: 0, height: 0).id("END")
                    }
                }
                .disabled(!isOverflowing)
                .onChange(of: scrollToPosition) { _, target in
                    let duration = max(3.0, Double((textWidth - containerWidth) / 25.0))
                    withAnimation(.easeInOut(duration: target == "END" ? duration : duration)) {
                        scrollProxy.scrollTo(target, anchor: target == "END" ? .trailing : .leading)
                    }
                }
                .task(id: isOverflowing) {
                    guard isOverflowing else { return }
                    
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(2))
                        if Task.isCancelled { break }
                        scrollToPosition = "END"
                        
                        let duration = max(3.0, Double((textWidth - containerWidth) / 25.0))
                        try? await Task.sleep(for: .seconds(duration + 2.0))
                        if Task.isCancelled { break }
                        scrollToPosition = "START"
                    }
                }
            }
            // MARK: Trailing Gradient Blur Mask
            .mask(
                HStack(spacing: 0) {
                    Rectangle().fill(Color.black)
                    
                    if isOverflowing {
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 20)
                    }
                }
            )
        }
        .frame(height: fontHeight)
    }
    
    private func updateSizes(textW: CGFloat, hostW: CGFloat) {
        DispatchQueue.main.async {
            self.textWidth = textW
            self.containerWidth = hostW
        }
    }
    
    private var fontHeight: CGFloat {
        switch font {
            case .title: return 34
            case .title2: return 28
            case .headline: return 22
            default: return 20
        }
    }
}
