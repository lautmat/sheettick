import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! The glance: "TODAY · 9 · 2 late" over the next task. It draws what the background job saved.
(:glance)
class TodayGlance extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var font = Graphics.FONT_GLANCE;
        var top = height / 4;
        var bottom = height * 3 / 4;
        var justify = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        var heading = "SHEETTICK";
        var late = "";
        var line;
        if (Today.reply() == null) {
            var error = Today.error();
            line = error != null ? error : "Open to set up";
        } else {
            var tasks = Today.tasks();
            if (tasks.size() == 0) {
                heading = "TODAY";
                line = "All clear";
            } else {
                heading = "TODAY · " + Today.count(tasks);
                var lateCount = Today.lateCount(tasks);
                if (lateCount > 0) {
                    late = " · " + lateCount + " late";
                }
                var next = Today.next(tasks) as Dictionary;
                line = next["ti"] as String;
                if (next["dd"] == 0 && (next["t"] as Number) >= 0) {
                    line = Today.clockText(next["t"] as Number) + " " + line;
                }
            }
        }
        var stale = "";
        var seconds = Today.ageSeconds();
        if (seconds != null && seconds >= 3600) {
            stale = Today.age() + " · ";
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, top, font, heading, justify);
        if (!late.equals("")) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getTextWidthInPixels(heading, font), top, font, late, justify);
        }
        var x = 0;
        if (!stale.equals("")) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, bottom, font, stale, justify);
            x = dc.getTextWidthInPixels(stale, font);
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, bottom, font, fit(dc, line, font, width - x), justify);
    }

    //! [text] cut with "..." to fit in [width] pixels.
    private function fit(dc as Graphics.Dc, text as String, font as Graphics.FontType, width as Number) as String {
        if (dc.getTextWidthInPixels(text, font) <= width) {
            return text;
        }
        var n = text.length();
        while (n > 1 && dc.getTextWidthInPixels((text.substring(0, n) as String) + "...", font) > width) {
            n--;
        }
        return (text.substring(0, n) as String) + "...";
    }
}
