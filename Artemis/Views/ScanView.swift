
import SwiftUI
import RealityKit
import ARKit
import Vision

struct ScanView: View {
    @StateObject private var scanService = ARScanService()
    @State private var instructions: String = "Move your device to scan the entire room."
    @State private var scanProgress: Double = 0.0
    @State private var isScanning: Bool = true
    @State private var show3DModel: Bool = false
    var onExit: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            if isScanning {
                ARViewContainer(scanService: scanService, progress: $scanProgress, instructions: $instructions, isScanning: $isScanning)
                    .edgesIgnoringSafeArea(.all)
                AnimatedInstructionsOverlay(scanService: scanService, progress: scanProgress, instructions: instructions)
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { onExit?() }) {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                                .padding()
                        }
                    }
                    Spacer()
                }
            } else {
                Room3DModelView(roomScan: scanService.roomScan, onBack: {
                    isScanning = true
                })
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var scanService: ARScanService
    @Binding var progress: Double
    @Binding var instructions: String
    @Binding var isScanning: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(scanService: scanService, progress: $progress, instructions: $instructions, isScanning: $isScanning)
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        scanService.setupARSession(for: arView, delegate: context.coordinator)
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    class Coordinator: NSObject, ARSessionDelegate {
        var scanService: ARScanService
        @Binding var progress: Double
        @Binding var instructions: String
        @Binding var isScanning: Bool
        
        init(scanService: ARScanService, progress: Binding<Double>, instructions: Binding<String>, isScanning: Binding<Bool>) {
            self.scanService = scanService
            _progress = progress
            _instructions = instructions
            _isScanning = isScanning
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            scanService.processFrame(frame) { coverage, nextInstruction in
                DispatchQueue.main.async {
                    self.progress = coverage
                    self.instructions = nextInstruction
                }
            }
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            scanService.handleAnchors(anchors)
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            scanService.handleAnchors(anchors)
        }
        
        func session(_ session: ARSession, didFinish sessionRun: ARSession) {
            DispatchQueue.main.async {
                self.isScanning = false
            }
        }
    }
}

struct AnimatedInstructionsOverlay: View {
    @ObservedObject var scanService: ARScanService
    var progress: Double
    var instructions: String
    @State private var animateArrows = false
    @State private var animateDots = false
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Projected mesh feature points as dots
                ForEach(Array(scanService.surfaceFeaturePoints.prefix(50).enumerated()), id: \.offset) { idx, point in
                    if let screenPoint = scanService.projectToScreen(point) {
                        let isFurniture = scanService.furnitureFeatureIndices.contains(idx)
                        Circle()
                            .fill(isFurniture ? Color.green.opacity(0.8) : Color.white.opacity(0.8))
                            .frame(width: animateDots ? 18 : 10, height: animateDots ? 18 : 10)
                            .position(x: screenPoint.x, y: screenPoint.y)
                            .scaleEffect(animateDots ? 1.2 : 1.0)
                            .animation(Animation.easeInOut(duration: 1.2).repeatForever().delay(Double(idx)*0.02), value: animateDots)
                    }
                }
                // Arrows: point to areas with less mesh coverage (placeholder: top, left, right, bottom)
                ForEach(arrowDirections(for: scanService.surfaceFeaturePoints, in: geo.size), id: \.self) { dir in
                    ArrowView(direction: dir, animate: animateArrows, geoSize: geo.size)
                }
                VStack {
                    Text(instructions)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 40)
                    Spacer()
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(2)
                        .padding(.bottom, 60)
                }
                .padding()
            }
            .onAppear {
                animateArrows = true
                animateDots = true
            }
        }
    }
    // Heuristic: if there are fewer points in a region, suggest scanning there
    func arrowDirections(for points: [SIMD3<Float>], in size: CGSize) -> [ArrowDirection] {
        // Divide screen into quadrants, count points in each
        var counts = [ArrowDirection.up: 0, .down: 0, .left: 0, .right: 0]
        for point in points {
            if let screen = scanService.projectToScreen(point) {
                if screen.y < size.height * 0.3 { counts[.up, default: 0] += 1 }
                else if screen.y > size.height * 0.7 { counts[.down, default: 0] += 1 }
                if screen.x < size.width * 0.3 { counts[.left, default: 0] += 1 }
                else if screen.x > size.width * 0.7 { counts[.right, default: 0] += 1 }
            }
        }
        // Find regions with lowest coverage
        let minCount = counts.values.min() ?? 0
        return counts.filter { $0.value == minCount && minCount < 10 }.map { $0.key }
    }
}

enum ArrowDirection: Hashable { case up, down, left, right }

struct ArrowView: View {
    let direction: ArrowDirection
    let animate: Bool
    let geoSize: CGSize
    @State private var offset: CGFloat = 0
    var body: some View {
        let (rotation, pos): (Double, CGPoint) = {
            switch direction {
            case .up: return (0, CGPoint(x: geoSize.width/2, y: 60))
            case .down: return (180, CGPoint(x: geoSize.width/2, y: geoSize.height-60))
            case .left: return (-90, CGPoint(x: 60, y: geoSize.height/2))
            case .right: return (90, CGPoint(x: geoSize.width-60, y: geoSize.height/2))
            }
        }()
        return Image(systemName: "arrowtriangle.up.fill")
            .resizable()
            .frame(width: 40, height: 40)
            .rotationEffect(.degrees(rotation))
            .foregroundColor(.blue)
            .opacity(0.8)
            .position(pos)
            .offset(x: animate ? (direction == .left ? -20 : direction == .right ? 20 : 0) : 0,
                    y: animate ? (direction == .up ? -20 : direction == .down ? 20 : 0) : 0)
            .animation(Animation.easeInOut(duration: 1.2).repeatForever(), value: animate)
    }
}

// Placeholder for 3D model view
struct Room3DModelView: View {
    var roomScan: RoomScan?
    var onBack: () -> Void
    var body: some View {
        VStack {
            Text("3D Room Model")
            Button("Back to Scan", action: onBack)
        }
    }
}
