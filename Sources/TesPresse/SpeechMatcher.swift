import AVFoundation
import Foundation

@MainActor
final class SpeechMatcher: NSObject, AVAudioRecorderDelegate {
    var onTranscript: ((String) -> Void)?
    var onListeningStateChange: ((Bool) -> Void)?
    var onTranscriptionStateChange: ((Bool) -> Void)?

    private let configurationProvider: () -> VoiceServiceConfiguration
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var transcriptionTask: Task<Void, Never>?

    init(configurationProvider: @escaping () -> VoiceServiceConfiguration) {
        self.configurationProvider = configurationProvider
        super.init()
    }

    func startListening() {
        Task {
            let microphoneGranted = await requestMicrophoneAccess()

            guard microphoneGranted else {
                onTranscript?("Microphone permission is required.")
                onListeningStateChange?(false)
                return
            }

            stopListening(cancelTranscription: true)

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("tespresse-\(UUID().uuidString)")
                .appendingPathExtension("wav")

            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]

            do {
                let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
                recorder.delegate = self
                recorder.prepareToRecord()
                recorder.record()
                audioRecorder = recorder
                recordingURL = outputURL
                onListeningStateChange?(true)
            } catch {
                onTranscript?("Unable to start recording: \(error.localizedDescription)")
                onListeningStateChange?(false)
            }
        }
    }

    func stopListening(cancelTranscription: Bool = false) {
        audioRecorder?.stop()
        audioRecorder = nil
        onListeningStateChange?(false)

        if cancelTranscription {
            transcriptionTask?.cancel()
            transcriptionTask = nil
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.handleFinishedRecording(successfully: flag)
        }
    }

    private func handleFinishedRecording(successfully flag: Bool) {
        guard flag, let recordingURL else {
            onTranscript?("Recording failed.")
            cleanupRecordingFile()
            return
        }

        onTranscriptionStateChange?(true)
        transcriptionTask?.cancel()
        transcriptionTask = Task {
            defer {
                Task { @MainActor in
                    self.onTranscriptionStateChange?(false)
                    self.cleanupRecordingFile()
                }
            }

            do {
                let transcript = try await VoiceServiceClient.transcribeAudio(
                    fileURL: recordingURL,
                    configuration: configurationProvider()
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.onTranscript?(transcript)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.onTranscript?("Open-source transcription failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func cleanupRecordingFile() {
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
            self.recordingURL = nil
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
