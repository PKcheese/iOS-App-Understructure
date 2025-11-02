import Foundation

enum MaquetteServiceError: Error {
    case unableToCreateBody
    case badServerResponse
}

struct MaquetteService {
    /// Update this if the API runs on a different host or port.
    static var baseURL = URL(string: "http://127.0.0.1:8000")!

    static func makeMaquette(imageData: Data, filename: String, mimeType: String) async throws -> URL {
        let endpoint = baseURL.appendingPathComponent("maquette")
        var request = URLRequest(url: endpoint)
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

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let zipURL = documentsURL.appendingPathComponent("maquette_variants.zip", conformingTo: .zip)
        try data.write(to: zipURL, options: .atomic)
        return zipURL
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
}
