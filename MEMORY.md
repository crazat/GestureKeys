# GestureKeys Project Memory

## 2026-08-09 — Long-uptime stability fix

- Symptom: the app process could remain alive while gestures became unreliable after repeated screen lock/unlock cycles.
- Root cause: `didWake`, `screensDidWake`, `sessionDidBecomeActive`, and `com.apple.screenIsUnlocked` all used the same full wake-recovery path. Each ordinary unlock unregistered the current MT callback without stopping the still-live device, then called `MTDeviceStart` again. MultitouchSupport accumulated one worker thread per cycle.
- Reproduction: posting ten `com.apple.screenIsUnlocked` notifications at intervals increased process threads from 6 to 16.
- Resolution: full device re-registration is now exclusive to real `didWake` events. Screen/session resume notifications only reinstall EventTap and refresh input-source/Caps Lock resources. Sleep entry cancels queued recovery work before handles become stale.
- Regression result: the same ten-cycle test held at 6 threads before and after; RSS stayed effectively flat (about 73.9–74.1 MB). Debug build, Xcode static analysis, installation, launch, and deep code-signature verification passed.

## Durable recovery rules

- A screen waking is not proof that the system slept.
- Use the existing device watchdog for a genuinely dead MT callback; do not proactively restart healthy devices on session resume.
- Keep the stable installed path at `~/Applications/GestureKeys.app` so accessibility and login-item identity remain consistent.
