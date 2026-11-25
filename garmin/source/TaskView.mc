import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! One task's details: its title, when it is due and its list, then its notes and checklist, fetched when the screen
//! opens. UP and DOWN scroll, START asks to mark it done, BACK returns to the list.
class TaskView extends WatchUi.View {
    //! Pixels kept clear at each side and at the top and bottom of the round screen.
    private const SIDE = 34;
    private const EDGE = 44;

    private var _menu as TodayMenu;
    private var _task as Dictionary;
    private var _detail as Dictionary? = null;
    private var _error as String? = null;
    //! [text, font, colour] per line, laid out on the first draw after the content changes.
    private var _lines as Array<Array>? = null;
    private var _height as Number = 0;
    private var _scroll as Number = 0;
    private var _step as Number = 60;
    private var _close as Boolean = false;
    private var _timer as Timer.Timer? = null;

    function initialize(menu as TodayMenu, task as Dictionary) {
        View.initialize();
        _menu = menu;
        _task = task;
        TodayApi.fetchTask(task["id"] as String, method(:onDetail));
    }

    function onDetail(code as Number, data as Dictionary or String or Null) as Void {
        if (TodayApi.isOk(code, data) && (data as Dictionary)["ti"] instanceof String) {
            _detail = data as Dictionary;
        } else if (TodayApi.isOk(code, data)) {
            _error = "Web app out of date";
        } else {
            _error = TodayApi.problem(code, data);
        }
        _lines = null;
        WatchUi.requestUpdate();
    }

    function onShow() as Void {
        // Back from a "Done?" answered yes: the task is going, so go back to the list too.
        if (_close) {
            var timer = new Timer.Timer();
            _timer = timer;
            timer.start(method(:close), 50, false);
        }
    }

    function close() as Void {
        // The timer is held only so it is not collected before it fires.
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _timer = null;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function closeWhenShown() as Void {
        _close = true;
    }

    //! Asks "Done?" and, on yes, completes the task and goes back to the list. A repeating task is carried on to its
    //! next date by the app, so the watch leaves it alone.
    function markDone() as Void {
        if (_task["r"] == 1) {
            WatchUi.showToast("Repeats: use the app", null);
            return;
        }
        WatchUi.pushView(
            new WatchUi.Confirmation("Done?\n" + _task["ti"]),
            new DoneDelegate(_menu, _task, self),
            WatchUi.SLIDE_UP
        );
    }

    //! Scrolls a screenful's step down (1) or up (-1).
    function scroll(direction as Number) as Void {
        var max = _height - (System.getDeviceSettings().screenHeight - 2 * EDGE);
        var next = _scroll + direction * _step;
        if (next > max) {
            next = max;
        }
        if (next < 0) {
            next = 0;
        }
        if (next != _scroll) {
            _scroll = next;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var width = dc.getWidth() - 2 * SIDE;
        var lines = _lines;
        if (lines == null) {
            lines = layout(dc, width);
            _lines = lines;
            _height = 0;
            for (var i = 0; i < lines.size(); i++) {
                _height += dc.getFontHeight(lines[i][1] as Graphics.FontType);
            }
            _step = dc.getHeight() / 3;
        }
        var y = EDGE - _scroll;
        var x = dc.getWidth() / 2;
        for (var i = 0; i < lines.size(); i++) {
            var font = lines[i][1] as Graphics.FontType;
            var h = dc.getFontHeight(font);
            if (y + h > 0 && y < dc.getHeight()) {
                dc.setColor(lines[i][2] as Graphics.ColorType, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, y, font, lines[i][0] as String, Graphics.TEXT_JUSTIFY_CENTER);
            }
            y += h;
        }
    }

    //! The screen as lines: title, when and list, notes, checklist, and what START does.
    private function layout(dc as Graphics.Dc, width as Number) as Array<Array> {
        var out = [] as Array<Array>;
        var detail = _detail;
        var title = detail != null ? detail["ti"] as String : _task["ti"] as String;
        add(out, dc, title, Graphics.FONT_SMALL, priorityColour(), width);

        var when = Today.when(_task);
        if (detail != null && detail["ls"] instanceof String && !(detail["ls"] as String).equals("")) {
            when += " · " + detail["ls"];
        }
        add(out, dc, when, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY, width);
        out.add(["", Graphics.FONT_XTINY, Graphics.COLOR_WHITE]);

        if (detail == null) {
            add(out, dc, _error != null ? _error as String : "Loading...", Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY,
                width);
        } else {
            var notes = detail["c"];
            if (notes instanceof String && !notes.equals("")) {
                add(out, dc, notes, Graphics.FONT_XTINY, Graphics.COLOR_WHITE, width);
                out.add(["", Graphics.FONT_XTINY, Graphics.COLOR_WHITE]);
            }
            var items = detail["cl"];
            if (items instanceof Array && items.size() > 0) {
                for (var i = 0; i < items.size(); i++) {
                    var item = items[i] as Dictionary;
                    var done = item["s"] == 1;
                    add(out, dc, (done ? "[x] " : "[ ] ") + item["ti"], Graphics.FONT_XTINY,
                        done ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE, width);
                }
                var total = detail["ncl"];
                if (total instanceof Number && total > items.size()) {
                    add(out, dc, "+" + (total - items.size()) + " more in the app", Graphics.FONT_XTINY,
                        Graphics.COLOR_LT_GRAY, width);
                }
                out.add(["", Graphics.FONT_XTINY, Graphics.COLOR_WHITE]);
            }
            if ((notes == null || (notes instanceof String && notes.equals(""))) && !(items instanceof Array && items.size() > 0)) {
                add(out, dc, "No notes", Graphics.FONT_XTINY, Graphics.COLOR_DK_GRAY, width);
                out.add(["", Graphics.FONT_XTINY, Graphics.COLOR_WHITE]);
            }
        }
        var hint = _task["r"] == 1 ? "Repeats: finish it in the app" : "START: mark done";
        add(out, dc, hint, Graphics.FONT_XTINY, Graphics.COLOR_BLUE, width);
        return out;
    }

    private function priorityColour() as Graphics.ColorType {
        var p = _task["p"];
        if (p == 5) {
            return Graphics.COLOR_RED;
        } else if (p == 3) {
            return Graphics.COLOR_ORANGE;
        } else if (p == 1) {
            return Graphics.COLOR_BLUE;
        }
        return Graphics.COLOR_WHITE;
    }

    //! Adds [text] word-wrapped to [width], one entry per line; "\n" starts a new line, an empty one a blank line.
    private function add(out as Array<Array>, dc as Graphics.Dc, text as String, font as Graphics.FontType,
            colour as Graphics.ColorType, width as Number) as Void {
        var rest = text;
        while (true) {
            var nl = rest.find("\n");
            var paragraph = nl == null ? rest : rest.substring(0, nl) as String;
            wrap(out, dc, paragraph, font, colour, width);
            if (nl == null) {
                return;
            }
            rest = rest.substring(nl + 1, rest.length()) as String;
        }
    }

    private function wrap(out as Array<Array>, dc as Graphics.Dc, paragraph as String, font as Graphics.FontType,
            colour as Graphics.ColorType, width as Number) as Void {
        if (paragraph.length() == 0) {
            out.add(["", font, colour]);
            return;
        }
        var line = "";
        var rest = paragraph;
        while (rest.length() > 0) {
            var space = rest.find(" ");
            var word = space == null ? rest : rest.substring(0, space) as String;
            rest = space == null ? "" : rest.substring(space + 1, rest.length()) as String;
            var candidate = line.equals("") ? word : line + " " + word;
            if (dc.getTextWidthInPixels(candidate, font) <= width) {
                line = candidate;
                continue;
            }
            if (!line.equals("")) {
                out.add([line, font, colour]);
            }
            // A word wider than the screen is cut into pieces that fit.
            while (dc.getTextWidthInPixels(word, font) > width && word.length() > 1) {
                var n = word.length() - 1;
                while (n > 1 && dc.getTextWidthInPixels(word.substring(0, n) as String, font) > width) {
                    n--;
                }
                out.add([word.substring(0, n) as String, font, colour]);
                word = word.substring(n, word.length()) as String;
            }
            line = word;
        }
        if (!line.equals("")) {
            out.add([line, font, colour]);
        }
    }
}

//! UP and DOWN scroll the details; START asks to mark the task done.
class TaskDelegate extends WatchUi.BehaviorDelegate {
    private var _view as TaskView;

    function initialize(view as TaskView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.scroll(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scroll(-1);
        return true;
    }

    function onSelect() as Boolean {
        _view.markDone();
        return true;
    }
}
