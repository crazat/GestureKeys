import Foundation
import AppKit

// MARK: - Pre-computed log path for signal handler (async-signal-safe)

/// C string path for the crash log file, computed once at install time.
/// Signal handlers must use only async-signal-safe functions (POSIX open/write/close).
private var crashLogPathCString: [CChar] = []

/// Static message prefix written by the signal handler (no dynamic allocation).
private let signalCrashPrefix: StaticString = "GestureKeys Crash Report\n========================\nReason: Fatal Signal\n\nSignal: "

/// Signal number → name mapping (static, no allocation).
private let signalNames: [(sig: Int32, name: StaticString)] = [
    (SIGSEGV, "SIGSEGV"), (SIGBUS, "SIGBUS"), (SIGABRT, "SIGABRT"),
    (SIGFPE, "SIGFPE"), (SIGILL, "SIGILL"), (SIGTRAP, "SIGTRAP"),
]

// MARK: - C-compatible signal handler (async-signal-safe only)

private func crashSignalHandler(_ sigNum: Int32) {
    // Use only POSIX I/O — no Foundation, no String, no allocation.
    guard !crashLogPathCString.isEmpty else {
        signal(sigNum, SIG_DFL)
        raise(sigNum)
        return
    }
    let fd = crashLogPathCString.withUnsafeBufferPointer { buf -> Int32 in
        Darwin.open(buf.baseAddress!, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
    }
    if fd >= 0 {
        // Write prefix
        signalCrashPrefix.withUTF8Buffer { buf in
            _ = Darwin.write(fd, buf.baseAddress, buf.count)
        }
        // Write signal name
        let name = signalNames.first(where: { $0.sig == sigNum })?.name ?? "UNKNOWN"
        name.withUTF8Buffer { buf in
            _ = Darwin.write(fd, buf.baseAddress, buf.count)
        }
        let nl: StaticString = "\n"
        nl.withUTF8Buffer { buf in
            _ = Darwin.write(fd, buf.baseAddress, buf.count)
        }
        Darwin.close(fd)
    }
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
        // Ensure log directory exists (safe to do here, before any crash)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        // Pre-compute C string path for the signal handler (must not allocate at signal time)
        crashLogPathCString = Array(logPath.path.utf8CString)

        // Exception handler runs in normal context — Foundation APIs are safe here
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

    // MARK: - Internal (used by NSSetUncaughtExceptionHandler only — NOT signal-safe)

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

        try? log.write(to: logPath, atomically: true, encoding: .utf8)
    }
}
