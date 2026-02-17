import SwiftUI
import AppKit

/// Three-page onboarding flow shown on first launch.
struct OnboardingView: View {

    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                permissionPage.tag(1)
                quickStartPage.tag(2)
            }
            .tabViewStyle(.automatic)

            Divider()

            HStack {
                if currentPage > 0 {
                    Button("이전") {
                        withAnimation { currentPage -= 1 }
                    }
                }
                Spacer()

                // Page indicators
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()
                if currentPage < 2 {
                    Button("다음") {
                        withAnimation { currentPage += 1 }
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("시작하기") {
                        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        .frame(width: 440, height: 380)
    }

    private var welcomePage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hand.raised.fingers.spread")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("GestureKeys에 오신 것을 환영합니다")
                .font(.title2)
                .fontWeight(.bold)
            Text("트랙패드 멀티터치 제스처로\n키보드 단축키를 실행하세요.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(24)
    }

    private var permissionPage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("접근성 권한 설정")
                .font(.title2)
                .fontWeight(.bold)
            Text("GestureKeys가 트랙패드 제스처를 인식하고\n키 입력을 시뮬레이션하려면 접근성 권한이 필요합니다.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("시스템 설정 열기") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            Spacer()
        }
        .padding(24)
    }

    private var quickStartPage: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("빠른 시작")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                quickTip(icon: "hand.tap", text: "두 손가락 더블탭 → 복사")
                quickTip(icon: "hand.tap", text: "세 손가락 더블탭 → 붙여넣기")
                quickTip(icon: "hand.draw", text: "두 손가락 스와이프 → 뒤로/앞으로")
                quickTip(icon: "hand.raised", text: "세 손가락 클릭 → 탭 닫기")
            }
            .padding(.horizontal, 40)

            Text("메뉴바 아이콘에서 설정과 바로가기를 확인할 수 있습니다.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }

    private func quickTip(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.callout)
        }
    }
}

// MARK: - Window Controller

final class OnboardingWindowController {

    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "onboardingCompleted") else { return }
        show()
    }

    func show() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: OnboardingView())

        let window = NSWindow(contentViewController: hostingController)
        window.title = "GestureKeys"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
