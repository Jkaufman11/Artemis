
import SwiftUI
import RealityKit

struct ScanView: View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        return ARView(frame: .zero)
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
