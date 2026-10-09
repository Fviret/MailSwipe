import SwiftUI

extension SwipeDirection {
    var color: Color {
        switch self {
        case .right: return .green
        case .left: return .red
        case .up: return .blue
        case .down: return .purple
        }
    }
}
