import Foundation
import UIKit

/// Un aliment détecté sur la photo par l'IA, avant confirmation/ajustement par l'utilisateur.
struct DetectedFoodItem: Identifiable, Decodable {
    var id: String { name }
    var name: String
    var estimatedQuantityGrams: Double
    var estimatedCalories: Double
    var estimatedProteinGrams: Double
    var estimatedCarbsGrams: Double
    var estimatedFatGrams: Double
    var confidence: String

    enum CodingKeys: String, CodingKey {
        case name, estimatedQuantityGrams, estimatedCalories
        case estimatedProteinGrams, estimatedCarbsGrams, estimatedFatGrams, confidence
    }
}

enum FoodVisionError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Aucune clé API Claude configurée. Ajoutez-la dans Réglages > Clé API."
        case .invalidResponse:
            return "Réponse inattendue de l'IA. Réessayez ou ajoutez l'aliment manuellement."
        case .apiError(let message):
            return "Erreur API : \(message)"
        }
    }
}

/// Envoie une photo de repas à l'API Claude (vision) et récupère une estimation
/// structurée des aliments détectés, de leurs quantités et de leurs calories.
/// L'utilisateur doit fournir sa propre clé API Anthropic (stockée dans le Keychain, voir `KeychainStore`).
final class FoodVisionService {
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-5"

    func analyzeMealPhoto(_ image: UIImage) async throws -> [DetectedFoodItem] {
        guard let apiKey = KeychainStore.loadAPIKey(), !apiKey.isEmpty else {
            throw FoodVisionError.missingAPIKey
        }
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            throw FoodVisionError.invalidResponse
        }
        let base64Image = jpegData.base64EncodedString()

        let promptText = """
        Tu es un nutritionniste expert. Analyse cette photo de repas et identifie chaque aliment visible.
        Pour chaque aliment, estime la quantité en grammes en te basant sur les proportions visuelles \
        (taille de l'assiette, ustensiles de référence si visibles), puis calcule les calories et macronutriments \
        correspondants à cette quantité (pas pour 100g, pour la quantité estimée réelle).

        Réponds UNIQUEMENT avec un JSON valide, sans texte autour, au format suivant :
        {
          "items": [
            {
              "name": "nom de l'aliment en français",
              "estimatedQuantityGrams": 150,
              "estimatedCalories": 250,
              "estimatedProteinGrams": 20,
              "estimatedCarbsGrams": 10,
              "estimatedFatGrams": 12,
              "confidence": "high | medium | low"
            }
          ]
        }
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1500,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": promptText
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodVisionError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "code \(httpResponse.statusCode)"
            throw FoodVisionError.apiError(message)
        }

        return try parseDetectedItems(from: data)
    }

    private func parseDetectedItems(from data: Data) throws -> [DetectedFoodItem] {
        struct ClaudeResponse: Decodable {
            struct ContentBlock: Decodable {
                var type: String
                var text: String?
            }
            var content: [ContentBlock]
        }
        struct ItemsWrapper: Decodable {
            var items: [DetectedFoodItem]
        }

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = claudeResponse.content.first(where: { $0.type == "text" })?.text else {
            throw FoodVisionError.invalidResponse
        }

        // Le modèle peut parfois entourer le JSON de balises ```json ... ``` malgré la consigne ; on nettoie.
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw FoodVisionError.invalidResponse
        }

        let wrapper = try JSONDecoder().decode(ItemsWrapper.self, from: jsonData)
        return wrapper.items
    }
}
