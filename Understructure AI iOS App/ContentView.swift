import SwiftUI
import PhotosUI
import SceneKit
import SceneKit.ModelIO
import MetalKit
import ModelIO

struct ContentView: View {
    @StateObject private var viewModel = MaquetteViewModel()
    @State private var isShowingViewer = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PhotosPicker(selection: $viewModel.selectedItem, matching: .images) {
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

                if let url = viewModel.savedModelURL {
                    Button {
                        isShowingViewer = true
                    } label: {
                        Label("View GLB", systemImage: "cube")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: url) {
                        Label("Share GLB", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Understructure AI")
            .sheet(isPresented: $isShowingViewer) {
                if let url = viewModel.savedModelURL {
                    NavigationStack {
                        GLBViewerView(url: url)
                            .ignoresSafeArea()
                            .navigationTitle("Preview")
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { isShowingViewer = false }
                                }
                            }
                    }
                }
            }
            .onChange(of: viewModel.savedModelURL) { _, _ in
                isShowingViewer = false
            }
        }
    }
}

#Preview {
    ContentView()
}

struct GLBViewerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .systemBackground
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        loadScene(into: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        loadScene(into: uiView)
    }

    private func loadScene(into view: SCNView) {
        DispatchQueue.global(qos: .userInitiated).async {
            let scene = buildScene()
            DispatchQueue.main.async {
                view.scene = scene
                print("Scene node count:", scene?.rootNode.childNodes.count ?? 0)
                if let scene = scene { printSceneNodes(scene.rootNode, depth: 0) }
            }
        }
    }

    private func buildScene() -> SCNScene? {
        if let device = MTLCreateSystemDefaultDevice() {
            let allocator = MTKMeshBufferAllocator(device: device)
            if let asset = try? MDLAsset(url: url, vertexDescriptor: nil, bufferAllocator: allocator) {
                asset.loadTextures()
                MDLAsset.load()
                let scene = SCNScene(mdlAsset: asset)
                prepare(scene)
                return scene
            }
        }
        if let scene = try? SCNScene(url: url, options: [SCNSceneSource.LoadingOption.checkConsistency: true]) {
            prepare(scene)
            return scene
        }
        if let source = try? SCNSceneSource(url: url, options: nil),
           let scene = source.scene(options: nil) {
            prepare(scene)
            return scene
        }
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
