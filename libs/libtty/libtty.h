#ifndef LIBTTY_LIBTTY_H
#define LIBTTY_LIBTTY_H

#include <sys/ioctl.h>
#include <unistd.h>
#include <stdexcept>
#include <cstdarg>

namespace tty {
    struct point2d {
        int x;
        int y;
    };

    struct size2d {
        int width;
        int height;
    };



#define TTY_ESC "\033"

    namespace detail{
        enum struct ctrl;
        void print_fmt(const char *, ...)  __attribute__ ((format (printf, 1, 2)));
        void print_fmt_seq(ctrl fmt, ...);

        template <typename...Args>
        void print_ctrl_seq(Args&&...args);

        enum struct ctrl : int {
            RESET = 0,
            MOVE_HOME,
            CLEAR_BELOW,
            CLEAR_ABOVE,

            ERASE_END_OF_LINE,
            ERASE_START_OF_LINE,
            ERASE_LINE,

            MOVE_XY,
            MOVE_UP_BY,
            MOVE_DOWN_BY,
            MOVE_RIGHT_BY,
            MOVE_LEFT_BY,

            ATTRIBUTE_2_SET
        };

        const char * seqs[] = {
            "s",
            "[H",
            "[J",
            "[1J",

            "[K",
            "[1K",
            "[2K",

            "[%d;%dH",
            "[%dA",
            "[%dB",
            "[%dC",
            "[%dD",
            "[%d;%dm"
        };

        void print_fmt(const char * fmt, ...)  {
            va_list args;
            va_start(args, fmt);
            std::fprintf(stdout, TTY_ESC);
            std::vfprintf(stdout, fmt, args);
        }

        void print_fmt_seq(ctrl fmt, ...)  {
            va_list args;
            va_start(args, fmt);
            std::fprintf(stdout, TTY_ESC);
            std::vfprintf(stdout, seqs[static_cast<int>(fmt)], args);
        }

        template <typename...Args>
        void print_ctrl_seq(Args&&...args){
            (std::fprintf(stdout, TTY_ESC"%s", seqs[static_cast<int>(std::forward<Args>(args))]),...);
        }
    }

    enum struct foreground_color : int {
        BLACK   = 30,
        RED     = 31,
        GREEN   = 32,
        YELLOW  = 33,
        BLUE    = 34,
        MAGNETA = 35,
        CYAN    = 36,
        WHITE   = 37
    };

    enum struct color_variant : int {
        NORMAL  = 0,
        BRIGHT  = 1,
        DIM     = 2
    };

    struct console {

        void reset() const {
            using namespace detail;
            detail::print_ctrl_seq(ctrl::RESET);
        }

        size2d size() const noexcept(false) {
            if (isatty(fileno(stdout))) {
                struct winsize ws;
                ioctl(fileno(stdout), TIOCGWINSZ, &ws);
                return {ws.ws_col, ws.ws_row};
            } else if (isatty(fileno(stdin))) {
                struct winsize ws;
                ioctl(fileno(stdin), TIOCGWINSZ, &ws);
                return {ws.ws_col, ws.ws_row};
            } else if (isatty(fileno(stderr))) {
                struct winsize ws;
                ioctl(fileno(stderr), TIOCGWINSZ, &ws);
                return {ws.ws_col, ws.ws_row};
            }
            throw std::runtime_error("None of the standard streams is associated with the terminal. Cannot get the terminal window size.");
        }

        void move_xy(int col, int row){
            using namespace detail;
            print_fmt_seq(ctrl::MOVE_XY, row, col);
        }

        void move_up_by(int lines){
            using namespace detail;
            print_fmt_seq(ctrl::MOVE_UP_BY, lines);
        }

        void move_down_by(int lines){
            using namespace detail;
            print_fmt_seq(ctrl::MOVE_DOWN_BY, lines);
        }

        void move_right_by(int chars){
            using namespace detail;
            print_fmt_seq(ctrl::MOVE_RIGHT_BY, chars);
        }

        void move_left_by(int chars){
            using namespace detail;
            print_fmt_seq(ctrl::MOVE_LEFT_BY, chars);
        }

        void clear() const {
            using namespace detail;
            print_ctrl_seq(ctrl::MOVE_HOME, ctrl::CLEAR_BELOW);
        }

        void move_home() const{
            using namespace detail;
            print_ctrl_seq(ctrl::MOVE_HOME);
        }

        void clear_below() const {
            using namespace detail;
            print_ctrl_seq(ctrl::CLEAR_BELOW);
        }

        void clear_above() const {
            using namespace detail;
            print_ctrl_seq(ctrl::CLEAR_ABOVE);
        }

        void erase_end_of_line() const {
            using namespace detail;
            print_ctrl_seq(ctrl::ERASE_END_OF_LINE);
        }

        void erase_start_of_line() const {
            using namespace detail;
            print_ctrl_seq(ctrl::ERASE_START_OF_LINE);
        }

        void erase_current_line() const {
            using namespace detail;
            print_ctrl_seq(ctrl::ERASE_LINE);
        }

        void set_fg_color(foreground_color color, color_variant var = color_variant::NORMAL){
            using namespace detail;
            print_fmt_seq(ctrl::ATTRIBUTE_2_SET, static_cast<int>(var), static_cast<int>(color));
        }

    };

#ifdef TTY_ESC
    #undef TTY_ESC
#endif

}


#endif //LIBTTY_LIBTTY_H
