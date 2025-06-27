module novacrash;
import std::io;

fn int main(String[] args)
{
    novacrash::setup();
    novacrash::uses_raylib = false; /* true, if you use raylib */

    unreachable("Manual panic");
}
