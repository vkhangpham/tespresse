import Foundation
import PDFKit

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
    private static let supportedFileExtensions: Set<String> = ["pdf", "txt", "md", "docx"]
    private static let defaultRelativeSourcePaths = [
        "Study/books/198 French Phrases and expressions.pdf",
        "Study/Francais/tcf/Expressions et Vocabulaire 1.docx"
    ]

    static func defaultSourcePaths() -> [String] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path

        return defaultRelativeSourcePaths
            .map { "\(homeDirectory)/\($0)" }
            .filter { FileManager.default.fileExists(atPath: $0) }
    }

    static func importSentences(from configuredPaths: [String]) -> SentenceImportResult {
        let sourcePaths = configuredPaths.isEmpty ? defaultSourcePaths() : configuredPaths
        let files = resolvedSupportedFiles(from: sourcePaths)
        var importedSentences: [FrenchSentence] = []
        var summaries: [SentenceSourceSummary] = []

        for file in files {
            guard let text = extractText(from: file) else { continue }

            let sentences = parseSentences(from: text, sourcePath: file)
            guard !sentences.isEmpty else { continue }

            importedSentences.append(contentsOf: sentences)
            summaries.append(
                SentenceSourceSummary(
                    path: file,
                    importedSentenceCount: sentences.count,
                    kind: URL(fileURLWithPath: file).pathExtension.lowercased()
                )
            )
        }

        let deduplicatedSentences = deduplicate(importedSentences)
        let message: String

        if deduplicatedSentences.isEmpty {
            if sourcePaths.isEmpty {
                message = "No default French source files were found. Using the built-in fallback prompts."
            } else {
                message = "I scanned the selected sources but couldn’t extract usable French prompts. Using the built-in fallback prompts."
            }
        } else {
            message = "Imported \(deduplicatedSentences.count) French prompts from \(summaries.count) source\(summaries.count == 1 ? "" : "s")."
        }

        return SentenceImportResult(
            sentences: deduplicatedSentences,
            sources: summaries.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending },
            statusMessage: message
        )
    }

    private static func resolvedSupportedFiles(from paths: [String]) -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default

        for path in paths {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { continue }

            if isDirectory.boolValue {
                let enumerator = fileManager.enumerator(atPath: path)
                while let next = enumerator?.nextObject() as? String {
                    let fullPath = URL(fileURLWithPath: path).appendingPathComponent(next).path
                    let pathExtension = URL(fileURLWithPath: fullPath).pathExtension.lowercased()
                    if supportedFileExtensions.contains(pathExtension) {
                        files.append(fullPath)
                    }
                }
            } else {
                let pathExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
                if supportedFileExtensions.contains(pathExtension) {
                    files.append(path)
                }
            }
        }

        return Array(Set(files)).sorted()
    }

    private static func extractText(from sourcePath: String) -> String? {
        switch URL(fileURLWithPath: sourcePath).pathExtension.lowercased() {
        case "pdf":
            return extractTextFromPDF(at: sourcePath)
        case "docx":
            return runProcess("/usr/bin/textutil", arguments: ["-convert", "txt", "-stdout", sourcePath])
        case "txt", "md":
            return try? String(contentsOfFile: sourcePath, encoding: .utf8)
        default:
            return nil
        }
    }

    private static func extractTextFromPDF(at sourcePath: String) -> String? {
        if let pdfToText = firstAvailableExecutable(in: [
            "/opt/homebrew/bin/pdftotext",
            "/usr/local/bin/pdftotext",
            "/usr/bin/pdftotext"
        ]), let output = runProcess(pdfToText, arguments: ["-layout", sourcePath, "-"]) {
            return output
        }

        guard let document = PDFDocument(url: URL(fileURLWithPath: sourcePath)) else {
            return nil
        }

        return (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n\n")
    }

    private static func parseSentences(from text: String, sourcePath: String) -> [FrenchSentence] {
        let filename = URL(fileURLWithPath: sourcePath).lastPathComponent.lowercased()

        if filename.contains("198 french phrases") {
            return parse198ExpressionsGuide(text, sourcePath: sourcePath)
        }

        if filename.contains("expressions et vocabulaire") {
            return parseQuotedExpressions(text, sourcePath: sourcePath)
        }

        return parseGenericFrenchSentences(text, sourcePath: sourcePath)
    }

    private static func parse198ExpressionsGuide(_ text: String, sourcePath: String) -> [FrenchSentence] {
        let sourceTitle = URL(fileURLWithPath: sourcePath).lastPathComponent
        let pages = text.components(separatedBy: "\u{0c}")
        var collected: [String] = []

        for (pageIndex, page) in pages.enumerated() where pageIndex >= 8 {
            var sawExpressionBullet = false
            var pendingExample: String?
            var pendingBullet: String?

            func flushPendingExample() {
                guard let currentPendingExample = pendingExample else { return }
                let cleaned = cleanPrompt(currentPendingExample)
                if looksLikeSpeakablePrompt(cleaned) {
                    collected.append(cleaned)
                }
                pendingExample = nil
            }

            func flushPendingBullet() {
                guard let currentPendingBullet = pendingBullet else { return }
                let cleaned = cleanPrompt(currentPendingBullet)
                if looksLikeSpeakablePrompt(cleaned) {
                    collected.append(cleaned)
                }
                pendingBullet = nil
            }

            for rawLine in page.components(separatedBy: .newlines) {
                let leftColumn = leftColumnText(from: rawLine)
                let trimmed = leftColumn.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.isEmpty {
                    flushPendingExample()
                    flushPendingBullet()
                    continue
                }

                if isPageDecoration(trimmed) {
                    continue
                }

                let isIndented = indentationLevel(of: leftColumn) >= 2

                if startsWithListMarker(trimmed) {
                    sawExpressionBullet = true
                    flushPendingExample()
                    flushPendingBullet()

                    let bulletPrompt = stripListMarker(from: trimmed)
                    if bulletPrompt.isEmpty || shouldIgnoreGuideLine(bulletPrompt) {
                        continue
                    }

                    if bulletPrompt.last.map({ ".?!…".contains($0) }) == true {
                        let cleaned = cleanPrompt(bulletPrompt)
                        if looksLikeSpeakablePrompt(cleaned) {
                            collected.append(cleaned)
                        }
                    } else {
                        pendingBullet = bulletPrompt
                    }

                    continue
                }

                if let currentPendingBullet = pendingBullet, isIndented, startsWithLowercaseLetter(trimmed) {
                    let merged = "\(currentPendingBullet) \(trimmed)"
                    let cleaned = cleanPrompt(merged)
                    if looksLikeSpeakablePrompt(cleaned) {
                        collected.append(cleaned)
                    }
                    pendingBullet = nil
                    continue
                }

                if pendingBullet != nil {
                    flushPendingBullet()
                }

                guard sawExpressionBullet, isIndented else { continue }

                let cleanedLine = cleanPrompt(trimmed)
                guard !cleanedLine.isEmpty else { continue }

                if pendingExample != nil, startsWithLowercaseLetter(cleanedLine) {
                    pendingExample = [pendingExample, cleanedLine]
                        .compactMap { $0 }
                        .joined(separator: " ")

                    if cleanedLine.last.map({ ".?!…".contains($0) }) == true {
                        flushPendingExample()
                    }
                    continue
                }

                guard looksLikeExampleStart(cleanedLine) else { continue }

                pendingExample = [pendingExample, cleanedLine]
                    .compactMap { $0 }
                    .joined(separator: " ")

                if cleanedLine.last.map({ ".?!…".contains($0) }) == true {
                    flushPendingExample()
                }
            }

            flushPendingExample()
            flushPendingBullet()
        }

        return deduplicateStrings(collected).map {
            FrenchSentence(text: $0, sourcePath: sourcePath, sourceTitle: sourceTitle)
        }
    }

    private static func parseQuotedExpressions(_ text: String, sourcePath: String) -> [FrenchSentence] {
        let sourceTitle = URL(fileURLWithPath: sourcePath).lastPathComponent
        let pattern = "«\\s*([^»]+?)\\s*»|\\\"\\s*([^\\\"]+?)\\s*\\\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let expressions = matches.compactMap { match -> String? in
            for rangeIndex in 1..<match.numberOfRanges {
                let range = match.range(at: rangeIndex)
                guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { continue }
                let cleaned = cleanPrompt(String(text[swiftRange]))
                if looksLikeSpeakablePrompt(cleaned, allowShortPrompts: true) {
                    return cleaned
                }
            }
            return nil
        }

        return deduplicateStrings(expressions).map {
            FrenchSentence(text: $0, sourcePath: sourcePath, sourceTitle: sourceTitle)
        }
    }

    private static func parseGenericFrenchSentences(_ text: String, sourcePath: String) -> [FrenchSentence] {
        let sourceTitle = URL(fileURLWithPath: sourcePath).lastPathComponent
        let candidates = text
            .components(separatedBy: .newlines)
            .map(cleanPrompt)
            .filter { looksLikeSpeakablePrompt($0) }

        return deduplicateStrings(candidates).map {
            FrenchSentence(text: $0, sourcePath: sourcePath, sourceTitle: sourceTitle)
        }
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

    private static func deduplicateStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var deduplicated: [String] = []

        for value in values {
            let normalized = SentenceMatcher.normalizeForMatching(value)
            if !normalized.isEmpty, seen.insert(normalized).inserted {
                deduplicated.append(value)
            }
        }

        return deduplicated
    }

    private static func cleanPrompt(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "\u{fb01}", with: "fi")
            .replacingOccurrences(of: "\u{fb02}", with: "fl")
            .replacingOccurrences(of: "\\[[^\\]]+\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\*+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "•●-–—")))
    }

    private static func looksLikeSpeakablePrompt(_ value: String, allowShortPrompts: Bool = false) -> Bool {
        guard !value.isEmpty else { return false }
        guard value.count <= 140 else { return false }
        guard allowShortPrompts || value.count >= 6 else { return false }
        guard !value.contains(" / The ") else { return false }
        guard !isPageDecoration(value) else { return false }
        guard !value.lowercased().hasPrefix("sommaire") else { return false }
        guard !value.lowercased().hasPrefix("introduction") else { return false }
        guard !value.lowercased().hasPrefix("les expressions") else { return false }

        let hasSentencePunctuation = value.last.map { ".?!…\"”".contains($0) } == true
        let hasDialogueMarker = value.contains(":") || value.contains("«") || value.contains("»")
        let looksFrench = containsFrenchSignal(in: value)

        if allowShortPrompts {
            return looksFrench
        }

        return looksFrench && (hasSentencePunctuation || hasDialogueMarker)
    }

    private static func looksLikeExampleStart(_ value: String) -> Bool {
        guard value.count >= 6 else { return false }
        guard !startsWithLowercaseLetter(value) || value.contains("’") || value.contains("'") || value.contains("Ça") else {
            return false
        }
        return true
    }

    private static func containsFrenchSignal(in value: String) -> Bool {
        let lowered = value.lowercased()
        let frenchSignals = [
            " je ", " j'", " tu ", " t'", " il ", " elle ", " on ", " nous ", " vous ",
            " ils ", " elles ", " c'", " ça", " est", " une ", " des ", " dans ", " avec ",
            " pour ", " chez ", " bon ", " merci", "jour", "soir", "quoi", "comment",
            " ai ", " suis ", " veux ", " peux ", " va ", " pas ", " ne ", " au ", " aux "
        ]

        if lowered.range(of: "[àâçéèêëîïôùûüÿœæ]", options: .regularExpression) != nil {
            return true
        }

        let padded = " \(lowered) "
        return frenchSignals.contains(where: { padded.contains($0) })
    }

    private static func leftColumnText(from rawLine: String) -> String {
        let cleanedLine = rawLine.replacingOccurrences(of: "\u{0c}", with: "")
        if let splitRange = cleanedLine.range(of: "\\s{4,}", options: .regularExpression) {
            return String(cleanedLine[..<splitRange.lowerBound])
        }
        return cleanedLine
    }

    private static func indentationLevel(of value: String) -> Int {
        value.prefix(while: \.isWhitespace).count
    }

    private static func startsWithListMarker(_ value: String) -> Bool {
        value.hasPrefix("●") || value.hasPrefix("•") || value.hasPrefix("-")
    }

    private static func stripListMarker(from value: String) -> String {
        value.replacingOccurrences(of: "^[●•\\-]+\\s*", with: "", options: .regularExpression)
    }

    private static func isPageDecoration(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if Int(trimmed) != nil { return true }
        return false
    }

    private static func shouldIgnoreGuideLine(_ value: String) -> Bool {
        let lowered = value.lowercased()
        return lowered.contains("table of contents") || lowered.contains("spoke") || lowered.contains("final words")
    }

    private static func startsWithLowercaseLetter(_ value: String) -> Bool {
        guard let scalar = value.unicodeScalars.first else { return false }
        return CharacterSet.lowercaseLetters.contains(scalar)
    }

    private static func firstAvailableExecutable(in candidates: [String]) -> String? {
        candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    private static func runProcess(_ executable: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
