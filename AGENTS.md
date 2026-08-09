# GestureKeys Agent Guide

`CLAUDE.md` is the canonical project guide. Read it before changing code, and keep it synchronized when architecture, lifecycle, build, or recovery behavior changes.

## Required workflow

- Preserve unrelated working-tree changes.
- Generate and build with `xcodegen generate` followed by `xcodebuild -scheme GestureKeys -configuration Debug -derivedDataPath .build build`.
- Install and launch with `./install.sh`; do not validate long-running behavior from DerivedData or `.build` because the app intentionally relaunches the stable `~/Applications/GestureKeys.app` copy.
- For lifecycle or recovery changes, also run `xcodebuild -scheme GestureKeys -configuration Debug -derivedDataPath .build analyze` and a targeted repeated-event/resource test.

## Stability invariants

- Only `NSWorkspace.didWakeNotification` may trigger full MultitouchSupport device re-registration after real system sleep.
- `screensDidWake`, `sessionDidBecomeActive`, and `com.apple.screenIsUnlocked` must recover EventTap/input-source resources without restarting a healthy MT device. Restarting it on every unlock leaks a MultitouchSupport worker thread.
- Never call `MTDeviceStop` on handles that may be stale after sleep or disconnect; MultitouchSupport can race its own cleanup and crash.
- Cancel pending device/EventTap recovery work when entering sleep, and retain generation guards for delayed work.
- Keep callback-shared engine state under `engineLock`, and execute synthesized actions only after releasing that lock.

See `MEMORY.md` for the latest reproduced failure, root cause, and regression evidence.
