import Foundation
import AppKit

// MARK: - C-compatible signal handler (no captures allowed)

private func crashSignalHandler(_ sigNum: Int32) {
    CrashReporter.writeCrashLog(
        reason: "Fatal Signal",
        detail: "Signal \(sigNum) (\(CrashReporter.signalName(sigNum)))"
    )
    signal(sigNum, SIG_DFL)
    raise(sigNum)
}

/// Minimal crash reporter that catches uncaught exceptions and fatal signals,
/// writes a log to ~/Library/Logs/GestureKeys/crash.log, and offers to show it on next launch.
enum CrashReporter {

    private static let logDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/GestureKeys")
    private static let logPath = logDir.appendingPathComponent("crash.log")

    /// Install exception and signal handlers. Call once at app launch (before anything else).
    static func install() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.writeCrashLog(
                reason: "Uncaught Exception",
                detail: "\(exception.name.rawValue): \(exception.reason ?? "unknown")\n\(exception.callStackSymbols.joined(separator: "\n"))"
            )
        }

        signal(SIGSEGV, crashSignalHandler)
        signal(SIGBUS, crashSignalHandler)
        signal(SIGABRT, crashSignalHandler)
        signal(SIGFPE, crashSignalHandler)
        signal(SIGILL, crashSignalHandler)
        signal(SIGTRAP, crashSignalHandler)
    }

    /// Check for a crash log from a previous session. Call after UI is ready.
    static func checkForPreviousCrash() {
        guard FileManager.default.fileExists(atPath: logPath.path) else { return }

        guard let content = try? String(contentsOf: logPath, encoding: .utf8) else { return }

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "이전 실행에서 크래시가 감지되었습니다"
            alert.informativeText = "크래시 로그가 저장되었습니다.\n\(logPath.path)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "로그 복사")
            alert.addButton(withTitle: "로그 보기")
            alert.addButton(withTitle: "무시")

            let response = alert.runModal()

            switch response {
            case .alertFirstButtonReturn:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(content, forType: .string)
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(logPath)
            default:
                break
            }

            // Remove the log so we don't show the alert again
            try? FileManager.default.removeItem(at: logPath)
        }
    }

    // MARK: - Internal (accessed by signal handler)

    static func writeCrashLog(reason: String, detail: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        let log = """
        GestureKeys Crash Report
        ========================
        Date: \(timestamp)
        Version: \(version) (\(build))
        Reason: \(reason)

        \(detail)
        """

        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        try? log.write(to: logPath, atomically: true, encoding: .utf8)
    }

    static func signalName(_ sig: Int32) -> String {
        switch sig {
        case SIGSEGV: return "SIGSEGV"
        case SIGBUS: return "SIGBUS"
        case SIGABRT: return "SIGABRT"
        case SIGFPE: return "SIGFPE"
        case SIGILL: return "SIGILL"
        case SIGTRAP: return "SIGTRAP"
        default: return "SIG\(sig)"
        }
    }
}
