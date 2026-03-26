import Foundation
import Testing
@testable import TesPresse

struct SentenceImportServiceTests {
    @Test
    func bundledSentencePoolLoads198Prompts() {
        let result = SentenceImportService.importSentences(from: SentenceImportService.defaultSourcePaths())

        #expect(result.sentences.count == 198)
        #expect(result.sources.count == 1)
        #expect(result.sources.first?.displayName == "default_sentence_pool.txt")
        #expect(result.sentences.first?.text == "On peut se tutoyer ?")
        #expect(result.sentences.last?.text == "Tu vas à la résoi de Yannick ?")
    }

    @Test
    func customSentencePoolUsesOnePromptPerLineAndDeduplicatesNormalizedVariants() throws {
        let customPoolURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")

        try """
        # My drill pool

        Bonjour !
        bonjour
        Ça va ?
        ça va
        Enchanté(e).
        """.write(to: customPoolURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: customPoolURL) }

        let result = SentenceImportService.importSentences(from: [customPoolURL.path])

        #expect(result.sentences.map(\.text) == [
            "Bonjour !",
            "Ça va ?",
            "Enchanté(e)."
        ])
        #expect(result.sources.first?.path == customPoolURL.path)
        #expect(result.statusMessage.contains("one prompt per line"))
    }

    @Test
    func missingCustomSentencePoolFallsBackToBundledPool() {
        let result = SentenceImportService.importSentences(from: ["/tmp/tespresse-missing-pool.txt"])

        #expect(result.sentences.count == 198)
        #expect(result.sources.first?.displayName == "default_sentence_pool.txt")
        #expect(result.statusMessage.contains("bundled 198-prompt pool"))
    }

    @Test
    func invalidUtf8SentencePoolFallsBackToBundledPool() throws {
        let invalidPoolURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")

        try Data([0xFF, 0xFE, 0x00, 0x61]).write(to: invalidPoolURL)
        defer { try? FileManager.default.removeItem(at: invalidPoolURL) }

        let result = SentenceImportService.importSentences(from: [invalidPoolURL.path])

        #expect(result.sentences.count == 198)
        #expect(result.sources.first?.displayName == "default_sentence_pool.txt")
        #expect(result.statusMessage.contains("bundled 198-prompt pool"))
    }
}
