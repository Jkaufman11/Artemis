import Foundation
import ARKit
import RealityKit
import Vision
import Combine

class ARScanService: ObservableObject {
    @Published var roomScan: RoomScan? = nil
    private var meshAnchors: [ARMeshAnchor] = []
    private var recognizedObjects: [RecognizedObject] = []
    private var arView: ARView?
    private var visionRequests: [VNRequest] = []
    private var cancellables = Set<AnyCancellable>()
    // Published array of world positions for UI overlays (e.g., mesh vertices on furniture)
    @Published var surfaceFeaturePoints: [SIMD3<Float>] = []
    // Published set of indices for points on recognized furniture
    @Published var furnitureFeatureIndices: Set<Int> = []
    
    func setupARSession(for arView: ARView, delegate: ARSessionDelegate) {
        self.arView = arView
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        config.planeDetection = [.horizontal, .vertical]
        arView.session.delegate = delegate
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        // setupVision() // Commented out: Vision/CoreML not available
    }
    
    func processFrame(_ frame: ARFrame, completion: @escaping (Double, String) -> Void) {
        // Calculate coverage and update instructions
        let coverage = calculateCoverage()
        let nextInstruction = guidanceInstruction(for: coverage)
        // Update surface feature points for UI overlays
        updateSurfaceFeaturePoints(frame: frame)
        // recognizeObjects(in: frame) // Commented out: Vision/CoreML not available
        completion(coverage, nextInstruction)
    }
    
    func handleAnchors(_ anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.append(meshAnchor)
            }
        }
        updateRoomScan()
    }
    
    private func updateRoomScan() {
        roomScan = RoomScan(meshAnchors: meshAnchors, recognizedObjects: recognizedObjects)
    }
    
    private func calculateCoverage() -> Double {
        // Placeholder: Use meshAnchors to estimate coverage (0.0 - 1.0)
        return min(Double(meshAnchors.count) / 50.0, 1.0)
    }
    
    private func guidanceInstruction(for coverage: Double) -> String {
        switch coverage {
        case ..<0.2: return "Scan the floor and move around the room."
        case ..<0.5: return "Scan the walls by moving your device up."
        case ..<0.8: return "Scan the ceiling and corners."
        default: return "Scan complete!"
        }
    }
    
    // Extract a sample of mesh vertices as feature points for UI overlays
    private func updateSurfaceFeaturePoints(frame: ARFrame) {
        var points: [SIMD3<Float>] = []
        var furnitureIndices = Set<Int>()
        var idx = 0
        for anchor in meshAnchors {
            let mesh = anchor.geometry
            let vertexCount = mesh.vertices.count
            let vertexBuffer = mesh.vertices
            let vertexPointer = vertexBuffer.buffer.contents().advanced(by: vertexBuffer.offset)
            let vertexStride = vertexBuffer.stride
            // Sample every Nth vertex for performance
            let step = max(1, vertexCount / 50)
            for i in stride(from: 0, to: vertexCount, by: step) {
                let pointer = vertexPointer.advanced(by: i * vertexStride)
                let vertex = pointer.bindMemory(to: SIMD3<Float>.self, capacity: 1).pointee
                let worldVertex = anchor.transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
                let worldPoint = SIMD3<Float>(worldVertex.x, worldVertex.y, worldVertex.z)
                points.append(worldPoint)
                // Mark as furniture if within threshold of any recognized object
                for obj in recognizedObjects {
                    if simd_distance(worldPoint, obj.position) < 0.2 { // 20cm threshold
                        furnitureIndices.insert(idx)
                        break
                    }
                }
                idx += 1
            }
        }
        surfaceFeaturePoints = points
        furnitureFeatureIndices = furnitureIndices
    }
    
    // Project a 3D world point to 2D screen coordinates using ARView and ARFrame
    func projectToScreen(_ point: SIMD3<Float>) -> CGPoint? {
        guard let arView = arView, let frame = arView.session.currentFrame else { return nil }
        let projected = frame.camera.projectPoint(point, orientation: .portrait, viewportSize: arView.bounds.size)
        return projected
    }
    
    // Commented out: Vision/CoreML not available
    /*
    private func setupVision() {
        // Load CoreML model for furniture detection (replace with your model)
        guard let model = try? VNCoreMLModel(for: FurnitureClassifier().model) else { return }
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            self?.handleVisionResults(request: request, error: error)
        }
        visionRequests = [request]
    }
    
    private func recognizeObjects(in frame: ARFrame) {
        guard let pixelBuffer = frame.capturedImage as CVPixelBuffer? else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform(visionRequests)
    }
    
    private func handleVisionResults(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
        for observation in results {
            let label = observation.labels.first?.identifier ?? "Object"
            let boundingBox = observation.boundingBox
            // Convert boundingBox to world position using ARFrame/ARView (placeholder)
            let position = SIMD3<Float>(0,0,0) // TODO: Map to world
            let recognized = RecognizedObject(label: label, position: position)
            if !recognizedObjects.contains(where: { $0.label == label && $0.position == position }) {
                recognizedObjects.append(recognized)
                // Optionally add ARAnchor for tag
            }
        }
        updateRoomScan()
    }
    */
    
    // Manual tag adjustment methods (move, relabel, delete) would go here
} 