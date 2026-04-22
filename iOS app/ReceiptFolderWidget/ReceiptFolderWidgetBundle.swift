import WidgetKit
import SwiftUI

@main
struct ReceiptFolderWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextExpiringWidget()
        TopExpiringWidget()
    }
}
