//
//  OnboardingView.swift
//  BookScanPDF
//

import SwiftUI

public struct OnboardingView: View {
    @Binding public var isPresented: Bool
    @State private var currentPage = 0
    
    private let pages: [(title: String, subtitle: String, systemImage: String, color: Color)] = [
        (
            "Rapid Series Capture",
            "Keep the camera open and scan 300–500+ pages consecutively. No editor interruptions, zero shutter lag.",
            "camera.viewfinder",
            Theme.primaryLight
        ),
        (
            "Live Alignment Guide",
            "The smart viewfinder turns vivid green when your page is level, complete, and unskewed.",
            "rectangle.and.hand.point.up.left.fill",
            Theme.successGreen
        ),
        (
            "Streamed Lightweight PDF",
            "Embeds captured pages directly without re-encoding. 100% true to your original scans at tiny file sizes.",
            "doc.zipper",
            Theme.accent
        )
    ]
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: Theme.spacingL) {
                // Top Skip Button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.secondaryLabel)
                    .padding(.horizontal, Theme.spacingL)
                    .padding(.top, Theme.spacingM)
                }
                
                // Paging Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: Theme.spacingXL) {
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(pages[index].color.opacity(0.12))
                                    .frame(width: 160, height: 160)
                                
                                Image(systemName: pages[index].systemImage)
                                    .font(.system(size: 72, weight: .regular))
                                    .foregroundColor(pages[index].color)
                            }
                            
                            VStack(spacing: Theme.spacingM) {
                                Text(pages[index].title)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.label)
                                    .multilineTextAlignment(.center)
                                
                                Text(pages[index].subtitle)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Theme.secondaryLabel)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Theme.spacingL)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                
                // Bottom Button
                VStack(spacing: Theme.spacingM) {
                    if currentPage == pages.count - 1 {
                        PrimaryButton(title: "Get Started", icon: "arrow.right", variant: .accent) {
                            completeOnboarding()
                        }
                    } else {
                        PrimaryButton(title: "Continue", variant: .primary) {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.spacingXL)
                .padding(.bottom, Theme.spacingXL)
            }
        }
    }
    
    private func completeOnboarding() {
        AppSettings.shared.hasCompletedOnboarding = true
        withAnimation {
            isPresented = false
        }
    }
}
