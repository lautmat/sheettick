# tools/

Helper scripts that are not part of the app.

- `oauth_defines.dart`: turns the OAuth client files downloaded from Google Cloud (in `app/secrets/`) into
  `app/secrets/dart_defines.json`, which the app is built with. See `app/secrets/README.md`.

Planned:
- `import_ticktick/`: one-time migration of existing TickTick data into the Sheet (from TickTick's CSV backup,
  Settings → Account → Backup, or through the TickTick MCP). Phase 1.

## Re-running the REA analysis

The research in `docs/research/rea-findings.md` was produced with REA (`npx rea-agents@latest`, v6.7.0):

```
# Windows (.NET) — path without spaces works best
npx rea-agents@latest inspect-managed-artifact <TickTick.exe> --json
npx rea-agents@latest inspect-managed-members <TickTick.exe> --type ticktick_WPF.Models.TaskModel --format json

# Android — needs JDK 17+ (JAVA_HOME) and REA_JADX_MCP_JAR=jadx-headless-mcp-0.7.1-all.jar
npx rea-agents@latest inspect-android-package <base.apk> --format json
npx rea-agents@latest search-android-classes <base.apk> com.ticktick.task --format json
npx rea-agents@latest inspect-android-class <base.apk> com.ticktick.task.data.Task2 --format json
```

On Windows, keep the JDK and APK under a short path (long temp paths break the Java launcher), and
in PowerShell remember variable names are case-insensitive.
