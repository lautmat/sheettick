import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! SheetTick on the watch: a glance with how many tasks are due today and the next one, and a list of today's tasks
//! to tick off. A background job fetches the list every 15 minutes through the phone (TodayService) and saves it; the
//! glance only reads what was saved, since a glance cannot reach the network.
(:background, :glance)
class SheetTickApp extends Application.AppBase {
    private var _menu as TodayMenu?;

    function initialize() {
        AppBase.initialize();
    }

    //! The list of today's tasks, opened from the glance or the apps menu. Opening it once also starts the background
    //! fetches.
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        TodayApi.keepFetching();
        var menu = new TodayMenu(0, null);
        _menu = menu;
        menu.refresh();
        return [menu, new TodayMenuDelegate(menu)];
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new TodayGlance()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new TodayService()];
    }

    //! The background job saved a new list.
    function onBackgroundData(data as Application.PersistableType) as Void {
        var menu = _menu;
        if (menu != null) {
            menu.rebuild();
        }
        WatchUi.requestUpdate();
    }
}
