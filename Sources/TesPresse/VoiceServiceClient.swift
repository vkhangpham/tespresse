import AVFoundation
import Foundation

struct VoiceServiceConfiguration: Equatable {
    var baseURL: String
    var ttsModel: String
    var ttsVoice: String
    var ttsLanguageCode: String
    var sttModel: String
    var ttsSpeed: Double

    static let `default` = VoiceServiceConfiguration(
        baseURL: "http://127.0.0.1:8000",
        ttsModel: "mlx-community/Kokoro-82M-bf16",
        ttsVoice: "ff_siwis",
        ttsLanguageCode: "f",
        sttModel: "mlx-community/whisper-large-v3-turbo-asr-fp16",
        ttsSpeed: 1.0
    )

    var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

enum VoiceServiceError: LocalizedError {
    case invalidBaseURL
    case invalidResponse(statusCode: Int, message: String?)
    case emptyTranscription

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The voice server URL is invalid."
        case let .invalidResponse(statusCode, message):
            if let message, !message.isEmpty {
                return "The voice server returned HTTP \(statusCode): \(message)"
            }
            return "The voice server returned HTTP \(statusCode)."
        case .emptyTranscription:
            return "The voice server returned an empty transcription."
        }
    }
}

enum VoiceServiceClient {
    static func fetchLoadedModels(configuration: VoiceServiceConfiguration) async throws -> [String] {
        let baseURL = try normalizedBaseURL(from: configuration)
        var request = URLRequest(url: baseURL.appending(path: "v1/models"))
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)

        let payload = try JSONDecoder().decode(ModelListResponse.self, from: data)
        return payload.data.map(\.id)
    }

    static func synthesizeSpeech(text: String, configuration: VoiceServiceConfiguration) async throws -> Data {
        let baseURL = try normalizedBaseURL(from: configuration)
        var request = URLRequest(url: baseURL.appending(path: "v1/audio/speech"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = SpeechRequestPayload(
            model: configuration.ttsModel,
            input: text,
            voice: configuration.ttsVoice,
            speed: configuration.ttsSpeed,
            lang_code: configuration.ttsLanguageCode,
            response_format: "wav"
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        return data
    }

    static func transcribeAudio(fileURL: URL, configuration: VoiceServiceConfiguration) async throws -> String {
        let baseURL = try normalizedBaseURL(from: configuration)
        var request = URLRequest(url: baseURL.appending(path: "v1/audio/transcriptions"))
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try createTranscriptionBody(fileURL: fileURL, configuration: configuration, boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)

        let transcript = data
            .split(separator: UInt8(ascii: "\n"))
            .compactMap { line -> String? in
                guard !line.isEmpty else { return nil }
                guard let decoded = try? JSONDecoder().decode(TranscriptionChunk.self, from: Data(line)) else {
                    return nil
                }
                if let accumulated = decoded.accumulated, !accumulated.isEmpty {
                    return accumulated
                }
                return decoded.text
            }
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !transcript.isEmpty else {
            throw VoiceServiceError.emptyTranscription
        }

        return transcript
    }

    private static func createTranscriptionBody(
        fileURL: URL,
        configuration: VoiceServiceConfiguration,
        boundary: String
    ) throws -> Data {
        let audioData = try Data(contentsOf: fileURL)
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "model", value: configuration.sttModel)
        appendField(name: "language", value: "fr")

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    private static func normalizedBaseURL(from configuration: VoiceServiceConfiguration) throws -> URL {
        guard let url = URL(string: configuration.trimmedBaseURL), let scheme = url.scheme, !scheme.isEmpty else {
            throw VoiceServiceError.invalidBaseURL
        }
        return url
    }

    private static func validate(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceServiceError.invalidResponse(statusCode: -1, message: nil)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(240)
            throw VoiceServiceError.invalidResponse(
                statusCode: httpResponse.statusCode,
                message: message.map(String.init)
            )
        }
    }
}

private struct SpeechRequestPayload: Encodable {
    let model: String
    let input: String
    let voice: String
    let speed: Double
    let lang_code: String
    let response_format: String
}

private struct ModelListResponse: Decodable {
    let data: [LoadedModel]
}

private struct LoadedModel: Decodable {
    let id: String
}

private struct TranscriptionChunk: Decodable {
    let text: String?
    let accumulated: String?
}

@MainActor
final class AudioPlaybackController: NSObject {
    private var audioPlayer: AVAudioPlayer?

    func play(audioData: Data) throws {
        stop()
        let player = try AVAudioPlayer(data: audioData)
        player.prepareToPlay()
        player.play()
        audioPlayer = player
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
