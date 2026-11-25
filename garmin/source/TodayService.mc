import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

//! The background job: fetches today's tasks and saves them for the glance and the list.
(:background)
class TodayService extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        TodayApi.fetchToday(method(:onReply));
    }

    function onReply(code as Number, data as Dictionary or String or Null) as Void {
        Background.exit(TodayApi.save(code, data));
    }
}
