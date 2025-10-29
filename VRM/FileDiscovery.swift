import Foundation

// Simple auto-discovery
struct FileDiscovery {
    static func discoverFiles() -> (vrmFiles: [String], fbxFiles: [String]) {
        var vrmFiles: [String] = []
        var fbxFiles: [String] = []

        if let vrmURLs = Bundle.main.urls(forResourcesWithExtension: "vrm", subdirectory: nil) {
            vrmFiles = vrmURLs.map { $0.lastPathComponent }
        }

        if let fbxURLs = Bundle.main.urls(forResourcesWithExtension: "fbx", subdirectory: nil) {
            fbxFiles = fbxURLs.map { $0.lastPathComponent }
        }

        return (vrmFiles, fbxFiles)
    }

    static func generateFileListJSON() -> String {
        let files = discoverFiles()
        let jsonObject: [String: Any] = [
            "vrmFiles": files.vrmFiles,
            "fbxFiles": files.fbxFiles
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{\"vrmFiles\":[],\"fbxFiles\":[]}"
    }
}


