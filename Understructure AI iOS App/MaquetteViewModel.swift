import Foundation
import SwiftUI
import Combine
import PhotosUI
import UniformTypeIdentifiers

@MainActor
final class MaquetteViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem?
    @Published var isUploading = false
    @Published var statusMessage: String?
    @Published var result: MaquetteResult?

    func uploadSelectedImage() async {
        guard let item = selectedItem else { return }
        do {
            isUploading = true
            statusMessage = "Preparing image…"
            result = nil

            guard let data = try await item.loadTransferable(type: Data.self) else {
                statusMessage = "Could not read the selected image."
                isUploading = false
                return
            }

            let filename = item.suggestedFilename ?? "photo.png"
            let mimeType = item.preferredMIMEType ?? UTType(filenameExtension: URL(fileURLWithPath: filename).pathExtension)?.preferredMIMEType ?? "image/jpeg"

            statusMessage = "Uploading…"
            let maquetteResult = try await MaquetteService.makeMaquette(imageData: data, filename: filename, mimeType: mimeType)
            result = maquetteResult
            statusMessage = """
Saved files:
- \(maquetteResult.nonInteractiveURL.lastPathComponent)
- \(maquetteResult.interactiveURL.lastPathComponent)
- \(maquetteResult.gestureURL.lastPathComponent)
- \(maquetteResult.zipURL.lastPathComponent)
""".trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            statusMessage = "Upload failed: \(error.localizedDescription)"
        }

        isUploading = false
    }
}

private extension PhotosPickerItem {
    var suggestedFilename: String? {
        if let id = itemIdentifier, !id.isEmpty {
            return URL(fileURLWithPath: id).lastPathComponent
        }
        return nil
    }

    var preferredMIMEType: String? {
        if #available(iOS 16.0, *), let type = supportedContentTypes.first?.preferredMIMEType {
            return type
        }
        return nil
    }
}
