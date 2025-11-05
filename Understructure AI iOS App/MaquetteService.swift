import Foundation
import UniformTypeIdentifiers

enum MaquetteServiceError: Error {
    case unableToCreateBody
    case badServerResponse
}

struct MaquetteResult: Equatable {
    let zipURL: URL
    let nonInteractiveURL: URL
    let interactiveURL: URL
    let gestureURL: URL
}

struct MaquetteService {
    /// Update this URL if the API runs on a different host or port.
    static var baseURL = URL(string: "http://127.0.0.1:8001")!

    static func makeMaquette(imageData: Data, filename: String, mimeType: String) async throws -> MaquetteResult {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let zipURL = documentsURL.appendingPathComponent("maquette_variants.zip")
        let nonInteractiveURL = documentsURL.appendingPathComponent("maquette_modified_rings.glb")
        let interactiveURL = documentsURL.appendingPathComponent("maquette_interactive.glb")
        let gestureURL = documentsURL.appendingPathComponent("gesture_overlay.png")

        try? FileManager.default.removeItem(at: zipURL)
        try? FileManager.default.removeItem(at: nonInteractiveURL)
        try? FileManager.default.removeItem(at: interactiveURL)
        try? FileManager.default.removeItem(at: gestureURL)

        let zipData = try await performRequest(imageData: imageData, filename: filename, mimeType: mimeType, variant: nil)
        try zipData.write(to: zipURL, options: .atomic)
        print("Saved zip at \(zipURL.path) size=\(zipData.count) bytes")

        let matchData = try await performRequest(imageData: imageData, filename: filename, mimeType: mimeType, variant: "match")
        try matchData.write(to: nonInteractiveURL, options: .atomic)
        print("Saved non-interactive GLB at \(nonInteractiveURL.path) size=\(matchData.count) bytes")

        let interactiveData = try await performRequest(imageData: imageData, filename: filename, mimeType: mimeType, variant: "interactive")
        try interactiveData.write(to: interactiveURL, options: .atomic)
        print("Saved interactive GLB at \(interactiveURL.path) size=\(interactiveData.count) bytes")

        let gestureData = try await performRequest(imageData: imageData, filename: filename, mimeType: mimeType, variant: "gesture")
        try gestureData.write(to: gestureURL, options: .atomic)
        print("Saved gesture overlay at \(gestureURL.path) size=\(gestureData.count) bytes")

        return MaquetteResult(
            zipURL: zipURL,
            nonInteractiveURL: nonInteractiveURL,
            interactiveURL: interactiveURL,
            gestureURL: gestureURL
        )
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

    private static func createMultipartBody(imageData: Data, filename: String, mimeType: String, boundary: String) -> Data? {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
