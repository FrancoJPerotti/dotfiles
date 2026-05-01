#!/usr/bin/env python3
import curses
import subprocess
import sys
from typing import List, Dict


def tmux(*args: str, check: bool = True) -> str:
    p = subprocess.run(["tmux", *args], capture_output=True, text=True)
    if check and p.returncode != 0:
        raise RuntimeError(p.stderr.strip() or p.stdout.strip() or "tmux command failed")
    return p.stdout.strip()


def list_sessions() -> List[Dict[str, str]]:
    current = tmux("display-message", "-p", "#S", check=False)
    out = tmux("list-sessions", "-F", "#{session_name}\t#{?session_attached,1,0}\t#{session_windows}", check=False)
    sessions = []
    if not out:
        return sessions
    for line in out.splitlines():
        name, attached, windows = (line.split("\t") + ["", "", ""])[:3]
        sessions.append({"name": name, "attached": attached, "windows": windows, "current": "1" if name == current else "0"})
    sessions.sort(key=lambda s: (s["current"] != "1", s["name"].lower()))
    return sessions


def filter_sessions(sessions: List[Dict[str, str]], query: str) -> List[Dict[str, str]]:
    q = query.lower().strip()
    if not q:
        return sessions
    return [s for s in sessions if q in s["name"].lower()]


def prompt(stdscr, label: str, initial: str = "") -> str:
    curses.curs_set(1)
    value = initial
    while True:
        h, w = stdscr.getmaxyx()
        stdscr.move(h - 2, 0)
        stdscr.clrtoeol()
        text = f"{label}: {value}"
        stdscr.addnstr(h - 2, 0, text, max(0, w - 1), curses.A_BOLD)
        stdscr.refresh()
        ch = stdscr.get_wch()
        if ch in ("\n", "\r"):
            curses.curs_set(0)
            return value.strip()
        if ch == "\x1b":
            curses.curs_set(0)
            return ""
        if ch in (curses.KEY_BACKSPACE, "\b", "\x7f"):
            value = value[:-1]
        elif isinstance(ch, str) and ch.isprintable():
            value += ch


def confirm(stdscr, label: str) -> bool:
    curses.curs_set(0)
    while True:
        h, w = stdscr.getmaxyx()
        stdscr.move(h - 2, 0)
        stdscr.clrtoeol()
        stdscr.addnstr(h - 2, 0, f"{label} [y/N]", max(0, w - 1), curses.A_BOLD)
        stdscr.refresh()
        ch = stdscr.get_wch()
        if ch in ("y", "Y"):
            return True
        if ch in ("n", "N", "\x1b", "\n", "\r"):
            return False


def message(stdscr, text: str) -> None:
    h, w = stdscr.getmaxyx()
    stdscr.move(h - 2, 0)
    stdscr.clrtoeol()
    stdscr.addnstr(h - 2, 0, text, max(0, w - 1), curses.A_DIM)
    stdscr.refresh()


def draw(stdscr, sessions: List[Dict[str, str]], filtered: List[Dict[str, str]], query: str, index: int) -> None:
    stdscr.erase()
    h, w = stdscr.getmaxyx()
    header = "Enter switch  ·  a create  ·  d detach  ·  r rename  ·  D delete  ·  Esc close"
    stdscr.addnstr(0, 0, header, max(0, w - 1), curses.color_pair(4) | curses.A_BOLD)
    stdscr.addnstr(1, 0, "query:", max(0, w - 1), curses.color_pair(5) | curses.A_BOLD)
    if query:
        stdscr.addnstr(1, 7, f" {query}", max(0, w - 8), curses.color_pair(3))

    max_rows = max(1, h - 5)
    start = 0
    if index >= max_rows:
        start = index - max_rows + 1
    visible = filtered[start:start + max_rows]

    for row, sess in enumerate(visible, start=3):
        real_idx = start + row - 3
        selected = real_idx == index
        pointer = "›" if selected else " "
        pointer_attr = curses.color_pair(3) | (curses.A_BOLD if selected else curses.A_DIM)
        marker = "●" if sess["attached"] == "1" else "○"
        marker_attr = curses.color_pair(2 if sess["attached"] == "1" else 5)
        name_attr = curses.color_pair(3 if sess.get("current") == "1" else 1)
        meta_attr = curses.color_pair(5)
        if selected:
            name_attr |= curses.A_BOLD
            marker_attr |= curses.A_BOLD
            meta_attr |= curses.A_BOLD
        stdscr.addnstr(row, 0, f"{pointer} ", min(w, 2), pointer_attr)
        stdscr.addnstr(row, 2, f"{marker} ", min(max(0, w - 2), 2), marker_attr)
        name_width = max(0, w - 16)
        stdscr.addnstr(row, 4, sess['name'], name_width, name_attr)
        meta = f" ({sess['windows']}w)"
        meta_x = min(w - 1, 5 + len(sess['name']))
        if meta_x < w:
            stdscr.addnstr(row, meta_x, meta, max(0, w - meta_x - 1), meta_attr)

    footer = f"{len(filtered)}/{len(sessions)} sessions  ·  ● attached  ·  cyan = current"
    stdscr.addnstr(h - 1, 0, footer, max(0, w - 1), curses.color_pair(5) | curses.A_DIM)
    stdscr.refresh()


def main(stdscr) -> int:
    try:
        curses.set_escdelay(25)
    except Exception:
        pass
    curses.curs_set(0)
    curses.use_default_colors()
    stdscr.keypad(True)
    if curses.has_colors():
        curses.start_color()
        curses.init_pair(1, 252, -1)
        curses.init_pair(2, 114, -1)
        curses.init_pair(3, 111, -1)
        curses.init_pair(4, 180, -1)
        curses.init_pair(5, 245, -1)

    query = ""
    index = 0
    previous_query = ""

    while True:
        sessions = list_sessions()
        filtered = filter_sessions(sessions, query)
        if query != previous_query:
            index = 0
            previous_query = query
        if filtered:
            index = max(0, min(index, len(filtered) - 1))
        else:
            index = 0

        draw(stdscr, sessions, filtered, query, index)
        ch = stdscr.get_wch()

        if ch in ("\x1b",):
            return 0
        if ch in (curses.KEY_UP,):
            if filtered:
                index = max(0, index - 1)
            continue
        if ch in (curses.KEY_DOWN,):
            if filtered:
                index = min(len(filtered) - 1, index + 1)
            continue
        if ch in (curses.KEY_BACKSPACE, "\b", "\x7f"):
            query = query[:-1]
            continue
        if ch in ("\n", "\r"):
            if filtered:
                tmux("switch-client", "-t", filtered[index]["name"])
                return 0
            continue
        if ch == "a":
            name = prompt(stdscr, "new session name")
            if name:
                tmux("new-session", "-Ad", "-s", name)
                tmux("switch-client", "-t", name)
                return 0
            continue
        if ch == "d":
            tmux("detach-client")
            return 0
        if ch == "r":
            if not filtered:
                message(stdscr, "select a session to rename")
                continue
            old = filtered[index]["name"]
            new = prompt(stdscr, "rename session", old)
            if new and new != old:
                tmux("rename-session", "-t", old, new)
            continue
        if ch == "D":
            if not filtered:
                message(stdscr, "select a session to delete")
                continue
            name = filtered[index]["name"]
            if confirm(stdscr, f"delete session '{name}'?"):
                tmux("kill-session", "-t", name)
            continue
        if isinstance(ch, str) and ch.isprintable():
            query += ch
            continue


if __name__ == "__main__":
    try:
        raise SystemExit(curses.wrapper(main))
    except Exception as e:
        tmux("display-message", f"session picker error: {str(e).replace('"', "'")}", check=False)
        raise
