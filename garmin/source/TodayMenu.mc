import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

//! The list of today's tasks, overdue first, with a Refresh item at the foot. Selecting a task asks to complete it.
class TodayMenu extends WatchUi.Menu2 {
    private var _tasks as Array<Dictionary> = [] as Array<Dictionary>;
    private var _busy as Boolean = false;
    private var _saving as Dictionary? = null;

    function initialize() {
        Menu2.initialize({:title => "Today"});
        rebuild();
    }

    //! Refills the list from the saved reply.
    function rebuild() as Void {
        while (getItem(0) != null) {
            deleteItem(0);
        }
        _tasks = Today.tasks();
        for (var i = 0; i < _tasks.size(); i++) {
            var t = _tasks[i];
            addItem(new WatchUi.MenuItem(label(t), Today.when(t), t["id"], null));
        }
        if (_tasks.size() == 0 && Today.reply() != null) {
            addItem(new WatchUi.MenuItem("All clear", "Nothing due today", :none, null));
        }
        addItem(new WatchUi.MenuItem("Refresh", status(), :refresh, null));
        updateTitle();
        WatchUi.requestUpdate();
    }

    //! Fetches the list now.
    function refresh() as Void {
        if (_busy) {
            return;
        }
        _busy = true;
        setSubLabel(:refresh, "Refreshing...");
        TodayApi.fetchToday(method(:onToday));
    }

    function onToday(code as Number, data as Dictionary or String or Null) as Void {
        _busy = false;
        TodayApi.save(code, data);
        rebuild();
    }

    //! The task with [id], or null.
    function taskWith(id as String) as Dictionary? {
        for (var i = 0; i < _tasks.size(); i++) {
            if (id.equals(_tasks[i]["id"])) {
                return _tasks[i];
            }
        }
        return null;
    }

    //! Completes [task] in the Sheet. The item says "Saving..." until the reply comes.
    function complete(task as Dictionary) as Void {
        if (_busy) {
            WatchUi.showToast("Busy, try again", null);
            return;
        }
        _busy = true;
        _saving = task;
        setSubLabel(task["id"], "Saving...");
        TodayApi.markDone(task["id"] as String, task["v"] as Number, method(:onDone));
    }

    function onDone(code as Number, data as Dictionary or String or Null) as Void {
        _busy = false;
        var task = _saving;
        _saving = null;
        if (task == null) {
            return;
        }
        if (TodayApi.isOk(code, data)) {
            forget(task["id"] as String);
            WatchUi.showToast("Done", null);
        } else {
            setSubLabel(task["id"], Today.when(task));
            WatchUi.showToast(TodayApi.problem(code, data), null);
            if (code == 200 && data instanceof Dictionary && "changed".equals(data["err"])) {
                refresh();
            }
        }
        WatchUi.requestUpdate();
    }

    //! Takes a completed task off the list and out of the saved reply.
    private function forget(id as String) as Void {
        var r = Today.reply();
        if (r != null && r["tasks"] instanceof Array) {
            var all = r["tasks"] as Array<Dictionary>;
            var kept = [] as Array<Dictionary>;
            for (var i = 0; i < all.size(); i++) {
                if (!id.equals(all[i]["id"])) {
                    kept.add(all[i]);
                }
            }
            r["tasks"] = kept;
            if (r["n0"] instanceof Number && (r["n0"] as Number) > 0) {
                r["n0"] = (r["n0"] as Number) - 1;
            }
            if (r["n1"] instanceof Number && (r["n1"] as Number) > 0) {
                r["n1"] = (r["n1"] as Number) - 1;
            }
            Storage.setValue(Today.KEY_REPLY, r as Dictionary<String, Application.PropertyValueType>);
        }
        var task = taskWith(id);
        if (task != null) {
            _tasks.remove(task);
        }
        if (_tasks.size() == 0) {
            rebuild();
            return;
        }
        var index = findItemById(id);
        if (index >= 0) {
            deleteItem(index);
        }
        updateTitle();
    }

    private function updateTitle() as Void {
        setTitle(_tasks.size() == 0 ? "Today" : "Today · " + Today.count(_tasks));
    }

    private function setSubLabel(id as Object, text as String) as Void {
        var index = findItemById(id);
        if (index < 0) {
            return;
        }
        var item = getItem(index);
        if (item != null) {
            item.setSubLabel(text);
            updateItem(item, index);
        }
        WatchUi.requestUpdate();
    }

    //! The line under Refresh: when the list was fetched, or why the last fetch failed.
    private function status() as String {
        var error = Today.error();
        if (error != null) {
            return error;
        }
        var age = Today.age();
        return age != null ? "Updated " + age : "Not fetched yet";
    }

    //! A task's title, with "! " in front when its priority is high.
    private function label(t as Dictionary) as String {
        var title = t["ti"] as String;
        return t["p"] == 5 ? "! " + title : title;
    }
}

//! Select on a task asks to complete it; select on Refresh fetches the list. A repeating task is carried on to its
//! next date by the app, so the watch leaves it alone.
class TodayMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as TodayMenu;

    function initialize(menu as TodayMenu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :refresh) {
            _menu.refresh();
            return;
        }
        if (!(id instanceof String)) {
            return;
        }
        var task = _menu.taskWith(id);
        if (task == null) {
            return;
        }
        if (task["r"] == 1) {
            WatchUi.showToast("Repeats: use the app", null);
            return;
        }
        WatchUi.pushView(
            new WatchUi.Confirmation("Done?\n" + task["ti"]),
            new DoneDelegate(_menu, task),
            WatchUi.SLIDE_UP
        );
    }
}

class DoneDelegate extends WatchUi.ConfirmationDelegate {
    private var _menu as TodayMenu;
    private var _task as Dictionary;

    function initialize(menu as TodayMenu, task as Dictionary) {
        ConfirmationDelegate.initialize();
        _menu = menu;
        _task = task;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _menu.complete(_task);
        }
        return true;
    }
}
