import Foundation

enum ResponseMode: String, CaseIterable, Identifiable {
    case typingOnly = "typing_only"
    case speechOnly = "speech_only"
    case either = "either"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .typingOnly:
            return "Typing only"
        case .speechOnly:
            return "Speech only"
        case .either:
            return "Typing or speech"
        }
    }

    var subtitle: String {
        switch self {
        case .typingOnly:
            return "Dismiss alarms by typing the French sentence."
        case .speechOnly:
            return "Dismiss alarms by repeating the sentence into the microphone."
        case .either:
            return "Let the user type it or say it back."
        }
    }
}

struct SentenceSourceSummary: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let importedSentenceCount: Int
    let kind: String

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

struct SentenceImportResult {
    let sentences: [FrenchSentence]
    let sources: [SentenceSourceSummary]
    let statusMessage: String
}

enum SentenceImportService {
    private static let bundledSentencePoolName = "default_sentence_pool"
    private static let bundledSentencePoolExtension = "txt"

    static func defaultSourcePaths() -> [String] {
        guard let bundledURL = bundledSentencePoolURL() else {
            return []
        }

        return [bundledURL.path]
    }

    static func importSentences(from configuredPaths: [String]) -> SentenceImportResult {
        let requestedPath = configuredPaths.first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bundledURL = bundledSentencePoolURL()
        let bundledPath = bundledURL?.path
        let selectedURL = sentencePoolURL(for: requestedPath)
        let usedBundledFallbackImmediately = requestedPath != nil
            && selectedURL?.path == bundledPath
            && requestedPath != bundledPath

        guard let selectedURL else {
            return SentenceImportResult(
                sentences: [],
                sources: [],
                statusMessage: "No sentence pool file is available. Restore the bundled 198-prompt pool to keep the alarm running."
            )
        }

        let sourcePath = selectedURL.path
        let sourceTitle = URL(fileURLWithPath: sourcePath).lastPathComponent
        let shouldTryBundledFallback = requestedPath != nil && sourcePath != bundledPath

        if let result = loadSentencePool(from: selectedURL) {
            let statusMessage = usedBundledFallbackImmediately
                ? "The selected sentence pool was unavailable, so the bundled 198-prompt pool is loaded instead."
                : "Loaded \(result.sentences.count) French prompts from \(sourceTitle). Keep the file as plain text with one prompt per line."

            return SentenceImportResult(
                sentences: result.sentences,
                sources: [result.summary],
                statusMessage: statusMessage
            )
        }

        if shouldTryBundledFallback,
           let bundledURL,
           bundledURL.path != sourcePath,
           let fallbackResult = loadSentencePool(from: bundledURL) {
            return SentenceImportResult(
                sentences: fallbackResult.sentences,
                sources: [fallbackResult.summary],
                statusMessage: "The selected sentence pool was unavailable, so the bundled 198-prompt pool is loaded instead."
            )
        }

        return SentenceImportResult(
            sentences: [],
            sources: [],
            statusMessage: "The sentence pool at \(sourceTitle) could not be read as UTF-8 plain text."
        )
    }

    private static func sentencePoolURL(for preferredPath: String?) -> URL? {
        if let preferredPath,
           let readableURL = readableFileURL(for: preferredPath) {
            return readableURL
        }

        return bundledSentencePoolURL()
    }

    private static func bundledSentencePoolURL() -> URL? {
        Bundle.module.url(
            forResource: bundledSentencePoolName,
            withExtension: bundledSentencePoolExtension
        )
    }

    private static func readableFileURL(for path: String) -> URL? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: trimmedPath, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }

        return URL(fileURLWithPath: trimmedPath)
    }

    private static func parseSentencePool(from text: String, sourcePath: String) -> [FrenchSentence] {
        let sourceTitle = URL(fileURLWithPath: sourcePath).lastPathComponent

        return text
            .components(separatedBy: .newlines)
            .compactMap { rawLine -> FrenchSentence? in
                let cleaned = cleanPrompt(rawLine)
                guard isSentencePoolEntry(cleaned) else {
                    return nil
                }

                return FrenchSentence(
                    text: cleaned,
                    sourcePath: sourcePath,
                    sourceTitle: sourceTitle
                )
            }
    }

    private static func loadSentencePool(from url: URL) -> (sentences: [FrenchSentence], summary: SentenceSourceSummary)? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let sentences = deduplicate(parseSentencePool(from: text, sourcePath: url.path))
        guard !sentences.isEmpty else {
            return nil
        }

        let summary = SentenceSourceSummary(
            path: url.path,
            importedSentenceCount: sentences.count,
            kind: url.pathExtension.lowercased().isEmpty ? "text" : url.pathExtension.lowercased()
        )
        return (sentences, summary)
    }

    private static func deduplicate(_ sentences: [FrenchSentence]) -> [FrenchSentence] {
        var seen = Set<String>()
        var deduplicated: [FrenchSentence] = []

        for sentence in sentences {
            let normalized = SentenceMatcher.normalizeForMatching(sentence.text)
            if seen.insert(normalized).inserted {
                deduplicated.append(sentence)
            }
        }

        return deduplicated
    }

    private static func cleanPrompt(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{FB00}", with: "ff")
            .replacingOccurrences(of: "\u{fb01}", with: "fi")
            .replacingOccurrences(of: "\u{fb02}", with: "fl")
            .replacingOccurrences(of: "\u{fb03}", with: "ffi")
            .replacingOccurrences(of: "\u{fb04}", with: "ffl")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isSentencePoolEntry(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        guard !value.hasPrefix("#") else { return false }
        guard Int(value) == nil else { return false }
        return value.count >= 3 && value.count <= 180
    }
}
