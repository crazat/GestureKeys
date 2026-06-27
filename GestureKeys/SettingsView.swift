import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - SwiftUI Settings View

struct SettingsView: View {
    @ObservedObject var config = GestureConfig.shared
    @State private var hasPermission = AXIsProcessTrusted()
    @State private var launchAtLogin = LaunchAtLoginHelper.isEnabled
    @State private var showingAppOverrides = false
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var expandedCategories: Set<String> = {
        if let saved = UserDefaults.standard.array(forKey: "expandedCategories") as? [String] {
            return Set(saved)
        }
        return Set(GestureConfig.categories.map(\.id))  // Default: all expanded
    }()

    private let permissionTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var filteredCategories: [GestureConfig.Category] {
        if debouncedSearch.isEmpty { return GestureConfig.categories }
        return GestureConfig.categories.compactMap { category in
            let filtered = category.gestures.filter {
                $0.name.localizedCaseInsensitiveContains(debouncedSearch) ||
                $0.action.localizedCaseInsensitiveContains(debouncedSearch) ||
                config.actionFor($0.id).displayName.localizedCaseInsensitiveContains(debouncedSearch)
            }
            if filtered.isEmpty { return nil }
            return GestureConfig.Category(id: category.id, title: category.title, icon: category.icon, gestures: filtered)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if !hasPermission {
                accessibilityBanner
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    generalSection
                    sensitivitySection
                    ForEach(filteredCategories) { category in
                        section(category: category)
                    }
                    if filteredCategories.isEmpty && !debouncedSearch.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("'\(debouncedSearch)' 검색 결과가 없습니다")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                    macroSection
                    tipsSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 460, minHeight: 560)
        .onChange(of: searchText) { _, newValue in
            // Debounce search for Korean IME composition — prevents flickering
            // during intermediate character composition (ㅂ → 복 → 복사)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if searchText == newValue { debouncedSearch = newValue }
            }
        }
        .onReceive(permissionTimer) { _ in
            hasPermission = AXIsProcessTrusted()
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
                    .font(.body)
                Text("일반")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: launchAtLogin) { _, newValue in
                            LaunchAtLoginHelper.setEnabled(newValue)
                            launchAtLogin = LaunchAtLoginHelper.isEnabled
                        }

                    Text("로그인 시 자동 시작")
                        .font(.body)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().padding(.leading, 44)

                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { config.hudEnabled },
                        set: { config.hudEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Text("제스처 HUD 표시")
                        .font(.body)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().padding(.leading, 44)

                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { config.hapticEnabled },
                        set: { config.hapticEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Text("햅틱 피드백")
                        .font(.body)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().padding(.leading, 44)

                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { config.typingSuppressionEnabled },
                        set: { config.typingSuppressionEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("타이핑 중 제스처 억제")
                            .font(.body)
                        Text("키보드 입력 직후 트랙패드 오작동 방지")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                if config.typingSuppressionEnabled {
                    Divider().padding(.leading, 44)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Spacer().frame(width: 36)
                            Text("억제 시간")
                                .font(.body)
                            Spacer()
                            Text(String(format: "%.1f초", config.typingSuppressionWindow))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        HStack {
                            Spacer().frame(width: 36)
                            Slider(value: Binding(
                                get: { config.typingSuppressionWindow },
                                set: { config.typingSuppressionWindow = $0 }
                            ), in: 0.1...1.0, step: 0.1)
                            .controlSize(.small)
                        }
                        HStack {
                            Spacer().frame(width: 36)
                            Text("키보드 입력 후 제스처를 억제하는 시간 (기본 0.3초)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                Divider().padding(.leading, 44)

                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { config.capsLockInputSwitch },
                        set: { newVal in
                            config.capsLockInputSwitch = newVal
                            if newVal && config.capsLockFastSwitch && !CapsLockMonitor.accessGranted() {
                                CapsLockMonitor.requestAccess()
                            }
                            CapsLockMonitor.shared.refresh()
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Caps Lock → 한영전환")
                            .font(.body)
                        Text("Caps Lock 키로 입력 소스를 즉시 전환합니다 (딜레이 없음)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Sub-option: raw HID capture to bypass the built-in keyboard's
                // ~250ms Caps Lock debounce (fixes dropped fast taps).
                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { config.capsLockFastSwitch },
                        set: { newVal in
                            config.capsLockFastSwitch = newVal
                            if newVal && !CapsLockMonitor.accessGranted() {
                                CapsLockMonitor.requestAccess()
                            }
                            CapsLockMonitor.shared.refresh()
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(!config.capsLockInputSwitch)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("빠른 인식 (입력 모니터링 권한)")
                            .font(.body)
                        Text("내장 키보드의 Caps Lock ~250ms 딜레이를 우회해 빠른 탭도 놓치지 않습니다. 권한 허용 후 앱 재시작을 권장합니다.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.leading, 44)
                .padding(.trailing, 12)
                .padding(.vertical, 8)
                .opacity(config.capsLockInputSwitch ? 1 : 0.5)

                Divider().padding(.leading, 44)

                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { config.cooldownEnabled },
                        set: { config.cooldownEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("제스처 쿨다운")
                            .font(.body)
                        Text("같은 제스처의 연속 발동을 방지합니다")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().padding(.leading, 44)

                HStack(spacing: 12) {
                    Spacer().frame(width: 32)
                    Button("앱별 제스처 설정...") {
                        showingAppOverrides = true
                    }
                    .controlSize(.small)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
        .sheet(isPresented: $showingAppOverrides) {
            AppOverrideView(config: config)
        }
    }

    @State private var showingMacroEditor = false

    private var macroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal")
                    .foregroundColor(.secondary)
                    .font(.body)
                Text("매크로")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showingMacroEditor = true }) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("새 매크로 추가")
            }

            VStack(spacing: 0) {
                if config.macros.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "bolt.horizontal")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("등록된 매크로가 없습니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("예: 3손가락 길게 → 3손가락 더블탭 = 복사 + 붙여넣기")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(Array(config.macros.enumerated()), id: \.element.id) { index, macro in
                        MacroRowView(macro: macro, config: config)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        if index < config.macros.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
        .sheet(isPresented: $showingMacroEditor) {
            MacroEditorView(config: config)
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .foregroundColor(.secondary)
                    .font(.body)
                Text("팁")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                tipRow(icon: "rectangle.split.2x1", text: "윈도우 스냅: 제스처 액션을 \"윈도우 왼쪽 절반\" 등으로 변경하면 창을 빠르게 정렬할 수 있습니다 (macOS 15+)")
                tipRow(icon: "computermouse", text: "미들클릭: 브라우저에서 탭 닫기, 새 탭으로 링크 열기 등에 활용할 수 있습니다")
                tipRow(icon: "terminal", text: "셸 명령: 어떤 제스처든 셸 명령이나 Apple Shortcuts에 연결할 수 있습니다")
                tipRow(icon: "keyboard", text: "Shift + 밝기 키: 키보드 백라이트를 조절합니다 (항상 활성)")
                tipRow(icon: "hand.draw", text: "제스처 테스트: 메뉴바에서 \"제스처 테스트\"로 인식 상태를 실시간 확인할 수 있습니다")
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
                .font(.callout)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var sensitivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.secondary)
                    .font(.body)
                Text("감도")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                sensitivitySlider(
                    label: "탭 속도",
                    value: Binding(get: { config.tapSpeedMultiplier }, set: { config.tapSpeedMultiplier = $0 }),
                    description: "탭/더블탭 인식 시간 허용치",
                    leftLabel: "빠르게", rightLabel: "느리게"
                )
                Divider().padding(.leading, 12)
                sensitivitySlider(
                    label: "스와이프 거리",
                    value: Binding(get: { config.swipeThresholdMultiplier }, set: { config.swipeThresholdMultiplier = $0 }),
                    description: "스와이프 인식에 필요한 이동 거리",
                    leftLabel: "짧게", rightLabel: "길게"
                )
                Divider().padding(.leading, 12)
                sensitivitySlider(
                    label: "이동 허용치",
                    value: Binding(get: { config.moveThresholdMultiplier }, set: { config.moveThresholdMultiplier = $0 }),
                    description: "탭 시 허용되는 손가락 움직임",
                    leftLabel: "엄격", rightLabel: "관대"
                )
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }

    private func sensitivitySlider(label: String, value: Binding<Double>, description: String, leftLabel: String, rightLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.body)
                Spacer()
                if value.wrappedValue != 1.0 {
                    Button("초기화") { value.wrappedValue = 1.0 }
                        .controlSize(.mini)
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                }
                Text(String(format: "%.1f×", value.wrappedValue))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 4) {
                Text(leftLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
                Slider(value: value, in: 0.5...2.0, step: 0.1)
                    .controlSize(.small)
                Text(rightLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .leading)
            }
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.body)
            VStack(alignment: .leading, spacing: 2) {
                Text("접근성 권한이 필요합니다")
                    .font(.callout)
                    .fontWeight(.medium)
                Text("제스처 인식을 위해 시스템 설정에서 허용해주세요")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("시스템 설정 열기") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "hand.raised.fingers.spread")
                    .font(.title2)
                Text("GestureKeys 설정")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                Spacer()
                Button(action: exportSettings) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("설정 내보내기")

                Button(action: importSettings) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("설정 가져오기")

                Menu("프리셋") {
                    Button {
                        applyPreset(.default)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("기본")
                            Text("권장 설정 — 탐색, 편집, 창 관리 제스처")
                                .font(.caption)
                        }
                    }
                    Button {
                        applyPreset(.minimal)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("최소")
                            Text("필수 제스처만 — 가장 간결한 설정")
                                .font(.caption)
                        }
                    }
                    Button {
                        applyPreset(.all)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("전체")
                            Text("모든 제스처 활성화 — 파워 유저용")
                                .font(.caption)
                        }
                    }
                }
                .controlSize(.small)
            }
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("제스처 검색...", text: $searchText)
                        .textFieldStyle(.plain)
                        .controlSize(.small)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
        }
        .padding(16)
    }

    private enum Preset { case `default`, minimal, all }

    private func applyPreset(_ preset: Preset) {
        for info in GestureConfig.all {
            switch preset {
            case .default:
                config.setEnabled(info.id, info.defaultEnabled)
            case .minimal:
                config.setEnabled(info.id, false)
            case .all:
                config.setEnabled(info.id, true)
            }
        }
    }

    private func section(category: GestureConfig.Category) -> some View {
        let isExpanded = expandedCategories.contains(category.id)
        return VStack(alignment: .leading, spacing: 0) {
            // Full-width tappable header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedCategories.remove(category.id)
                    } else {
                        expandedCategories.insert(category.id)
                    }
                    UserDefaults.standard.set(Array(expandedCategories), forKey: "expandedCategories")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Image(systemName: category.icon)
                        .foregroundColor(.secondary)
                        .font(.body)
                    Text(category.title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(category.gestures.filter { config.uiIsEnabled($0.id) }.count)/\(category.gestures.count)")
                        .font(.caption)
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))

                    if isExpanded {
                        let allEnabled = category.gestures.allSatisfy { config.uiIsEnabled($0.id) }
                        Button(allEnabled ? "모두 끄기" : "모두 켜기") {
                            let newValue = !allEnabled
                            for g in category.gestures {
                                config.setEnabled(g.id, newValue)
                            }
                        }
                        .controlSize(.mini)
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                VStack(spacing: 0) {
                    ForEach(Array(category.gestures.enumerated()), id: \.element.id) { index, gesture in
                        gestureRow(gesture)
                        if index < category.gestures.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private func gestureRow(_ gesture: GestureConfig.Info) -> some View {
        GestureRowView(gesture: gesture, config: config)
    }

    // MARK: - Export / Import

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "GestureKeys-Settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var dict: [String: Any] = [:]
        let defaults = UserDefaults.standard
        for info in GestureConfig.all {
            dict["gesture.\(info.id)"] = defaults.object(forKey: "gesture.\(info.id)")
            dict["action.\(info.id)"] = defaults.object(forKey: "action.\(info.id)")
            dict["cooldown.\(info.id)"] = defaults.object(forKey: "cooldown.\(info.id)")
            dict["shortcut.\(info.id)"] = defaults.object(forKey: "shortcut.\(info.id)")
            dict["zones.enabled.\(info.id)"] = defaults.object(forKey: "zones.enabled.\(info.id)")
            dict["zones.\(info.id).left"] = defaults.object(forKey: "zones.\(info.id).left")
            dict["zones.\(info.id).right"] = defaults.object(forKey: "zones.\(info.id).right")
            dict["shellCommand.\(info.id)"] = defaults.object(forKey: "shellCommand.\(info.id)")
            dict["customKey.\(info.id).keyCode"] = defaults.object(forKey: "customKey.\(info.id).keyCode")
            dict["customKey.\(info.id).flags"] = defaults.object(forKey: "customKey.\(info.id).flags")
        }
        for key in ["hudEnabled", "hapticEnabled", "cooldownEnabled", "capsLockInputSwitch",
                     "tapSpeedMultiplier", "swipeThresholdMultiplier", "moveThresholdMultiplier",
                     "typingSuppressionEnabled", "typingSuppressionWindow",
                     "macros"] {
            if key == "macros" {
                if let data = defaults.data(forKey: key),
                   let object = try? JSONSerialization.jsonObject(with: data) {
                    dict[key] = object
                }
            } else {
                dict[key] = defaults.object(forKey: key)
            }
        }
        // Filter nil values
        let filtered = dict.compactMapValues { $0 }
        do {
            let data = try JSONSerialization.data(withJSONObject: filtered, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            let alert = NSAlert()
            alert.messageText = "내보내기 완료"
            alert.informativeText = "설정이 저장되었습니다."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "확인")
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "내보내기 실패"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "확인")
            alert.runModal()
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let alert = NSAlert()
            alert.messageText = "불러오기 실패"
            alert.informativeText = "올바른 JSON 파일이 아닙니다."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "확인")
            alert.runModal()
            return
        }

        // Whitelist: only import keys that exportSettings() would produce.
        // Prevents arbitrary UserDefaults injection from malformed JSON.
        var allowedKeys = Set<String>()
        for info in GestureConfig.all {
            let id = info.id
            for prefix in ["gesture.", "action.", "cooldown.", "shortcut.",
                           "zones.enabled.", "shellCommand."] {
                allowedKeys.insert("\(prefix)\(id)")
            }
            allowedKeys.insert("zones.\(id).left")
            allowedKeys.insert("zones.\(id).right")
            allowedKeys.insert("customKey.\(id).keyCode")
            allowedKeys.insert("customKey.\(id).flags")
        }
        for key in ["hudEnabled", "hapticEnabled", "cooldownEnabled", "capsLockInputSwitch",
                     "tapSpeedMultiplier", "swipeThresholdMultiplier", "moveThresholdMultiplier",
                     "typingSuppressionEnabled", "typingSuppressionWindow",
                     "macros"] {
            allowedKeys.insert(key)
        }

        let defaults = UserDefaults.standard
        var importedCount = 0
        for (key, value) in dict where allowedKeys.contains(key) {
            if key == "macros" {
                guard JSONSerialization.isValidJSONObject(value),
                      let data = try? JSONSerialization.data(withJSONObject: value) else {
                    continue
                }
                defaults.set(data, forKey: key)
                importedCount += 1
            } else if isImportablePropertyListValue(value) {
                defaults.set(value, forKey: key)
                importedCount += 1
            }
        }
        config.reloadFromDefaults()

        let alert = NSAlert()
        alert.messageText = "불러오기 완료"
        alert.informativeText = "\(importedCount)개 설정을 불러왔습니다."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    private func isImportablePropertyListValue(_ value: Any) -> Bool {
        switch value {
        case is String, is NSNumber, is Date, is Data:
            return true
        case let array as [Any]:
            return array.allSatisfy { isImportablePropertyListValue($0) }
        case let dict as [String: Any]:
            return dict.values.allSatisfy { isImportablePropertyListValue($0) }
        default:
            return false
        }
    }
}

private let twoFingerSwipeIds: Set<String> = [
    "twoFingerSwipeRight", "twoFingerSwipeLeft",
]

private let threeFingerSwipeIds: Set<String> = [
    "threeFingerSwipeRight", "threeFingerSwipeLeft",
    "threeFingerSwipeUp", "threeFingerSwipeDown",
]

private struct GestureRowView: View {
    let gesture: GestureConfig.Info
    @ObservedObject var config: GestureConfig
    @State private var showingHowTo = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { config.uiIsEnabled(gesture.id) },
                    set: { config.setEnabled(gesture.id, $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)

                Text(gesture.name)
                    .font(.body)

                Spacer()

                Button(action: { showingHowTo.toggle() }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingHowTo, arrowEdge: .trailing) {
                    Text(gesture.howTo)
                        .font(.callout)
                        .padding(12)
                        .frame(width: 240)
                }
            }

            HStack(spacing: 12) {
                Spacer().frame(width: 32)
                Picker("", selection: Binding(
                    get: { config.actionFor(gesture.id) },
                    set: { config.setAction(gesture.id, $0) }
                )) {
                    ForEach(KeySynthesizer.Action.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)

                let currentAction = config.actionFor(gesture.id)
                if currentAction != .shortcut && currentAction != .custom && currentAction != .shellCommand {
                    Button(action: { currentAction.execute() }) {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .help("이 액션 테스트")
                }

                if let defaultAction = KeySynthesizer.defaultActions[gesture.id],
                   currentAction != defaultAction {
                    Button("초기화") {
                        config.setAction(gesture.id, defaultAction)
                    }
                    .controlSize(.mini)
                    .buttonStyle(.borderless)
                    .foregroundColor(.accentColor)
                }
            }

            if twoFingerSwipeIds.contains(gesture.id) && config.uiIsEnabled(gesture.id) {
                HStack(spacing: 6) {
                    Spacer().frame(width: 32)
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("시스템 설정 → 트랙패드 → 기타 제스처의 '페이지 사이를 쓸어넘기기'가 켜져 있으면 이중 동작이 발생할 수 있습니다.")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }

            if threeFingerSwipeIds.contains(gesture.id) && config.uiIsEnabled(gesture.id) {
                HStack(spacing: 6) {
                    Spacer().frame(width: 32)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("시스템 설정 → 트랙패드 → 기타 제스처에서 세 손가락 스와이프를 꺼야 충돌이 방지됩니다.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            if config.cooldownEnabled {
                HStack(spacing: 8) {
                    Spacer().frame(width: 32)
                    Text("쿨다운")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f초", config.cooldownDuration(for: gesture.id)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(width: 32)
                    Slider(
                        value: Binding(
                            get: { config.cooldownDuration(for: gesture.id) },
                            set: { config.setCooldownDuration(for: gesture.id, duration: $0) }
                        ),
                        in: 0.1...2.0, step: 0.1
                    )
                    .controlSize(.mini)
                }
            }

            if GestureConfig.zoneCapableGestures.contains(gesture.id) {
                ZoneConfigView(gestureId: gesture.id, config: config)
            }

            if config.actionFor(gesture.id) == .shortcut {
                HStack(spacing: 12) {
                    Spacer().frame(width: 32)
                    ShortcutNameView(gestureId: gesture.id, config: config)
                }
            }

            if config.actionFor(gesture.id) == .custom {
                HStack(spacing: 12) {
                    Spacer().frame(width: 32)
                    CustomKeySettingView(gestureId: gesture.id)
                }
            }

            if config.actionFor(gesture.id) == .shellCommand {
                HStack(spacing: 12) {
                    Spacer().frame(width: 32)
                    ShellCommandView(gestureId: gesture.id)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .opacity(config.uiIsEnabled(gesture.id) ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.15), value: config.uiIsEnabled(gesture.id))
    }
}

// MARK: - Zone Config View

private struct ZoneConfigView: View {
    let gestureId: String
    @ObservedObject var config: GestureConfig

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                Spacer().frame(width: 32)
                Toggle("존 기반 액션", isOn: Binding(
                    get: { config.zonesEnabled(for: gestureId) },
                    set: { config.setZonesEnabled(for: gestureId, enabled: $0) }
                ))
                .controlSize(.small)
                .font(.caption)
                Spacer()
            }

            if config.zonesEnabled(for: gestureId) {
                HStack(spacing: 12) {
                    Spacer().frame(width: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        zonePicker(zone: .left, label: "왼쪽")
                        zonePicker(zone: .right, label: "오른쪽")
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(4)
                }
            }
        }
    }

    private func zonePicker(zone: TrackpadZone, label: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .frame(width: 40, alignment: .trailing)
            Picker("", selection: Binding(
                get: { config.zoneAction(for: gestureId, zone: zone) ?? config.actionFor(gestureId) },
                set: { config.setZoneAction(for: gestureId, zone: zone, action: $0) }
            )) {
                ForEach(KeySynthesizer.Action.allCases) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .labelsHidden()
            .controlSize(.mini)
        }
    }
}

// MARK: - Shortcut Name View

private struct ShortcutNameView: View {
    let gestureId: String
    @ObservedObject var config: GestureConfig
    @State private var name: String = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField("Shortcut 이름", text: $name)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .onAppear { name = config.shortcutName(for: gestureId) ?? "" }
                .onSubmit { config.setShortcutName(for: gestureId, name: name) }
                .onChange(of: name) { _, newValue in
                    config.setShortcutName(for: gestureId, name: newValue)
                }

            Button(action: {
                KeySynthesizer.executeShortcut(gestureId: gestureId)
            }) {
                Image(systemName: "play.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Shortcut 테스트 실행")
            .disabled(name.isEmpty)
        }
    }
}

// MARK: - Shell Command View

private struct ShellCommandView: View {
    let gestureId: String
    @State private var command: String = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField("셸 명령 (예: open -a Calculator)", text: $command)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .onAppear { command = UserDefaults.standard.string(forKey: "shellCommand.\(gestureId)") ?? "" }
                .onSubmit { save() }
                .onChange(of: command) { _, _ in save() }

            Button(action: {
                KeySynthesizer.executeShellCommand(gestureId: gestureId)
            }) {
                Image(systemName: "play.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("셸 명령 테스트 실행")
            .disabled(command.isEmpty)
        }
    }

    private func save() {
        UserDefaults.standard.set(command, forKey: "shellCommand.\(gestureId)")
    }
}

// MARK: - App Override View

struct AppOverrideView: View {
    @ObservedObject var config: GestureConfig
    @Environment(\.dismiss) private var dismiss
    @State private var newBundleId = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("앱별 제스처 설정")
                .font(.title3)
                .fontWeight(.semibold)

            Text("앱별로 제스처를 끄거나 다른 액션으로 변경할 수 있습니다.")
                .font(.callout)
                .foregroundColor(.secondary)

            // Quick add: show the last active app for one-click addition
            if let lastBundleId = GestureConfig.shared.lastExternalBundleId,
               config.appOverrides[lastBundleId] == nil {
                HStack(spacing: 8) {
                    if let icon = appIcon(for: lastBundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    Text(lastBundleId)
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("이 앱 추가") {
                        addBundleId(lastBundleId)
                    }
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(6)
            }

            HStack {
                TextField("Bundle ID (예: com.apple.Safari)", text: $newBundleId)
                    .textFieldStyle(.roundedBorder)
                Button("추가") {
                    addBundleId(newBundleId)
                }
                .disabled(newBundleId.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("앱 선택...") {
                    pickApp()
                }
                .controlSize(.small)
                .help("Applications 폴더에서 앱을 선택합니다")
            }

            if config.overriddenBundleIds.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.title)
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("등록된 앱이 없습니다")
                        .foregroundColor(.secondary)
                    Text("Bundle ID를 입력하거나 \"이전 앱\" 버튼을 사용하세요")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(config.overriddenBundleIds, id: \.self) { bundleId in
                            appSection(bundleId: bundleId)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("닫기") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 520, height: 500)
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "제스처를 설정할 앱을 선택하세요"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
            addBundleId(bundleId)
        }
    }

    private func addBundleId(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if config.appOverrides[trimmed] == nil {
            var overrides = config.appOverrides
            overrides[trimmed] = []
            config.appOverrides = overrides
        }
        newBundleId = ""
    }

    private func appSection(bundleId: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let appIcon = appIcon(for: bundleId) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                Text(bundleId)
                    .font(.callout)
                    .fontWeight(.medium)
                Spacer()
                Button(action: { config.removeAppOverride(bundleId: bundleId) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("이 앱 설정 삭제")
            }

            VStack(spacing: 2) {
                ForEach(GestureConfig.categories) { category in
                    Text(category.title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                        .padding(.leading, 4)
                    ForEach(category.gestures) { gesture in
                    HStack(spacing: 6) {
                        Toggle("", isOn: Binding(
                            get: { !config.isGestureDisabledForApp(gesture.id, bundleId: bundleId) },
                            set: { config.setGestureDisabledForApp(gesture.id, bundleId: bundleId, disabled: !$0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .frame(width: 32)

                        Text(gesture.name)
                            .font(.caption)
                            .frame(width: 120, alignment: .leading)
                            .lineLimit(1)

                        Picker("", selection: Binding(
                            get: {
                                config.appActionOverride(for: gesture.id, bundleId: bundleId) ?? config.actionFor(gesture.id)
                            },
                            set: { newAction in
                                if newAction == config.actionFor(gesture.id) {
                                    config.setAppActionOverride(for: gesture.id, bundleId: bundleId, action: nil)
                                } else {
                                    config.setAppActionOverride(for: gesture.id, bundleId: bundleId, action: newAction)
                                }
                            }
                        )) {
                            ForEach(KeySynthesizer.Action.allCases) { action in
                                Text(action.displayName).tag(action)
                            }
                        }
                        .controlSize(.mini)
                        .frame(maxWidth: .infinity)
                    }
                    }
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private func appIcon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Macro Row View

private struct MacroRowView: View {
    let macro: MacroDefinition
    @ObservedObject var config: GestureConfig
    @State private var showingEditor = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { macro.isEnabled },
                set: { newValue in
                    var updated = macro
                    updated.isEnabled = newValue
                    config.updateMacro(updated)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(macro.name.isEmpty ? "이름 없는 매크로" : macro.name)
                    .font(.body)
                Text(triggerSummary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if hasDisabledTrigger {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("트리거 제스처 비활성화됨")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }

            Spacer()

            Text("\(macro.resultActions.count)개 액션")
                .font(.caption2)
                .foregroundColor(.secondary)

            Button("편집") { showingEditor = true }
                .controlSize(.mini)
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)

            Button(action: { config.deleteMacro(id: macro.id) }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .opacity(macro.isEnabled ? 1.0 : 0.5)
        .sheet(isPresented: $showingEditor) {
            MacroEditorView(macro: macro, config: config)
        }
    }

    private var triggerSummary: String {
        macro.triggerGestures
            .compactMap { GestureConfig.info(for: $0)?.name }
            .joined(separator: " → ")
    }

    private var hasDisabledTrigger: Bool {
        macro.isEnabled && macro.triggerGestures.contains { !config.uiIsEnabled($0) }
    }
}

// MARK: - Window Controller

final class SettingsWindowController {

    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())

        let window = NSWindow(contentViewController: hostingController)
        window.title = "GestureKeys 설정"
        window.styleMask = [.titled, .closable, .resizable]
        window.setFrameAutosaveName("SettingsWindow")
        if !window.setFrameUsingName("SettingsWindow") {
            window.center()  // Only center on first launch (no saved frame)
        }
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
