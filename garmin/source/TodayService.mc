import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

//! The background job: sends the completions kept while the phone was out of reach, then fetches today's tasks and
//! saves them for the glance and the list.
(:background)
class TodayService extends System.ServiceDelegate {
    private var _outbox as Outbox?;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var outbox = new Outbox(method(:fetch));
        _outbox = outbox;
        outbox.start();
    }

    function fetch() as Void {
        TodayApi.fetchToday(method(:onReply));
    }

    function onReply(code as Number, data as Dictionary or String or Null) as Void {
        Background.exit(TodayApi.save(code, data));
    }
}
