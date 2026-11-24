# garmin/: SheetTick on a Garmin watch (#107)

A Connect IQ watch app for the Forerunner 255 (all four variants: `fr255`, `fr255m`, `fr255s`, `fr255sm`).

- **Glance:** `TODAY · 9 · 6 late` over the next task. Scroll to it from the watch face.
- **List:** press START on the glance. You get today's tasks, overdue first, in the app's Today order. High priority
  shows `!` in front. Under each title is when it is due (`Yesterday`, `3 days ago`, `14:30 · late`, `Today`), plus
  `· repeats` for a repeating task. **Refresh** at the foot fetches the list again and says how old the list is.
- **Completing:** select a task and confirm. The task is marked done in the Sheet, and the apps pick that up on their
  next sync. A repeating task says "Repeats: use the app" instead, because only the app carries a series on to its next
  date (`core/tasks/task_completion.dart`).

Reminders are not part of this app. The Android app's reminder notifications already reach the watch through Garmin
Connect's smart notifications. Turn on SheetTick under Garmin Connect → device → Notifications & Alerts → App
Notifications, and Smart Notifications on the watch.

## How it works

```
watch (background, every 15 min) ──BLE──> Garmin Connect on the phone ──HTTPS GET──> Apps Script web app ──> Sheet
```

- `source/TodayService.mc` is the background job. It calls the web app and saves the reply in `Application.Storage`.
  A glance cannot reach the network, so `source/TodayGlance.mc` only draws what was saved.
- The reply also carries tomorrow's tasks and the day it was made. After midnight the watch moves the list on by
  itself, so it stays right until the next fetch.
- The web app is `apps-script/WebApp.js`, with its logic in `apps-script/Today.js` (node tests in
  `apps-script/test/today.test.js`). "Today" is the app's Today list: open, undeleted tasks whose due day, or start day
  when there is no due, is today or earlier. Dates are read as the app reads them.
- A completion writes `status = 2`, `completed_at`, `updated_at`, `version + 1` and `device = gmn-xxxx`. It is refused
  (`Changed elsewhere`) when the row's version moved since the watch fetched it, and the list is fetched again.
- Every call carries a token, which the web app checks. The token and the web app URL are compiled into the watch app
  from `secrets/Secrets.mc`, which is git-ignored.

## Set up (one time)

1. Make the token and the secrets files, then push the script (see `apps-script/README.md` for the deployment):
   ```
   node tools/watch_secrets.mjs --url https://script.google.com/macros/s/<deployment id>/exec
   cd apps-script && clasp push -f
   ```
   The token is kept on later runs. To change it, delete `apps-script/WatchSecret.js`, run the command again, push
   the script and rebuild the watch app.
2. Build (Connect IQ SDK 8, a developer key in `%APPDATA%\Garmin\ConnectIQ\developer_key`). Pick your variant:
   ```
   monkeyc -r -d fr255 -f garmin/monkey.jungle -o garmin/bin/SheetTick.prg -y "%APPDATA%\Garmin\ConnectIQ\developer_key"
   ```
3. Install: connect the watch by USB. In File Explorer it shows as a device: copy `SheetTick.prg` to
   `Internal Storage\GARMIN\APPS`, then unplug. Nothing goes through the Connect IQ Store.
4. Add the glance on the watch: from the watch face, scroll to the glances, then hold UP (MENU) → Glances → Add →
   SheetTick. **Open the app once** (START on the glance): that starts the 15-minute background fetch and fetches the
   list right away.

The phone has to be near, with Garmin Connect running, for a fetch or a completion. Without it the list stays as it
was and Refresh says `Phone not connected`.

## Simulator

```
connectiq                                   # starts the simulator
monkeydo garmin/bin/SheetTick.prg fr255
```

- The simulator starts a glance-capable app as its glance. Settings → Glance Launch Mode → Launch in Normal Mode opens
  the list instead.
- Simulation → Background Events → Temporal Event runs the background fetch.
- The simulator calls the real web app, so **Confirm** on a task completes it in the real Sheet.
