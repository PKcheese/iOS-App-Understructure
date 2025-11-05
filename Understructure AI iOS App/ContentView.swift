import SwiftUI
import PhotosUI
import SceneKit
import SceneKit.ModelIO
import MetalKit
import ModelIO
import Combine

struct ContentView: View {
    @StateObject private var viewModel = MaquetteViewModel()
    @State private var isShowingViewer = false
    @State private var activePreviewURL: URL?
    @State private var activePreviewTitle: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PhotosPicker(selection: selectedItemBinding, matching: .images) {
                    Label("Choose Photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task { await viewModel.uploadSelectedImage() }
                } label: {
                    Label(viewModel.isUploading ? "Uploading…" : "Send to API", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedItem == nil || viewModel.isUploading)

                if viewModel.isUploading {
                    ProgressView()
                }

                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if let result = viewModel.result {
                    Button {
                        activePreviewURL = result.nonInteractiveURL
                        activePreviewTitle = "Non-interactive"
                        isShowingViewer = true
                    } label: {
                        Label("View Non-interactive", systemImage: "cube")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        activePreviewURL = result.interactiveURL
                        activePreviewTitle = "Interactive"
                        isShowingViewer = true
                    } label: {
                        Label("View Interactive", systemImage: "cube.transmission")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        activePreviewURL = result.gestureURL
                        activePreviewTitle = "Gesture Overlay"
                        isShowingViewer = true
                    } label: {
                        Label("View Gesture", systemImage: "hand.draw")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: result.zipURL) {
                        Label("Share Zip", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Understructure AI")
            .sheet(isPresented: $isShowingViewer) {
                if let url = activePreviewURL {
                    if url.pathExtension.lowercased() == "png" {
                        NavigationStack {
                            ImagePreviewView(url: url)
                                .ignoresSafeArea()
                                .navigationTitle(activePreviewTitle ?? "Preview")
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Done") { isShowingViewer = false }
                                    }
                                }
                        }
                    } else {
                        NavigationStack {
                            PreviewView(url: url)
                                .ignoresSafeArea()
                                .navigationTitle(activePreviewTitle ?? "Preview")
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Done") { isShowingViewer = false }
                                    }
                                }
                        }
                    }
                }
            }
            .onChange(of: viewModel.result) { _ in
                resetPreviewState()
            }
        }
    }

    private var selectedItemBinding: Binding<PhotosPickerItem?> {
        Binding(
            get: { viewModel.selectedItem },
            set: { viewModel.selectedItem = $0 }
        )
    }

    private func resetPreviewState() {
        isShowingViewer = false
        activePreviewURL = nil
        activePreviewTitle = nil
    }
}

#Preview {
    ContentView()
}

struct PreviewView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIView {
        let view = SCNView()
        view.backgroundColor = .systemBackground
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        loadScene(into: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let scnView = uiView as? SCNView {
            loadScene(into: scnView)
        }
    }

    private func loadScene(into view: SCNView) {
        DispatchQueue.global(qos: .userInitiated).async {
            let scene = buildScene()
            DispatchQueue.main.async {
                if let scene = scene {
                    view.scene = scene
                    print("Loaded scene with", scene.rootNode.childNodes.count, "children")
                    printSceneNodes(scene.rootNode, depth: 0)
                } else {
                    print("Failed to load scene at", url.path)
                }
            }
        }
    }

    private func buildScene() -> SCNScene? {
        if let device = MTLCreateSystemDefaultDevice() {
            let allocator = MTKMeshBufferAllocator(device: device)
            do {
                let asset = try MDLAsset(url: url, vertexDescriptor: nil, bufferAllocator: allocator)
                asset.loadTextures()
                let scene = SCNScene(mdlAsset: asset)
                prepare(scene)
                return scene
            } catch {
                print("ModelIO load failed:", error)
            }
        }
        if let scene = try? SCNScene(url: url, options: [SCNSceneSource.LoadingOption.checkConsistency: true]) {
            prepare(scene)
            return scene
        }
        if let source = try? SCNSceneSource(url: url, options: nil), let scene = source.scene(options: nil) {
            prepare(scene)
            return scene
        }
        print("All scene loading strategies failed for", url.path)
        return nil
    }

    private func prepare(_ scene: SCNScene) {
        centerContents(of: scene.rootNode)
        if scene.rootNode.childNode(withName: "camera", recursively: true) == nil {
            let cameraNode = SCNNode()
            cameraNode.name = "camera"
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zFar = 100
            cameraNode.position = SCNVector3(0, 0, 3)
            scene.rootNode.addChildNode(cameraNode)
        }
        if scene.rootNode.childNode(withName: "fillLight", recursively: true) == nil {
            let lightNode = SCNNode()
            lightNode.name = "fillLight"
            lightNode.light = SCNLight()
            lightNode.light?.type = .omni
            lightNode.position = SCNVector3(2, 2, 2)
            scene.rootNode.addChildNode(lightNode)
        }
    }


    private func printSceneNodes(_ node: SCNNode, depth: Int) {
        let indent = String(repeating: "  ", count: depth)
        print("\(indent)node: \(node.name ?? "(unnamed)")")
        for child in node.childNodes {
            printSceneNodes(child, depth: depth + 1)
        }
    }
    private func centerContents(of root: SCNNode) {
        let (minVec, maxVec) = root.boundingBox
        let center = SCNVector3((minVec.x + maxVec.x) * 0.5,
                                (minVec.y + maxVec.y) * 0.5,
                                (minVec.z + maxVec.z) * 0.5)
        root.childNodes.forEach { node in
            node.position = SCNVector3(node.position.x - center.x,
                                       node.position.y - center.y,
                                       node.position.z - center.z)
        }
    }
}
