import Foundation
import TipKit

struct ScanReceiptTip: Tip {
    var title: Text { Text("Scan a Receipt") }
    var message: Text? { Text("Take a photo of your receipt and we'll automatically detect the store, date, and total. Return policies are applied instantly.") }
    var image: Image? { Image(systemName: "doc.viewfinder") }
}

struct ReturnModeTip: Tip {
    @Parameter
    static var hasViewedItem: Bool = false

    var title: Text { Text("Return Mode") }
    var message: Text? { Text("Tap Return Mode to see everything you need: receipt, store address, what to bring, and your exact deadline — all on one screen.") }
    var image: Image? { Image(systemName: "arrow.uturn.left.circle") }

    var rules: [Rule] {
        #Rule(Self.$hasViewedItem) { $0 == true }
    }
}

struct WidgetTip: Tip {
    @Parameter
    static var hasAddedItem: Bool = false

    var title: Text { Text("Add a Widget") }
    var message: Text? { Text("Add the Receipt Folder widget to your lock screen or home screen to see your most urgent deadlines at a glance.") }
    var image: Image? { Image(systemName: "square.grid.2x2") }

    var rules: [Rule] {
        #Rule(Self.$hasAddedItem) { $0 == true }
    }
}

struct CalendarTip: Tip {
    var title: Text { Text("Add to Calendar") }
    var message: Text? { Text("Tap to add this return deadline to your calendar so you never miss it.") }
    var image: Image? { Image(systemName: "calendar.badge.plus") }
}

