# Dev environment (Windows 11)

Set up on 2026-10-19. `flutter doctor -v` reports no issues for Windows and Android.

| Component | Version | Location |
| --- | --- | --- |
| Flutter (stable) | 3.47.7, Dart 3.13.5 | `C:\dev\flutter` |
| JDK | Temurin 21.0.9 (`JAVA_HOME`) | `%LOCALAPPDATA%\Programs\Eclipse Adoptium\jdk-21.0.9.10-hotspot` |
| Android SDK | platform 36, build-tools 36.0.0, platform-tools 37.0.1, cmdline-tools 23.0, NDK 28.2.13676358 | `%LOCALAPPDATA%\Android\Sdk` (`ANDROID_HOME`) |
| Visual Studio | Community 2026 (18.1) with "Desktop development with C++" | default |

Android Studio and the Android emulator are intentionally not installed. Android is tested on a physical phone.

## Reproducing the setup

1. **Flutter**: download `flutter_windows_<version>-stable.zip` from
   `https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/`, check the SHA-256 listed in
   `releases_windows.json`, extract to `C:\dev`, add `C:\dev\flutter\bin` to the user `PATH`.
2. **C++ workload**: Visual Studio Installer, "Desktop development with C++" (workload
   `Microsoft.VisualStudio.Workload.NativeDesktop`).
3. **Android SDK**: extract the Windows command-line tools zip from `https://developer.android.com/studio#command-line-tools-only`
   to `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest`, then:
   ```
   sdkmanager --sdk_root=%LOCALAPPDATA%\Android\Sdk platform-tools "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358"
   ```
   The NDK is required by Flutter's Android template. Gradle cannot auto-install it with the new `sdkmanager` shim,
   so install it up front (about 2 GB unpacked). The first Android build also lets Gradle download CMake 3.22.1
   into the SDK (needed by the SQLite plugin); that one works unattended.
   Set `ANDROID_HOME` to the SDK folder and add `platform-tools` to `PATH`.
4. `flutter config --android-sdk %ANDROID_HOME% --no-analytics`, then `flutter doctor --android-licenses`.
5. `flutter doctor -v` must show no issues.

## Running on a phone
Enable Developer options and USB debugging on the phone, connect it, accept the RSA prompt, then `adb devices` should list it
and `flutter run -d <id>` installs the debug build.
