import Foundation
import AppKit

// MARK: - Data Types

/// A macro action that can be executed as part of a macro sequence.
enum MacroAction: Codable, Equatable {
    case builtIn(String)        // KeySynthesizer.Action rawValue
    case shortcut(String)       // Apple Shortcuts name
    case shellCommand(String)   // shell command
    case delay(Int)             // inter-action delay in ms

    var displayName: String {
        switch self {
        case .builtIn(let raw):
            return KeySynthesizer.Action(rawValue: raw)?.displayName ?? raw
        case .shortcut(let name): return "⌘ \(name)"
        case .shellCommand(let cmd):
            let display = cmd.count > 20 ? String(cmd.prefix(20)) + "…" : cmd
            return "$ \(display)"
        case .delay(let ms): return "\(ms)ms 대기"
        }
    }
}

/// A macro definition: a sequence of trigger gestures → a sequence of result actions.
struct MacroDefinition: Codable, Identifiable {
    let id: UUID
    var name: String
    var triggerGestures: [String]     // ordered gesture IDs (2-3)
    var resultActions: [MacroAction]  // ordered actions to execute (1-5)
    var timeoutMs: Int                // window between gestures (300-2000, default 800)
    var isEnabled: Bool

    var timeoutInterval: TimeInterval { Double(timeoutMs) / 1000.0 }

    init(id: UUID = UUID(), name: String = "", triggerGestures: [String] = [],
         resultActions: [MacroAction] = [], timeoutMs: Int = 800, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.triggerGestures = triggerGestures
        self.resultActions = resultActions
        self.timeoutMs = timeoutMs
        self.isEnabled = isEnabled
    }
}

// MARK: - MacroEngine

/// Intercepts gesture firings and matches them against macro trigger sequences.
/// State is accessed under the global `engineLock` (same lock as GestureEngine).
final class MacroEngine {

    static let shared = MacroEngine()

    /// Result of macro interception check.
    enum Decision {
        case passthrough                    // no macro involvement, fire normally
        case consumed                       // gesture consumed (partial match started/advanced)
        case completed([MacroAction])       // macro completed, fire these actions
    }

    // MARK: - State (accessed under engineLock)

    private struct PartialMatch {
        let id: UUID
        let macro: MacroDefinition
        let stepIndex: Int                  // next expected step (1-based: 1 = first step consumed)
        let consumedGestureId: String       // the first gesture that was consumed
        let timestamp: TimeInterval
    }

    private var stateLock = os_unfair_lock()
    private var partialMatch: PartialMatch?
    private var timeoutItem: DispatchWorkItem?

    // MARK: - Cached macros (protected by macrosLock)

    private var macrosLock = os_unfair_lock()
    private var cachedMacros: [MacroDefinition] = []
    /// gestureId → macros that START with this gesture
    private var firstGestureLookup: [String: [MacroDefinition]] = [:]

    private init() {}

    // MARK: - Configuration

    /// Updates cached macros from settings. Called from main thread.
    func updateMacros(_ macros: [MacroDefinition]) {
        var lookup: [String: [MacroDefinition]] = [:]
        for macro in macros where macro.isEnabled && macro.triggerGestures.count >= 2 {
            let firstGesture = macro.triggerGestures[0]
            lookup[firstGesture, default: []].append(macro)
        }
        os_unfair_lock_lock(&macrosLock)
        cachedMacros = macros
        firstGestureLookup = lookup
        os_unfair_lock_unlock(&macrosLock)
        reset()
    }

    /// Resets macro state. Thread-safe.
    func reset() {
        os_unfair_lock_lock(&stateLock)
        timeoutItem?.cancel()
        timeoutItem = nil
        partialMatch = nil
        os_unfair_lock_unlock(&stateLock)
    }

    // MARK: - Interception (called under engineLock)

    /// Checks if the fired gesture is part of a macro sequence.
    /// Must be called while engineLock is held.
    func interceptGesture(gestureId: String) -> Decision {
        // Read lookup under macrosLock (fast snapshot)
        os_unfair_lock_lock(&macrosLock)
        let lookup = firstGestureLookup
        os_unfair_lock_unlock(&macrosLock)

        let now = ProcessInfo.processInfo.systemUptime

        // --- Partial match in progress ---
        os_unfair_lock_lock(&stateLock)
        if let partial = partialMatch {
            timeoutItem?.cancel()
            timeoutItem = nil

            guard partial.stepIndex < partial.macro.triggerGestures.count else {
                partialMatch = nil
                os_unfair_lock_unlock(&stateLock)
                return checkNewMacro(gestureId: gestureId, lookup: lookup, now: now)
            }
            let expectedGesture = partial.macro.triggerGestures[partial.stepIndex]

            if expectedGesture == gestureId {
                // Correct next gesture
                let nextStep = partial.stepIndex + 1

                if nextStep >= partial.macro.triggerGestures.count {
                    // Macro complete!
                    partialMatch = nil
                    let actions = partial.macro.resultActions
                    let macroName = partial.macro.name
                    os_unfair_lock_unlock(&stateLock)
                    KeySynthesizer.appendPendingAction {
                        GestureHUD.shared.show(name: "매크로: \(macroName)", action: "✓ 완료")
                    }
                    return .completed(actions)
                } else {
                    // Advance partial match
                    let nextMatch = PartialMatch(
                        id: UUID(),
                        macro: partial.macro,
                        stepIndex: nextStep,
                        consumedGestureId: partial.consumedGestureId,
                        timestamp: now
                    )
                    partialMatch = nextMatch
                    let step = nextStep
                    let total = partial.macro.triggerGestures.count
                    let macroName = partial.macro.name
                    os_unfair_lock_unlock(&stateLock)
                    KeySynthesizer.appendPendingAction {
                        GestureHUD.shared.show(
                            name: "매크로: \(macroName)",
                            action: "단계 \(step)/\(total) ✓ → 다음 제스처 대기..."
                        )
                    }
                    scheduleTimeout(macro: nextMatch.macro, consumedGestureId: nextMatch.consumedGestureId, matchId: nextMatch.id)
                    return .consumed
                }
            } else {
                // Wrong gesture — partial match fails
                let consumedId = partial.consumedGestureId
                partialMatch = nil
                os_unfair_lock_unlock(&stateLock)

                // Fire the originally-consumed standalone action
                KeySynthesizer.fireStandaloneAction(gestureId: consumedId)

                // Check if THIS gesture starts a new macro
                return checkNewMacro(gestureId: gestureId, lookup: lookup, now: now)
            }
        }
        os_unfair_lock_unlock(&stateLock)

        // --- Idle: check if this gesture starts a macro ---
        return checkNewMacro(gestureId: gestureId, lookup: lookup, now: now)
    }

    // MARK: - Private

    private func checkNewMacro(gestureId: String, lookup: [String: [MacroDefinition]], now: TimeInterval) -> Decision {
        guard let candidates = lookup[gestureId], !candidates.isEmpty else {
            return .passthrough
        }

        // Use first matching macro (simplification: no multi-candidate ambiguity)
        let macro = candidates[0]

        let match = PartialMatch(
            id: UUID(),
            macro: macro,
            stepIndex: 1,
            consumedGestureId: gestureId,
            timestamp: now
        )
        os_unfair_lock_lock(&stateLock)
        timeoutItem?.cancel()
        timeoutItem = nil
        partialMatch = match
        os_unfair_lock_unlock(&stateLock)

        let macroName = macro.name
        let total = macro.triggerGestures.count
        KeySynthesizer.appendPendingAction {
            GestureHUD.shared.show(
                name: "매크로: \(macroName)",
                action: "단계 1/\(total) ✓ → 다음 제스처 대기..."
            )
        }

        scheduleTimeout(macro: macro, consumedGestureId: gestureId, matchId: match.id)
        return .consumed
    }

    private func scheduleTimeout(macro: MacroDefinition, consumedGestureId: String, matchId: UUID) {
        // Capture the action closure for the consumed gesture while under engineLock.
        let config = GestureConfig.shared
        let feedback = config.feedbackSnapshot
        let action = config.appAwareActionFor(consumedGestureId)
        let gestureInfo = GestureConfig.info(for: consumedGestureId)

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }

            os_unfair_lock_lock(&self.stateLock)
            guard let partial = self.partialMatch, partial.id == matchId else {
                os_unfair_lock_unlock(&self.stateLock)
                return
            }
            self.partialMatch = nil
            self.timeoutItem = nil
            os_unfair_lock_unlock(&self.stateLock)

            // Execute the originally-consumed standalone action on main thread
            GestureStats.shared.record(gestureId: consumedGestureId)
            if feedback.hudEnabled, let info = gestureInfo {
                GestureHUD.shared.show(name: info.name, action: info.action)
            }
            if feedback.hapticEnabled {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            if action == .shortcut {
                KeySynthesizer.executeShortcut(gestureId: consumedGestureId)
            } else if action == .custom {
                KeySynthesizer.postCustomKey(forGesture: consumedGestureId)
            } else if action == .shellCommand {
                KeySynthesizer.executeShellCommand(gestureId: consumedGestureId)
            } else {
                action.execute()
            }
        }

        os_unfair_lock_lock(&stateLock)
        let shouldSchedule = partialMatch?.id == matchId
        if shouldSchedule {
            timeoutItem?.cancel()
            timeoutItem = item
        }
        os_unfair_lock_unlock(&stateLock)

        if shouldSchedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + macro.timeoutInterval, execute: item)
        }
    }

    // MARK: - Macro Execution

    /// Executes macro result actions sequentially. Called from pendingActions (after lock release).
    static func executeMacroActions(_ actions: [MacroAction]) {
        var delay: TimeInterval = 0
        for action in actions {
            switch action {
            case .delay(let ms):
                delay += Double(ms) / 1000.0
            case .builtIn(let raw):
                if let a = KeySynthesizer.Action(rawValue: raw) {
                    let d = delay
                    if d > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + d) { a.execute() }
                    } else {
                        a.execute()
                    }
                }
            case .shortcut(let name):
                let d = delay
                DispatchQueue.main.asyncAfter(deadline: .now() + d) {
                    KeySynthesizer.executeShortcut(name: name)
                }
            case .shellCommand(let cmd):
                let d = delay
                DispatchQueue.main.asyncAfter(deadline: .now() + d) {
                    KeySynthesizer.executeShellCommandDirect(command: cmd)
                }
            }
        }
    }
}
