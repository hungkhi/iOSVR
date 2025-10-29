import SwiftUI

// MARK: - Costume Bottom Sheet
struct CostumeSheetView: View {
    @Environment(\ .dismiss) private var dismiss
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var items: [CostumeItem] = []
    var characterId: String = "74432746-0bab-4972-a205-9169bece07f9"
    let onSelect: (CostumeItem) -> Void

    private let grid = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let errorMessage {
                    VStack(spacing: 10) {
                        Text("Failed to load").foregroundStyle(.white)
                        Text(errorMessage).foregroundStyle(.white.opacity(0.7)).font(.footnote)
                        Button("Retry") { let h = UIImpactFeedbackGenerator(style: .medium); h.impactOccurred(); load() }
                    }
                } else if items.isEmpty {
                    VStack(spacing: 10) {
                        Text("No costumes").foregroundStyle(.white.opacity(0.8))
                        Button("Reload") { let h = UIImpactFeedbackGenerator(style: .medium); h.impactOccurred(); load() }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: grid, spacing: 14) {
                            ForEach(items) { item in
                                Button { let h = UIImpactFeedbackGenerator(style: .medium); h.impactOccurred(); onSelect(item); dismiss() } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)).aspectRatio(1, contentMode: .fit)
                                            if let t = item.thumbnail, let u = URL(string: t) {
                                                AsyncImage(url: u) { phase in
                                                    switch phase {
                                                    case .success(let image): image.resizable().scaledToFill()
                                                    case .empty: ProgressView().tint(.white)
                                                    case .failure(_): Color.white.opacity(0.06)
                                                    @unknown default: Color.white.opacity(0.06)
                                                    }
                                                }
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                .aspectRatio(1, contentMode: .fit)
                                            }
                                        }
                                        Text(item.costume_name).font(.footnote).foregroundStyle(.white).lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .background(Color.clear.ignoresSafeArea())
                }
            }
            .background(.ultraThinMaterial.opacity(0.25))
            .navigationTitle("Change Costume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { let h = UIImpactFeedbackGenerator(style: .medium); h.impactOccurred(); dismiss() } label: { Image(systemName: "xmark") } } }
        }
        .onAppear { if items.isEmpty { load() } }
    }

    private func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        items.removeAll()
        let effectiveId = characterId.isEmpty ? "74432746-0bab-4972-a205-9169bece07f9" : characterId
        let urlString = "https://n8n8n.top/webhook/costumes?character_id=\(effectiveId)"
        guard let url = URL(string: urlString) else { isLoading = false; return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error { errorMessage = error.localizedDescription; return }
                guard let data = data else { errorMessage = "No data"; return }
                do { let decoded = try JSONDecoder().decode([CostumeItem].self, from: data); items = decoded } catch { errorMessage = "Decoding error: \(error.localizedDescription)" }
            }
        }.resume()
    }
}

// MARK: - Room Bottom Sheet
struct RoomSheetView: View {
    @Environment(\ .dismiss) private var dismiss
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var items: [RoomItem] = []
    let onSelect: (RoomItem) -> Void

    private let grid = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading { ProgressView().tint(.white) }
                else if let errorMessage {
                    VStack(spacing: 10) {
                        Text("Failed to load").foregroundStyle(.white)
                        Text(errorMessage).foregroundStyle(.white.opacity(0.7)).font(.footnote)
                        Button("Retry") { let h = UIImpactFeedbackGenerator(style: .medium); h.impactOccurred(); load() }
                    }
                } else if items.isEmpty {
                    VStack(spacing: 10) {
                        Text("No rooms").foregroundStyle(.white.opacity(0.8))
                        Button("Reload") { let h = UIImpactFeedbackGenerator(style: .medium); h.impactOccurred(); load() }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: grid, spacing: 14) {
                            ForEach(items) { item in
                                Button { let h = UIImpactFeedbackGenerator(style: .medium); h.impactOccurred(); onSelect(item); dismiss() } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)).aspectRatio(1, contentMode: .fit)
                                            if let t = item.thumbnail, let u = URL(string: t) {
                                                AsyncImage(url: u) { phase in
                                                    switch phase {
                                                    case .success(let image): image.resizable().scaledToFill()
                                                    case .empty: ProgressView().tint(.white)
                                                    case .failure(_): Color.white.opacity(0.06)
                                                    @unknown default: Color.white.opacity(0.06)
                                                    }
                                                }
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                .aspectRatio(1, contentMode: .fit)
                                            }
                                        }
                                        Text(item.name).font(.footnote).foregroundStyle(.white).lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .background(Color.clear.ignoresSafeArea())
                }
            }
            .background(.ultraThinMaterial.opacity(0.25))
            .navigationTitle("Change Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { let h = UIImpactFeedbackGenerator(style: .medium); h.impactOccurred(); dismiss() } label: { Image(systemName: "xmark") } } }
        }
        .onAppear { if items.isEmpty { load() } }
    }

    private func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        items.removeAll()
        let urlString = "https://n8n8n.top/webhook/rooms"
        guard let url = URL(string: urlString) else { isLoading = false; return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error { errorMessage = error.localizedDescription; return }
                guard let data = data else { errorMessage = "No data"; return }
                do { let decoded = try JSONDecoder().decode([RoomItem].self, from: data); items = decoded } catch { errorMessage = "Decoding error: \(error.localizedDescription)" }
            }
        }.resume()
    }
}

// MARK: - Placeholder Page
struct PlaceholderView: View {
    let title: String
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Function is under development").foregroundStyle(.white).font(.headline)
        }
        .navigationTitle(title)
    }
}

// MARK: - Skeleton Loading Views
struct SkeletonCharacterCardView: View {
    private let cornerRadius: CGFloat = 20
    private let horizontalPadding: CGFloat = 16
    private let interItemSpacing: CGFloat = 16
    private let contentPadding: CGFloat = 16
    @State private var animate: Bool = false

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let targetWidth = max(0, (screenWidth - horizontalPadding * 2 - interItemSpacing) / 2.0)

        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.white.opacity(0.06))
            LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.14)).frame(height: 18)
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.10)).frame(width: targetWidth * 0.6, height: 12)
            }
            .padding(.horizontal, contentPadding + 20)
            .padding(.bottom, contentPadding + 10)
            shimmer.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)).allowsHitTesting(false)
        }
        .frame(width: targetWidth, height: targetWidth * 1.3)
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .onAppear { withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { animate = true } }
    }

    private var shimmer: some View {
        GeometryReader { geo in
            let width = geo.size.width
            LinearGradient(gradient: Gradient(stops: [
                .init(color: Color.white.opacity(0.0), location: 0.0),
                .init(color: Color.white.opacity(0.18), location: 0.5),
                .init(color: Color.white.opacity(0.0), location: 1.0)
            ]), startPoint: .leading, endPoint: .trailing)
            .frame(width: width * 0.6)
            .offset(x: animate ? width : -width)
            .blendMode(.plusLighter)
        }
        .opacity(0.55)
    }
}

// MARK: - Thumbnail Prefetcher
enum ImagePrefetcher {
    static func prefetch(urls: [URL]) {
        let session = URLSession.shared
        for url in urls { session.dataTask(with: url) { _, _, _ in }.resume() }
    }
}


