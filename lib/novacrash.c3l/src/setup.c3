module novacrash;

import std::io;
import std::core::builtin;
import novacrash::trace;
import novacrash::ui;

bool in_panic @local = false;
bool uses_raylib = false;

fn void nova_panic(String msg, String file, String fun, uint line) @if(env::NATIVE_STACKTRACE)
{
    if (in_panic) {
    $if $defined(io::stderr):
        io::eprintn("Double panic!");
    $endif
        return;
    }
    in_panic = true;
    StackTrace trace;
    trace.init(mem);
    defer trace.free();

    if (!trace.populate()) {
    $if $defined(io::stderr):
        io::eprintn("Unable to populate the stack trace!");
    $endif
        $$trap();
    }

    Ui ui;
    if (catch ui.init(msg, file, fun, line, &trace)) {
        builtin::print_backtrace(msg, 5);
        $$trap();
    }
    if (catch ui.draw()) $$trap();

    in_panic = false;
    $$trap();
}

fn void nova_panic(String msg, String file, String fun, uint line) @if(!env::NATIVE_STACKTRACE)
{
    if (in_panic) {
    $if $defined(io::stderr):
        io::eprintn("Double panic!");
    $endif
        return;
    }
    in_panic = true;
    $if $defined(io::stderr):
	io::eprint("\nERROR: '");
	io::eprint(msg);
	io::eprintfn("', in %s (%s:%d)", fun, file, line);
    $endif
    in_panic = false;
    $$trap();
}

fn void setup() @init {
    builtin::panic = &nova_panic;
}
