import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AlarmManager: NSObject, ObservableObject {
    static let shared = AlarmManager()

    @Published var currentChallenge: AlarmChallenge?
    @Published var typedResponse = ""
    @Published var speechTranscript = ""
    @Published var nextTriggerDate: Date?
    @Published var pauseUntil: Date?
    @Published var muteUntil: Date?
    @Published var isListening = false
    @Published var isTranscribingSpeech = false
    @Published var isAnswerRevealed = false
    @Published var alarmCount = 0
    @Published var importedSentences: [FrenchSentence] = []
    @Published var sourceSummaries: [SentenceSourceSummary] = []
    @Published var isImportingSentenceSources = false
    @Published var importStatusMessage = "Looking for your French source books..."
    @Published var loadedVoiceModels: [String] = []
    @Published var voiceServerStatusMessage = "Waiting for the MLX-Audio voice server..."
    @Published var isRefreshingVoiceServerStatus = false

    @Published var selectedSourcePaths: [String] {
        didSet {
            defaults.set(selectedSourcePaths, forKey: Keys.selectedSourcePaths)
        }
    }

    @Published var voiceServiceBaseURL: String {
        didSet {
            defaults.set(voiceServiceBaseURL, forKey: Keys.voiceServiceBaseURL)
        }
    }

    @Published var ttsModelName: String {
        didSet {
            defaults.set(ttsModelName, forKey: Keys.ttsModelName)
        }
    }

    @Published var ttsVoiceName: String {
        didSet {
            defaults.set(ttsVoiceName, forKey: Keys.ttsVoiceName)
        }
    }

    @Published var ttsLanguageCode: String {
        didSet {
            defaults.set(ttsLanguageCode, forKey: Keys.ttsLanguageCode)
        }
    }

    @Published var sttModelName: String {
        didSet {
            defaults.set(sttModelName, forKey: Keys.sttModelName)
        }
    }

    @Published var ttsSpeed: Double {
        didSet {
            let normalizedValue = min(max(0.7, ttsSpeed), 1.35)
            if ttsSpeed != normalizedValue {
                ttsSpeed = normalizedValue
                return
            }
            defaults.set(normalizedValue, forKey: Keys.ttsSpeed)
        }
    }

    @Published var minimumIntervalMinutes: Double {
        didSet {
            let normalizedValue = min(max(1, minimumIntervalMinutes.rounded()), maximumIntervalMinutes)
            if minimumIntervalMinutes != normalizedValue {
                minimumIntervalMinutes = normalizedValue
                return
            }
            defaults.set(normalizedValue, forKey: Keys.minimumIntervalMinutes)
        }
    }

    @Published var maximumIntervalMinutes: Double {
        didSet {
            let normalizedValue = max(minimumIntervalMinutes, maximumIntervalMinutes.rounded())
            if maximumIntervalMinutes != normalizedValue {
                maximumIntervalMinutes = normalizedValue
                return
            }
            defaults.set(normalizedValue, forKey: Keys.maximumIntervalMinutes)
        }
    }

    @Published var repeatSpeechEverySeconds: Double {
        didSet {
            let normalizedValue = min(max(5, repeatSpeechEverySeconds.rounded()), 90)
            if repeatSpeechEverySeconds != normalizedValue {
                repeatSpeechEverySeconds = normalizedValue
                return
            }
            defaults.set(normalizedValue, forKey: Keys.repeatSpeechEverySeconds)
        }
    }

    @Published var responseMode: ResponseMode {
        didSet {
            defaults.set(responseMode.rawValue, forKey: Keys.responseMode)
            if responseMode == .speechOnly {
                typedResponse = ""
            }
            if responseMode == .typingOnly {
                stopListening()
            }
        }
    }

    private let defaults = UserDefaults.standard
    private let fallbackSynthesizer = AVSpeechSynthesizer()
    private let audioPlaybackController = AudioPlaybackController()
    private lazy var speechMatcher = SpeechMatcher(configurationProvider: { [weak self] in
        self?.voiceServiceConfiguration ?? .default
    })
    private var schedulerTask: Task<Void, Never>?
    private var repeatSpeechTask: Task<Void, Never>?
    private var voiceServerStatusTask: Task<Void, Never>?
    private var speechSynthesisTask: Task<Void, Never>?
    private var overrideNextTriggerDate: Date?
    private var lastSentenceID: UUID?
    private weak var challengeWindowController: ChallengeWindowController?
    private weak var controlCenterWindowController: ControlCenterWindowController?

    var menuBarSymbolName: String {
        if currentChallenge != nil {
            return "speaker.wave.3.fill"
        }
        if pauseUntil.map({ $0 > Date() }) == true {
            return "pause.circle.fill"
        }
        if muteUntil.map({ $0 > Date() }) == true {
            return "speaker.slash.fill"
        }
        if importedSentences.isEmpty {
            return "text.badge.exclamationmark"
        }
        return "text.bubble.fill"
    }

    var canReplayNow: Bool {
        currentChallenge != nil && !(muteUntil.map { $0 > Date() } ?? false)
    }

    var activeSentencePool: [FrenchSentence] {
        importedSentences.isEmpty ? SentenceLibrary.fallbackSentences : importedSentences
    }

    var voiceServiceConfiguration: VoiceServiceConfiguration {
        VoiceServiceConfiguration(
            baseURL: voiceServiceBaseURL,
            ttsModel: ttsModelName,
            ttsVoice: ttsVoiceName,
            ttsLanguageCode: ttsLanguageCode,
            sttModel: sttModelName,
            ttsSpeed: ttsSpeed
        )
    }

    var voiceServerLaunchCommand: String {
        "./scripts/start_mlx_audio_server_tmux.sh"
    }

    private override init() {
        let defaultVoice = VoiceServiceConfiguration.default
        let storedMinimum = defaults.object(forKey: Keys.minimumIntervalMinutes) as? Double ?? 5
        let storedMaximum = defaults.object(forKey: Keys.maximumIntervalMinutes) as? Double ?? 20
        let storedRepeat = defaults.object(forKey: Keys.repeatSpeechEverySeconds) as? Double ?? 12
        let legacyStudyFrenchPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Study/French").path
        let storedSourcePaths = defaults.stringArray(forKey: Keys.selectedSourcePaths) ?? []
        let cleanedSourcePaths = storedSourcePaths.filter { $0 != legacyStudyFrenchPath }

        minimumIntervalMinutes = storedMinimum
        maximumIntervalMinutes = max(storedMinimum, storedMaximum)
        repeatSpeechEverySeconds = storedRepeat
        responseMode = ResponseMode(rawValue: defaults.string(forKey: Keys.responseMode) ?? "") ?? .either
        selectedSourcePaths = cleanedSourcePaths.isEmpty ? SentenceImportService.defaultSourcePaths() : cleanedSourcePaths
        voiceServiceBaseURL = defaults.string(forKey: Keys.voiceServiceBaseURL) ?? defaultVoice.baseURL
        ttsModelName = defaults.string(forKey: Keys.ttsModelName) ?? defaultVoice.ttsModel
        ttsVoiceName = defaults.string(forKey: Keys.ttsVoiceName) ?? defaultVoice.ttsVoice
        ttsLanguageCode = defaults.string(forKey: Keys.ttsLanguageCode) ?? defaultVoice.ttsLanguageCode
        sttModelName = defaults.string(forKey: Keys.sttModelName) ?? defaultVoice.sttModel
        ttsSpeed = defaults.object(forKey: Keys.ttsSpeed) as? Double ?? defaultVoice.ttsSpeed
        pauseUntil = defaults.object(forKey: Keys.pauseUntil) as? Date
        muteUntil = defaults.object(forKey: Keys.muteUntil) as? Date
        super.init()

        speechMatcher.onTranscript = { [weak self] transcript in
            guard let self else { return }
            self.speechTranscript = transcript
            self.evaluateSpokenAnswer(transcript)
        }

        speechMatcher.onListeningStateChange = { [weak self] isListening in
            self?.isListening = isListening
        }

        speechMatcher.onTranscriptionStateChange = { [weak self] isTranscribing in
            self?.isTranscribingSpeech = isTranscribing
        }
    }

    func attachWindowController(_ controller: ChallengeWindowController) {
        challengeWindowController = controller
    }

    func attachControlCenterWindowController(_ controller: ControlCenterWindowController) {
        controlCenterWindowController = controller
    }

    func bootstrap() {
        clearExpiredSuppressions()
        showControlCenter()
        refreshSentenceSources()
        refreshVoiceServerStatus()
        start()
    }

    func start() {
        schedulerTask?.cancel()
        schedulerTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                self.clearExpiredSuppressions()

                if let pauseUntil, pauseUntil > Date() {
                    nextTriggerDate = pauseUntil
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }

                let fireDate = overrideNextTriggerDate ?? Date().addingTimeInterval(randomDelay())
                overrideNextTriggerDate = nil
                nextTriggerDate = fireDate

                while !Task.isCancelled && Date() < fireDate {
                    self.clearExpiredSuppressions()
                    if let pauseUntil, pauseUntil > Date() {
                        break
                    }
                    try? await Task.sleep(for: .seconds(1))
                }

                if Task.isCancelled {
                    return
                }

                clearExpiredSuppressions()

                guard pauseUntil.map({ $0 <= Date() }) ?? true else {
                    continue
                }

                guard currentChallenge == nil else {
                    continue
                }

                triggerAlarm()
            }
        }
    }

    func triggerAlarm() {
        let sentence = SentenceLibrary.randomSentence(from: activeSentencePool, excluding: lastSentenceID)
        lastSentenceID = sentence.id
        currentChallenge = AlarmChallenge(sentence: sentence, triggeredAt: Date())
        typedResponse = ""
        speechTranscript = ""
        isAnswerRevealed = false
        alarmCount += 1
        challengeWindowController?.present()
        speakCurrentSentenceNow()
        beginRepeatingSpeech()
    }

    func revealAnswer() {
        isAnswerRevealed = true
    }

    func replaySentence() {
        speakCurrentSentenceNow()
    }

    func submitTypedResponse() {
        guard responseMode != .speechOnly else { return }
        guard let sentence = currentChallenge?.sentence else { return }
        if SentenceMatcher.matches(input: typedResponse, target: sentence.text) {
            dismissCurrentAlarm()
        }
    }

    func startListening() {
        guard responseMode != .typingOnly else { return }
        guard currentChallenge != nil else { return }
        speechTranscript = ""
        speechMatcher.startListening()
    }

    func stopListening() {
        speechMatcher.stopListening()
    }

    func snooze(minutes: Double) {
        overrideNextTriggerDate = Date().addingTimeInterval(minutes * 60)
        dismissCurrentAlarm(scheduleNext: false)
    }

    func pause(minutes: Double) {
        pauseUntil = Date().addingTimeInterval(minutes * 60)
        defaults.set(pauseUntil, forKey: Keys.pauseUntil)
        dismissCurrentAlarm(scheduleNext: false)
    }

    func mute(minutes: Double) {
        muteUntil = Date().addingTimeInterval(minutes * 60)
        defaults.set(muteUntil, forKey: Keys.muteUntil)
        stopSpeaking()
    }

    func clearMute() {
        muteUntil = nil
        defaults.removeObject(forKey: Keys.muteUntil)
    }

    func clearPause() {
        pauseUntil = nil
        defaults.removeObject(forKey: Keys.pauseUntil)
    }

    func dismissCurrentAlarm(scheduleNext: Bool = true) {
        currentChallenge = nil
        typedResponse = ""
        speechTranscript = ""
        isAnswerRevealed = false
        isTranscribingSpeech = false
        repeatSpeechTask?.cancel()
        repeatSpeechTask = nil
        speechMatcher.stopListening(cancelTranscription: true)
        stopSpeaking()
        challengeWindowController?.dismiss()

        if scheduleNext {
            overrideNextTriggerDate = nil
        }
    }

    func statusSummary(now: Date = Date()) -> String {
        if let currentChallenge {
            return "Alarm active from \(currentChallenge.sentence.sourceTitle)"
        }
        if let pauseUntil, pauseUntil > now {
            return "Paused until \(pauseUntil.formatted(date: .omitted, time: .shortened))"
        }
        if let nextTriggerDate, nextTriggerDate > now {
            return "Next prompt around \(nextTriggerDate.formatted(date: .omitted, time: .shortened))"
        }
        if importedSentences.isEmpty {
            return "Using the built-in fallback prompts"
        }
        return "Using \(importedSentences.count) imported French prompts"
    }

    func countdownSummary(now: Date = Date()) -> String {
        guard let nextTriggerDate else {
            return "No alarm scheduled"
        }

        let seconds = max(0, Int(nextTriggerDate.timeIntervalSince(now)))
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02dm %02ds", minutes, remainingSeconds)
    }

    func showControlCenter() {
        controlCenterWindowController?.present()
    }

    func refreshSentenceSources() {
        let sourcePaths = selectedSourcePaths.isEmpty ? SentenceImportService.defaultSourcePaths() : selectedSourcePaths
        selectedSourcePaths = sourcePaths
        isImportingSentenceSources = true
        importStatusMessage = "Scanning your French books for prompts..."

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                SentenceImportService.importSentences(from: sourcePaths)
            }.value

            await MainActor.run {
                self.importedSentences = result.sentences
                self.sourceSummaries = result.sources
                self.importStatusMessage = result.statusMessage
                self.isImportingSentenceSources = false
                print("[T'es pressé ?] \(result.statusMessage)")
            }
        }
    }

    func refreshVoiceServerStatus() {
        voiceServerStatusTask?.cancel()
        isRefreshingVoiceServerStatus = true
        voiceServerStatusMessage = "Checking MLX-Audio at \(voiceServiceBaseURL)..."

        voiceServerStatusTask = Task { [weak self] in
            guard let self else { return }

            do {
                let models = try await VoiceServiceClient.fetchLoadedModels(configuration: voiceServiceConfiguration)
                await MainActor.run {
                    self.loadedVoiceModels = models
                    self.isRefreshingVoiceServerStatus = false
                    if models.isEmpty {
                        self.voiceServerStatusMessage = "MLX-Audio is reachable. Models load lazily on first request."
                    } else {
                        self.voiceServerStatusMessage = "MLX-Audio is reachable. Loaded models: \(models.joined(separator: ", "))"
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadedVoiceModels = []
                    self.isRefreshingVoiceServerStatus = false
                    self.voiceServerStatusMessage = "MLX-Audio is unavailable at \(self.voiceServiceBaseURL). Start it with `\(self.voiceServerLaunchCommand)`."
                }
            }
        }
    }

    func restoreDefaultSources() {
        selectedSourcePaths = SentenceImportService.defaultSourcePaths()
        refreshSentenceSources()
    }

    func restoreDefaultVoiceSettings() {
        let defaultVoice = VoiceServiceConfiguration.default
        voiceServiceBaseURL = defaultVoice.baseURL
        ttsModelName = defaultVoice.ttsModel
        ttsVoiceName = defaultVoice.ttsVoice
        ttsLanguageCode = defaultVoice.ttsLanguageCode
        sttModelName = defaultVoice.sttModel
        ttsSpeed = defaultVoice.ttsSpeed
        refreshVoiceServerStatus()
    }

    func chooseSentenceSources() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .pdf,
            .plainText,
            .text,
            UTType(filenameExtension: "docx") ?? .data
        ]

        if panel.runModal() == .OK {
            let chosenPaths = panel.urls.map(\.path)
            selectedSourcePaths = Array(Set(selectedSourcePaths + chosenPaths)).sorted()
            refreshSentenceSources()
        }
    }

    private func randomDelay() -> TimeInterval {
        let minimum = minimumIntervalMinutes * 60
        let maximum = maximumIntervalMinutes * 60
        return Double.random(in: minimum...maximum)
    }

    private func beginRepeatingSpeech() {
        repeatSpeechTask?.cancel()
        repeatSpeechTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(repeatSpeechEverySeconds))
                guard !Task.isCancelled else { return }
                guard currentChallenge != nil else { return }
                if muteUntil.map({ $0 > Date() }) == true {
                    continue
                }
                speakCurrentSentenceNow()
            }
        }
    }

    private func speakCurrentSentenceNow() {
        guard let sentence = currentChallenge?.sentence.text else { return }
        guard muteUntil.map({ $0 > Date() }) != true else { return }

        speechSynthesisTask?.cancel()
        speechSynthesisTask = Task { [weak self] in
            guard let self else { return }

            do {
                let audioData = try await VoiceServiceClient.synthesizeSpeech(
                    text: sentence,
                    configuration: voiceServiceConfiguration
                )
                await MainActor.run {
                    do {
                        try self.audioPlaybackController.play(audioData: audioData)
                        self.voiceServerStatusMessage = "Speaking with MLX-Audio using \(self.ttsVoiceName) and \(self.ttsModelName)."
                    } catch {
                        self.playFallbackSpeech(sentence, reason: error.localizedDescription)
                    }
                }
            } catch {
                await MainActor.run {
                    self.playFallbackSpeech(sentence, reason: error.localizedDescription)
                }
            }
        }
    }

    private func playFallbackSpeech(_ text: String, reason: String) {
        voiceServerStatusMessage = "MLX-Audio speech failed: \(reason). Falling back to the macOS voice."

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR") ?? AVSpeechSynthesisVoice(language: "fr-CA")
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.02
        utterance.volume = 1.0

        fallbackSynthesizer.stopSpeaking(at: .immediate)
        fallbackSynthesizer.speak(utterance)
    }

    private func stopSpeaking() {
        speechSynthesisTask?.cancel()
        speechSynthesisTask = nil
        audioPlaybackController.stop()
        fallbackSynthesizer.stopSpeaking(at: .immediate)
    }

    private func evaluateSpokenAnswer(_ transcript: String) {
        guard let sentence = currentChallenge?.sentence else { return }
        if SentenceMatcher.matches(input: transcript, target: sentence.text, tolerateMinorSpeechRecognitionErrors: true) {
            dismissCurrentAlarm()
        }
    }

    private func clearExpiredSuppressions() {
        if let pauseUntil, pauseUntil <= Date() {
            clearPause()
        }
        if let muteUntil, muteUntil <= Date() {
            clearMute()
        }
    }

    private enum Keys {
        static let minimumIntervalMinutes = "minimumIntervalMinutes"
        static let maximumIntervalMinutes = "maximumIntervalMinutes"
        static let repeatSpeechEverySeconds = "repeatSpeechEverySeconds"
        static let pauseUntil = "pauseUntil"
        static let muteUntil = "muteUntil"
        static let responseMode = "responseMode"
        static let selectedSourcePaths = "selectedSourcePaths"
        static let voiceServiceBaseURL = "voiceServiceBaseURL"
        static let ttsModelName = "ttsModelName"
        static let ttsVoiceName = "ttsVoiceName"
        static let ttsLanguageCode = "ttsLanguageCode"
        static let sttModelName = "sttModelName"
        static let ttsSpeed = "ttsSpeed"
    }
}

struct AlarmChallenge: Identifiable {
    let id = UUID()
    let sentence: FrenchSentence
    let triggeredAt: Date
}
