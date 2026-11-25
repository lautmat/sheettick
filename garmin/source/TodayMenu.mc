import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

//! The list of today's tasks, overdue first, each with a ring in its priority colour, then a Tomorrow item and a
//! Refresh item at the foot. Selecting a task opens its details. The same class lists tomorrow's tasks ([day] 1),
//! opened from the Tomorrow item.
class TodayMenu extends WatchUi.Menu2 {
    private var _day as Number;
    private var _parent as TodayMenu?;
    private var _outbox as Outbox? = null;
    private var _tasks as Array<Dictionary> = [] as Array<Dictionary>;
    private var _busy as Boolean = false;
    private var _saving as Dictionary? = null;
    private var _icons as Dictionary<Number, WatchUi.Bitmap> = {} as Dictionary<Number, WatchUi.Bitmap>;

    function initialize(day as Number, parent as TodayMenu?) {
        Menu2.initialize({:title => day == 0 ? "Today" : "Tomorrow"});
        _day = day;
        _parent = parent;
        rebuild();
    }

    //! Refills the list from the saved reply.
    function rebuild() as Void {
        while (getItem(0) != null) {
            deleteItem(0);
        }
        _tasks = _day == 0 ? Today.tasks() : Today.tomorrow();
        for (var i = 0; i < _tasks.size(); i++) {
            var t = _tasks[i];
            addItem(new WatchUi.IconMenuItem(t["ti"] as String, Today.when(t), t["id"], priorityIcon(t), null));
        }
        if (_tasks.size() == 0 && Today.reply() != null) {
            addItem(new WatchUi.MenuItem("All clear", _day == 0 ? "Nothing due today" : "Nothing due", :none, null));
        }
        if (_day == 0) {
            if (Today.knowsTomorrow()) {
                addItem(new WatchUi.MenuItem("Tomorrow", tomorrowText(), :tomorrow, null));
            }
            addItem(new WatchUi.MenuItem("Refresh", status(), :refresh, null));
        }
        updateTitle();
        WatchUi.requestUpdate();
    }

    //! Sends any completions kept while the phone was out of reach, then fetches the list.
    function refresh() as Void {
        if (_busy) {
            return;
        }
        _busy = true;
        setSubLabel(:refresh, "Refreshing...");
        var outbox = new Outbox(method(:fetch));
        _outbox = outbox;
        outbox.start();
    }

    function fetch() as Void {
        _outbox = null;
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
        } else if (TodayApi.retryable(code, data)) {
            // No phone, or no answer: keep it and let the background job send it.
            Today.queue(task["id"] as String, task["v"] as Number);
            forget(task["id"] as String);
            WatchUi.showToast("Saved: sends later", null);
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
            var gone = null as Dictionary?;
            for (var i = 0; i < all.size(); i++) {
                if (id.equals(all[i]["id"])) {
                    gone = all[i];
                }
            }
            // n0 counts up to today and n1 up to tomorrow, both on the reply's day.
            if (gone != null && (gone["d"] as Number) <= 0 && r["n0"] instanceof Number && (r["n0"] as Number) > 0) {
                r["n0"] = (r["n0"] as Number) - 1;
            }
            if (gone != null && r["n1"] instanceof Number && (r["n1"] as Number) > 0) {
                r["n1"] = (r["n1"] as Number) - 1;
            }
            Storage.setValue(Today.KEY_REPLY, r as Dictionary<String, Application.PropertyValueType>);
        }
        var task = taskWith(id);
        if (task != null) {
            _tasks.remove(task);
        }
        var parent = _parent;
        if (parent != null) {
            parent.updateTomorrow();
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
        updateTomorrow();
    }

    private function updateTitle() as Void {
        var name = _day == 0 ? "Today" : "Tomorrow";
        var n = _day == 0 ? Today.count(_tasks) : Today.tomorrowCount(_tasks);
        setTitle(_tasks.size() == 0 ? name : name + " · " + n);
    }

    //! Brings the Tomorrow item's count up to date.
    function updateTomorrow() as Void {
        if (_day == 0) {
            setSubLabel(:tomorrow, tomorrowText());
        }
    }

    private function tomorrowText() as String {
        var n = Today.tomorrowCount(Today.tomorrow());
        return n == 0 ? "Nothing due" : n == 1 ? "1 task" : n + " tasks";
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

    //! A ring in the task's priority colour, as TickTick draws its checkbox: red high, orange medium, blue low, grey
    //! none. Each colour is loaded once.
    function priorityIcon(t as Dictionary) as WatchUi.Bitmap {
        var p = t["p"];
        var key = p == 5 ? 5 : p == 3 ? 3 : p == 1 ? 1 : 0;
        var icon = _icons[key];
        if (icon == null) {
            var id = key == 5 ? Rez.Drawables.PrioHigh : key == 3 ? Rez.Drawables.PrioMedium
                : key == 1 ? Rez.Drawables.PrioLow : Rez.Drawables.PrioNone;
            icon = new WatchUi.Bitmap({:rezId => id});
            _icons[key] = icon;
        }
        return icon;
    }
}

//! Select on a task opens its details (TaskView), where it can be completed; Tomorrow opens tomorrow's list; Refresh
//! fetches the list.
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
        if (id == :tomorrow) {
            var tomorrow = new TodayMenu(1, _menu);
            WatchUi.pushView(tomorrow, new TodayMenuDelegate(tomorrow), WatchUi.SLIDE_LEFT);
            return;
        }
        if (!(id instanceof String)) {
            return;
        }
        var task = _menu.taskWith(id);
        if (task == null) {
            return;
        }
        var view = new TaskView(_menu, task);
        WatchUi.pushView(view, new TaskDelegate(view), WatchUi.SLIDE_LEFT);
    }
}

//! The "Done?" prompt. On yes it completes the task, and closes the details screen it was asked from.
class DoneDelegate extends WatchUi.ConfirmationDelegate {
    private var _menu as TodayMenu;
    private var _task as Dictionary;
    private var _view as TaskView?;

    function initialize(menu as TodayMenu, task as Dictionary, view as TaskView?) {
        ConfirmationDelegate.initialize();
        _menu = menu;
        _task = task;
        _view = view;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _menu.complete(_task);
            var view = _view;
            if (view != null) {
                view.closeWhenShown();
            }
        }
        return true;
    }
}
