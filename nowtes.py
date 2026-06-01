#!/usr/bin/env python3
"""Nowtes - A simple todo app for Hyprland/omarchy"""

import json
from datetime import datetime
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.widgets import Footer, Header, Input, Label, ListItem, ListView, Static

DATA_DIR = Path.home() / ".local" / "share" / "nowtes"
DATA_FILE = DATA_DIR / "todos.json"


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


class TodoItem(ListItem):
    def __init__(self, todo: dict) -> None:
        super().__init__()
        self.todo = todo
        if todo["done"]:
            self.add_class("done")

    def compose(self) -> ComposeResult:
        icon = "✓" if self.todo["done"] else "○"
        yield Label(f" {icon}  {self.todo['created_at']}  {self.todo['text']}")


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
        margin: 0 2 1 2;
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
        Binding("q", "quit", "Quit", show=True),
        Binding("escape", "cancel", "Cancel", show=False),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.todos = load_todos()

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        yield ListView(id="list")
        yield Input(
            placeholder="New todo… Enter to save, Esc to cancel",
            id="input",
        )
        yield Static("n:New  d:Delete  Space:Toggle done  q:Quit", id="hint")
        yield Footer()

    def on_mount(self) -> None:
        self._refresh()
        self.query_one(ListView).focus()

    def _refresh(self, keep_index: int | None = None) -> None:
        lv = self.query_one(ListView)
        lv.clear()
        for todo in self.todos:
            lv.append(TodoItem(todo))
        if keep_index is not None and self.todos:
            lv.index = min(keep_index, len(self.todos) - 1)

    def action_new(self) -> None:
        inp = self.query_one(Input)
        inp.add_class("input-visible")
        inp.focus()

    def action_cancel(self) -> None:
        inp = self.query_one(Input)
        if "input-visible" in inp.classes:
            inp.value = ""
            inp.remove_class("input-visible")
            self.query_one(ListView).focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        text = event.value.strip()
        if text:
            self.todos.append({
                "text": text,
                "done": False,
                "created_at": datetime.now().strftime("%Y-%m-%d %H:%M"),
            })
            save_todos(self.todos)
            self._refresh(keep_index=len(self.todos) - 1)
        self.action_cancel()

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
