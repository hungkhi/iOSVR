import AVFoundation
import Foundation
import Combine

// MARK: - Voice Recording Manager
class VoiceRecordingManager: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var audioMeterLevel: Float = 0.0
    @Published var currentRecordingSamples: [Float] = []
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingStartTime: Date?
    private var recordedFileURL: URL?
    private var meterTimer: Timer?
    
    func startRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            
            switch session.recordPermission {
            case .granted:
                break
            case .undetermined:
                session.requestRecordPermission { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.startRecording(completion: completion)
                        } else {
                            completion(.failure(NSError(domain: "VoiceRecording", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])))
                        }
                    }
                }
                return
            default:
                completion(.failure(NSError(domain: "VoiceRecording", code: -2, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])))
                return
            }
            
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            isRecording = true
            recordingStartTime = Date()
            recordedFileURL = url
            currentRecordingSamples.removeAll()
            
            meterTimer?.invalidate()
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.audioRecorder?.updateMeters()
                let power = self?.audioRecorder?.averagePower(forChannel: 0) ?? -160
                let normalized = max(0.0, min(1.0, (power + 60) / 60))
                DispatchQueue.main.async {
                    self?.audioMeterLevel = Float(normalized)
                    if let samples = self?.currentRecordingSamples, samples.count < 30 {
                        self?.currentRecordingSamples.append(Float(normalized))
                    } else if var samples = self?.currentRecordingSamples {
                        let i = Int.random(in: 0..<30)
                        samples[i] = Float(normalized)
                        self?.currentRecordingSamples = samples
                    }
                }
            }
            
            completion(.success(url))
        } catch {
            isRecording = false
            completion(.failure(error))
        }
    }
    
    func stopRecording() -> (url: URL?, duration: Int, samples: [Float]) {
        meterTimer?.invalidate()
        meterTimer = nil
        audioRecorder?.stop()
        let fileURL = recordedFileURL
        audioRecorder = nil
        isRecording = false
        audioMeterLevel = 0
        
        let duration: Int
        if let start = recordingStartTime {
            duration = max(0, Int(Date().timeIntervalSince(start).rounded()))
        } else {
            duration = 0
        }
        
        recordingStartTime = nil
        let samples = currentRecordingSamples.isEmpty ? Array(repeating: 0.3, count: 20) : currentRecordingSamples
        
        return (fileURL, duration, samples)
    }
}

extension VoiceRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Handle completion if needed
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording = false
    }
}

