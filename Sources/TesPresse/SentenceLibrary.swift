import Foundation

struct FrenchSentence: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let sourcePath: String
    let sourceTitle: String
}

enum SentenceLibrary {
    static let fallbackSentences: [FrenchSentence] = [
        .init(text: "Je suis déjà en retard, mais je garde le sourire.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Tu peux fermer la fenêtre avant de partir ?", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "J'ai oublié mon carnet sur la table du salon.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Il faut que je prenne le bus dans trois minutes.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Pourquoi est-ce que tu parles si vite aujourd'hui ?", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "On se retrouve devant la gare après le travail.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Je n'ai pas encore fini mon café.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Le train part plus tôt que prévu ce soir.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Je cherche mes clés partout dans l'appartement.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Tu as pensé à envoyer le message à ta sœur ?", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Je voudrais réserver une table pour deux personnes.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Tu peux répéter la dernière phrase plus lentement ?", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "J'ai besoin d'une minute pour réfléchir.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Je préfère arriver en avance plutôt que courir.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Je répète cette phrase pour travailler mon oreille.", sourcePath: "built-in", sourceTitle: "Fallback"),
        .init(text: "Je vais essayer de mieux prononcer cette phrase.", sourcePath: "built-in", sourceTitle: "Fallback")
    ]

    static func randomSentence(from sentences: [FrenchSentence], excluding previousID: UUID?) -> FrenchSentence {
        let pool = sentences.isEmpty ? fallbackSentences : sentences
        let filtered = pool.filter { $0.id != previousID }
        return filtered.randomElement() ?? pool[0]
    }
}
