import SwiftUI
import AppKit
import ServiceManagement

// MARK: - SwiftUI Settings View

struct SettingsView: View {
    @ObservedObject var config = GestureConfig.shared
    @State private var hasPermission = AXIsProcessTrusted()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showingAppOverrides = false
    @State private var searchText = ""

    private let permissionTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var filteredCategories: [GestureConfig.Category] {
        if searchText.isEmpty { return GestureConfig.categories }
        return GestureConfig.categories.compactMap { category in
            let filtered = category.gestures.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.action.localizedCaseInsensitiveContains(searchText)
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
                }
                .padding(20)
            }
        }
        .frame(minWidth: 460, minHeight: 560)
        .onReceive(permissionTimer) { _ in
            hasPermission = AXIsProcessTrusted()
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Text("일반")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: launchAtLogin) { newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                NSLog("GestureKeys: Launch at login error: %@", error.localizedDescription)
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
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
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

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

    private var sensitivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Text("감도")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                sensitivitySlider(
                    label: "탭 속도",
                    value: Binding(get: { config.tapSpeedMultiplier }, set: { config.tapSpeedMultiplier = $0 }),
                    description: "탭/더블탭 인식 시간 허용치"
                )
                Divider().padding(.leading, 12)
                sensitivitySlider(
                    label: "스와이프 거리",
                    value: Binding(get: { config.swipeThresholdMultiplier }, set: { config.swipeThresholdMultiplier = $0 }),
                    description: "스와이프 인식에 필요한 이동 거리"
                )
                Divider().padding(.leading, 12)
                sensitivitySlider(
                    label: "이동 허용치",
                    value: Binding(get: { config.moveThresholdMultiplier }, set: { config.moveThresholdMultiplier = $0 }),
                    description: "탭 시 허용되는 손가락 움직임"
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

    private func sensitivitySlider(label: String, value: Binding<Double>, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
            Slider(value: value, in: 0.5...2.0, step: 0.1)
                .controlSize(.small)
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("접근성 권한이 필요합니다")
                .font(.callout)
                .fontWeight(.medium)
            Spacer()
            Button("시스템 설정 열기") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "hand.raised.fingers.spread")
                    .font(.title2)
                Text("GestureKeys 설정")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Menu("프리셋") {
                    Button("기본") { applyPreset(.default) }
                    Button("최소") { applyPreset(.minimal) }
                    Button("전체") { applyPreset(.all) }
                }
                .controlSize(.small)
            }
            HStack {
                TextField("제스처 검색...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                Spacer()
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup {
                VStack(spacing: 0) {
                    ForEach(Array(category.gestures.enumerated()), id: \.element.id) { index, gesture in
                        gestureRow(gesture)
                        if index < category.gestures.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Text(category.title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }

            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }

    private func gestureRow(_ gesture: GestureConfig.Info) -> some View {
        GestureRowView(gesture: gesture, config: config)
    }
}

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
            }

            if config.actionFor(gesture.id) == .custom {
                HStack(spacing: 12) {
                    Spacer().frame(width: 32)
                    CustomKeySettingView(gestureId: gesture.id)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

            Text("특정 앱에서 비활성화할 제스처를 선택하세요.")
                .font(.callout)
                .foregroundColor(.secondary)

            HStack {
                TextField("Bundle ID (예: com.apple.Safari)", text: $newBundleId)
                    .textFieldStyle(.roundedBorder)
                Button("추가") {
                    addBundleId(newBundleId)
                }
                .disabled(newBundleId.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("이전 앱") {
                    if let bundleId = GestureConfig.shared.lastExternalBundleId {
                        addBundleId(bundleId)
                    }
                }
                .controlSize(.small)
                .help("GestureKeys 실행 전 사용 중이던 앱의 Bundle ID를 자동 입력합니다")
                .disabled(GestureConfig.shared.lastExternalBundleId == nil)
            }

            if config.overriddenBundleIds.isEmpty {
                Text("등록된 앱이 없습니다.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
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
        .frame(width: 420, height: 400)
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
                Text(bundleId)
                    .font(.callout)
                    .fontWeight(.medium)
                Spacer()
                Button(action: { config.removeAppOverride(bundleId: bundleId) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            let allGestures = GestureConfig.all
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 4) {
                ForEach(allGestures) { gesture in
                    Toggle(gesture.name, isOn: Binding(
                        get: { config.isGestureDisabledForApp(gesture.id, bundleId: bundleId) },
                        set: { config.setGestureDisabledForApp(gesture.id, bundleId: bundleId, disabled: $0) }
                    ))
                    .controlSize(.small)
                    .font(.caption)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
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
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
