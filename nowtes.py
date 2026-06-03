#!/usr/bin/env python3
"""Nowtes - A simple todo app for Hyprland/omarchy"""

import json
import re
import subprocess
import webbrowser
from datetime import datetime
from pathlib import Path

from rich.style import Style
from rich.text import Text
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container
from textual.screen import ModalScreen
from textual.widgets import Footer, Header, Input, Label, ListItem, ListView, Static

DATA_DIR = Path.home() / ".local" / "share" / "nowtes"
DATA_FILE = DATA_DIR / "todos.json"

LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


def render_note(text: str) -> Text:
    """Parse [name](url) markdown links into Rich Text with OSC 8 hyperlinks."""
    result = Text()
    last_end = 0
    for m in LINK_RE.finditer(text):
        if m.start() > last_end:
            result.append(text[last_end:m.start()])
        result.append(m.group(1), style=Style(link=m.group(2), underline=True))
        last_end = m.end()
    if last_end < len(text):
        result.append(text[last_end:])
    return result

_SOUND_FILES = [
    "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga",
    "/usr/share/sounds/freedesktop/stereo/bell.oga",
    "/usr/share/sounds/freedesktop/stereo/complete.oga",
]
_SOUND_PLAYERS = ["paplay", "pw-play", "aplay"]


def load_todos() -> list:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if DATA_FILE.exists():
        try:
            return json.loads(DATA_FILE.read_text())
        except (json.JSONDecodeError, OSError):
            return []
    return []


def save_todos(todos: list) -> None:
    DATA_FILE.write_text(json.dumps(todos, indent=2))


def parse_remind_at(text: str) -> str | None:
    text = text.strip()
    if not text:
        return None
    for fmt in ("%H:%M", "%Y-%m-%d %H:%M"):
        try:
            dt = datetime.strptime(text, fmt)
            if fmt == "%H:%M":
                today = datetime.now().date()
                dt = dt.replace(year=today.year, month=today.month, day=today.day)
            return dt.strftime("%Y-%m-%d %H:%M")
        except ValueError:
            continue
    return None


def play_sound() -> None:
    for sound in _SOUND_FILES:
        if Path(sound).exists():
            for player in _SOUND_PLAYERS:
                try:
                    subprocess.Popen(
                        [player, sound],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    return
                except FileNotFoundError:
                    continue
    print("\a", end="", flush=True)


def send_notification(text: str) -> None:
    try:
        subprocess.Popen(
            ["notify-send", "-u", "critical", "-t", "0", "Nowtes Reminder", text],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        pass


class AlarmScreen(ModalScreen):
    BINDINGS = [
        Binding("escape", "dismiss_alarm", show=False),
        Binding("enter", "dismiss_alarm", show=False),
        Binding("space", "dismiss_alarm", show=False),
    ]

    CSS = """
    AlarmScreen {
        align: center middle;
    }

    #alarm-box {
        width: 64;
        height: 11;
        border: heavy $error;
        background: $error 25%;
        padding: 1 4;
        align: center middle;
    }

    #alarm-box.flash {
        background: $error 60%;
        border: heavy $warning;
    }

    #alarm-title {
        text-align: center;
        text-style: bold;
        color: $error;
        width: 1fr;
        margin-bottom: 1;
    }

    #alarm-box.flash #alarm-title {
        color: $warning;
    }

    #alarm-text {
        text-align: center;
        color: $text;
        width: 1fr;
        margin-bottom: 1;
    }

    #alarm-dismiss {
        text-align: center;
        color: $text-muted;
        width: 1fr;
    }
    """

    def __init__(self, text: str) -> None:
        super().__init__()
        self.todo_text = text

    def compose(self) -> ComposeResult:
        with Container(id="alarm-box"):
            yield Label("! REMINDER !", id="alarm-title")
            yield Label(self.todo_text, id="alarm-text")
            yield Label("Enter / Space / Esc to dismiss", id="alarm-dismiss")

    def on_mount(self) -> None:
        self.set_interval(0.5, self._toggle_flash)

    def _toggle_flash(self) -> None:
        self.query_one("#alarm-box").toggle_class("flash")

    def action_dismiss_alarm(self) -> None:
        self.dismiss()


class TodoItem(ListItem):
    def __init__(self, todo: dict) -> None:
        super().__init__()
        self.todo = todo
        if todo["done"]:
            self.add_class("done")

    def compose(self) -> ComposeResult:
        icon = "✓" if self.todo["done"] else "○"
        remind_at = self.todo.get("remind_at")
        remind = f"  @{remind_at[11:16]}" if remind_at else ""
        label = Text(f" {icon}  {self.todo['created_at']}{remind}  ")
        label.append_text(render_note(self.todo["text"]))
        yield Label(label)


class NowApp(App):
    TITLE = "Nowtes"
    CSS = """
    Screen {
        background: $surface;
    }

    ListView {
        height: 1fr;
        margin: 1 2;
        border: round $primary;
    }

    ListItem {
        padding: 0 1;
    }

    ListItem.done Label {
        color: $success;
    }

    ListItem.--highlight {
        background: $accent 20%;
    }

    ListItem.done.--highlight Label {
        color: $success;
    }

    Input {
        margin: 0 2 0 2;
        display: none;
    }

    Input.input-visible {
        display: block;
    }

    #hint {
        text-align: center;
        color: $text-muted;
        padding: 0 0 1 0;
    }
    """

    BINDINGS = [
        Binding("n", "new", "New", show=True),
        Binding("d", "delete", "Delete", show=True),
        Binding("space", "toggle", "Toggle Done", show=True),
        Binding("o", "open_links", "Open Link", show=True),
        Binding("c", "copy_note", "Copy", show=True),
        Binding("q", "quit", "Quit", show=True),
        Binding("escape", "cancel", "Cancel", show=False),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.todos = load_todos()
        self._pending_text = ""
        self._input_step = 0  # 0=idle, 1=entering text, 2=entering remind time

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        yield ListView(id="list")
        yield Input(
            placeholder="New todo… Enter to continue, Esc to cancel",
            id="input-text",
        )
        yield Input(
            placeholder="Remind at: HH:MM or YYYY-MM-DD HH:MM  (empty to skip)",
            id="input-remind",
        )
        yield Static("n:New  d:Delete  Space:Toggle  o:Open link  c:Copy  q:Quit", id="hint")
        yield Footer()

    def on_mount(self) -> None:
        self._refresh()
        self.query_one(ListView).focus()
        self.set_interval(30, self._check_reminders)
        self.call_after_refresh(self._check_reminders)

    def _refresh(self, keep_index: int | None = None) -> None:
        lv = self.query_one(ListView)
        lv.clear()
        for todo in self.todos:
            lv.append(TodoItem(todo))
        if keep_index is not None and self.todos:
            lv.index = min(keep_index, len(self.todos) - 1)

    def _check_reminders(self) -> None:
        now = datetime.now().strftime("%Y-%m-%d %H:%M")
        changed = False
        for todo in self.todos:
            if (
                todo.get("remind_at")
                and not todo.get("done")
                and not todo.get("fired")
                and todo["remind_at"] <= now
            ):
                todo["fired"] = True
                changed = True
                self._trigger_alarm(todo["text"])
        if changed:
            save_todos(self.todos)
            self._refresh()

    def _trigger_alarm(self, text: str) -> None:
        play_sound()
        send_notification(text)
        self.push_screen(AlarmScreen(text))

    def action_new(self) -> None:
        self.action_cancel()
        self._input_step = 1
        inp = self.query_one("#input-text", Input)
        inp.add_class("input-visible")
        inp.focus()

    def action_cancel(self) -> None:
        self._input_step = 0
        self._pending_text = ""
        for inp_id in ("#input-text", "#input-remind"):
            inp = self.query_one(inp_id, Input)
            inp.value = ""
            inp.remove_class("input-visible")
        self.query_one(ListView).focus()

    def on_key(self, event) -> None:
        if event.key == "ctrl+v" and self._input_step > 0:
            inp_id = "#input-text" if self._input_step == 1 else "#input-remind"
            inp = self.query_one(inp_id, Input)
            try:
                result = subprocess.run(
                    ["wl-paste", "--no-newline"],
                    capture_output=True,
                    text=True,
                    timeout=2,
                )
                if result.returncode == 0 and result.stdout:
                    pos = inp.cursor_position
                    inp.value = inp.value[:pos] + result.stdout + inp.value[pos:]
                    inp.cursor_position = pos + len(result.stdout)
            except (FileNotFoundError, subprocess.TimeoutExpired):
                pass

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if self._input_step == 1:
            text = event.value.strip()
            if not text:
                self.action_cancel()
                return
            self._pending_text = text
            self._input_step = 2
            self.query_one("#input-text", Input).remove_class("input-visible")
            inp_remind = self.query_one("#input-remind", Input)
            inp_remind.add_class("input-visible")
            inp_remind.focus()
        elif self._input_step == 2:
            remind_at = parse_remind_at(event.value)
            self.todos.append({
                "text": self._pending_text,
                "done": False,
                "created_at": datetime.now().strftime("%Y-%m-%d %H:%M"),
                "remind_at": remind_at,
            })
            save_todos(self.todos)
            self._refresh(keep_index=len(self.todos) - 1)
            self.action_cancel()

    def action_open_links(self) -> None:
        lv = self.query_one(ListView)
        idx = lv.index
        if idx is not None and 0 <= idx < len(self.todos):
            for _, url in LINK_RE.findall(self.todos[idx]["text"]):
                webbrowser.open_new_tab(url)

    def action_copy_note(self) -> None:
        lv = self.query_one(ListView)
        idx = lv.index
        if idx is not None and 0 <= idx < len(self.todos):
            text = self.todos[idx]["text"]
            try:
                subprocess.run(
                    ["wl-copy"],
                    input=text.encode(),
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            except FileNotFoundError:
                pass

    def action_delete(self) -> None:
        lv = self.query_one(ListView)
        idx = lv.index
        if idx is not None and 0 <= idx < len(self.todos):
            self.todos.pop(idx)
            save_todos(self.todos)
            self._refresh(keep_index=idx)

    def action_toggle(self) -> None:
        lv = self.query_one(ListView)
        idx = lv.index
        if idx is not None and 0 <= idx < len(self.todos):
            self.todos[idx]["done"] = not self.todos[idx]["done"]
            save_todos(self.todos)
            self._refresh(keep_index=idx)


if __name__ == "__main__":
    NowApp().run()
