"""Small, private, thread-safe SQLite history store.

Screen images are transient: history preserves text and tool evidence, not screenshots.
"""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import sqlite3
import threading
import time
import uuid
from typing import Any


class Store:
    def __init__(self, path: str | Path | None = None):
        if path is None:
            root = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
            path = root / "wynxo" / "history.sqlite3"
        self.path = Path(path).expanduser()
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        # Create with private permissions before SQLite opens the file.
        fd = os.open(self.path, os.O_CREAT | os.O_WRONLY, 0o600)
        os.close(fd)
        os.chmod(self.path, 0o600)
        self._lock = threading.RLock()
        self._db = sqlite3.connect(self.path, check_same_thread=False)
        self._db.row_factory = sqlite3.Row
        self._db.execute("PRAGMA foreign_keys = ON")
        self._db.execute("PRAGMA journal_mode = WAL")
        self._db.executescript("""
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                model TEXT NOT NULL DEFAULT '',
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS messages (
                conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
                position INTEGER NOT NULL,
                payload TEXT NOT NULL,
                PRIMARY KEY (conversation_id, position)
            );
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        """)
        self._db.commit()
        columns = {row["name"] for row in self._db.execute("PRAGMA table_info(conversations)")}
        if "pinned" not in columns:
            self._db.execute("ALTER TABLE conversations ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0")
            self._db.commit()

    def create_conversation(self, title: str = "New conversation", model: str = "") -> dict:
        now = time.time()
        item = {"id": uuid.uuid4().hex, "title": title.strip()[:200] or "New conversation",
                "model": model, "created_at": now, "updated_at": now, "pinned": 0}
        with self._lock, self._db:
            self._db.execute("INSERT INTO conversations (id,title,model,created_at,updated_at,pinned) "
                             "VALUES (:id,:title,:model,:created_at,:updated_at,:pinned)", item)
        return item

    def list_conversations(self) -> list[dict]:
        with self._lock:
            return [dict(row) for row in self._db.execute("SELECT * FROM conversations ORDER BY pinned DESC, updated_at DESC, id DESC")]

    def get_conversation(self, conversation_id: str) -> dict | None:
        with self._lock:
            row = self._db.execute("SELECT * FROM conversations WHERE id=?", (conversation_id,)).fetchone()
        return dict(row) if row else None

    def rename_conversation(self, conversation_id: str, title: str) -> None:
        with self._lock, self._db:
            self._db.execute("UPDATE conversations SET title=?,updated_at=? WHERE id=?",
                             (title.strip()[:200] or "New conversation", time.time(), conversation_id))

    def set_pinned(self, conversation_id: str, pinned: bool) -> None:
        with self._lock, self._db:
            self._db.execute("UPDATE conversations SET pinned=?,updated_at=? WHERE id=?",
                             (1 if pinned else 0, time.time(), conversation_id))

    def delete_conversation(self, conversation_id: str) -> None:
        with self._lock, self._db:
            self._db.execute("DELETE FROM conversations WHERE id=?", (conversation_id,))

    def get_messages(self, conversation_id: str) -> list[dict]:
        with self._lock:
            rows = self._db.execute("SELECT payload FROM messages WHERE conversation_id=? ORDER BY position", (conversation_id,))
            return [json.loads(row[0]) for row in rows]

    def set_messages(self, conversation_id: str, messages: list[dict], model: str | None = None) -> None:
        # Never mutate the live conversation; it may still contain images for inference.
        saved = copy.deepcopy([message for message in messages
            if not (message.get("images") and message.get("content", "").startswith("Current desktop screenshot ("))])
        for message in saved:
            message.pop("images", None)
        encoded = [json.dumps(message, ensure_ascii=False, allow_nan=False) for message in saved]
        with self._lock, self._db:
            if self._db.execute("SELECT 1 FROM conversations WHERE id=?", (conversation_id,)).fetchone() is None:
                raise KeyError(f"Unknown conversation: {conversation_id}")
            self._db.execute("DELETE FROM messages WHERE conversation_id=?", (conversation_id,))
            self._db.executemany("INSERT INTO messages VALUES (?,?,?)",
                                 [(conversation_id, i, payload) for i, payload in enumerate(encoded)])
            if model is None:
                self._db.execute("UPDATE conversations SET updated_at=? WHERE id=?", (time.time(), conversation_id))
            else:
                self._db.execute("UPDATE conversations SET updated_at=?,model=? WHERE id=?", (time.time(), model, conversation_id))

    def get_setting(self, key: str, default: Any = None) -> Any:
        with self._lock:
            row = self._db.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return json.loads(row[0]) if row else default

    def set_setting(self, key: str, value: Any) -> None:
        encoded = json.dumps(value, ensure_ascii=False, allow_nan=False)
        with self._lock, self._db:
            self._db.execute("INSERT INTO settings VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", (key, encoded))

    def close(self) -> None:
        with self._lock:
            self._db.close()
