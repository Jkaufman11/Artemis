import Foundation
import ARKit

struct RoomScan {
    var meshAnchors: [ARMeshAnchor]
    var recognizedObjects: [RecognizedObject]
}

struct RecognizedObject: Identifiable, Equatable {
    let id = UUID()
    var label: String
    var position: SIMD3<Float>
} 