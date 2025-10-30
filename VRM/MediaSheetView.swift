import SwiftUI
import AVKit
// Simple shared cache to keep AVPlayer alive across view lifecycle (prevents black flash)
private final class PlayerCache {
    static let shared = PlayerCache()
    private var map: [String: AVPlayer] = [:]
    private init() {}
    func player(for url: URL, muted: Bool) -> AVPlayer {
        if let p = map[url.absoluteString] {
            p.isMuted = muted
            return p
        }
        let p = AVPlayer(url: url)
        p.isMuted = muted
        p.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { _ in
            p.seek(to: .zero)
            p.play()
        }
        map[url.absoluteString] = p
        return p
    }
}

struct MediaItem: Identifiable, Decodable {
    let id: String
    let url: String
    let thumbnail: String?
    let character_id: String
    let created_at: String?
}

struct MediaSheetView: View {
    let characterId: String
    @State private var items: [MediaItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var lightboxIndex: Int? = nil
    @Environment(\.dismiss) private var dismiss

    private let grid = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.001).ignoresSafeArea()
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else if let errorMessage {
                        VStack(spacing: 10) {
                            Text("Failed to load media")
                                .foregroundStyle(.white)
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.7))
                            Button("Retry") { load() }
                        }
                        .padding()
                    } else if items.isEmpty {
                        Text("No media found")
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        ScrollView {
                            LazyVGrid(columns: grid, spacing: 12) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { pair in
                                    let idx = pair.offset
                                    let item = pair.element
                                    Button(action: { lightboxIndex = idx }) {
                                        MediaCell(item: item)
                                    }
                                    .buttonStyle(.plain)
                                    .onAppear { prewarmAround(index: idx) }
                                }
                            }
                            .padding(12)
                        }
                    }
                }
            }
            .navigationTitle("Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) { Image(systemName: "xmark") }
                }
            }
        }
        .onAppear { if items.isEmpty { load() } }
        .fullScreenCover(isPresented: Binding(get: { lightboxIndex != nil }, set: { if !$0 { lightboxIndex = nil } })) {
            MediaLightboxPager(items: items, startIndex: lightboxIndex ?? 0) { lightboxIndex = nil }
                .preferredColorScheme(.dark)
        }
    }

    private func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        items.removeAll()
        let effectiveId = characterId
        let query: [URLQueryItem] = [
            URLQueryItem(name: "character_id", value: "eq.\(effectiveId)"),
            URLQueryItem(name: "select", value: "id,url,thumbnail,character_id,created_at"),
            URLQueryItem(name: "order", value: "created_at.asc")
        ]
        guard let request = makeSupabaseRequest(path: "/rest/v1/medias", queryItems: query) else { isLoading = false; errorMessage = "Failed to build Supabase media query"; return }
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error { errorMessage = error.localizedDescription; return }
                guard let data else { errorMessage = "No data"; return }
                do {
                    let decoded = try JSONDecoder().decode([MediaItem].self, from: data)
                    items = decoded
                    prefetch(items: decoded)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }.resume()
    }

    private func prefetch(items: [MediaItem]) {
        // Prefetch images (full urls and thumbnails) using existing cache
        let imageURLs: [URL] = items.compactMap { item in
            let u = item.url.lowercased()
            if u.hasSuffix(".mp4") || u.contains("video") {
                return item.thumbnail.flatMap(URL.init(string:))
            }
            return URL(string: item.url)
        }
        ImagePrefetcher.prefetch(urls: imageURLs)

        // Light pre-warm for videos so playback starts quicker
        let videoURLs: [URL] = items.compactMap { item in
            let u = item.url.lowercased()
            return (u.hasSuffix(".mp4") || u.contains("video")) ? URL(string: item.url) : nil
        }
        DispatchQueue.global(qos: .utility).async {
            for url in videoURLs {
                let asset = AVURLAsset(url: url)
                asset.resourceLoader.preloadsEligibleContentKeys = true
                asset.loadValuesAsynchronously(forKeys: ["playable"]) {}
            }
        }
    }

    private func prewarmAround(index: Int) {
        guard !items.isEmpty else { return }
        let candidates = [index + 1, index + 2]
        for i in candidates {
            guard items.indices.contains(i) else { continue }
            let it = items[i]
            let u = it.url.lowercased()
            if u.hasSuffix(".mp4") || u.contains("video"), let url = URL(string: it.url) {
                let p = PlayerCache.shared.player(for: url, muted: true)
                p.currentItem?.preferredForwardBufferDuration = 5
                // Don't start playback here; keep it ready
            }
        }
    }
}

private struct MediaCell: View {
    let item: MediaItem
    @State private var aspect: CGFloat = 0.8
    @State private var player: AVPlayer? = nil
    @State private var isReady: Bool = false
    var body: some View {
        ZStack {
            if item.url.lowercased().hasSuffix(".mp4") || item.url.lowercased().contains("video") {
                // Show skeleton until we computed ratio, then build player
                if isReady {
                    VideoPlayer(player: player)
                        .allowsHitTesting(false)
                        .onAppear {
                            if player == nil { setupPlayer() } else { player?.play() }
                        }
                        .onDisappear { player?.pause() }
                } else {
                    MediaSkeletonView()
                        .aspectRatio(0.8, contentMode: .fit)
                        .task { await updateAspectFromVideo() }
                }
            } else if let imgURL = URL(string: item.url) ?? (item.thumbnail.flatMap(URL.init(string:))) {
                AsyncImage(url: imgURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .onAppear { Task { await updateAspectFromImage(url: imgURL) } }
                    case .empty:
                        MediaSkeletonView()
                            .aspectRatio(0.8, contentMode: .fit)
                            .task { Task { await updateAspectFromImage(url: imgURL) } }
                    case .failure(_): Color.white.opacity(0.06)
                    @unknown default: Color.white.opacity(0.06)
                    }
                }
            } else {
                Color.white.opacity(0.06)
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .contentShape(Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            Group {
                if isReady {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
            }
        )
    }

    private func updateAspectFromVideo() async {
        guard let url = URL(string: item.url) else { return }
        let asset = AVAsset(url: url)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let track = tracks.first {
                let size = try await track.load(.naturalSize)
                let w = max(size.width, 1)
                let h = max(size.height, 1)
                await MainActor.run {
                    let ratio: CGFloat = h == 0 ? 1 : (w / h)
                    aspect = max(ratio, 0.3)
                    isReady = true
                }
            }
        } catch { }
    }

    private func updateAspectFromImage(url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            #if canImport(UIKit)
            if let img = UIImage(data: data) {
                let w = max(img.size.width, 1)
                let h = max(img.size.height, 1)
                await MainActor.run {
                    let ratio: CGFloat = h == 0 ? 1 : (w / h)
                    aspect = max(ratio, 0.3)
                    isReady = true
                }
            }
            #endif
        } catch { }
    }

    private func setupPlayer() {
        guard let url = URL(string: item.url) else { return }
        let p = PlayerCache.shared.player(for: url, muted: true)
        p.play()
        player = p
    }
}

private struct MutedLoopingVideoView: View {
    let urlString: String
    var isMuted: Bool = true
    @State private var player: AVPlayer? = nil
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                if let url = URL(string: urlString) {
                    let p = PlayerCache.shared.player(for: url, muted: isMuted)
                    p.play()
                    player = p
                    // Ensure audio plays even with silent switch
                    let session = AVAudioSession.sharedInstance()
                    try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
                    try? session.setActive(true, options: [])
                }
            }
            .onChange(of: isMuted) { _, newVal in
                player?.isMuted = newVal
                if !newVal {
                    let session = AVAudioSession.sharedInstance()
                    try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
                    try? session.setActive(true, options: [])
                }
            }
            .onDisappear {
                // Keep player cached to avoid black frame when quickly returning
                player?.pause()
            }
    }
}

// MARK: - Skeleton
private struct MediaSkeletonView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.06))
    }
}

private struct MediaLightboxView: View {
    let item: MediaItem
    let onClose: () -> Void
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if item.url.lowercased().hasSuffix(".mp4") || item.url.lowercased().contains("video") {
                    MutedLoopingVideoView(urlString: item.url)
                        .ignoresSafeArea()
                } else if let url = URL(string: item.url) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit().ignoresSafeArea()
                        case .empty: ProgressView().tint(.white)
                        case .failure(_): Color.white.opacity(0.06)
                        @unknown default: Color.white.opacity(0.06)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark.circle.fill").font(.system(size: 24, weight: .bold)) }
                        .tint(.white)
                        .padding(16)
                }
                Spacer()
            }
        }
    }
}

private struct MediaLightboxPager: View {
    let items: [MediaItem]
    let startIndex: Int
    let onClose: () -> Void
    @State private var index: Int = 0
    @State private var isMuted: Bool = false
    @State private var dragY: CGFloat = 0
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea().opacity(max(0.2, 1 - abs(dragY)/400.0))
                TabView(selection: $index) {
                    ForEach(Array(items.enumerated()), id: \.offset) { pair in
                        let it = pair.element
                        ZStack {
                            if it.url.lowercased().hasSuffix(".mp4") || it.url.lowercased().contains("video") {
                                MutedLoopingVideoView(urlString: it.url, isMuted: isMuted)
                                    .ignoresSafeArea()
                            } else if let url = URL(string: it.url) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image): image.resizable().scaledToFit().ignoresSafeArea()
                                    case .empty: ProgressView().tint(.white)
                                    case .failure(_): Color.white.opacity(0.06)
                                    @unknown default: Color.white.opacity(0.06)
                                    }
                                }
                            }
                        }
                        .tag(pair.offset)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .offset(y: dragY)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in dragY = value.translation.height }
                        .onEnded { value in
                            let dy = value.translation.height
                            if dy > 120 { onClose(); return }
                            withAnimation(.easeOut(duration: 0.2)) { dragY = 0 }
                        }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { isMuted.toggle() }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onAppear {
            index = min(max(0, startIndex), max(0, items.count - 1))
            // Autoplay with sound when lightbox shows
            isMuted = false
            prewarmNeighbors()
        }
        .onChange(of: index) { _, _ in prewarmNeighbors() }
    }

    private func prewarmNeighbors() {
        let neighbors = [index + 1, index - 1]
        for i in neighbors {
            guard items.indices.contains(i) else { continue }
            let it = items[i]
            let u = it.url.lowercased()
            if u.hasSuffix(".mp4") || u.contains("video"), let url = URL(string: it.url) {
                let p = PlayerCache.shared.player(for: url, muted: true)
                p.currentItem?.preferredForwardBufferDuration = 5
            }
        }
    }
}


