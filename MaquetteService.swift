import Foundation

enum MaquetteServiceError: Error {
    case unableToCreateBody
    case badServerResponse
}

struct MaquetteResult: Equatable {
    let zipURL: URL
    let nonInteractiveURL: URL
    let interactiveURL: URL
}

struct MaquetteService {
    /// Update this if the API runs on a different host or port.
    static var baseURL = URL(string: "http://127.0.0.1:8001")!

    static func makeMaquette(imageData: Data, filename: String, mimeType: String) async throws -> MaquetteResult {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let zipURL = documentsURL.appendingPathComponent("maquette_variants.zip", conformingTo: .zip)
        let nonInteractiveURL = documentsURL.appendingPathComponent("maquette_modified_rings.glb")
        let interactiveURL = documentsURL.appendingPathComponent("maquette_interactive.glb")

        try? FileManager.default.removeItem(at: zipURL)
        try? FileManager.default.removeItem(at: nonInteractiveURL)
        try? FileManager.default.removeItem(at: interactiveURL)

        let zipData = try await performRequest(imageData: imageData, filename: filename, mimeType: mimeType, variant: nil)
        try zipData.write(to: zipURL, options: .atomic)

        let matchData = try await performRequest(imageData: imageData, filename: filename, mimeType: mimeType, variant: "match")
        try matchData.write(to: nonInteractiveURL, options: .atomic)

        let interactiveData = try await performRequest(imageData: imageData, filename: filename, mimeType: mimeType, variant: "interactive")
        try interactiveData.write(to: interactiveURL, options: .atomic)

        return MaquetteResult(zipURL: zipURL, nonInteractiveURL: nonInteractiveURL, interactiveURL: interactiveURL)
    }

    private static func createMultipartBody(imageData: Data, filename: String, mimeType: String, boundary: String) -> Data? {
        var body = Data()
        let lineBreak = "\r\n"

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private static func performRequest(imageData: Data, filename: String, mimeType: String, variant: String?) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent("maquette"), resolvingAgainstBaseURL: false)!
        if let variant {
            components.queryItems = [URLQueryItem(name: "variant", value: variant)]
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"

        let boundary = "Boundary-" + UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        guard let body = createMultipartBody(imageData: imageData, filename: filename, mimeType: mimeType, boundary: boundary) else {
            throw MaquetteServiceError.unableToCreateBody
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MaquetteServiceError.badServerResponse
        }
        return data
    }
}

extension MaquetteServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unableToCreateBody:
            return "Unable to create multipart form body."
        case .badServerResponse:
            return "Server responded with an unexpected status code."
        }
    }
}
