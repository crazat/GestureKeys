# GestureKeys

macOS 트랙패드 멀티터치 제스처를 키보드 단축키/시스템 액션에 매핑하는 메뉴바 앱.

## 빌드 & 실행

```bash
cd /Users/crazat/Projects/GestureKeys

# 빌드 + ~/Applications에 설치 + 실행 (권장)
./install.sh

# 또는 수동:
xcodegen generate && xcodebuild -scheme GestureKeys -configuration Debug -derivedDataPath .build build
pkill -f "GestureKeys.app/Contents/MacOS/GestureKeys" || true
cp -R .build/Build/Products/Debug/GestureKeys.app ~/Applications/
open ~/Applications/GestureKeys.app
```

**중요:** 항상 `~/Applications/GestureKeys.app`에서 실행해야 SMAppService 로그인 항목이 올바른 경로를 가리킴. DerivedData나 .build에서 직접 실행하면 로그인 시 옛 빌드가 실행될 수 있음.

**요구사항:** Accessibility 권한 필요 (시스템 설정 → 개인정보 보호 → 손쉬운 사용)

**참고:** Apple Development 인증서로 서명하므로 재빌드해도 접근성 권한이 유지됨. 최초 1회만 손쉬운 사용에서 허용하면 됨. 앱은 권한 미부여 시 1초 간격으로 폴링하여 권한 부여 즉시 엔진을 시작함.

## 기술 스택

| 항목 | 값 |
|------|-----|
| 언어 | Swift 5 |
| 플랫폼 | macOS 14.0+ |
| 빌드 | XcodeGen (`project.yml`) |
| UI | SwiftUI (설정창) + AppKit (메뉴바) |
| 코드서명 | Apple Development (접근성 권한 유지를 위해 ad-hoc 대신 사용) |
| 샌드박스 | 비활성 |
| Bundle ID | com.gesturekeys.app |
| LSUIElement | true (Dock에 표시 안 됨) |

## 프로젝트 구조

```
GestureKeys/
├── project.yml                          # XcodeGen 설정
├── install.sh                           # 빌드 + ~/Applications 설치 + 실행 스크립트
└── GestureKeys/
    ├── GestureKeysApp.swift             # @main 진입점 (접근성 폴링, 크래시 리포팅, 설정 마이그레이션)
    ├── Info.plist
    ├── GestureKeys.entitlements
    │
    ├── GestureEngine.swift              # 터치 처리 허브 (18개 인식기 관리, 히트맵 기록)
    ├── GestureConfig.swift              # 제스처 활성화/비활성화/쿨다운/존/Shortcuts (UserDefaults)
    ├── KeySynthesizer.swift             # CGEvent 키 합성 + 시스템 키 + osascript + pmset + Shortcuts + 쿨다운
    ├── MultitouchBindings.swift         # MultitouchSupport.framework 바인딩
    ├── TouchModels.swift                # MTTouch 구조체 (96 bytes) + TrackpadZone
    │
    ├── SettingsMigration.swift          # 설정 스키마 버전 관리 & 순차 마이그레이션
    ├── LaunchAtLoginHelper.swift        # SMAppService 래퍼 (로그인 시 자동 시작)
    ├── CrashReporter.swift              # 크래시 로그 (NSException + signal handler)
    ├── GestureStats.swift               # 제스처 사용 통계 (일별 집계, 추천)
    │
    ├── MenuBarController.swift          # 상태바 메뉴
    ├── SettingsView.swift               # SwiftUI 설정 윈도우 (존 설정, Shortcuts 이름, 쿨다운 토글 포함)
    ├── StatsView.swift                  # 통계 대시보드 (차트, 추천, 요약 카드)
    ├── OnboardingView.swift             # 첫 실행 온보딩 (3페이지)
    ├── CheatSheetView.swift             # 바로가기 참조 윈도우
    ├── GestureMonitorView.swift         # 제스처 테스트 모드 + 터치 히트맵 (Canvas 20×20)
    ├── GestureHUD.swift                 # 제스처 인식 HUD 표시
    ├── KeyCaptureView.swift             # 사용자 지정 키 캡처
    │
    ├── ThreeFingerClickRecognizer.swift  # 3손가락 클릭 → 탭 닫기 ★최우선 (존 지원), Force Touch → 앱 종료
    ├── FourFingerClickRecognizer.swift   # 4손가락 클릭 → 전체화면, Force Touch → 앱 숨기기
    ├── FiveFingerClickRecognizer.swift   # 5손가락 Force Touch 클릭 → 강제 종료 (일반 클릭 무시)
    ├── TapWhileHoldingRecognizer.swift   # 2홀드 + 탭 → 새로고침/새 탭
    ├── SwipeWhileHoldingRecognizer.swift # 2홀드 + 스와이프 → 탭 이동 등
    ├── LongPressWhileHoldingRecognizer.swift # 2홀드 + 길게 → 저장/실행취소
    ├── ThreeFingerDoubleTapRecognizer.swift  # 3손가락 더블탭 → 붙여넣기 (존 지원)
    ├── ThreeFingerTripleTapRecognizer.swift  # 3손가락 트리플탭 → 실행취소
    ├── ThreeFingerLongPressRecognizer.swift  # 3손가락 길게 → 복사
    ├── ThreeFingerSwipeRecognizer.swift      # 3손가락 스와이프 → 탭 전환/페이지 + 대각선 4방향
    ├── FourFingerDoubleTapRecognizer.swift   # 4손가락 더블탭 → 스크린샷
    ├── FourFingerLongPressRecognizer.swift   # 4손가락 길게 → 화면캡처UI
    ├── FiveFingerTapRecognizer.swift         # 5손가락 탭 → 잠금화면 (존 지원)
    ├── FiveFingerLongPressRecognizer.swift   # 5손가락 길게 → 화면 끄기 (deferred sleep)
    ├── OneFingerHoldTapRecognizer.swift      # 1홀드 + 탭 → 이전/다음 탭
    ├── OneFingerHoldSwipeRecognizer.swift    # 1홀드 + 스와이프 → 볼륨/밝기
    ├── TwoFingerSwipeRecognizer.swift        # 2손가락 스와이프 → 뒤로/앞으로
    ├── TwoFingerTapRecognizer.swift          # 2손가락 더블탭 → 잘라내기 (존 지원)
    └── TwoFingerHoldDetector.swift           # 2손가락 홀드 감지 (공유 유틸)
```

## 아키텍처

### 터치 처리 파이프라인

```
MultitouchSupport.framework (private, @_silgen_name 바인딩)
  ↓  MTRegisterContactFrameCallback
touchCallback() — @convention(c) 글로벌 함수
  ↓  engineLock/engineInstance 안전 참조 (use-after-free 방지)
GestureEngine.processTouches()
  ↓  os_unfair_lock 보호 하에 18개 인식기 순차 전달
  ↓  인식기가 fireAction() 호출 → pendingActions 배열에 버퍼링
  ↓  takePendingActions() → os_unfair_lock_unlock
KeySynthesizer — lock 해제 후 CGEvent 합성 실행 (지연 실행 패턴)
  ↓  쿨다운 체크 → 통계 기록 (GestureStats.shared.record)
  ↓  .shortcut 액션 시 /usr/bin/shortcuts run 실행
```

### 앱 시작 순서

```
CrashReporter.install()          — 크래시 핸들러 설치 (최우선)
SettingsMigration.runIfNeeded()   — 설정 스키마 마이그레이션
MenuBarController.setup()         — 메뉴바 UI
OnboardingWindowController        — 첫 실행 온보딩
CrashReporter.checkForPreviousCrash() — 이전 크래시 알림
AXIsProcessTrusted() → engine.start() or 폴링
```

### CGEventTap (물리 클릭 + 시스템 키 가로채기)

- `.leftMouseDown` 이벤트를 `.cghidEventTap` 레벨에서 인터셉트
- `NX_SYSDEFINED` (미디어/밝기 키) 인터셉트: Shift+밝기 키 → 키보드 백라이트 변환
- 3/4/5손가락 클릭 시 `nil` 반환으로 시스템 클릭 억제
- 우선순위: 5FC > 4FC > **3FC (최우선, 다른 3손가락 제스처에 의해 차단되지 않음)**
- 5FC 발동(clickHeld) 시 5FT, 5FLP, 4FDT, 4FLP 리셋 — Force Touch 대기 중 경쟁 방지
- 4FC 발동(.fired) 시 클릭 억제, 4FC Force Touch(.clickHeld) 시 4FDT, 4FLP 리셋
- 3FC 발동(.fired) 시 경쟁 인식기 전부 리셋 (TWH, SWH, LPWH, 3FDT, 3FTT, 3FLP, 3FSwipe)
- 3FC Force Touch(.clickHeld) 시에도 동일하게 리셋 — 물리 클릭이 long press(복사)와 구분 기준

### 제스처 우선순위 & 충돌 해소 (processTouches 순서)

1. 클릭 인식기 (CGEventTap 별도 처리, 3FC 최우선)
2. 2홀드+탭 → 2홀드+스와이프 (발동 시 TWH/LPWH reset) → 2홀드+길게 (발동 시 TWH/SWH reset)
3. 3손가락 제스처 (스와이프 발동 시 3FDT/3FTT reset, **3FC/3FLP는 리셋하지 않음**)
4. 4손가락 제스처 (4FC clickHeld 중 4FLP 처리 건너뜀, **`suppressFourFinger` 플래그로 5손가락 세션 중 완전 억제**)
5. 5손가락 제스처 (탭 발동 시 5FC/5FLP/4FLP/4FDT reset, 길게 발동 시 5FT/5FC/4FLP/4FDT reset)
6. 1홀드+탭 → 1홀드+스와이프 (발동 시 OFHT reset)
7. 2손가락 스와이프 (발동 시 OFHT/OFHS/TFTR reset) → 2손가락 탭

### 스레드 안전성

- 멀티터치 콜백: 시스템 고우선순위 스레드에서 실행
- `engineLock` (`os_unfair_lock`): engine 인스턴스 접근, 인식기 상태, 설정 캐시 읽기 보호
- `engineInstance`: 글로벌 변수로 `engineLock` 보호. C 콜백에서 안전한 참조 획득 (refcon 대신 사용하여 shutdown 중 use-after-free 방지)
- `synthesisLock`: `KeySynthesizer.lastSynthesisTimestamp` 보호 (CGEventTap 콜백 읽기 ↔ 키 합성 쓰기)
- `enabledLock`: `GestureConfig.enabledCache` + `cachedFrontmostBundleId` 보호 (터치 콜백 읽기 ↔ UI 쓰기)
- `appOverridesLock`: 앱별 오버라이드 캐시 보호
- `inputSourceLock`: `KeySynthesizer.cachedSources`/`sourceIdToIndex` 보호 (EventTap 콜백 읽기 ↔ 알림 콜백 무효화)
- `GestureStats.lock`: 통계 레코드 읽기/쓰기 보호
- **지연 실행 패턴**: `fireAction()`이 `pendingActions`에 클로저 버퍼링 (engineLock 하), lock 해제 후 실행. CGEvent 포스팅이 lock 밖에서 실행되어 lock 점유 시간 최소화
- UI 쓰기는 메인 스레드 (@Published + SwiftUI)
- `cachedHudEnabled`/`cachedHapticEnabled`/`actionCache`: 인메모리 캐시로 UserDefaults I/O 제거

## 제스처 인식기 패턴

모든 인식기는 동일한 상태 머신 패턴을 따름:

```swift
final class XxxRecognizer {
    enum State { case idle, ... }
    private(set) var state: State = .idle

    func processTouches(_ touches: [MTTouch], timestamp: TimeInterval) { ... }
    func reset() { state = .idle; /* clear tracking vars */ }
}
```

**공통 규칙:**
- `touches.filter { $0.touchState.isActive }` → `.touching`/`.active` 상태만 카운트
- 좌표: 0.0~1.0 정규화 (normalizedVector.position)
- 이동 임계값: 대부분 0.03 (스와이프는 0.06~0.15)
- 시간: `ProcessInfo.processInfo.systemUptime` 기준
- 각 액션은 `GestureConfig.shared.isEnabled("gestureId")`로 가드
- **Grace period**: 클릭 인식기(3FC/4FC/5FC)는 200ms, 나머지는 80ms. down 상태에서 손가락 수가 목표보다 적어질 때 즉시 리셋 대신 유예. 클릭 인식기는 물리 클릭 시 손가락 displacement를 커버하기 위해 길게 설정.
- **Fired timeout**: `.fired` 상태를 가진 스와이프/롱프레스 인식기는 `firedTimeout` (2.0초)을 적용. 터치가 0으로 떨어지지 않더라도 타임아웃 후 자동 리셋하여 무한 stuck 방지. 적용 대상: TwoFingerSwipe, ThreeFingerSwipe, ThreeFingerTripleTap, FourFingerLongPress, FiveFingerLongPress.

## 제스처 전체 목록

### 탭 관리
| ID | 제스처 | 액션 | 기본값 |
|----|--------|------|--------|
| ofhLeftTap | 1홀드 + 왼쪽 탭 | 이전 탭 (⇧⌘[) | ON |
| ofhRightTap | 1홀드 + 오른쪽 탭 | 다음 탭 (⇧⌘]) | ON |
| twhLeftDoubleTap | 2홀드 + 왼쪽 더블탭 | 새로고침 (⌘R) | ON |
| twhRightDoubleTap | 2홀드 + 오른쪽 더블탭 | 새 탭 (⌘T) | ON |
| swhLeft | 2홀드 + 스와이프 ← | 이전 탭 (⇧⌘[) | ON |
| swhRight | 2홀드 + 스와이프 → | 다음 탭 (⇧⌘]) | ON |
| threeFingerSwipeRight | 3손가락 스와이프 → | 다음 탭 (⇧⌘]) | OFF |
| threeFingerSwipeLeft | 3손가락 스와이프 ← | 이전 탭 (⇧⌘[) | OFF |

### 탐색
| ID | 제스처 | 액션 | 기본값 |
|----|--------|------|--------|
| twoFingerSwipeRight | 2손가락 스와이프 → | 뒤로가기 (⌘[) | ON |
| twoFingerSwipeLeft | 2손가락 스와이프 ← | 앞으로가기 (⌘]) | ON |
| rightSwipeUp | 2홀드 + 오른쪽 스와이프 ↑ | 주소창 (⌘L) | OFF |
| threeFingerSwipeUp | 3손가락 스와이프 ↑ | 페이지 상단 (⌘↑) | OFF |
| threeFingerSwipeDown | 3손가락 스와이프 ↓ | 페이지 하단 (⌘↓) | OFF |
| threeFingerSwipeDiagUpRight | 3손가락 대각선 ↗ | Spotlight (⌘Space) | OFF |
| threeFingerSwipeDiagUpLeft | 3손가락 대각선 ↖ | 검색 (⌘F) | OFF |
| threeFingerSwipeDiagDownRight | 3손가락 대각선 ↘ | 페이지 하단 (⌘↓) | OFF |
| threeFingerSwipeDiagDownLeft | 3손가락 대각선 ↙ | 페이지 상단 (⌘↑) | OFF |

### 창 관리
| ID | 제스처 | 액션 | 기본값 |
|----|--------|------|--------|
| threeFingerClick | 3손가락 클릭 | 탭 닫기 (⌘W) | ON |
| threeFingerLongClick | 3손가락 세게 클릭 (Force Touch) | 앱 종료 (⌘Q) | OFF |
| fourFingerClick | 4손가락 클릭 | 전체화면 (⌃⌘F) | ON |
| fourFingerLongClick | 4손가락 세게 클릭 (Force Touch) | 앱 숨기기 (⌘H) | OFF |
| swhUp | 2홀드 + 스와이프 ↑ | 새 창 (⌘N) | ON |
| swhDown | 2홀드 + 스와이프 ↓ | 최소화 (⌘M) | ON |

### 편집
| ID | 제스처 | 액션 | 기본값 |
|----|--------|------|--------|
| twoFingerDoubleTap | 2손가락 더블탭 | 잘라내기 (⌘X) | ON |
| threeFingerDoubleTap | 3손가락 더블탭 | 붙여넣기 (⌘V) | ON |
| threeFingerLongPress | 3손가락 길게 누르기 | 복사 (⌘C) | ON |
| threeFingerTripleTap | 3손가락 트리플탭 | 실행취소 (⌘Z) | ON |
| twhLeftLongPress | 2홀드 + 왼쪽 길게 | 저장 (⌘S) | OFF |
| twhRightLongPress | 2홀드 + 오른쪽 길게 | 실행취소 (⌘Z) | OFF |

### 시스템
| ID | 제스처 | 액션 | 기본값 |
|----|--------|------|--------|
| ofhLeftSwipeUp | 1홀드 + 왼쪽 ↑ | 볼륨 증가 | OFF |
| ofhLeftSwipeDown | 1홀드 + 왼쪽 ↓ | 볼륨 감소 | OFF |
| ofhRightSwipeUp | 1홀드 + 오른쪽 ↑ | 밝기 증가 | OFF |
| ofhRightSwipeDown | 1홀드 + 오른쪽 ↓ | 밝기 감소 | OFF |
| fourFingerDoubleTap | 4손가락 더블탭 | 스크린샷 (⇧⌘4) | OFF |
| fourFingerLongPress | 4손가락 길게 | 전체 선택 (⌘A) | OFF |
| fiveFingerTap | 5손가락 탭 | 잠금화면 (⌃⌘Q) | OFF |
| fiveFingerClick | 5손가락 세게 클릭 (Force Touch 필수) | 강제 종료 (⌥⌘Esc) | OFF |
| fiveFingerLongPress | 5손가락 길게 | 화면 끄기 | OFF |

## 화면 끄기 (Display Sleep)

`pmset displaysleepnow`로 실제 디스플레이 슬립 실행:

- **구현**: `Process`로 `/usr/bin/pmset displaysleepnow` 실행 (백그라운드 스레드)
- **지연 실행**: 제스처 인식 시 HUD/햅틱만 즉시 피드백, 실제 슬립은 손가락을 뗀 후 실행 (트랙패드 터치-업이 디스플레이를 다시 깨우는 것 방지)
- **동작**: `FiveFingerLongPressRecognizer`가 `sleepDisplay` 액션일 때 `deferredSleep` 플래그 설정 → 손가락 리프트 시 `liftedAfterFire` → `GestureEngine`이 `consumeLiftEvent()`로 감지 후 슬립 실행
- **참고**: 잠금화면 설정에 따라 디스플레이 깨울 때 비밀번호를 요구할 수 있음

## 추가 기능

- **로그인 시 자동 시작**: `LaunchAtLoginHelper` → `SMAppService` (macOS 13+). `GestureConfig.launchAtLogin`
- **쿨다운**: `KeySynthesizer.lastFireTime`으로 제스처별 발동 간격 제한 (탭 0.3s, 나머지 0.5s)
- **Shortcuts 연동**: `.shortcut` 액션 → `/usr/bin/shortcuts run "name"` 실행
- **대각선 스와이프**: `ThreeFingerSwipeRecognizer`에서 비율 0.7~1.4 = 대각선, 4분면 판정
- **존 기반 액션**: `TrackpadZone` (x < 0.5 기준 좌/우). 대상: `twoFingerDoubleTap`, `threeFingerDoubleTap`, `threeFingerClick`, `fiveFingerTap`
- **터치 히트맵**: `GestureMonitorView` Canvas 20×20 그리드 (100ms 스로틀)
- **통계**: `GestureStats.shared` 일별 집계 30일 보관, `StatsView` 대시보드 + 추천
- **크래시 리포팅**: `CrashReporter` → `~/Library/Logs/GestureKeys/crash.log`
- **설정 마이그레이션**: `SettingsMigration` 순차 체인, `currentVersion` 범프로 스키마 변경 대응
- **Caps Lock 한영전환**: EventTap에서 Caps Lock(0x39) 인터셉트 → Carbon TIS API로 즉시 입력 소스 전환 (macOS 딜레이 없음). `GestureConfig.capsLockInputSwitch` 토글. 50ms 디바운스. **주의**: macOS 시스템 설정의 "Caps Lock으로 입력 소스 전환"은 꺼야 이중 전환 방지.
  - **캐싱**: `TISCreateInputSourceList` 결과를 캐시 (`cachedSources`/`sourceIdToIndex`). `kTISNotifyEnabledKeyboardInputSourcesChanged` 알림으로 자동 무효화. O(1) 해시맵 룩업.
  - **동기 실행**: EventTap 콜백에서 동기 실행하여 전환 완료 전에 다음 키 이벤트가 처리되지 않도록 보장 (영→한 첫 글자 race 방지). 캐시 히트 시 ~6-25ms.
  - **실패 복구**: `TISSelectInputSource` 실패 시 캐시 무효화 + 1회 재시도. 엔진 stop 시 캐시 정리 (`invalidateInputSourceCache()`).
- **한영전환 액션**: `KeySynthesizer.Action.toggleInputSource` — 어떤 제스처든 한영전환에 매핑 가능

## 성능 & 안정성 원칙

- **Hot path (60Hz+)**: heap 할당 최소화 (`removeAll(keepingCapacity:)`, `UnsafeBufferPointer.filter`), 인메모리 캐시로 UserDefaults I/O 제거, 지연 실행 패턴으로 lock 점유 최소화
- **메모리**: `Unmanaged.passUnretained(event)` 참조 누수 방지, GestureHUD NSView 재사용
- **안정성**: `engineLock`/`engineInstance` use-after-free 방지, `synthesisLock` data race 제거, `firedTimeout` 2.0초 stuck 방지, `MTTouch._sizeCheck` 레이아웃 assertion

## 새 제스처 추가 절차

1. `XxxRecognizer.swift` 생성 — 상태 머신 패턴 따름
2. `GestureEngine.swift` — 인스턴스 추가, `stop()` reset 추가, `processTouches()` 호출 추가
3. `GestureConfig.swift` — 해당 카테고리에 `Info` 항목 추가, `defaultActions`/`gestureSensitivityAxes`/`conflicts`에 등록
4. `KeySynthesizer.swift` — 필요 시 새 키 조합 메서드 추가, `defaultActions`에 기본 액션 추가
5. (선택) 존 지원: `GestureConfig.zoneCapableGestures`에 추가, 인식기에 존 판정 로직 삽입
6. (선택) 쿨다운: `GestureConfig.defaultCooldowns`에 기본값 추가
7. 빌드 & 테스트

## 주요 상수

| 상수 | 값 | 용도 |
|------|-----|------|
| moveThreshold (3FC) | 0.08 | 3손가락 클릭 이동 허용치 (클릭 displacement 감안) |
| moveThreshold (기타) | 0.03~0.05 | 탭/클릭 이동 허용치 |
| swipeThreshold (hold) | 0.06 | 홀드+스와이프 발동 |
| swipeThreshold (2finger) | 0.15 | 2손가락 스와이프 발동 |
| swipeThreshold (3finger) | 0.10 | 3손가락 스와이프 발동 |
| maxTapDuration | 0.25s | 단일 탭 최대 시간 |
| multiTapWindow | 0.35~0.40s | 더블탭 간격 |
| holdDuration | 0.10~0.20s | 홀드 인식 시간 |
| longPressDuration | 0.30~0.50s | 길게 누르기 인식 |
| stabilizationDuration (Force Touch) | 0.15s | Force Touch 기준 압력 측정 구간 (3FC/4FC/5FC) |
| forceTouchMultiplier | 1.5 | Force Touch 판정: basePressure × 1.5 초과 시 발동 |
| clickHeldTimeout | 2.0s | Force Touch 안전 타임아웃 (3FC/4FC → 일반 클릭, 5FC → 취소) |
| gracePeriod (클릭) | 0.20s | 클릭 인식기 손가락 이탈 유예 (물리 클릭 커버) |
| gracePeriod (기타) | 0.08s | 나머지 인식기 손가락 ramping 허용 |
| firedTimeout | 2.0s | `.fired` 상태 자동 리셋 타임아웃 (stuck 방지) |

## 알려진 이슈 & 해결책

### ⌥⌘Esc (강제 종료) — CGEvent.post로 불가
WindowServer 시스템 레벨 단축키라 CGEvent.post 불가. osascript + System Events로 우회 (`KeySynthesizer.postForceQuit`).

### 재빌드 후 접근성 권한
Apple Development 인증서로 서명하므로 재빌드해도 접근성 권한이 유지됨. 인증서가 만료/변경된 경우에만 시스템 설정에서 재허용 필요.

### Force Touch 클릭 (3FC/4FC/5FC)
3FC/4FC/5FC의 "세게 클릭"은 Force Touch 압력 감지로 발동. 클릭 후 150ms 안정화 구간에서 기준 압력(basePressure)을 기록하고, 이후 압력이 basePressure × 1.5를 초과하면 Force Touch로 판정. 2초 안전 타임아웃: 3FC/4FC는 일반 클릭 발동, 5FC는 아무 동작 없이 취소 (안전 장치). clickHeld 상태일 때 해당 long press recognizer의 `processTouches` 호출을 건너뜀 (3FLP, 4FLP). **참고**: 2손가락 Force Touch는 시스템 우클릭(`.rightMouseDown`)과 충돌하여 구현 불가.

### 3손가락 클릭 reliability
물리 클릭 시 손가락이 밀리면서 터치 카운트가 일시적으로 3 아래로 떨어짐. grace period 200ms + moveThreshold 0.08 + 3FC 최우선 우선순위로 대응. 3손가락 스와이프는 기본 OFF (3FC와 충돌).

### 5손가락 제스처 중 4손가락 오발동 방지 (`suppressFourFinger`)
5손가락 길게 누르기 후 손가락을 뗄 때, 카운트가 5→4로 지나가면서 4손가락 인식기(4FDT/4FLP)가 활성화되는 문제.
특히 5FLP `firedTimeout`(2초) 만료 후 count=4가 유지되면 4FLP가 500ms 뒤 발동 가능.
**해결**: `suppressFourFinger` 래치 플래그 — 5손가락 접촉 또는 5손가락 인식기 활성 시 설정, `activeCount == 0`(모든 손가락 리프트) 시에만 해제. 억제 중 매 프레임 4FDT/4FLP 리셋.

### EventTap 자동 복구 (Sleep/Wake 무력화 방지)
macOS가 잠자기/화면잠금/시스템 부하 등으로 CGEventTap의 Mach port를 무효화하면 모든 제스처가 무력화되는 문제.
**원인**: `reEnableEventTap()`은 이미 죽은 Mach port에 대해 `CGEvent.tapEnable()`만 호출 — 효과 없음.
**해결** (3단계):
1. `removeEventTap()`에서 `CFMachPortInvalidate(tap)` 추가 — 시스템 레벨 이벤트 탭 등록을 완전 해제
2. `handleWake()`에서 `reEnableEventTap()` → `reinstallEventTap()`으로 변경 — 이벤트 탭 완전 재생성 (2초 딜레이)
3. `startEventTapHealthCheck()` 추가 — 10초 주기로 `CFMachPortIsValid()` 확인, 무효화 시 자동 reinstall

## 의존성

- **MultitouchSupport.framework** (Apple private) — `@_silgen_name` 바인딩
- **Carbon.HIToolbox** (Apple) — TIS API (입력 소스 전환)
- **ServiceManagement** (Apple) — `SMAppService` 로그인 시 자동 시작 (macOS 13+)
- 외부 라이브러리 없음 (순수 네이티브)

## 개발 참고

- **SourceKit 진단 오류**: `@_silgen_name`으로 바인딩된 private framework 심볼은 SourceKit에서 "Cannot find in scope" 경고를 표시하지만, 실제 빌드는 정상 성공. 이 진단은 무시해도 안전.
- **GitHub**: https://github.com/crazat/GestureKeys

## 구형 맥북 (2013 Intel) 레거시 빌드

2013 MacBook Pro (macOS 11 Big Sur, Intel x86_64)용 별도 빌드. **본 프로젝트 소스는 절대 수정하지 않고**, `/tmp/GestureKeys-Legacy`에 복사 후 수정하여 빌드.

### 빌드 절차

```bash
# 1. 임시 복사
rm -rf /tmp/GestureKeys-Legacy
cp -R /Users/crazat/Projects/GestureKeys /tmp/GestureKeys-Legacy

# 2. 아래 "필수 수정 사항" 전부 적용

# 3. 빌드
cd /tmp/GestureKeys-Legacy
xcodegen generate
xcodebuild -scheme GestureKeys -configuration Release -derivedDataPath .build -arch x86_64 build

# 4. 데스크톱으로 복사 (AirDrop용)
cp -R .build/Build/Products/Release/GestureKeys.app ~/Desktop/

# 5. 임시 디렉터리 정리
rm -rf /tmp/GestureKeys-Legacy
```

### 필수 수정 사항 (macOS 14 → 11 호환)

| 파일 | 변경 | 이유 |
|------|------|------|
| `project.yml` | `MACOSX_DEPLOYMENT_TARGET: "11.0"`, `ARCHS: x86_64` 추가 | macOS 11 + Intel 타깃 |
| **새 파일** `ColorCompat.swift` | `Color(fromNS:)` 확장 추가 | `Color(nsColor:)` macOS 12+ |
| `SettingsView.swift` | `Color(nsColor:)` → `Color(fromNS:)` (7곳) | macOS 12+ |
| `SettingsView.swift` | `.monospacedDigit()` 제거 (2곳) | macOS 12+ |
| `SettingsView.swift` | `SMAppService` → `#available(macOS 13, *)` 래핑 | macOS 13+ |
| `SettingsView.swift` | `hand.raised.fingers.spread` → `hand.raised.fill` | SF Symbols 3 (macOS 12+) |
| `SettingsView.swift` (AppOverrideView) | `@Environment(\.dismiss)` → `\.presentationMode` | macOS 12+ |
| `LaunchAtLoginHelper.swift` | `SMAppService` → `#available(macOS 13, *)` 래핑 또는 제거 | macOS 13+ |
| `StatsView.swift` | `Color(nsColor:)` → `Color(fromNS:)`, `.monospacedDigit()` 제거 | macOS 12+ |
| `GestureMonitorView.swift` | Canvas 히트맵 → `#available(macOS 13, *)` 래핑, `.monospacedDigit()` 교체 | macOS 12+/13+ |
| `OnboardingView.swift` | `@Environment(\.dismiss)` → `\.presentationMode` | macOS 12+ |
| `OnboardingView.swift` | `hand.raised.fingers.spread` → `hand.raised.fill` | SF Symbols 3 |
| `CheatSheetView.swift` | `Color(nsColor:)` → `Color(fromNS:)` (2곳) | macOS 12+ |
| `MenuBarController.swift` | `hand.raised.fingers.spread` → `hand.raised.fill` (2곳) | SF Symbols 3 — **이것이 메뉴바 아이콘 안 보이는 원인** |

### 구 맥북 설치 후 필수 확인

1. **Gatekeeper 차단 시**: `xattr -cr /Applications/GestureKeys.app`
2. **접근성 권한**: 시스템 환경설정 → 손쉬운 사용 → GestureKeys 체크
3. **바이너리 변경 후**: 접근성 목록에서 GestureKeys 체크 해제 → 다시 체크

### 호환성 요약

- 엔진 코어/인식기: macOS 11 호환, 수정 불필요. `MTTouch` 96바이트 레이아웃 동일 검증됨.
- macOS 12+: `Color(nsColor:)` → `Color(fromNS:)` 확장 필요, `hand.raised.fingers.spread` → `hand.raised.fill`
- macOS 13+: `SMAppService`, Canvas 히트맵 — `#available` 래핑 필요
- Non-Force Touch 트랙패드: 물리 클릭 시 displacement가 더 클 수 있음 → `moveThreshold` 조정 검토

## 유닛 테스트 (GestureKeysLegacy)

테스트는 `/Users/crazat/Projects/GestureKeysLegacy` 프로젝트에 위치. 본 프로젝트와 소스 공유.

```bash
cd /Users/crazat/Projects/GestureKeysLegacy
xcodegen generate && xcodebuild -scheme GestureKeys build-for-testing
```

모든 인식기 + Config/Stats/ConflictResolver 테스트 포함. `MTTouchFactory`로 합성 터치 생성 (`touches(count:)`, `swipeTouches(...)`, `palmTouch()`, `edgeTouch()`).
