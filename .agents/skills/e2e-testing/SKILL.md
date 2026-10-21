---
name: e2e-testing
description: Use when reproducing a bug on a real phone, verifying a fix end-to-end, or adding/running instrumented (androidTest) tests for Ember.
---

# E2E testing — Ember

Current state: no `app/src/androidTest/`, no instrumentation deps, no device attached by default.
If you couldn't run on a device, say "E2E not run" — never claim end-to-end verification.

**Never install or start an Android emulator.** Emulators eat disk and freeze this laptop. Physical phone only.

## Setup (physical phone)
1. Phone: Settings → About → tap Build number 7× → Developer options → USB debugging (or Wireless debugging).
2. USB: plug in, accept the RSA prompt. Wireless: `adb pair <ip:port>` (pairing code), then `adb connect <ip:port>`.
3. `adb devices` must list the phone as `device` (not `unauthorized`).
4. `./gradlew installDebug`, then `adb shell monkey -p com.sarvarbek.ember 1` to launch.
   `adb` lives in `$ANDROID_HOME/platform-tools` (`sdk.dir` in `local.properties`).

## Seed / reset data
- Push a PDF: `adb push sample.pdf /sdcard/Download/`.
- Import via Library picker (`OpenDocument` in `features/library/LibraryScreen.kt`), or Files app
  "Open with" / Share (VIEW / SEND filters in the manifest, handled in `MainActivity.kt`).
- Fresh state: `adb shell pm clear com.sarvarbek.ember`.
- Logs: `adb logcat --pid=$(adb shell pidof com.sarvarbek.ember)`.

## Instrumented tests (first time only)
- Add to `gradle/libs.versions.toml` + `app/build.gradle.kts`: `androidx.test.ext:junit`,
  `androidx.test:runner`, Compose `ui-test-junit4` (+ `ui-test-manifest` as `debugImplementation`), and
  `testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"` in `defaultConfig`.
- Tests go in `app/src/androidTest/java/com/sarvarbek/ember/`, mirroring source packages.
- Run all: `./gradlew connectedDebugAndroidTest`
- Run one: `./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.sarvarbek.ember.<pkg>.<Class>`

## Bug-reproduction procedure
1. Write the user's steps down (tap by tap, which PDF, which setting).
2. Reproduce manually on the phone; capture logcat. Can't reproduce → stop, report what you tried.
3. Write an instrumented test that fails the same way.
4. Fix at the root cause.
5. Rerun the test and the manual steps.
6. Report exactly how you verified (device model, steps, test name).

## Gotchas
- PdfBox-Android needs a `Context` for font resources — that's why JVM unit tests feed hand-built
  `PdfLine`s to `reflowLines` instead of real PDFs. Real-PDF extraction is only testable on device.
- PdfBox line stripping, PdfRenderer covers and pager gestures have never been verified on device.
