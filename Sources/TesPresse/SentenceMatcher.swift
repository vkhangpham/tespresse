import Foundation

enum SentenceMatchMode {
    case typing
    case speech
}

enum SentenceMatcher {
    static func matches(
        input: String,
        target: String,
        mode: SentenceMatchMode = .typing
    ) -> Bool {
        let normalizedInput = normalizeForMatching(input)

        guard !normalizedInput.isEmpty else {
            return false
        }

        return targetVariants(for: target).contains { variant in
            let normalizedTarget = normalizeForMatching(variant)
            guard !normalizedTarget.isEmpty else {
                return false
            }

            return matchesNormalizedInput(
                normalizedInput,
                against: normalizedTarget,
                mode: mode
            )
        }
    }

    static func normalizeForMatching(_ text: String) -> String {
        let folded = replaceCompatibilityCharacters(in: text)
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                locale: Locale(identifier: "fr_FR")
            )
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar) ? Character(scalar) : " "
        }

        return String(scalars)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchesNormalizedInput(
        _ normalizedInput: String,
        against normalizedTarget: String,
        mode: SentenceMatchMode
    ) -> Bool {
        if normalizedInput == normalizedTarget {
            return true
        }

        let overlapRatio = Double(min(normalizedInput.count, normalizedTarget.count)) / Double(max(normalizedInput.count, normalizedTarget.count))
        if (normalizedInput.contains(normalizedTarget) || normalizedTarget.contains(normalizedInput)),
           overlapRatio >= containmentThreshold(for: mode) {
            return true
        }

        let inputCharacters = Array(normalizedInput)
        let targetCharacters = Array(normalizedTarget)
        let characterDistance = levenshtein(inputCharacters, targetCharacters)
        let characterSimilarity = 1 - (Double(characterDistance) / Double(max(inputCharacters.count, targetCharacters.count)))

        let inputTokens = tokens(from: normalizedInput)
        let targetTokens = tokens(from: normalizedTarget)
        let tokenDistance = levenshtein(inputTokens, targetTokens)

        switch mode {
        case .typing:
            if characterDistance <= 1, max(inputCharacters.count, targetCharacters.count) >= 8 {
                return true
            }

            return tokenDistance <= 1 && characterSimilarity >= 0.96
        case .speech:
            let tokenThreshold = max(1, targetTokens.count / 6)
            if tokenDistance <= tokenThreshold && characterSimilarity >= 0.84 {
                return true
            }

            let characterThreshold = max(2, targetCharacters.count / 8)
            return characterDistance <= characterThreshold && characterSimilarity >= 0.9
        }
    }

    private static func containmentThreshold(for mode: SentenceMatchMode) -> Double {
        switch mode {
        case .typing:
            return 0.96
        case .speech:
            return 0.88
        }
    }

    private static func tokens(from normalizedText: String) -> [String] {
        normalizedText
            .split(separator: " ")
            .map(String.init)
    }

    private static func targetVariants(for target: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\(([^)]+)\\)") else {
            return [target]
        }

        var pending = Set([target])
        var expanded = true

        while expanded {
            expanded = false
            var nextVariants = Set<String>()

            for variant in pending {
                let range = NSRange(variant.startIndex..., in: variant)
                guard let match = regex.firstMatch(in: variant, range: range),
                      let fullRange = Range(match.range(at: 0), in: variant),
                      let contentRange = Range(match.range(at: 1), in: variant) else {
                    nextVariants.insert(variant)
                    continue
                }

                expanded = true
                let withoutOptional = cleanVariantSpacing(
                    variant.replacingCharacters(in: fullRange, with: "")
                )
                let withOptional = cleanVariantSpacing(
                    variant.replacingCharacters(
                        in: fullRange,
                        with: String(variant[contentRange])
                    )
                )
                nextVariants.insert(withoutOptional)
                nextVariants.insert(withOptional)
            }

            pending = nextVariants
        }

        return pending.filter { !$0.isEmpty }
    }

    private static func cleanVariantSpacing(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+([?.!,;:])", with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replaceCompatibilityCharacters(in text: String) -> String {
        let replacements = [
            "\u{2019}": "'",
            "\u{2018}": "'",
            "\u{201C}": "\"",
            "\u{201D}": "\"",
            "\u{2026}": "...",
            "\u{00A0}": " ",
            "\u{202F}": " ",
            "\u{0153}": "oe",
            "\u{0152}": "oe",
            "\u{00E6}": "ae",
            "\u{00C6}": "ae",
            "\u{FB00}": "ff",
            "\u{FB01}": "fi",
            "\u{FB02}": "fl",
            "\u{FB03}": "ffi",
            "\u{FB04}": "ffl"
        ]

        return replacements.reduce(into: text) { value, replacement in
            value = value.replacingOccurrences(of: replacement.key, with: replacement.value)
        }
    }

    private static func levenshtein<T: Equatable>(_ lhs: [T], _ rhs: [T]) -> Int {
        var distances = Array(0...rhs.count)

        for (lhsIndex, lhsValue) in lhs.enumerated() {
            var previousDistance = distances[0]
            distances[0] = lhsIndex + 1

            for (rhsIndex, rhsValue) in rhs.enumerated() {
                let currentDistance = distances[rhsIndex + 1]

                if lhsValue == rhsValue {
                    distances[rhsIndex + 1] = previousDistance
                } else {
                    distances[rhsIndex + 1] = min(
                        distances[rhsIndex] + 1,
                        distances[rhsIndex + 1] + 1,
                        previousDistance + 1
                    )
                }

                previousDistance = currentDistance
            }
        }

        return distances[rhs.count]
    }
}
