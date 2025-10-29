//
//  VRMApp.swift
//  VRM
//
//  Created by Nguyễn Hùng on 27/10/25.
//

import SwiftUI

@main
struct VRMApp: App {
    @State private var showSplash: Bool = true
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(onModelReady: {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showSplash = false
                    }
                })
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
            // No auto-dismiss; splash hides when model reports loaded
        }
    }
}

private struct SplashView: View {
    @State private var animate: Bool = false
    @State private var image: UIImage? = nil
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: 160, height: 160)
                .scaleEffect(animate ? 1.04 : 0.92)
                .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
            }
        }
        .onAppear {
            // Pulse animation
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                animate = true
            }
            // Try to load from asset catalog first
            if let assetImg = UIImage(named: "Splash") {
                image = assetImg
                return
            }
            // Fallback: look for Splash.png in bundle resources
            if let path = Bundle.main.path(forResource: "Splash", ofType: "png"),
               let fileImg = UIImage(contentsOfFile: path) {
                image = fileImg
            } else {
                print("⚠️ Splash image not found. Ensure 'Splash' exists in Assets.xcassets or as Splash.png in bundle and is part of target.")
            }
        }
    }
}
