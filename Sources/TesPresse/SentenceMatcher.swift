import Foundation

enum SentenceMatcher {
    static func matches(
        input: String,
        target: String,
        tolerateMinorSpeechRecognitionErrors: Bool = false
    ) -> Bool {
        let normalizedInput = normalizeForMatching(input)
        let normalizedTarget = normalizeForMatching(target)

        guard !normalizedInput.isEmpty else {
            return false
        }

        if normalizedInput == normalizedTarget {
            return true
        }

        if normalizedInput.contains(normalizedTarget) || normalizedTarget.contains(normalizedInput) {
            return true
        }

        guard tolerateMinorSpeechRecognitionErrors else {
            return false
        }

        let distance = levenshtein(normalizedInput, normalizedTarget)
        let threshold = max(2, normalizedTarget.count / 10)
        return distance <= threshold
    }

    static func normalizeForMatching(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar) ? Character(scalar) : " "
        }

        return String(scalars)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        var distances = Array(0...rhsChars.count)

        for (lhsIndex, lhsChar) in lhsChars.enumerated() {
            var previousDistance = distances[0]
            distances[0] = lhsIndex + 1

            for (rhsIndex, rhsChar) in rhsChars.enumerated() {
                let currentDistance = distances[rhsIndex + 1]

                if lhsChar == rhsChar {
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

        return distances[rhsChars.count]
    }
}
