import Foundation

// MARK: - Persistence Keys (shared)
struct PersistKeys {
    static let characterId = "persist.characterId"
    static let modelName = "persist.modelName"
    static let modelURL = "persist.modelURL"
    static let backgroundURL = "persist.backgroundURL"
    static let roomName = "persist.roomName"
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


