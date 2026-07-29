//
//  Extension-Image.swift
//  Mac Controller
//
//  Created by Rishi Jansari on 29/07/2026.
//

import UIKit
import SwiftUI

extension UIImage {
    /// Extracts the top most frequently occurring vibrant colors from the image
    func extractDominantColors(count: Int = 5) -> [Color] {
        let sampleSize = CGSize(width: 20, height: 20) // 400 sample points
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: sampleSize, format: format)
        let resized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: sampleSize))
        }
        
        guard let cgImage = resized.cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return [.blue, .purple, .indigo, .teal, .cyan]
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        var colorCounts: [UIColor: Int] = [:]
        
        for y in 0..<20 {
            for x in 0..<20 {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = CGFloat(ptr[offset]) / 255.0
                let g = CGFloat(ptr[offset + 1]) / 255.0
                let b = CGFloat(ptr[offset + 2]) / 255.0
                
                // Quantize RGB slightly to group similar shades together
                let qR = (r * 8).rounded() / 8
                let qG = (g * 8).rounded() / 8
                let qB = (b * 8).rounded() / 8
                
                let uiColor = UIColor(red: qR, green: qG, blue: qB, alpha: 1.0)
                
                var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
                uiColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
                
                // Filter out extreme blacks/whites
                if bri > 0.1 && bri < 0.95 {
                    colorCounts[uiColor, default: 0] += 1
                }
            }
        }
        
        // Sort colors by frequency of occurrence
        let sortedColors = colorCounts.sorted { $0.value > $1.value }.map { Color($0.key) }
        
        if sortedColors.isEmpty {
            return [.purple, .indigo, .blue, .teal, .cyan]
        }
        
        // Fill remaining slots if fewer than requested colors were found
        var result = Array(sortedColors.prefix(count))
        let fallbacks: [Color] = [.blue, .purple, .indigo, .teal]
        while result.count < count {
            result.append(fallbacks.randomElement()!)
        }
        
        return result
    }
}
