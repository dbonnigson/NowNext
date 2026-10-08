import SwiftUI

/// Slot glyph colors. One accent (red) for Now; the lightning bolt is the
/// single yellow highlight; Next and Later stay white/muted.
extension Slot {
    var glyphColor: Color {
        switch self {
        case .now: Theme.yellow
        case .next: Theme.text
        case .later, .inbox: Theme.muted
        }
    }
}
