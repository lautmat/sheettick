import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

//! Calls to the watch endpoint (apps-script/WebApp.js), which go through the phone, and the saved reply.
(:background)
module TodayApi {
    //! Seconds between background fetches.
    const EVERY = 15 * 60;

    typedef Reply as Method(code as Number, data as Dictionary or String or Null) as Void;

    //! Fetches today's tasks in the background every EVERY seconds from now on (the registration survives restarts).
    function keepFetching() as Void {
        if (Background.getTemporalEventRegisteredTime() == null) {
            Background.registerForTemporalEvent(new Time.Duration(EVERY));
        }
    }

    function fetchToday(callback as Reply) as Void {
        call({"a" => "today", "tzo" => System.getClockTime().timeZoneOffset}, callback);
    }

    //! Completes the task [id], which the watch saw at [version].
    function markDone(id as String, version as Number, callback as Reply) as Void {
        call({"a" => "done", "id" => id, "ver" => version, "dev" => deviceTag()}, callback);
    }

    function call(params as Dictionary<Object, Object>, callback as Reply) as Void {
        params["k"] = Secrets.TOKEN;
        Communications.makeWebRequest(
            Secrets.URL,
            params,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            callback
        );
    }

    //! Saves a reply to fetchToday, or why it failed. True when a list was saved.
    function save(code as Number, data as Dictionary or String or Null) as Boolean {
        if (isOk(code, data)) {
            Storage.setValue(Today.KEY_REPLY, data as Dictionary<String, Application.PropertyValueType>);
            Storage.deleteValue(Today.KEY_ERROR);
            return true;
        }
        Storage.setValue(Today.KEY_ERROR, problem(code, data));
        return false;
    }

    function isOk(code as Number, data as Dictionary or String or Null) as Boolean {
        return code == 200 && data instanceof Dictionary && data["ok"] == true;
    }

    //! A few words on why a call failed.
    function problem(code as Number, data as Dictionary or String or Null) as String {
        if (code == 200 && data instanceof Dictionary) {
            var err = data["err"];
            if ("auth".equals(err)) {
                return "Wrong token";
            } else if ("changed".equals(err)) {
                return "Changed elsewhere";
            } else if ("repeats".equals(err)) {
                return "Repeats: use the app";
            } else if ("busy".equals(err)) {
                return "Busy, try again";
            } else if ("missing".equals(err) || "deleted".equals(err)) {
                return "Task is gone";
            } else if ("not open".equals(err)) {
                return "Already done";
            }
            return "Server error";
        } else if (code == Communications.BLE_CONNECTION_UNAVAILABLE) {
            return "Phone not connected";
        } else if (code == Communications.NETWORK_REQUEST_TIMED_OUT || code == Communications.BLE_HOST_TIMEOUT
                || code == Communications.BLE_SERVER_TIMEOUT) {
            return "No reply";
        }
        return "Error " + code;
    }

    //! Four hex digits of this watch's id, for the `device` column (`gmn-xxxx`).
    function deviceTag() as String {
        var id = System.getDeviceSettings().uniqueIdentifier;
        if (id == null || id.length() < 4) {
            return "0000";
        }
        return id.substring(0, 4) as String;
    }
}
