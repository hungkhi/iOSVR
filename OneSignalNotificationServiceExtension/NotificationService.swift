//
//  NotificationService.swift
//  OneSignalNotificationServiceExtension
//
//  Created by Nguyễn Hùng on 1/11/25.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }
        
        // Extract avatar URL from OneSignal payload
        var avatarURL: String? = nil
        var characterId: String? = nil
        
        if let userInfo = bestAttemptContent.userInfo as? [String: Any] {
            // Try to find avatar_url in multiple paths
            if let additionalData = userInfo["additionalData"] as? [String: Any] {
                avatarURL = additionalData["avatar_url"] as? String
                characterId = additionalData["character_id"] as? String
            }
            
            if avatarURL == nil, let custom = userInfo["custom"] as? [String: Any],
               let a = custom["a"] as? [String: Any] {
                avatarURL = a["avatar_url"] as? String
                characterId = characterId ?? (a["character_id"] as? String)
            }
            
            if avatarURL == nil, let data = userInfo["data"] as? [String: Any] {
                avatarURL = data["avatar_url"] as? String
                characterId = characterId ?? (data["character_id"] as? String)
            }
        }
        
        // Don't set category here - let OneSignal handle it from the payload
        // Only set targetContentIdentifier for grouping if we have character ID
        // Setting category here might cause crashes if not properly registered
        if let charId = characterId {
            bestAttemptContent.targetContentIdentifier = charId
        }
        
        // If no avatar URL, deliver notification immediately
        guard let imageURLString = avatarURL, !imageURLString.isEmpty,
              let imageURL = URL(string: imageURLString) else {
            contentHandler(bestAttemptContent)
            return
        }
        
        // Download and attach image with timeout protection
        downloadAndAttachImage(url: imageURL, content: bestAttemptContent)
    }
    
    private func downloadAndAttachImage(url: URL, content: UNMutableNotificationContent) {
        // Use a simple download task with proper error handling
        let task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, response, error in
            guard let self = self else {
                // If self is nil, we can't deliver - this shouldn't happen but handle it safely
                return
            }
            
            // If download failed, deliver notification without image
            guard let localURL = localURL, error == nil else {
                self.contentHandler?(content)
                return
            }
            
            // Get file extension
            let fileExtension = url.pathExtension.isEmpty ? "png" : url.pathExtension
            
            // Create unique temp file path
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + "." + fileExtension
            let finalURL = tempDir.appendingPathComponent(fileName)
            
            do {
                // Remove existing file if any
                try? FileManager.default.removeItem(at: finalURL)
                
                // Move downloaded file to final location
                try FileManager.default.moveItem(at: localURL, to: finalURL)
                
                // Create notification attachment - keep it simple to avoid crashes
                let attachment = try UNNotificationAttachment(
                    identifier: "avatar",
                    url: finalURL,
                    options: nil
                )
                
                // Attach to notification content
                content.attachments = [attachment]
                
            } catch {
                // If anything fails, just clean up and continue without attachment
                try? FileManager.default.removeItem(at: finalURL)
            }
            
            // Always call contentHandler to deliver notification (even if attachment failed)
            self.contentHandler?(content)
        }
        
        task.resume()
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before extension terminates - deliver immediately
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
