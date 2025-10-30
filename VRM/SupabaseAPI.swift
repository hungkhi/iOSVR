import Foundation

// MARK: - Supabase Configuration
private let SUPABASE_URL: String = "https://sgkkvcrnjlpqybevzxiy.supabase.co"
private let SUPABASE_ANON_KEY: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNna2t2Y3JuamxwcXliZXZ6eGl5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2MjA1MTEsImV4cCI6MjA3NzE5NjUxMX0.Jt0GI2EcQYwVF3eqyK2y9avYBN4I6KwsOPiAHKp4YAs"

fileprivate func makeSupabaseRequest(path: String, queryItems: [URLQueryItem]) -> URLRequest? {
    guard var components = URLComponents(string: SUPABASE_URL) else { return nil }
    components.path = path
    components.queryItems = queryItems
    guard let url = components.url else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
    request.setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
}

// MARK: - Supabase Models
struct CharacterItem: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let description: String?
    let thumbnail_url: String?
    let base_model_url: String?
    let agent_elevenlabs_id: String?
}

struct CostumeItem: Identifiable, Decodable, Hashable {
    let id: String
    let character_id: String
    let costume_name: String
    let url: String
    let thumbnail: String?
    let model_url: String?
}

struct MediaItem: Identifiable, Decodable, Hashable {
    let id: String
    let url: String
    let thumbnail: String?
    let character_id: String
    let created_at: String?
}

// MARK: - Supabase API Service
enum SupabaseAPI {
    static func getCharacters(completion: @escaping (Result<[CharacterItem], Error>) -> Void) {
        let query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "id,name,description,thumbnail_url,base_model_url,agent_elevenlabs_id"),
            URLQueryItem(name: "is_public", value: "is.true"),
            URLQueryItem(name: "order", value: "order.nullsfirst")
        ]
        guard let request = makeSupabaseRequest(path: "/rest/v1/characters", queryItems: query) else {
            completion(.failure(NSError(domain: "Supabase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid request for characters"])))
            return
        }
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(NSError(domain: "Supabase", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data for characters"]))); return }
            do {
                let decoded = try JSONDecoder().decode([CharacterItem].self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    static func getCostumes(for characterId: String, completion: @escaping (Result<[CostumeItem], Error>) -> Void) {
        let query: [URLQueryItem] = [
            URLQueryItem(name: "character_id", value: "eq.\(characterId)"),
            URLQueryItem(name: "select", value: "id,character_id,costume_name,url,thumbnail,model_url"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        guard let request = makeSupabaseRequest(path: "/rest/v1/character_costumes", queryItems: query) else {
            completion(.failure(NSError(domain: "Supabase", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid request for costumes"])))
            return
        }
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(NSError(domain: "Supabase", code: 4, userInfo: [NSLocalizedDescriptionKey: "No data for costumes"]))); return }
            do {
                let decoded = try JSONDecoder().decode([CostumeItem].self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    static func getMedias(for characterId: String, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
        let query: [URLQueryItem] = [
            URLQueryItem(name: "character_id", value: "eq.\(characterId)"),
            URLQueryItem(name: "select", value: "id,url,thumbnail,character_id,created_at"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        guard let request = makeSupabaseRequest(path: "/rest/v1/medias", queryItems: query) else {
            completion(.failure(NSError(domain: "Supabase", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid request for medias"])))
            return
        }
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(NSError(domain: "Supabase", code: 6, userInfo: [NSLocalizedDescriptionKey: "No data for medias"]))); return }
            do {
                let decoded = try JSONDecoder().decode([MediaItem].self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
