import SwiftUI

struct ImagePreviewView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .background(Color(.systemBackground))
            } else {
                ProgressView()
                    .task { await loadImage() }
            }
        }
        .onAppear {
            if image == nil {
                Task { await loadImage() }
            }
        }
    }

    private func loadImage() async {
        do {
            let data = try Data(contentsOf: url)
            if let uiImage = UIImage(data: data) {
                await MainActor.run { self.image = uiImage }
                print("Loaded gesture overlay image size", uiImage.size)
            } else {
                print("Unable to decode gesture overlay image at", url.path)
            }
        } catch {
            print("Error loading gesture overlay image at", url.path, error)
        }
    }
}
