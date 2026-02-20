# GestureKeys

macOS 트랙패드 멀티터치 제스처를 키보드 단축키/시스템 액션에 매핑하는 메뉴바 앱.

## 빌드 & 실행

```bash
cd /Users/crazat/Projects/GestureKeys

# XcodeGen으로 프로젝트 생성 + 빌드
xcodegen generate && xcodebuild -scheme GestureKeys -configuration Debug -derivedDataPath .build build

# 실행
.build/Build/Products/Debug/GestureKeys.app/Contents/MacOS/GestureKeys &

# 기존 프로세스 종료
pkill -f "GestureKeys.app/Contents/MacOS/GestureKeys"
```

**요구사항:** Accessibility 권한 필요 (시스템 설정 → 개인정보 보호 → 손쉬운 사용)

**참고:** 재빌드 후 바이너리가 변경되면 macOS가 접근성 권한을 무효화할 수 있음. 제스처가 안 되면 손쉬운 사용에서 GestureKeys를 끄고 → 다시 켜야 함. 앱은 권한 미부여 시 1초 간격으로 폴링하여 권한 부여 즉시 엔진을 시작함.

## 기술 스택

| 항목 | 값 |
|------|-----|
| 언어 | Swift 5 |
| 플랫폼 | macOS 14.0+ |
| 빌드 | XcodeGen (`project.yml`) |
| UI | SwiftUI (설정창) + AppKit (메뉴바) |
| 코드서명 | 없음 (Sign to Run Locally) |
| 샌드박스 | 비활성 |
| Bundle ID | com.gesturekeys.app |
| LSUIElement | true (Dock에 표시 안 됨) |

## 프로젝트 구조

```
GestureKeys/
├── project.yml                          # XcodeGen 설정
└── GestureKeys/
    ├── GestureKeysApp.swift             # @main 진입점 (접근성 폴링 포함)
    ├── Info.plist
    ├── GestureKeys.entitlements
    │
    ├── GestureEngine.swift              # 터치 처리 허브 (17개 인식기 관리)
    ├── GestureConfig.swift              # 제스처 활성화/비활성화 (UserDefaults)
    ├── KeySynthesizer.swift             # CGEvent 키 합성 + 시스템 키 + osascript + pmset
    ├── MultitouchBindings.swift         # MultitouchSupport.framework 바인딩
    ├── TouchModels.swift                # MTTouch 구조체 (96 bytes)
    │
    ├── MenuBarController.swift          # 상태바 메뉴
    ├── SettingsView.swift               # SwiftUI 설정 윈도우
    ├── OnboardingView.swift             # 첫 실행 온보딩 (3페이지)
    ├── CheatSheetView.swift             # 바로가기 참조 윈도우
    ├── GestureMonitorView.swift         # 제스처 테스트 모드
    ├── GestureHUD.swift                 # 제스처 인식 HUD 표시
    ├── ScreenBlackout.swift             # 화면 끄기 (검은 오버레이, 현재 미사용)
    ├── KeyCaptureView.swift             # 사용자 지정 키 캡처
    │
    ├── ThreeFingerClickRecognizer.swift  # 3손가락 클릭 → 탭 닫기 ★최우선
    ├── FourFingerClickRecognizer.swift   # 4손가락 클릭 → 전체화면
    ├── FiveFingerClickRecognizer.swift   # 5손가락 클릭 → 앱 종료
    ├── TapWhileHoldingRecognizer.swift   # 2홀드 + 탭 → 새로고침/새 탭
    ├── SwipeWhileHoldingRecognizer.swift # 2홀드 + 스와이프 → 탭 이동 등
    ├── LongPressWhileHoldingRecognizer.swift # 2홀드 + 길게 → 다시 실행/저장
    ├── ThreeFingerDoubleTapRecognizer.swift  # 3손가락 더블탭 → 붙여넣기
    ├── ThreeFingerLongPressRecognizer.swift  # 3손가락 길게 → 실행취소
    ├── ThreeFingerSwipeRecognizer.swift      # 3손가락 스와이프 → 탭 전환/페이지
    ├── FourFingerDoubleTapRecognizer.swift   # 4손가락 더블탭 → 스크린샷
    ├── FourFingerLongPressRecognizer.swift   # 4손가락 길게 → 화면캡처UI
    ├── FiveFingerTapRecognizer.swift         # 5손가락 탭 → 잠금화면
    ├── FiveFingerLongPressRecognizer.swift   # 5손가락 길게 → 화면 끄기 (deferred sleep)
    ├── OneFingerHoldTapRecognizer.swift      # 1홀드 + 탭 → 이전/다음 탭
    ├── OneFingerHoldSwipeRecognizer.swift    # 1홀드 + 스와이프 → 볼륨/밝기
    ├── TwoFingerSwipeRecognizer.swift        # 2손가락 스와이프 → 뒤로/앞으로
    └── TwoFingerTapRecognizer.swift          # 2손가락 더블탭 → 복사
```

## 아키텍처

### 터치 처리 파이프라인

```
MultitouchSupport.framework (private, @_silgen_name 바인딩)
  ↓  MTRegisterContactFrameCallback
touchCallback() — @convention(c) 글로벌 함수
  ↓  engineLock/engineInstance 안전 참조 (use-after-free 방지)
GestureEngine.processTouches()
  ↓  os_unfair_lock 보호 하에 17개 인식기 순차 전달
  ↓  인식기가 fireAction() 호출 → pendingActions 배열에 버퍼링
  ↓  takePendingActions() → os_unfair_lock_unlock
KeySynthesizer — lock 해제 후 CGEvent 합성 실행 (지연 실행 패턴)
```

### CGEventTap (물리 클릭 + 시스템 키 가로채기)

- `.leftMouseDown` 이벤트를 `.cghidEventTap` 레벨에서 인터셉트
- `NX_SYSDEFINED` (미디어/밝기 키) 인터셉트: Shift+밝기 키 → 키보드 백라이트 변환
- 3/4/5손가락 클릭 시 `nil` 반환으로 시스템 클릭 억제
- 우선순위: 5FC > 4FC > **3FC (최우선, 다른 3손가락 제스처에 의해 차단되지 않음)**
- 5FC 발동 시 5FT, 5FLP 리셋
- 3FC 발동 시 경쟁 인식기 전부 리셋 (TWH, SWH, LPWH, 3FDT, 3FLP, 3FSwipe)

### 제스처 우선순위 & 충돌 해소 (processTouches 순서)

1. 클릭 인식기 (CGEventTap 별도 처리, 3FC 최우선)
2. 2홀드+탭 → 2홀드+스와이프 (발동 시 TWH/LPWH reset) → 2홀드+길게 (발동 시 TWH/SWH reset)
3. 3손가락 제스처 (스와이프 발동 시 3FDT/3FLP reset, **3FC는 리셋하지 않음**)
4. 4손가락 제스처 (독립 처리)
5. 5손가락 제스처 (탭 발동 시 5FC/5FLP reset, 길게 발동 시 5FT/5FC reset)
6. 1홀드+탭 → 1홀드+스와이프 (발동 시 OFHT reset)
7. 2손가락 스와이프 (발동 시 OFHT/OFHS/TFTR reset) → 2손가락 탭

### 스레드 안전성

- 멀티터치 콜백: 시스템 고우선순위 스레드에서 실행
- `engineLock` (`os_unfair_lock`): engine 인스턴스 접근, 인식기 상태, 설정 캐시 읽기 보호
- `engineInstance`: 글로벌 변수로 `engineLock` 보호. C 콜백에서 안전한 참조 획득 (refcon 대신 사용하여 shutdown 중 use-after-free 방지)
- `synthesisLock`: `KeySynthesizer.lastSynthesisTimestamp` 보호 (CGEventTap 콜백 읽기 ↔ 키 합성 쓰기)
- `enabledLock`: `GestureConfig.enabledCache` 보호 (터치 콜백 읽기 ↔ UI 쓰기)
- `appOverridesLock`: 앱별 오버라이드 캐시 보호
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

### 창 관리
| ID | 제스처 | 액션 | 기본값 |
|----|--------|------|--------|
| threeFingerClick | 3손가락 클릭 | 탭 닫기 (⌘W) | ON |
| fourFingerClick | 4손가락 클릭 | 전체화면 (⌃⌘F) | ON |
| swhUp | 2홀드 + 스와이프 ↑ | 새 창 (⌘N) | ON |
| swhDown | 2홀드 + 스와이프 ↓ | 최소화 (⌘M) | ON |

### 편집
| ID | 제스처 | 액션 | 기본값 |
|----|--------|------|--------|
| twoFingerDoubleTap | 2손가락 더블탭 | 복사 (⌘C) | ON |
| threeFingerDoubleTap | 3손가락 더블탭 | 붙여넣기 (⌘V) | ON |
| threeFingerLongPress | 3손가락 길게 누르기 | 실행취소 (⌘Z) | ON |
| twhLeftLongPress | 2홀드 + 왼쪽 길게 | 다시 실행 (⇧⌘Z) | OFF |
| twhRightLongPress | 2홀드 + 오른쪽 길게 | 저장 (⌘S) | OFF |

### 시스템
| ID | 제스처 | 액션 | 기본값 |
|----|--------|------|--------|
| ofhLeftSwipeUp | 1홀드 + 왼쪽 ↑ | 볼륨 증가 | OFF |
| ofhLeftSwipeDown | 1홀드 + 왼쪽 ↓ | 볼륨 감소 | OFF |
| ofhRightSwipeUp | 1홀드 + 오른쪽 ↑ | 밝기 증가 | OFF |
| ofhRightSwipeDown | 1홀드 + 오른쪽 ↓ | 밝기 감소 | OFF |
| fourFingerDoubleTap | 4손가락 더블탭 | 스크린샷 (⇧⌘4) | OFF |
| fourFingerLongPress | 4손가락 길게 | 화면캡처 (⇧⌘5) | OFF |
| fiveFingerTap | 5손가락 탭 | 잠금화면 (⌃⌘Q) | OFF |
| fiveFingerClick | 5손가락 클릭 | 앱 종료 | OFF |
| fiveFingerLongPress | 5손가락 길게 | 화면 끄기 | OFF |

## 화면 끄기 (Display Sleep)

`pmset displaysleepnow`로 실제 디스플레이 슬립 실행:

- **구현**: `Process`로 `/usr/bin/pmset displaysleepnow` 실행 (백그라운드 스레드)
- **지연 실행**: 제스처 인식 시 HUD/햅틱만 즉시 피드백, 실제 슬립은 손가락을 뗀 후 실행 (트랙패드 터치-업이 디스플레이를 다시 깨우는 것 방지)
- **동작**: `FiveFingerLongPressRecognizer`가 `sleepDisplay` 액션일 때 `deferredSleep` 플래그 설정 → 손가락 리프트 시 `liftedAfterFire` → `GestureEngine`이 `consumeLiftEvent()`로 감지 후 슬립 실행
- **참고**: 잠금화면 설정에 따라 디스플레이 깨울 때 비밀번호를 요구할 수 있음
- **이전 방식**: `ScreenBlackout.swift`의 검은 오버레이 방식은 화면 보호기가 개입하는 문제로 대체됨 (코드는 보존)

## 설정 UI

- `DisclosureGroup` 대신 커스텀 Button + `contentShape(Rectangle())`로 전체 헤더 영역 클릭 가능
- `withAnimation(.easeInOut(duration: 0.2))` 빠른 펼침/접힘
- 접힌 상태에서 카테고리별 활성 제스처 수 표시 (예: `3/8`)

## 성능 최적화

### Hot Path (60Hz+ 터치 프레임)
- `UnsafeBufferPointer.filter`: C 버퍼에서 직접 필터링 (Array 할당 1회, 기존 2회)
- 카운팅 루프: `.filter{}.count` 대신 수동 카운팅 (heap 할당 제거)
- `removeAll(keepingCapacity: true)`: Dictionary/Array/Set 백킹 스토리지 재사용 (COW 최적화)
- 설정 캐시: `actionCache`, `enabledCache`, `cachedHudEnabled`/`cachedHapticEnabled` 등 인메모리 캐시로 UserDefaults I/O 완전 제거
- 지연 실행: CGEvent 포스팅, HUD 표시, 햅틱 피드백을 lock 밖으로 이동

### 메모리
- `Unmanaged.passUnretained(event)`: CGEvent 참조 카운트 누수 방지 (passRetained 대신)
- GestureHUD: NSView/NSTextField 재사용 (매 제스처마다 재생성 제거)

### 안정성
- `engineLock`/`engineInstance` 패턴: refcon 포인터 대신 안전한 글로벌 참조 (shutdown 중 use-after-free 방지)
- `synthesisLock`: `lastSynthesisTimestamp` data race 제거
- `guard let` 바인딩: force unwrap 제거 (OneFingerHoldTap/SwipeRecognizer)
- reEnableEventTap NSLog 5초 쓰로틀: 반복 비활성화 시 로그 폭주 방지
- ThreeFingerLongPress: 4손가락 이상 시 즉시 리셋 (기존 5손가락 이상)

## 새 제스처 추가 절차

1. `XxxRecognizer.swift` 생성 — 상태 머신 패턴 따름
2. `GestureEngine.swift` — 인스턴스 추가, `stop()` reset 추가, `processTouches()` 호출 추가
3. `GestureConfig.swift` — 해당 카테고리에 `Info` 항목 추가
4. `KeySynthesizer.swift` — 필요 시 새 키 조합 메서드 추가
5. 빌드 & 테스트

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
| gracePeriod (클릭) | 0.20s | 클릭 인식기 손가락 이탈 유예 (물리 클릭 커버) |
| gracePeriod (기타) | 0.08s | 나머지 인식기 손가락 ramping 허용 |

## 알려진 이슈 & 해결책

### ⌥⌘Esc (강제 종료) — CGEvent.post로 불가
WindowServer가 처리하는 시스템 레벨 단축키라 CGEvent.post(tap: .cghidEventTap)으로 트리거 불가.
osascript + System Events로 우회:
```swift
DispatchQueue.global(qos: .userInitiated).async {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = ["-e", "tell application \"System Events\" to key code 53 using {command down, option down}"]
    try? task.run()
    task.waitUntilExit()
}
```

### 재빌드 후 접근성 권한 무효화
바이너리가 변경되면 macOS가 권한을 실질적으로 무효화. `AXIsProcessTrusted()`는 true를 반환하지만 EventTap이 실제로 작동하지 않을 수 있음. 시스템 설정에서 GestureKeys를 끄고 → 다시 켜면 해결.

### 3손가락 클릭 reliability
물리 클릭 시 손가락이 밀리면서 터치 카운트가 일시적으로 3 아래로 떨어짐. grace period 200ms + moveThreshold 0.08 + 3FC 최우선 우선순위로 대응. 3손가락 스와이프는 기본 OFF (3FC와 충돌).

## 의존성

- **MultitouchSupport.framework** (Apple private) — `@_silgen_name` 바인딩
- 외부 라이브러리 없음 (순수 네이티브)

## 개발 참고

- **SourceKit 진단 오류**: `@_silgen_name`으로 바인딩된 private framework 심볼은 SourceKit에서 "Cannot find in scope" 경고를 표시하지만, 실제 빌드는 정상 성공. 이 진단은 무시해도 안전.
- **GitHub**: https://github.com/crazat/GestureKeys
