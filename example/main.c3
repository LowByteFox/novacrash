module novacrash;

import std::io;
import novacrash::options;

fn int main(String[] args)
{
    options::cfg.app_name = "Example";
    options::cfg.message = "has reached a";
    options::cfg.window = {
        .title = "Crash Report",
        .width = 500,
        .height = 750,
    };

    options::cfg.header = {
        .catch_phrases = {"!!!", "XXX", "PANIC", "ERROR"},
        .crash_icon = $embed("./assets/Dead_border.png"),
        .icon_size = { 128, 128 },
        .title_size = 32,
    };

    options::cfg.theme = {
        .font = $embed("./assets/Ubuntu-R.ttf"),
        .font_size = 22,
    };

    unreachable("Manual panic");
}
