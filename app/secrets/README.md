# app/secrets/ (git-ignored)

Everything in this folder except this README is ignored by git.

Files expected here (created in phase 0, from the Google Cloud console):

| File | Purpose |
| --- | --- |
| `desktop_client.json` | OAuth client of type **Desktop app**, used by the Windows build (loopback flow). |
| `android_client.txt` | OAuth client ID of type **Android** (package `com.lmathieu.sheettick` + SHA-1 of the signing key). Google Sign-In reads it from the Cloud project; this file is just a record. |
| `test_sheet_id.txt` | Spreadsheet ID of the throwaway test Sheet used by integration tests. |
