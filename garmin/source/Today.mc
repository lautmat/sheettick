import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

//! Today's tasks as last saved (see watchToday in apps-script/Today.js for the reply's fields).
//!
//! The reply holds today's tasks, the overdue ones, and tomorrow's. Its day `e` is days since 1970 on the watch's
//! clock; each task's `d` counts from it. A reply from an earlier day is moved on by the days gone by, so after
//! midnight the list is right without a fetch. Tasks completed on the watch while the phone was out of reach wait in
//! `pending` and are left out of the list until the background job has sent them.
(:background, :glance)
module Today {
    const KEY_REPLY = "today";
    const KEY_ERROR = "error";
    const KEY_PENDING = "pending";

    //! The saved reply, or null before the first fetch.
    function reply() as Dictionary? {
        return Storage.getValue(KEY_REPLY) as Dictionary?;
    }

    //! Why the last fetch failed, or null when it worked.
    function error() as String? {
        return Storage.getValue(KEY_ERROR) as String?;
    }

    //! Today on the watch's clock, as days since 1970.
    function day() as Number {
        return (Time.now().value() + System.getClockTime().timeZoneOffset) / 86400;
    }

    //! Minutes since midnight on the watch's clock.
    function minuteOfDay() as Number {
        var clock = System.getClockTime();
        return clock.hour * 60 + clock.min;
    }

    //! Days gone by since [r] was fetched.
    function shift(r as Dictionary) as Number {
        var e = r["e"];
        return e instanceof Number ? day() - e : 0;
    }

    //! The tasks due today or earlier, in the order of the reply, each with `dd`: its day counted from today.
    //! Completions waiting to be sent (pending) are left out.
    function tasks() as Array<Dictionary> {
        return between(-100000, 0);
    }

    //! Tomorrow's tasks, or none when the reply is from an earlier day and so does not hold them.
    function tomorrow() as Array<Dictionary> {
        var r = reply();
        if (r == null || shift(r) > 0) {
            return [] as Array<Dictionary>;
        }
        return between(1, 1);
    }

    //! True when the saved reply holds tomorrow's tasks.
    function knowsTomorrow() as Boolean {
        var r = reply();
        return r != null && shift(r) <= 0;
    }

    //! The tasks whose day, counted from today, is from [lo] to [hi], with `dd` set.
    function between(lo as Number, hi as Number) as Array<Dictionary> {
        var out = [] as Array<Dictionary>;
        var r = reply();
        if (r == null) {
            return out;
        }
        var all = r["tasks"];
        if (!(all instanceof Array)) {
            return out;
        }
        var s = shift(r);
        var waiting = pendingIds();
        for (var i = 0; i < all.size(); i++) {
            var t = all[i] as Dictionary;
            var d = (t["d"] as Number) - s;
            if (d >= lo && d <= hi && waiting.indexOf(t["id"]) < 0) {
                t["dd"] = d;
                out.add(t);
            }
        }
        return out;
    }

    //! How many tasks are due today or earlier: more than [shown] when the reply was cut short.
    function count(shown as Array<Dictionary>) as Number {
        var r = reply();
        if (r == null) {
            return shown.size();
        }
        var n = shift(r) <= 0 ? r["n0"] : r["n1"];
        if (!(n instanceof Number)) {
            return shown.size();
        }
        n -= waitingCount(r, -100000, 0);
        return n > shown.size() ? n : shown.size();
    }

    //! How many tasks are due tomorrow: more than [shown] when the reply was cut short.
    function tomorrowCount(shown as Array<Dictionary>) as Number {
        var r = reply();
        if (r == null || !(r["n0"] instanceof Number) || !(r["n1"] instanceof Number)) {
            return shown.size();
        }
        var n = (r["n1"] as Number) - (r["n0"] as Number) - waitingCount(r, 1, 1);
        return n > shown.size() ? n : shown.size();
    }

    //! How many tasks of the reply from day [lo] to [hi] are hidden because their completion is waiting to be sent.
    function waitingCount(r as Dictionary, lo as Number, hi as Number) as Number {
        var all = r["tasks"];
        var waiting = pendingIds();
        if (!(all instanceof Array) || waiting.size() == 0) {
            return 0;
        }
        var s = shift(r);
        var n = 0;
        for (var i = 0; i < all.size(); i++) {
            var t = all[i] as Dictionary;
            var d = (t["d"] as Number) - s;
            if (d >= lo && d <= hi && waiting.indexOf(t["id"]) >= 0) {
                n++;
            }
        }
        return n;
    }

    //! What the glance shows: the next task with a time later today, else the first of the highest priority. Null
    //! when there is none.
    function next(shown as Array<Dictionary>) as Dictionary? {
        var now = minuteOfDay();
        for (var i = 0; i < shown.size(); i++) {
            var t = shown[i];
            if (t["dd"] == 0 && (t["t"] as Number) >= now) {
                return t;
            }
        }
        var best = null as Dictionary?;
        for (var i = 0; i < shown.size(); i++) {
            if (best == null || (shown[i]["p"] as Number) > (best["p"] as Number)) {
                best = shown[i];
            }
        }
        return best;
    }

    //! Completions made while the phone was out of reach, [{id, v}], oldest first. The background job sends them.
    function pending() as Array<Dictionary> {
        var q = Storage.getValue(KEY_PENDING);
        return q instanceof Array ? q as Array<Dictionary> : [] as Array<Dictionary>;
    }

    function pendingIds() as Array<String> {
        var q = pending();
        var ids = [] as Array<String>;
        for (var i = 0; i < q.size(); i++) {
            ids.add(q[i]["id"] as String);
        }
        return ids;
    }

    //! Keeps the completion of [id], seen at [version], to send later.
    function queue(id as String, version as Number) as Void {
        if (pendingIds().indexOf(id) >= 0) {
            return;
        }
        var q = pending();
        q.add({"id" => id, "v" => version});
        Storage.setValue(KEY_PENDING, q as Array<Application.PropertyValueType>);
    }

    function unqueue(id as String) as Void {
        var q = pending();
        var kept = [] as Array<Dictionary>;
        for (var i = 0; i < q.size(); i++) {
            if (!id.equals(q[i]["id"])) {
                kept.add(q[i]);
            }
        }
        if (kept.size() == 0) {
            Storage.deleteValue(KEY_PENDING);
        } else {
            Storage.setValue(KEY_PENDING, kept as Array<Application.PropertyValueType>);
        }
    }

    //! Overdue: a day gone by, or a time today that has passed.
    function isLate(t as Dictionary) as Boolean {
        var dd = t["dd"] as Number;
        var minute = t["t"] as Number;
        return dd < 0 || (dd == 0 && minute >= 0 && minute < minuteOfDay());
    }

    function lateCount(shown as Array<Dictionary>) as Number {
        var n = 0;
        for (var i = 0; i < shown.size(); i++) {
            if (isLate(shown[i])) {
                n++;
            }
        }
        return n;
    }

    //! When [t] is due, short enough for a menu line: "Yesterday", "3 days ago", "14:30 · late", "Today", with
    //! " · repeats" when it repeats. Every task here is open, so a day gone by means overdue.
    function when(t as Dictionary) as String {
        var dd = t["dd"] as Number;
        var minute = t["t"] as Number;
        var text;
        if (dd == 1) {
            text = minute >= 0 ? "Tomorrow " + clockText(minute) : "Tomorrow";
        } else if (dd == -1) {
            text = "Yesterday";
        } else if (dd < 0) {
            text = (-dd) + " days ago";
        } else if (minute >= 0) {
            text = clockText(minute) + (isLate(t) ? " · late" : "");
        } else {
            text = "Today";
        }
        return t["r"] == 1 ? text + " · repeats" : text;
    }

    //! [minute] after midnight as the watch shows the time (24-hour or 12-hour).
    function clockText(minute as Number) as String {
        var h = minute / 60;
        var m = (minute % 60).format("%02d");
        if (System.getDeviceSettings().is24Hour) {
            return h + ":" + m;
        }
        var suffix = h < 12 ? " am" : " pm";
        var h12 = h % 12 == 0 ? 12 : h % 12;
        return h12 + ":" + m + suffix;
    }

    //! Seconds since the list was fetched, or null before the first fetch.
    function ageSeconds() as Number? {
        var r = reply();
        if (r == null || !(r["at"] instanceof Number)) {
            return null;
        }
        return Time.now().value() - (r["at"] as Number);
    }

    //! How long ago the list was fetched: "just now", "12 min ago", "3 h ago". Null before the first fetch.
    function age() as String? {
        var seconds = ageSeconds();
        if (seconds == null) {
            return null;
        }
        if (seconds < 60) {
            return "just now";
        } else if (seconds < 3600) {
            return (seconds / 60) + " min ago";
        } else if (seconds < 2 * 86400) {
            return (seconds / 3600) + " h ago";
        }
        return (seconds / 86400) + " days ago";
    }
}
