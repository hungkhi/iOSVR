import SwiftUI

// MARK: - Networking
// CharactersView: fetches from API and displays image + name cards
struct CharactersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var characters: [CharacterItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    let onSelect: (CharacterItem) -> Void

    // Two-column layout of rounded long image cards (top-aligned to avoid stagger overlap)
    private let grid = [
        GridItem(.flexible(), spacing: 16, alignment: .top),
        GridItem(.flexible(), spacing: 16, alignment: .top)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if isLoading {
                    ScrollView {
                        LazyVGrid(columns: grid, spacing: 16, pinnedViews: []) {
                            ForEach(0..<8, id: \.self) { _ in
                                SkeletonCharacterCardView()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text("Failed to load characters")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                        Button("Retry") { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            load() 
                        }
                    }
                    .padding()
                } else if characters.isEmpty {
                    VStack(spacing: 12) {
                        Text("No characters available")
                            .foregroundStyle(.white.opacity(0.8))
                        Button("Reload") { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            load() 
                        }
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: grid, spacing: 16, pinnedViews: []) {
                            ForEach(characters) { item in
                                Button {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    onSelect(item)
                                    dismiss()
                                } label: {
                                    CharacterCardView(item: item)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("Characters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reload") { 
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    load() 
                }
            }
        }
        .onAppear { if characters.isEmpty { load() } }
    }

    private func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        characters.removeAll()
        var request = URLRequest(url: URL(string: "https://n8n8n.top/webhook/characters")!)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error { errorMessage = error.localizedDescription; return }
                guard let data = data else { errorMessage = "No data"; return }
                do {
                    var cleaned = data
                    if var str = String(data: data, encoding: .utf8) {
                        str = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let range = str.range(of: "]", options: .backwards) {
                            let sliced = String(str[str.startIndex..<range.upperBound])
                            if let slicedData = sliced.data(using: .utf8) { cleaned = slicedData }
                        }
                    }
                    let items = try JSONDecoder().decode([CharacterItem].self, from: cleaned)
                    characters = items
                } catch {
                    errorMessage = "Decoding error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}


