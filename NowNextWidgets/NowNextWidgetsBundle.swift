import SwiftUI
import WidgetKit

@main
struct NowNextWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NowWidget()
        FocusLiveActivity()
    }
}
