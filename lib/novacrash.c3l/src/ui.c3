module novacrash::ui;

import raylib5::rl;
import raygui::rg;
import raygui::rg::style::dark;
import novacrash::trace;
import std::core::string;
import std::io::path;

struct Ui {
    String msg, file, fun;
    uint line;
    StackTrace *trace;
    bool toggle_full_path;
}

fn void Ui.init(&self, String msg, String file, String fun, uint line, StackTrace *trace)
{
    self.msg = msg;
    self.file = file;
    self.fun = fun;
    self.line = line;
    self.trace = trace;

    if (novacrash::uses_raylib) rl::closeWindow();

    rl::setTraceLogLevel(ERROR);
    rl::setConfigFlags(rl::FLAG_WINDOW_RESIZABLE);

    int width = 500;
    int height = 750;

    rl::initWindow(width, height, "Novacrash report");
    rl::setTargetFPS(60);
}

fn void? Ui.draw(&self)
{
    Rectangle panel_rec = { 10, 0, (float) rl::getScreenWidth() - 20, 0 };
    Rectangle panel_content_rec;
    Rectangle panel_view;
    Vector2 panel_scroll;

    dark::load();

    // rg::guiSetFont(rl::getFontDefault());

    Font font = rg::guiGetFont();

    while (!rl::windowShouldClose()) {
        rl::beginDrawing();
        rl::clearBackground(rl::getColor(rg::guiGetStyle(DEFAULT, rg::BACKGROUND_COLOR)));
        int width = rl::getScreenWidth();
        int height = rl::getScreenHeight();
        int y = 10;
        int font_size = 38;

        rg::guiSetStyle(DEFAULT, rg::TEXT_SIZE, font_size);
        rg::guiLabel((Rectangle) {
            .x = 10,
            .y = y,
            .width = (float) width - 20,
            .height = font_size,
        }, self.msg);
        y += font_size;

        font_size = 28;
        rg::guiSetStyle(DEFAULT, rg::TEXT_SIZE, font_size);
        @pool() {
            String str = string::tformat("in %s (%s:%d)", self.fun, self.file, self.line);
            rg::guiLabel((Rectangle) {
                .x = 10,
                .y = y,
                .width = (float) width - 20,
                .height = font_size,
            }, str.zstr_tcopy());
            y += font_size;
        };
        rg::guiCheckBox((Rectangle) {
            .x = 10,
            .y = y,
            .width = font_size,
            .height = font_size,
        }, "Toggle Full Paths", &self.toggle_full_path);
        y += font_size + 10;

        panel_rec.y = y;
        panel_rec.height = (float) height - y - 10;
        panel_rec.width = (float) width - 20;

        rg::guiScrollPanel(panel_rec, null, panel_content_rec, &panel_scroll, &panel_view);
        rl::beginScissorMode((int) panel_view.x, (int) panel_view.y, (int) panel_view.width, (int) panel_view.height);

        int content_height = (int) panel_view.y;
        int content_width = 0;

        foreach (i, &tr : self.trace.backtrace) {
            if (i < 6) continue;

            @pool() {
                Path file = path::temp(tr.file)!;
                String path_str = self.toggle_full_path ? file.str_view() : file.basename();

                String fmt = string::tformat("%s in %s at %d", tr.function, path_str, tr.line);
                ZString sfmt = fmt.zstr_tcopy();
                float w = rl::measureTextEx(font, sfmt, font_size, 2).x;
                rg::guiLabel((Rectangle) {
                    .x = 10 + panel_scroll.x,
                    .y = content_height,
                    .width = w,
                    .height = font_size,
                }, sfmt);
                content_height += font_size;

                if (w > content_width) content_width = (int) w;
            };
        }

        panel_content_rec.height = content_height;
        panel_content_rec.width = content_width;

        rl::endScissorMode();
        rl::endDrawing();
    }
}
