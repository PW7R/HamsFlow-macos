import OSLog

enum Log {
    static let audio = Logger(subsystem: "com.mesh.hamsflow", category: "audio")
    static let speech = Logger(subsystem: "com.mesh.hamsflow", category: "speech")
    static let hotkey = Logger(subsystem: "com.mesh.hamsflow", category: "hotkey")
    static let inject = Logger(subsystem: "com.mesh.hamsflow", category: "inject")
    static let app = Logger(subsystem: "com.mesh.hamsflow", category: "app")
}
