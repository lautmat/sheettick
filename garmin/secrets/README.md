# garmin/secrets/ (git-ignored)

Everything in this folder except this README is ignored by git.

| File | Purpose |
| --- | --- |
| `Secrets.mc` | **Generated** by `node tools/watch_secrets.mjs --url <web app URL>`: the Apps Script web app URL and the token it accepts, as Monkey C constants. The build reads it (`base.sourcePath = source;secrets`), so without it the watch app does not compile. |

The same token is in `apps-script/WatchSecret.js` (also git-ignored), which clasp pushes to the script. See
`garmin/README.md`.
