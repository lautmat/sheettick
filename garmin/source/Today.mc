import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

//! Today's tasks as last saved (see watchToday in apps-script/Today.js for the reply's fields).
//!
//! The reply holds today's tasks, the overdue ones, and tomorrow's. Its day `e` is days since 1970 on the watch's
//! clock; each task's `d` counts from it. A reply from an earlier day is moved on by the days gone by, so after
//! midnight the list is right without a fetch.
(:background, :glance)
module Today {
    const KEY_REPLY = "today";
    const KEY_ERROR = "error";

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
    function tasks() as Array<Dictionary> {
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
        for (var i = 0; i < all.size(); i++) {
            var t = all[i] as Dictionary;
            var d = (t["d"] as Number) - s;
            if (d <= 0) {
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
        return n instanceof Number && n > shown.size() ? n : shown.size();
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
        if (dd == -1) {
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

    //! How long ago the list was fetched: "just now", "12 min ago", "3 h ago". Null before the first fetch.
    function age() as String? {
        var r = reply();
        if (r == null || !(r["at"] instanceof Number)) {
            return null;
        }
        var seconds = Time.now().value() - (r["at"] as Number);
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
