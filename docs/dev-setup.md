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

## Building in GitHub Actions

The **Build apps** workflow (Actions tab, Run workflow) builds the Android APK and the Windows app on GitHub's runners, so
neither needs the laptop. It also runs by itself for Android on every push to `main` that touches `app/`, so each merged change is released. Otherwise pick the platform, and tick "dev tools" to include the TickTick import dialog.

With the secrets below set, each build is **published as a GitHub release** (`android-N` with the APK, `windows-N` with a
zip). Without them the workflow still builds both apps, as a compile check, and publishes nothing (it says so in a
warning). The Android build number is the run number, so every APK counts as an update of the one before.

Repository secrets it reads (Settings, Secrets and variables, Actions):

| Secret | What to put in it |
| --- | --- |
| `DART_DEFINES_ANDROID_JSON` | The whole content of `app/secrets/dart_defines_android.json`. |
| `DART_DEFINES_JSON` | The whole content of `app/secrets/dart_defines.json` (holds the desktop client secret). |
| `ANDROID_KEYSTORE_BASE64` | The keystore the phone app is signed with, base64 on one line. Google Sign-In ties the app to the SHA-1 of this key, and Android only accepts an update signed with the same key, so it must be the key the installed app already uses, which today is the debug keystore (`%USERPROFILE%\.android\debug.keystore`). `base64 -w0 debug.keystore`, or `certutil -encodehex -f debug.keystore out.txt 0x40000001` on Windows. |
| `ANDROID_KEYSTORE_PASSWORD` | `android` for the debug keystore. |
| `ANDROID_KEY_ALIAS` | `androiddebugkey` for the debug keystore. |
| `ANDROID_KEY_PASSWORD` | `android` for the debug keystore. |

The Android build reads `android/key.properties` when it exists (the workflow writes it from the secrets) and otherwise
signs with the debug key, so local builds are unchanged.

### Updating the phone with Obtainium

[Obtainium](https://obtainium.imranr.dev) is a free, open-source app that installs and updates apps from GitHub releases.
The repository is private, so it needs a read-only token.

1. On GitHub, create a fine-grained personal access token: Settings, Developer settings, Personal access tokens, only this
   repository, permission **Contents: read-only**. Copy it.
2. Install Obtainium on the phone, and allow it to install apps when Android asks.
3. In Obtainium: Settings, GitHub personal access token, paste it.
4. Add app, source `https://github.com/lautmat/sheettick`. Under the app's options set the release title filter to
   `android` (so the Windows releases are ignored), and turn on automatic update checks.
5. Install the first release, then each new release shows as an update. Android may still ask to confirm each install;
   on Android 12 and later Obtainium can update in the background for apps it installed.

Installing over an existing app only works when both are signed with the same key. If the installed app was built on the
laptop with the debug key, store that same key in `ANDROID_KEYSTORE_BASE64`. Otherwise uninstall the app first (sync
first: the Sheet keeps everything) and add the new key's SHA-1 to the Android OAuth client in Google Cloud.
