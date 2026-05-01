#!/usr/bin/env python3
import re
import subprocess
import sys
from typing import Dict, List, Optional


def tmux(*args: str, check: bool = True) -> str:
    p = subprocess.run(["tmux", *args], capture_output=True, text=True)
    if check and p.returncode != 0:
        msg = p.stderr.strip() or p.stdout.strip() or f"tmux {' '.join(args)} failed"
        raise SystemExit(msg)
    return p.stdout.strip()


def sanitize(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]", "_", name)


def pane_fields(target: str) -> Dict[str, str]:
    fmt = "\t".join([
        "#{pane_id}",
        "#{session_name}",
        "#{window_id}",
        "#{window_index}",
        "#{pane_title}",
        "#{pane_current_command}",
        "#{pane_current_path}",
        "#{host}",
    ])
    vals = tmux("display-message", "-p", "-t", target, fmt).split("\t")
    return dict(zip(["pane_id", "session_name", "window_id", "window_index", "pane_title", "pane_current_command", "pane_current_path", "host"], vals))


def pane_option(target: str, name: str) -> str:
    return tmux("show-options", "-p", "-v", "-t", target, name, check=False).strip()


def set_pane_option(target: str, name: str, value: str) -> None:
    tmux("set-option", "-p", "-t", target, name, value)


def unset_pane_option(target: str, name: str) -> None:
    tmux("set-option", "-p", "-u", "-t", target, name, check=False)


def set_pane_title(pane_id: str, title: str) -> None:
    tmux("select-pane", "-t", pane_id, "-T", title)


def current_label_for(info: Dict[str, str]) -> str:
    return info.get("pane_title") or info.get("pane_current_command") or "pane"


def list_all_panes() -> List[Dict[str, str]]:
    fmt = "\t".join([
        "#{pane_id}",
        "#{session_name}",
        "#{window_id}",
        "#{window_index}",
        "#{pane_title}",
        "#{pane_current_command}",
        "#{pane_current_path}",
        "#{@stack_gid}",
        "#{@stack_ord}",
        "#{pane_marked}",
        "#{pane_active}",
        "#{@stack_label}",
        "#{pane_left}",
        "#{pane_top}",
        "#{pane_right}",
        "#{pane_bottom}",
    ])
    out = tmux("list-panes", "-a", "-F", fmt, check=False)
    panes: List[Dict[str, str]] = []
    if not out:
        return panes
    keys = [
        "pane_id", "session_name", "window_id", "window_index", "pane_title", "pane_current_command",
        "pane_current_path", "stack_gid", "stack_ord", "pane_marked", "pane_active", "stack_label",
        "pane_left", "pane_top", "pane_right", "pane_bottom",
    ]
    for line in out.splitlines():
        vals = line.split("\t")
        vals += [""] * (len(keys) - len(vals))
        panes.append(dict(zip(keys, vals)))
    return panes


def group_members(gid: str) -> List[Dict[str, str]]:
    members = [p for p in list_all_panes() if p.get("stack_gid") == gid]
    members.sort(key=lambda p: int(p.get("stack_ord") or "0"))
    return members


def helper_session_name(session_name: str) -> str:
    return f"__stacked__{sanitize(session_name)}"


def ensure_helper(session_name: str) -> str:
    helper = helper_session_name(session_name)
    if subprocess.run(["tmux", "has-session", "-t", helper], capture_output=True).returncode != 0:
        tmux("new-session", "-d", "-s", helper, "-n", "parking")
        tmux("set-option", "-t", f"{helper}:parking", "allow-rename", "off", check=False)
        tmux("rename-window", "-t", f"{helper}:parking", "parking", check=False)
    return helper


def is_helper_session(session_name: str) -> bool:
    return session_name.startswith("__stacked__")


def ensure_title(pane_id: str) -> None:
    info = pane_fields(pane_id)
    title = info["pane_title"]
    if not title or title == info["host"]:
        fallback = info["pane_current_command"] or "pane"
        set_pane_title(pane_id, fallback)
        info["pane_title"] = fallback
    if not pane_option(pane_id, "@stack_label"):
        set_pane_option(pane_id, "@stack_label", current_label_for(info))


def pane_label(pane: Dict[str, str]) -> str:
    return pane.get("stack_label") or pane.get("pane_title") or pane.get("pane_current_command") or "pane"


def visible_member(gid: str) -> Optional[Dict[str, str]]:
    members = group_members(gid)
    visible = [m for m in members if not is_helper_session(m["session_name"])]
    return visible[0] if visible else (members[0] if members else None)


def refresh_group_titles(gid: str) -> None:
    members = group_members(gid)
    if not members:
        return
    changed = False
    for member in members:
        if not member.get("stack_label"):
            set_pane_option(member["pane_id"], "@stack_label", pane_label(member))
            changed = True
    if changed:
        members = group_members(gid)
    visible = visible_member(gid)
    if not visible:
        return
    group_title = "GROUP " + " ".join(
        f"[{pane_label(member)}]" if member["pane_id"] == visible["pane_id"] else pane_label(member)
        for member in members
    )
    if pane_fields(visible["pane_id"])["pane_title"] != group_title:
        set_pane_title(visible["pane_id"], group_title)


def clear_group_title(pane_id: str) -> None:
    info = pane_fields(pane_id)
    label = pane_option(pane_id, "@stack_label") or current_label_for(info)
    set_pane_title(pane_id, label)
    unset_pane_option(pane_id, "@stack_label")


def ensure_group_for_visible(pane_id: str) -> str:
    gid = pane_option(pane_id, "@stack_gid")
    if gid:
        ensure_title(pane_id)
        refresh_group_titles(gid)
        return gid
    info = pane_fields(pane_id)
    gid = f"{sanitize(info['session_name'])}_{sanitize(info['window_id'])}_{pane_id.replace('%', 'p')}"
    set_pane_option(pane_id, "@stack_gid", gid)
    set_pane_option(pane_id, "@stack_ord", "1")
    ensure_title(pane_id)
    refresh_group_titles(gid)
    return gid


def cleanup_group(gid: str) -> None:
    members = group_members(gid)
    for idx, member in enumerate(members, start=1):
        set_pane_option(member["pane_id"], "@stack_ord", str(idx))
    if members:
        refresh_group_titles(gid)


def visible_window_panes(window_id: str) -> List[Dict[str, str]]:
    return [p for p in list_all_panes() if p.get("window_id") == window_id and not is_helper_session(p.get("session_name", ""))]


def overlap(a1: int, a2: int, b1: int, b2: int) -> int:
    return max(0, min(a2, b2) - max(a1, b1))


def adjacent_visible_pane(pane_id: str, direction: str) -> Optional[Dict[str, str]]:
    info = next((p for p in list_all_panes() if p["pane_id"] == pane_id), None)
    if not info:
        return None
    left = int(info["pane_left"] or "0")
    right = int(info["pane_right"] or "0")
    top = int(info["pane_top"] or "0")
    bottom = int(info["pane_bottom"] or "0")
    candidates = []
    for pane in visible_window_panes(info["window_id"]):
        if pane["pane_id"] == pane_id:
            continue
        pl = int(pane["pane_left"] or "0")
        pr = int(pane["pane_right"] or "0")
        pt = int(pane["pane_top"] or "0")
        pb = int(pane["pane_bottom"] or "0")
        score = 0
        if direction == "left" and 0 < left - pr <= 2 and overlap(pt, pb, top, bottom) > 0:
            score = overlap(pt, pb, top, bottom)
        elif direction == "right" and 0 < pl - right <= 2 and overlap(pt, pb, top, bottom) > 0:
            score = overlap(pt, pb, top, bottom)
        elif direction == "up" and 0 < top - pb <= 2 and overlap(pl, pr, left, right) > 0:
            score = overlap(pl, pr, left, right)
        elif direction == "down" and 0 < pt - bottom <= 2 and overlap(pl, pr, left, right) > 0:
            score = overlap(pl, pr, left, right)
        if score > 0:
            candidates.append((score, pane))
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1] if candidates else None


def next_hidden_member(gid: str, current_pane: str, reverse: bool = False) -> Optional[Dict[str, str]]:
    members = group_members(gid)
    if len(members) < 2:
        return None
    ids = [m["pane_id"] for m in members]
    try:
        idx = ids.index(current_pane)
    except ValueError:
        return None
    for off in range(1, len(members)):
        j = (idx - off) % len(members) if reverse else (idx + off) % len(members)
        cand = members[j]
        if is_helper_session(cand["session_name"]):
            return cand
    return None


def switch_to_member(current_pane: str, target_member: Dict[str, str]) -> None:
    gid = pane_option(current_pane, "@stack_gid") or pane_option(target_member["pane_id"], "@stack_gid")
    tmux("swap-pane", "-d", "-s", current_pane, "-t", target_member["pane_id"])
    tmux("select-pane", "-t", target_member["pane_id"])
    if gid:
        refresh_group_titles(gid)


def switch_to(target_pane: str, reverse: bool = False) -> None:
    gid = pane_option(target_pane, "@stack_gid")
    if not gid:
        tmux("display-message", "current pane is not stacked")
        return
    target = next_hidden_member(gid, target_pane, reverse=reverse)
    if not target:
        tmux("display-message", "no other stacked pane")
        return
    switch_to_member(target_pane, target)


def create_new(pane_id: str, pane_path: str, reveal: bool = False) -> None:
    gid = ensure_group_for_visible(pane_id)
    info = pane_fields(pane_id)
    helper = ensure_helper(info["session_name"])
    members = group_members(gid)
    max_ord = max(int(m.get("stack_ord") or "0") for m in members) if members else 0
    new_pane = tmux("split-window", "-d", "-P", "-F", "#{pane_id}", "-t", pane_id, "-c", pane_path or info["pane_current_path"])
    set_pane_option(new_pane, "@stack_gid", gid)
    set_pane_option(new_pane, "@stack_ord", str(max_ord + 1))
    ensure_title(new_pane)
    tmux("join-pane", "-d", "-s", new_pane, "-t", f"{helper}:parking")
    refresh_group_titles(gid)
    if reveal:
        target = next((m for m in group_members(gid) if m["pane_id"] == new_pane), None)
        if target:
            switch_to_member(pane_id, target)
    tmux("display-message", f"stacked pane added ({len(group_members(gid))} total)")


def marked_pane() -> str:
    for pane in list_all_panes():
        if pane.get("pane_marked") == "1":
            return pane["pane_id"]
    return ""


def absorb_into_group(target_pane: str) -> None:
    src = marked_pane()
    if not src:
        tmux("display-message", "mark a pane first")
        return
    absorb_pane(src, target_pane)


def absorb_pane(src: str, target_pane: str) -> None:
    if src == target_pane:
        tmux("display-message", "cannot absorb the current pane")
        return
    src_gid = pane_option(src, "@stack_gid")
    target_gid = ensure_group_for_visible(target_pane)
    if src_gid and src_gid == target_gid:
        tmux("display-message", "pane already belongs to this stack")
        return
    target_info = pane_fields(target_pane)
    helper = ensure_helper(target_info["session_name"])
    members = group_members(target_gid)
    max_ord = max(int(m.get("stack_ord") or "0") for m in members) if members else 0

    if src_gid:
        replacement = next_hidden_member(src_gid, src, reverse=False) or next_hidden_member(src_gid, src, reverse=True)
        if replacement:
            tmux("swap-pane", "-d", "-s", src, "-t", replacement["pane_id"])

    set_pane_option(src, "@stack_gid", target_gid)
    set_pane_option(src, "@stack_ord", str(max_ord + 1))
    ensure_title(src)
    tmux("join-pane", "-d", "-s", src, "-t", f"{helper}:parking")
    refresh_group_titles(target_gid)

    if src_gid:
        cleanup_group(src_gid)
    tmux("select-pane", "-t", target_pane)
    tmux("display-message", "pane absorbed into stack")


def extract_from_group(pane_id: str, direction: str) -> None:
    gid = pane_option(pane_id, "@stack_gid")
    if not gid:
        tmux("display-message", "current pane is not stacked")
        return
    members = group_members(gid)
    if len(members) < 2:
        unset_pane_option(pane_id, "@stack_gid")
        unset_pane_option(pane_id, "@stack_ord")
        clear_group_title(pane_id)
        tmux("display-message", "stack dissolved")
        return
    replacement = next_hidden_member(gid, pane_id, reverse=False) or next_hidden_member(gid, pane_id, reverse=True)
    if not replacement:
        tmux("display-message", "no hidden stacked pane to replace current one")
        return
    tmux("swap-pane", "-d", "-s", pane_id, "-t", replacement["pane_id"])
    tmux("select-pane", "-t", replacement["pane_id"])
    args = ["join-pane", "-s", pane_id, "-t", replacement["pane_id"]]
    if direction in {"left", "right"}:
        args.append("-h")
        if direction == "left":
            args.append("-b")
    elif direction == "up":
        args.append("-b")
    tmux(*args)
    unset_pane_option(pane_id, "@stack_gid")
    unset_pane_option(pane_id, "@stack_ord")
    clear_group_title(pane_id)
    cleanup_group(gid)


def kill_current(pane_id: str) -> None:
    gid = pane_option(pane_id, "@stack_gid")
    if not gid:
        tmux("kill-pane", "-t", pane_id)
        return
    members = group_members(gid)
    if len(members) <= 1:
        tmux("kill-pane", "-t", pane_id)
        return
    replacement = next_hidden_member(gid, pane_id, reverse=False) or next_hidden_member(gid, pane_id, reverse=True)
    if not replacement:
        tmux("display-message", "no replacement pane available")
        return
    tmux("swap-pane", "-d", "-s", pane_id, "-t", replacement["pane_id"])
    tmux("select-pane", "-t", replacement["pane_id"])
    unset_pane_option(pane_id, "@stack_gid")
    unset_pane_option(pane_id, "@stack_ord")
    tmux("kill-pane", "-t", pane_id)
    cleanup_group(gid)


def split_normal(pane_id: str, pane_path: str, direction: str) -> None:
    args = ["split-window", "-P", "-F", "#{pane_id}", "-t", pane_id, "-c", pane_path]
    if direction in {"left", "right"}:
        args.append("-h")
        if direction == "left":
            args.append("-b")
    elif direction == "up":
        args.append("-b")
    tmux(*args)


def smart_split(pane_id: str, pane_path: str, direction: str) -> None:
    if pane_option(pane_id, "@stack_gid"):
        create_new(pane_id, pane_path, reveal=True)
    else:
        split_normal(pane_id, pane_path, direction)


def move_direction(pane_id: str, direction: str) -> None:
    neighbor = adjacent_visible_pane(pane_id, direction)
    current_gid = pane_option(pane_id, "@stack_gid")
    if neighbor and pane_option(neighbor["pane_id"], "@stack_gid"):
        absorb_pane(pane_id, neighbor["pane_id"])
        return
    if current_gid:
        extract_from_group(pane_id, direction)
        return
    if neighbor:
        flags = {"left": "-U", "up": "-U", "right": "-D", "down": "-D"}
        tmux("swap-pane", flags[direction], "-t", pane_id)
        return
    tmux("display-message", f"no pane {direction}")


def toggle_group(pane_id: str) -> None:
    gid = pane_option(pane_id, "@stack_gid")
    if not gid:
        ensure_group_for_visible(pane_id)
        tmux("display-message", "group enabled")
        return
    members = group_members(gid)
    if len(members) > 1:
        tmux("display-message", "cannot disable group with multiple children")
        return
    unset_pane_option(pane_id, "@stack_gid")
    unset_pane_option(pane_id, "@stack_ord")
    clear_group_title(pane_id)
    tmux("display-message", "group disabled")


def sync_style(pane_id: str) -> None:
    gid = pane_option(pane_id, "@stack_gid")
    active = "fg=#73daca" if gid else "fg=#7aa2f7"
    tmux("set-option", "-g", "pane-active-border-style", active)


def rename_pane(pane_id: str, title: str) -> None:
    set_pane_option(pane_id, "@stack_label", title)
    gid = pane_option(pane_id, "@stack_gid")
    if gid:
        refresh_group_titles(gid)
    else:
        set_pane_title(pane_id, title)


cmd = sys.argv[1] if len(sys.argv) > 1 else ""

if cmd == "toggle":
    toggle_group(sys.argv[2])
elif cmd == "style":
    sync_style(sys.argv[2])
elif cmd == "rename":
    rename_pane(sys.argv[2], sys.argv[3])
elif cmd == "new":
    create_new(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "", reveal=len(sys.argv) > 4 and sys.argv[4] == "reveal")
elif cmd == "split":
    smart_split(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "", sys.argv[4])
elif cmd == "move":
    move_direction(sys.argv[2], sys.argv[3])
elif cmd == "next":
    switch_to(sys.argv[2], reverse=False)
elif cmd == "prev":
    switch_to(sys.argv[2], reverse=True)
elif cmd == "absorb":
    absorb_into_group(sys.argv[2])
elif cmd == "absorb-pane":
    absorb_pane(sys.argv[2], sys.argv[3])
elif cmd == "extract":
    extract_from_group(sys.argv[2], sys.argv[3])
elif cmd == "kill":
    kill_current(sys.argv[2])
else:
    raise SystemExit(f"unknown command: {cmd}")
