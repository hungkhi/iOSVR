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
                    withAnimation(.easeInOut(duration: 0.6)) {
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
    @State private var spin: Bool = false
    @State private var image: UIImage? = nil
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    // Loading ring around the image (smaller, thinner, closer)
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .foregroundStyle(
                            AngularGradient(
                                gradient: Gradient(colors: [Color(#colorLiteral(red: 0.556, green: 0.651, blue: 1.0, alpha: 1.0)), Color(#colorLiteral(red: 0.416, green: 0.486, blue: 1.0, alpha: 1.0)), Color(#colorLiteral(red: 0.282, green: 0.733, blue: 0.471, alpha: 1.0)), Color(#colorLiteral(red: 0.556, green: 0.651, blue: 1.0, alpha: 1.0))]),
                                center: .center
                            )
                        )
                        .frame(width: 136, height: 136)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: spin)

                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "cube.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
                }
                .scaleEffect(animate ? 1.04 : 0.92)
            }
        }
        .onAppear {
            // Pulse animation
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                animate = true
            }
            // Spin ring
            spin = true
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
