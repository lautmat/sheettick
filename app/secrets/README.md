# app/secrets/ (git-ignored)

Everything in this folder except this README is ignored by git.

Files expected here (created in phase 0, from the Google Cloud console):

| File | Purpose |
| --- | --- |
| `desktop_client.json` | OAuth client of type **Desktop app**, as downloaded from the console. Used by the Windows build (loopback flow). |
| `web_client.txt` | One line: the client ID of the **Web application** client. Google Sign-In on Android passes it as `serverClientId`. It is an ID, not a secret. |
| `android_client.txt` | OAuth client ID of type **Android** (package `com.lmathieu.sheettick` + SHA-1 of the signing key). Google Sign-In finds it in the Cloud project from the package name and signature; this file is just a record. |
| `dart_defines.json` | **Generated**, not downloaded: `dart run tools/oauth_defines.dart` (from the repo root) builds it from the two files above. Used for Windows builds. |
| `dart_defines_android.json` | Hand-made, one key: `{ "WEB_CLIENT_ID": "<the id in web_client.txt>" }`. Use it for Android builds so the Windows client secret is not compiled into the APK. |
| `test_sheet_id.txt` | Spreadsheet ID of the throwaway test Sheet used by integration tests. |

## Running with sign-in

The app reads the client IDs at build time, so pass the generated file to Flutter:

```
cd app
flutter run -d windows --dart-define-from-file=secrets/dart_defines.json
flutter run -d <phone-id> --dart-define-from-file=secrets/dart_defines.json
```

Without it the app still runs, but signing in says the OAuth client is not configured. Tests and CI do not need it.
