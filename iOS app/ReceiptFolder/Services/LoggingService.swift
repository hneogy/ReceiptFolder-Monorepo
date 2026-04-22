import os

enum RFLogger {
    static let storage = Logger(subsystem: "com.receiptfolder", category: "storage")
    static let notification = Logger(subsystem: "com.receiptfolder", category: "notification")
    static let widget = Logger(subsystem: "com.receiptfolder", category: "widget")
    static let ocr = Logger(subsystem: "com.receiptfolder", category: "ocr")
    static let spotlight = Logger(subsystem: "com.receiptfolder", category: "spotlight")
    static let liveActivity = Logger(subsystem: "com.receiptfolder", category: "liveActivity")
    static let policy = Logger(subsystem: "com.receiptfolder", category: "policy")
    static let general = Logger(subsystem: "com.receiptfolder", category: "general")
}
