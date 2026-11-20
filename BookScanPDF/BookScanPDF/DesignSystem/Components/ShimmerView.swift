//
//  ShimmerView.swift
//  BookScanPDF
//

import SwiftUI

public struct ShimmerView: View {
    @State private var isAnimating = false
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.gray.opacity(0.18)
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.35),
                        Color.white.opacity(0.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(25))
                .offset(x: isAnimating ? geometry.size.width * 1.5 : -geometry.size.width * 1.5)
            }
            .clipped()
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.4)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
        }
    }
}
