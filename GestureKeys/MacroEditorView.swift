import SwiftUI

/// Sheet for creating or editing a macro definition.
struct MacroEditorView: View {

    @ObservedObject var config: GestureConfig
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var triggerGestures: [String]
    @State private var resultActions: [MacroAction]
    @State private var timeoutMs: Double
    @State private var isEnabled: Bool

    private let editingId: UUID?

    /// Create a new macro.
    init(config: GestureConfig) {
        self.config = config
        self.editingId = nil
        _name = State(initialValue: "")
        _triggerGestures = State(initialValue: ["", ""])
        _resultActions = State(initialValue: [.builtIn(KeySynthesizer.Action.cmdW.rawValue)])
        _timeoutMs = State(initialValue: 800)
        _isEnabled = State(initialValue: true)
    }

    /// Edit an existing macro.
    init(macro: MacroDefinition, config: GestureConfig) {
        self.config = config
        self.editingId = macro.id
        _name = State(initialValue: macro.name)
        _triggerGestures = State(initialValue: macro.triggerGestures)
        _resultActions = State(initialValue: macro.resultActions)
        _timeoutMs = State(initialValue: Double(macro.timeoutMs))
        _isEnabled = State(initialValue: macro.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingId == nil ? "새 매크로" : "매크로 편집")
                .font(.title3)
                .fontWeight(.semibold)

            // Name
            HStack {
                Text("이름")
                    .frame(width: 60, alignment: .trailing)
                TextField("매크로 이름", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            // Trigger gestures
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("트리거 제스처")
                        .font(.headline)
                    Spacer()
                    if triggerGestures.count < 3 {
                        Button {
                            triggerGestures.append("")
                        } label: {
                            Label("단계 추가", systemImage: "plus")
                        }
                        .controlSize(.small)
                        .help("트리거 시퀀스에 제스처 단계를 추가합니다 (최대 3단계)")
                    }
                }

                ForEach(triggerGestures.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        Text("단계 \(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)

                        Picker("", selection: $triggerGestures[index]) {
                            Text("선택...").tag("")
                            ForEach(GestureConfig.all) { info in
                                Text(info.name).tag(info.id)
                            }
                        }
                        .labelsHidden()

                        if index > 0, let name = GestureConfig.info(for: triggerGestures[index])?.name {
                            Text(name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        if triggerGestures.count > 2 {
                            Button(action: { triggerGestures.remove(at: index) }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Arrow between steps
                if triggerGestures.count >= 2 {
                    let validNames = triggerGestures.filter({ !$0.isEmpty })
                        .compactMap { GestureConfig.info(for: $0)?.name }
                    if validNames.count >= 2 {
                        Text(validNames.joined(separator: " → "))
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .padding(.leading, 58)
                    }
                }

                // Warn if first trigger gesture shadows a standalone action
                if let first = triggerGestures.first, !first.isEmpty,
                   GestureConfig.shared.uiIsEnabled(first) {
                    let actionName = config.actionFor(first).displayName
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption2)
                        Text("'\(GestureConfig.info(for: first)?.name ?? first)' → '\(actionName)' 액션이 매크로 대기 시간(\(Int(timeoutMs))ms) 동안 지연됩니다.")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .padding(.leading, 58)
                }
            }

            // Timeout
            HStack {
                Text("대기 시간")
                    .frame(width: 60, alignment: .trailing)
                Slider(value: $timeoutMs, in: 300...2000, step: 100)
                Text(String(format: "%.0fms", timeoutMs))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 48)
            }

            Divider()

            // Result actions
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("실행할 액션")
                        .font(.headline)
                    Spacer()
                    if resultActions.count < 5 {
                        Menu {
                            Button("액션 추가") {
                                resultActions.append(.builtIn(KeySynthesizer.Action.cmdW.rawValue))
                            }
                            Button("딜레이 추가") {
                                resultActions.append(.delay(100))
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .controlSize(.small)
                    }
                }

                ForEach(resultActions.indices, id: \.self) { index in
                    macroActionRow(index: index)
                }
            }

            Divider()

            // Validation + Buttons
            HStack {
                if let error = validationError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(editingId == nil ? "생성" : "저장") {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 480, height: 500)
    }

    // MARK: - Action Row

    @ViewBuilder
    private func macroActionRow(index: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16, alignment: .trailing)

            switch resultActions[index] {
            case .builtIn(let raw):
                Picker("", selection: Binding(
                    get: { KeySynthesizer.Action(rawValue: raw) ?? .cmdW },
                    set: { resultActions[index] = .builtIn($0.rawValue) }
                )) {
                    ForEach(KeySynthesizer.Action.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
                .controlSize(.small)

            case .delay(let ms):
                HStack {
                    Text("딜레이")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: Binding(
                        get: { Double(ms) },
                        set: { resultActions[index] = .delay(Int($0)) }
                    ), in: 50...2000, step: 50)
                    Text("\(ms)ms")
                        .font(.caption.monospacedDigit())
                        .frame(width: 48)
                }

            case .shortcut(let name):
                HStack {
                    Text("⌘")
                    TextField("Shortcut 이름", text: Binding(
                        get: { name },
                        set: { resultActions[index] = .shortcut($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                }

            case .shellCommand(let cmd):
                HStack {
                    Text("$")
                    TextField("셸 명령", text: Binding(
                        get: { cmd },
                        set: { resultActions[index] = .shellCommand($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                }
            }

            // Type switcher
            Menu {
                Button("내장 액션") { resultActions[index] = .builtIn(KeySynthesizer.Action.cmdW.rawValue) }
                Button("Shortcut") { resultActions[index] = .shortcut("") }
                Button("셸 명령") { resultActions[index] = .shellCommand("") }
                Button("딜레이") { resultActions[index] = .delay(100) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
            }
            .controlSize(.small)

            if resultActions.count > 1 {
                if index > 0 {
                    Button(action: { resultActions.swapAt(index, index - 1) }) {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                if index < resultActions.count - 1 {
                    Button(action: { resultActions.swapAt(index, index + 1) }) {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: { resultActions.remove(at: index) }) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Validation & Save

    private var isValid: Bool {
        validationError == nil
    }

    private var validationError: String? {
        if name.isEmpty { return "이름을 입력하세요" }
        if triggerGestures.count < 2 { return "트리거 제스처 2개 이상 필요" }
        if triggerGestures.contains(where: { $0.isEmpty }) { return "트리거 제스처를 모두 선택하세요" }
        let unique = Set(triggerGestures)
        if unique.count != triggerGestures.count { return "트리거 제스처가 중복되었습니다" }
        if resultActions.isEmpty { return "실행할 액션 1개 이상 필요" }
        let hasRealAction = resultActions.contains { action in
            switch action { case .delay: return false; default: return true }
        }
        if !hasRealAction { return "딜레이만으로는 매크로를 구성할 수 없습니다" }
        return nil
    }

    private func save() {
        let macro = MacroDefinition(
            id: editingId ?? UUID(),
            name: name,
            triggerGestures: triggerGestures,
            resultActions: resultActions,
            timeoutMs: Int(timeoutMs),
            isEnabled: isEnabled
        )
        if editingId != nil {
            config.updateMacro(macro)
        } else {
            config.addMacro(macro)
        }
    }
}
