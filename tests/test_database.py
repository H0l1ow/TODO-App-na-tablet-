"""Offline integration checks for the shipped SQLite schema and business rules.

These tests require only Python's stdlib; they exercise SQLite directly rather
than the Qt/C++ binary (which must be compiled with Qt on the target platform).
"""
from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
import xml.etree.ElementTree as ET
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = (ROOT / "sql" / "schema.sql").read_text(encoding="utf-8")
TABLES = ("members", "tasks", "completions", "shopping", "task_moves", "settings")


def make_db():
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys=ON")
    db.executescript(SCHEMA)
    return db


def insert_task(db, title, d, recurrence="once", mask=0, member_id=None):
    return db.execute(
        "INSERT INTO tasks(title,start_date,recurrence,weekdays,member_id,created_at) VALUES(?,?,?,?,?,?)",
        (title, d, recurrence, mask, member_id, "2026-10-14T10:00:00"),
    ).lastrowid


def scheduled(db, d):
    day = date.fromisoformat(d)
    bit = 1 << day.weekday()
    return db.execute(
        """SELECT t.id,t.title,COALESCE(c.done,0) AS done
        FROM tasks t LEFT JOIN completions c ON c.task_id=t.id AND c.day=?
        WHERE t.start_date<=? AND (t.archived_at IS NULL OR t.archived_at>?)
          AND ((t.recurrence='once' AND t.start_date=?) OR t.recurrence='daily'
               OR (t.recurrence='weekly' AND (t.weekdays & ?) != 0))
        ORDER BY COALESCE(c.done,0),t.id DESC""",
        (d, d, d, d, bit),
    ).fetchall()


def overdue(db, d):
    return db.execute(
        """SELECT t.id,t.start_date FROM tasks t WHERE t.recurrence='once' AND t.start_date<?
        AND (t.archived_at IS NULL OR t.archived_at>?)
        AND NOT EXISTS (SELECT 1 FROM completions c WHERE c.task_id=t.id
                        AND c.day=t.start_date AND c.done=1)""", (d, d)
    ).fetchall()


def snapshot(db):
    return {table: [dict(row) for row in db.execute(f"SELECT * FROM {table} ORDER BY rowid")]
            for table in TABLES}


class DatabaseTests(unittest.TestCase):
    def setUp(self):
        self.db = make_db()

    def tearDown(self):
        self.db.close()

    def test_schema_can_be_applied_again(self):
        self.db.executescript(SCHEMA)
        self.assertEqual(len(TABLES), 6)

    def test_once_daily_weekly_and_start_boundary(self):
        # 2026-10-14 is Wednesday (day 2 of Monday-first mask).
        self.assertEqual(date(2026, 10, 14).weekday(), 2)
        one = insert_task(self.db, "Jednorazowe", "2026-10-14")
        daily = insert_task(self.db, "Codziennie", "2026-10-14", "daily")
        weekly = insert_task(self.db, "Środy i piątki", "2026-10-14", "weekly", (1 << 2) | (1 << 4))
        self.assertEqual({r["id"] for r in scheduled(self.db, "2026-10-13")}, set())
        self.assertEqual({r["id"] for r in scheduled(self.db, "2026-10-14")}, {one, daily, weekly})
        self.assertEqual({r["id"] for r in scheduled(self.db, "2026-10-15")}, {daily})
        self.assertEqual({r["id"] for r in scheduled(self.db, "2026-10-16")}, {daily, weekly})

    def test_mark_and_unmark_one_occurrence(self):
        task = insert_task(self.db, "Zmywarka", "2026-10-14", "daily")
        self.db.execute("INSERT OR REPLACE INTO completions VALUES(?,?,?,?)", (task, "2026-10-14", 1, "now"))
        self.assertEqual(scheduled(self.db, "2026-10-14")[0]["done"], 1)
        self.assertEqual(scheduled(self.db, "2026-10-15")[0]["done"], 0)
        self.db.execute("INSERT OR REPLACE INTO completions VALUES(?,?,?,?)", (task, "2026-10-14", 0, None))
        self.assertEqual(scheduled(self.db, "2026-10-14")[0]["done"], 0)

    def test_only_pending_one_off_tasks_are_overdue(self):
        pending = insert_task(self.db, "Zaległe", "2026-10-12")
        done = insert_task(self.db, "Wykonane", "2026-10-11")
        insert_task(self.db, "Codziennie", "2026-10-11", "daily")
        self.db.execute("INSERT INTO completions VALUES(?,?,?,?)", (done, "2026-10-11", 1, "now"))
        items = overdue(self.db, "2026-10-14")
        self.assertEqual([r["id"] for r in items], [pending])

    def test_move_overdue_and_preserve_log(self):
        task = insert_task(self.db, "Naprawić zawias", "2026-10-12")
        for row in overdue(self.db, "2026-10-14"):
            self.db.execute("INSERT INTO task_moves (task_id,from_date,to_date,moved_at) VALUES(?,?,?,?)",
                            (row["id"], row["start_date"], "2026-10-14", "now"))
            self.db.execute("UPDATE tasks SET start_date=? WHERE id=?", ("2026-10-14", row["id"]))
        self.assertEqual([r["id"] for r in scheduled(self.db, "2026-10-14")], [task])
        self.assertEqual(len(overdue(self.db, "2026-10-14")), 0)
        move = self.db.execute("SELECT * FROM task_moves").fetchone()
        self.assertEqual((move["from_date"], move["to_date"]), ("2026-10-12", "2026-10-14"))

    def test_archived_task_is_not_scheduled_but_completed_history_remains(self):
        task = insert_task(self.db, "Codzienna praca", "2026-10-12", "daily")
        self.db.execute("INSERT INTO completions VALUES(?,?,?,?)", (task, "2026-10-13", 1, "now"))
        self.db.execute("UPDATE tasks SET archived_at='2026-10-14' WHERE id=?", (task,))
        self.assertEqual(len(scheduled(self.db, "2026-10-14")), 0)
        self.assertEqual(scheduled(self.db, "2026-10-13")[0]["done"], 1)

    def test_remove_member_unassigns_tasks(self):
        member = self.db.execute("INSERT INTO members(name,created_at) VALUES('Ala','now')").lastrowid
        task = insert_task(self.db, "Pranie", "2026-10-14", member_id=member)
        self.db.execute("DELETE FROM members WHERE id=?", (member,))
        self.assertIsNone(self.db.execute("SELECT member_id FROM tasks WHERE id=?", (task,)).fetchone()[0])
        self.assertEqual(len(scheduled(self.db, "2026-10-14")), 1)

    def test_shopping_check_uncheck_and_clear(self):
        self.db.execute("INSERT INTO shopping(name,quantity,created_at) VALUES('Mleko','2 l','now')")
        self.db.execute("INSERT INTO shopping(name,quantity,created_at) VALUES('Banany','1 kg','now')")
        self.db.execute("UPDATE shopping SET bought=1,bought_at='now' WHERE name='Mleko'")
        self.assertEqual(self.db.execute("SELECT count(*) FROM shopping WHERE bought=0").fetchone()[0], 1)
        self.db.execute("UPDATE shopping SET bought=0,bought_at=NULL WHERE name='Mleko'")
        self.assertEqual(self.db.execute("SELECT count(*) FROM shopping WHERE bought=0").fetchone()[0], 2)
        self.db.execute("UPDATE shopping SET bought=1 WHERE name='Mleko'")
        self.db.execute("DELETE FROM shopping WHERE bought=1")
        self.assertEqual([r[0] for r in self.db.execute("SELECT name FROM shopping")], ["Banany"])

    def test_backup_data_can_be_restored_with_foreign_keys(self):
        member = self.db.execute("INSERT INTO members(name,created_at) VALUES('Ola','now')").lastrowid
        task = insert_task(self.db, "Obiad", "2026-10-14", member_id=member)
        self.db.execute("INSERT INTO completions VALUES(?,?,?,?)", (task, "2026-10-14", 1, "now"))
        self.db.execute("INSERT INTO settings VALUES('theme','dark')")
        data = snapshot(self.db)
        decoded = json.loads(json.dumps(data, ensure_ascii=False))
        self.db.execute("DELETE FROM completions")
        self.db.execute("DELETE FROM tasks")
        self.db.execute("DELETE FROM members")
        self.db.execute("DELETE FROM settings")
        for table in TABLES:
            rows = decoded[table]
            for row in rows:
                cols = list(row)
                self.db.execute(f"INSERT INTO {table} ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})", list(row.values()))
        self.assertEqual(snapshot(self.db), data)
        self.assertEqual(self.db.execute("PRAGMA foreign_key_check").fetchall(), [])


class ProjectStructureTests(unittest.TestCase):
    def test_qrc_paths_exist(self):
        path = ROOT / "qml" / "resources.qrc"
        tree = ET.parse(path)
        for file in tree.findall(".//file"):
            self.assertTrue((path.parent / file.text).exists(), file.text)

    def test_qml_brackets_are_balanced(self):
        # Lightweight static check for obvious truncations in Qt source files.
        for path in (ROOT / "qml").rglob("*.qml"):
            source = path.read_text(encoding="utf-8")
            stack = []
            quote = None
            escape = False
            line_comment = False
            block_comment = False
            i = 0
            while i < len(source):
                char = source[i]
                nxt = source[i + 1] if i + 1 < len(source) else ""
                if line_comment:
                    if char == "\n":
                        line_comment = False
                elif block_comment:
                    if char == "*" and nxt == "/":
                        block_comment = False
                        i += 1
                elif quote:
                    if escape:
                        escape = False
                    elif char == "\\":
                        escape = True
                    elif char == quote:
                        quote = None
                elif char == "/" and nxt == "/":
                    line_comment = True
                    i += 1
                elif char == "/" and nxt == "*":
                    block_comment = True
                    i += 1
                elif char in ("'", '"'):
                    quote = char
                elif char in "{[(":
                    stack.append((char, i))
                elif char in "}])":
                    self.assertTrue(stack, str(path))
                    opening, _ = stack.pop()
                    self.assertEqual({"}": "{", "]": "[", ")": "("}[char], opening, str(path))
                i += 1
            self.assertFalse(stack, str(path))

    def test_no_network_dependencies(self):
        cmake = (ROOT / "CMakeLists.txt").read_text(encoding="utf-8")
        self.assertNotIn("Qt5::Network", cmake)
        self.assertNotIn("WebEngine", cmake)
        self.assertNotIn("Firebase", cmake)


if __name__ == "__main__":
    unittest.main(verbosity=2)
