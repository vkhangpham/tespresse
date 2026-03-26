import Testing
@testable import TesPresse

struct SentenceMatcherTests {
    @Test
    func normalizationHandlesAccentsCedillaLigaturesAndPunctuation() {
        let normalized = SentenceMatcher.normalizeForMatching("Ça, garçon, bouﬀer, œuvre, ENCHANTÉE !")

        #expect(normalized == "ca garcon bouffer oeuvre enchantee")
    }

    @Test
    func typingMatchAcceptsAccentAndOptionalMarkerDifferences() {
        #expect(
            SentenceMatcher.matches(
                input: "enchantee",
                target: "Enchanté(e).",
                mode: .typing
            )
        )
        #expect(
            SentenceMatcher.matches(
                input: "Ravie de t'avoir rencontree",
                target: "Ravi(e) de t'avoir rencontré(e).",
                mode: .typing
            )
        )
    }

    @Test
    func typingMatchRejectsPartialSubstring() {
        #expect(
            !SentenceMatcher.matches(
                input: "On se voit",
                target: "On se voit quand ?",
                mode: .typing
            )
        )
    }

    @Test
    func speechMatchAllowsSmallRecognitionNoise() {
        #expect(
            SentenceMatcher.matches(
                input: "Bon ça y est on peut y aller",
                target: "Ça y est, on peut y aller !",
                mode: .speech
            )
        )
        #expect(
            SentenceMatcher.matches(
                input: "ca va pas etre possible",
                target: "Ça va pas être possible.",
                mode: .speech
            )
        )
    }

    @Test
    func speechMatchStillRejectsDifferentPhrase() {
        #expect(
            !SentenceMatcher.matches(
                input: "On va boire un café ce soir",
                target: "Tu veux prendre un verre ce soir ?",
                mode: .speech
            )
        )
    }
}
