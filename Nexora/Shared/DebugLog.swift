// DebugLog.swift
import Foundation

#if DIAGNOSTIC
final class DebugLog {
    static let shared = DebugLog()
    
    private let url: URL
    private let queue = DispatchQueue(label: "debuglog.write", qos: .utility)
    private let maxFileLines = 500
    private let maxRenderLogs = 50
    private var renderCount = 0
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory)[0]
        self.url = docs.appendingPathComponent("crash_debug.log")
    }
    
    func append(_ line: String) {
        queue.async { [weak self] in self?.appendSync(line) }
    }
    
    func appendRender(_ line: String) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.renderCount < self.maxRenderLogs {
                self.renderCount += 1
                self.appendSync("RENDER \(line)")
            } else if self.renderCount == self.maxRenderLogs {
                self.renderCount += 1
                self.appendSync("… RENDER logs capped at \(self.maxRenderLogs)")
            }
        }
    }
    
    func resetRenderCounter() { queue.async { self.renderCount = 0 } }
    
    var fileURL: URL { url }
    
    func prepareExport() -> URL {
        queue.sync { }
        return url
    }
    
    var hasContent: Bool {
        FileManager.default.fileExists(atPath: url.path) &&
        (try? Data(contentsOf: url).isEmpty == false) == true
    }
    
    private func appendSync(_ line: String) {
        let entry = "\(ts()) \(line)"
        var lines: [String] = []
        if let data = try? Data(contentsOf: url),
           let content = String(data: data, encoding: .utf8) {
            lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        }
        lines.append(entry)
        if lines.count > maxFileLines { lines.removeFirst(lines.count - maxFileLines) }
        
        let data = (lines.joined(separator: "\n") + "\n").data(using: .utf8)!
        let tmp = url.appendingPathExtension("tmp")
        
        do {
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: tmp, to: url)
        } catch {
        }
    }
    
    private func ts() -> String {
        let d = Date()
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }
}
#else
final class DebugLog {
    static let shared = DebugLog()
    func append(_ line: String) {}
    func appendRender(_ line: String) {}
    func resetRenderCounter() {}
    var fileURL: URL { URL(fileURLWithPath: "") }
    var hasContent: Bool { false }
    func prepareExport() -> URL { URL(fileURLWithPath: "") }
}
#endif