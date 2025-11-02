import Foundation
enum MaquetteServiceError: Error {
    case badServerResponse
}

struct MaquetteService {
    /// Update this URL if the API is running on a different host or port.
    static var baseURL = URL(string: "http://127.0.0.1:8000")!

    static func makeMaquette(imageData: Data, filename: String, mimeType: String) async throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("maquette"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "variant", value: "nomatch")]
        guard let requestURL = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"

        let boundary = "Boundary-" + UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MaquetteServiceError.badServerResponse
        }

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelURL = documents.appendingPathComponent("maquette_modified_rings_nomatch.glb")
        try data.write(to: modelURL, options: .atomic)
        return modelURL
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
