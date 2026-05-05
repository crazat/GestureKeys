# GestureKeys

macOS 트랙패드 멀티터치 제스처를 키보드 단축키와 시스템 액션에 매핑하는 메뉴바 유틸리티.

## 주요 기능

- **40개 제스처** — 탭, 클릭, 스와이프, 길게 누르기, Force Touch (2~5손가락)
- **52개 내장 액션** — 탭 관리, 창 관리, 편집, 시스템 제어 + Apple Shortcuts 연동
- **커스텀 키 바인딩** — 어떤 제스처든 원하는 키 조합에 매핑
- **트랙패드 존** — 좌/우 영역별 다른 액션 설정 (7개 제스처)
- **Caps Lock 한영전환** — 지연 없는 즉시 입력 소스 전환
- **타이핑 중 자동 억제** — 키보드 입력 시 제스처 오작동 방지
- **통계 대시보드** — 제스처 사용 패턴 분석 및 추천

## 시스템 요구사항

- macOS 14.0 (Sonoma) 이상
- Apple Silicon 또는 Intel Mac
- 트랙패드 (내장 또는 외장)

## 설치

### 다운로드

[Releases](https://github.com/crazat/GestureKeys/releases)에서 최신 DMG를 다운로드하세요.

### 직접 빌드

```bash
git clone https://github.com/crazat/GestureKeys.git
cd GestureKeys
./install.sh
```

**요구사항:** Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### 접근성 권한

첫 실행 시 **시스템 설정 → 개인정보 보호 → 손쉬운 사용**에서 GestureKeys를 허용해야 합니다.

## 제스처 가이드

### 탭 관리
| 제스처 | 기본 액션 |
|--------|----------|
| 1홀드 + 좌/우 탭 | 이전/다음 탭 |
| 2홀드 + 좌 더블탭 | 새로고침 |
| 2홀드 + 우 더블탭 | 새 탭 |
| 2홀드 + 좌/우 스와이프 | 이전/다음 탭 |

### 탐색
| 제스처 | 기본 액션 |
|--------|----------|
| 2손가락 좌/우 스와이프 | 뒤로/앞으로 |

### 창 관리
| 제스처 | 기본 액션 |
|--------|----------|
| 3손가락 클릭 | 탭 닫기 (⌘W) |
| 3손가락 Force Touch | 앱 종료 (⌘Q) |
| 4손가락 클릭 | 전체화면 (⌃⌘F) |

### 편집
| 제스처 | 기본 액션 |
|--------|----------|
| 2손가락 더블탭 | 잘라내기 (⌘X) |
| 3손가락 더블탭 | 붙여넣기 (⌘V) |
| 3손가락 길게 | 복사 (⌘C) |
| 3손가락 트리플탭 | 실행취소 (⌘Z) |

### 시스템
| 제스처 | 기본 액션 |
|--------|----------|
| 5손가락 탭 | 잠금화면 |
| 5손가락 Force Touch | 강제 종료 |
| 5손가락 길게 | 화면 끄기 |

> 전체 40개 제스처는 앱 내 **바로가기** 메뉴에서 확인할 수 있습니다.

## 기술

- Swift 5 + SwiftUI/AppKit
- MultitouchSupport.framework (raw 18-finger tracking at 60Hz+)
- CGEventTap (keyboard shortcut synthesis)
- Carbon TIS API (input source switching)
- 외부 의존성 없음 (Sparkle 자동 업데이트 제외)

## 개인정보

GestureKeys는 **어떤 데이터도 수집하거나 전송하지 않습니다**. 모든 설정과 통계는 로컬에만 저장됩니다. [개인정보 처리방침](PRIVACY.md)

## 라이선스

[MIT License](LICENSE)
