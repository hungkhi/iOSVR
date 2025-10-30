import Foundation

// MARK: - Persistence Keys (shared)
struct PersistKeys {
    static let characterId = "persist.characterId"
    static let modelName = "persist.modelName"
    static let modelURL = "persist.modelURL"
    static let backgroundURL = "persist.backgroundURL"
    static let roomName = "persist.roomName"
    static let clientId = "persist.clientId"
}

// MARK: - Supabase Configuration

func makeSupabaseRequest(path: String, queryItems: [URLQueryItem]) -> URLRequest? {
    guard var components = URLComponents(string: SUPABASE_URL) else { return nil }
    components.path = path
    components.queryItems = queryItems
    guard let url = components.url else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
    request.setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let cid = ensureClientId() { request.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
    return request
}

// Generate or return a stable client id for guest usage
@discardableResult
func ensureClientId() -> String? {
    if let existing = UserDefaults.standard.string(forKey: PersistKeys.clientId) { return existing }
    let newId = UUID().uuidString
    UserDefaults.standard.set(newId, forKey: PersistKeys.clientId)
    return newId
}

// MARK: - Character API Models
struct CharacterItem: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let description: String?
    let thumbnail_url: String?
    let base_model_url: String?
    let agent_elevenlabs_id: String?
}

// Costume from API
struct CostumeItem: Identifiable, Decodable, Hashable {
    let id: String
    let character_id: String
    let costume_name: String
    let url: String
    let thumbnail: String?
    let model_url: String?
}

// Room from API
struct RoomItem: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let thumbnail: String?
    let image: String
    let created_at: String
    let `public`: Bool
}


