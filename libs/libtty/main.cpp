#include "libtty.h"
#include <iostream>
#include <vector>


int main() {
    tty::console conio;
    auto [width, height] = conio.size();

    std::cout << "Columns: " << width << " Rows: " << height << '\n';

    std::string line;
    std::cin >> line;
    conio.clear();
    std::cout << "Columns: " << width << " Rows: " << height << '\n';

    std::cin >> line;

    conio.move_xy(10, 5);
    std::cout << "Columns: " << width << " Rows: " << height << '\n';

    std::cin >> line;

    using namespace tty;
    int row = 0;
    int col = 0;
    conio.clear();

    for (auto var: std::vector{color_variant::BRIGHT, color_variant::NORMAL, color_variant::DIM}) {

        row = 0;
        for (auto color: std::vector{foreground_color::BLACK, foreground_color::RED, foreground_color::GREEN,
                                     foreground_color::YELLOW, foreground_color::BLUE, foreground_color::MAGNETA,
                                     foreground_color::CYAN, foreground_color::WHITE}) {
            conio.move_xy(col, row);
            conio.set_fg_color(color, var);
            std::cout << "COLOR";

            ++row;
        }
        col += 10;
    }

    std::cin >> line;

    return 0;
}
