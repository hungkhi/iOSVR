import SwiftUI
import WebKit

// MARK: - Content View Helpers
extension ContentView {
    func persistCharacter(id: String) {
        UserDefaults.standard.set(id, forKey: PersistKeys.characterId)
    }
    
    func persistModel(url: String?, name: String?) {
        if let url = url { 
            UserDefaults.standard.set(url, forKey: PersistKeys.modelURL) 
        } else { 
            UserDefaults.standard.removeObject(forKey: PersistKeys.modelURL) 
        }
        if let name = name { 
            UserDefaults.standard.set(name, forKey: PersistKeys.modelName) 
        }
    }
    
    func persistRoom(name: String, url: String) {
        UserDefaults.standard.set(url, forKey: PersistKeys.backgroundURL)
        UserDefaults.standard.set(name, forKey: PersistKeys.roomName)
    }
    
    func captureAndSaveCurrentBackgroundAndRoom() {
        let bgJS = "(function(){try{const s=getComputedStyle(document.body).backgroundImage;const m=s&&s.match(/url\\(\\\"?([^\\\"]+)\\\"?\\)/);return m?m[1]:'';}catch(e){return ''}})();"
        webViewRef?.evaluateJavaScript(bgJS, completionHandler: { result, _ in
            if let url = result as? String, !url.isEmpty {
                UserDefaults.standard.set(url, forKey: PersistKeys.backgroundURL)
                // Resolve room_id by image URL and upsert id (not raw image)
                var query: [URLQueryItem] = [
                    URLQueryItem(name: "select", value: "id,name"),
                    URLQueryItem(name: "image", value: "eq.\(url)"),
                    URLQueryItem(name: "limit", value: "1")
                ]
                if let req = makeSupabaseRequest(path: "/rest/v1/rooms", queryItems: query) {
                    URLSession.shared.dataTask(with: req) { data, _, _ in
                        guard let data = data,
                              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                              let row = arr.first,
                              let rid = row["id"] as? String else { return }
                        DispatchQueue.main.async {
                            setUserCurrentRoom(roomId: rid)
                        }
                    }.resume()
                }
            }
        })
        webViewRef?.evaluateJavaScript("(function(){try{return window.getCurrentRoomName&&window.getCurrentRoomName();}catch(e){return ''}})();", completionHandler: { result, _ in
            if let name = result as? String {
                UserDefaults.standard.set(name, forKey: PersistKeys.roomName)
                DispatchQueue.main.async { self.currentRoomName = name }
                // No direct upsert for name; server stores only ids
            }
        })
    }
    
    func prefetchCharacterThumbnails() {
        guard let url = URL(string: "https://n8n8n.top/webhook/characters") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            if let items = try? JSONDecoder().decode([CharacterItem].self, from: data) {
                let urls = items.compactMap { $0.thumbnail_url }.compactMap { URL(string: $0) }
                ImagePrefetcher.prefetch(urls: urls)
            }
        }.resume()
    }

    func prefetchCostumeThumbnails(for characterId: String) {
        let effectiveId = characterId.isEmpty ? "74432746-0bab-4972-a205-9169bece07f9" : characterId
        guard let url = URL(string: "https://n8n8n.top/webhook/costumes?character_id=\(effectiveId)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            if let items = try? JSONDecoder().decode([CostumeItem].self, from: data) {
                let urls = items.compactMap { $0.thumbnail }.compactMap { URL(string: $0) }
                ImagePrefetcher.prefetch(urls: urls)
            }
        }.resume()
    }
    
    func prefetchRoomThumbnails() {
        guard let url = URL(string: "https://n8n8n.top/webhook/rooms") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            if let items = try? JSONDecoder().decode([RoomItem].self, from: data) {
                let urls = items.compactMap { $0.thumbnail }.compactMap { URL(string: $0) }
                ImagePrefetcher.prefetch(urls: urls)
            }
        }.resume()
    }
    
    func calculateOpacity(for index: Int) -> Double {
        let total = chatMessages.count
        let fadeWindow = 6
        let start = max(0, total - fadeWindow)
        if index >= start { return 1.0 }
        let distance = Double(start - index)
        let maxDistance: Double = 6.0
        let alpha = max(0.15, 1.0 - distance / maxDistance)
        return alpha
    }
}

