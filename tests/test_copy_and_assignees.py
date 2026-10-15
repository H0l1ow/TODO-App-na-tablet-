"""SQLite integration tests for task copying and assignments.

These use the same SQL conditions as the C++ backend but cannot run its Qt
code: native Qt/Win32 execution is part of the Windows validation checklist.
"""
from __future__ import annotations

import sqlite3
import unittest
from datetime import date, timedelta
from pathlib import Path

SCHEMA = (Path(__file__).resolve().parents[1] / "sql" / "schema.sql").read_text(encoding="utf-8")


def create_db():
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys=ON")
    db.executescript(SCHEMA)
    return db


def member(db, name):
    return db.execute("INSERT INTO members (name,created_at) VALUES (?,?)", (name, "now")).lastrowid


def add_task(db, title, day="2026-10-14", recurrence="once", mask=0, member_id=None):
    return db.execute(
        "INSERT INTO tasks(title,start_date,recurrence,weekdays,member_id,created_at) VALUES(?,?,?,?,?,?)",
        (title, day, recurrence, mask, member_id, "now"),
    ).lastrowid


def day_rows(db, day):
    bit = 1 << date.fromisoformat(day).weekday()
    return db.execute(
        """SELECT t.id,t.title,COALESCE(t.member_id,-1) memberId,COALESCE(c.done,0) done
        FROM tasks t LEFT JOIN completions c ON c.task_id=t.id AND c.day=?
        WHERE t.start_date<=? AND (t.archived_at IS NULL OR t.archived_at>?)
        AND ((t.recurrence='once' AND t.start_date=?) OR t.recurrence='daily'
        OR (t.recurrence='weekly' AND (t.weekdays & ?) != 0))""",
        (day, day, day, day, bit),
    ).fetchall()


def copy_one(db, row, next_day):
    """Mirror the exact SQLite duplicate selector in Backend::copyOccurrence."""
    bit = 1 << date.fromisoformat(next_day).weekday()
    exists = db.execute(
        """SELECT 1 FROM tasks t WHERE t.title = ? COLLATE NOCASE
        AND COALESCE(t.member_id,-1)=? AND t.start_date<=?
        AND (t.archived_at IS NULL OR t.archived_at>?)
        AND ((t.recurrence='once' AND t.start_date=?) OR t.recurrence='daily'
        OR (t.recurrence='weekly' AND (t.weekdays & ?) != 0)) LIMIT 1""",
        (row["title"], row["memberId"], next_day, next_day, next_day, bit),
    ).fetchone()
    if exists:
        return False
    db.execute(
        "INSERT INTO tasks (title,start_date,recurrence,weekdays,member_id,created_at) "
        "VALUES (?,?,'once',0,?,?)",
        (row["title"], next_day, row["memberId"] if row["memberId"] > 0 else None, "now"),
    )
    return True


def copy_day(db, day, include_completed):
    to = (date.fromisoformat(day) + timedelta(days=1)).isoformat()
    copied = skipped = done = 0
    for row in day_rows(db, day):
        if row["done"] and not include_completed:
            done += 1
        elif copy_one(db, row, to):
            copied += 1
        else:
            skipped += 1
    return copied, skipped, done


class CopyAndAssigneeTests(unittest.TestCase):
    def setUp(self):
        self.db = create_db()

    def tearDown(self):
        self.db.close()

    def test_everyone_and_two_people_are_distinct(self):
        ala, ola = member(self.db, "Ala"), member(self.db, "Ola")
        shared = add_task(self.db, "Wynieść śmieci")
        personal = add_task(self.db, "Pranie", member_id=ala)
        people = self.db.execute("SELECT id,name FROM members ORDER BY id").fetchall()
        self.assertEqual([p["name"] for p in people], ["Ala", "Ola"])
        # Assignment can be changed after task creation and set back to shared.
        self.db.execute("UPDATE tasks SET member_id=? WHERE id=?", (ola, personal))
        self.assertEqual(self.db.execute("SELECT member_id FROM tasks WHERE id=?", (personal,)).fetchone()[0], ola)
        self.db.execute("UPDATE tasks SET member_id=NULL WHERE id=?", (personal,))
        self.assertEqual({r["memberId"] for r in day_rows(self.db, "2026-10-14")}, {-1})
        self.assertIsNone(self.db.execute("SELECT member_id FROM tasks WHERE id=?", (shared,)).fetchone()[0])

    def test_copy_a_pending_task_unchecked_and_keep_original(self):
        a = member(self.db, "Ala")
        task = add_task(self.db, "Wstawić pranie", member_id=a)
        original = next(r for r in day_rows(self.db, "2026-10-14") if r["id"] == task)
        self.assertTrue(copy_one(self.db, original, "2026-10-15"))
        tomorrow = day_rows(self.db, "2026-10-15")
        self.assertEqual(len(tomorrow), 1)
        self.assertEqual(tomorrow[0]["memberId"], a)
        self.assertEqual(tomorrow[0]["done"], 0)
        self.assertEqual(len(day_rows(self.db, "2026-10-14")), 1)

    def test_copy_repeating_daily_skips_if_tomorrow_is_scheduled(self):
        add_task(self.db, "Zmywarka", recurrence="daily")
        self.assertEqual(copy_day(self.db, "2026-10-14", True), (0, 1, 0))
        self.assertEqual(len(day_rows(self.db, "2026-10-15")), 1)

    def test_weekly_not_scheduled_tomorrow_can_be_copied_once(self):
        # 2026-10-14 is a Wednesday, tomorrow is a Thursday.
        add_task(self.db, "Wymienić ręczniki", recurrence="weekly", mask=1 << 2)
        self.assertEqual(copy_day(self.db, "2026-10-14", True), (1, 0, 0))
        self.assertEqual(day_rows(self.db, "2026-10-15")[0]["title"], "Wymienić ręczniki")
        self.assertEqual(copy_day(self.db, "2026-10-14", True), (0, 1, 0))

    def test_copy_only_unfinished_or_whole_day(self):
        undone = add_task(self.db, "Pranie")
        done = add_task(self.db, "Posprzątać kuchnię")
        add_task(self.db, "Umyć zmywarkę", recurrence="daily")
        self.db.execute("INSERT INTO completions VALUES (?,?,?,?)", (done, "2026-10-14", 1, "now"))
        self.assertEqual(copy_day(self.db, "2026-10-14", False), (1, 1, 1))
        # Copying all afterwards adds only the previously finished task.
        self.assertEqual(copy_day(self.db, "2026-10-14", True), (1, 2, 0))
        self.assertEqual({r["title"] for r in day_rows(self.db, "2026-10-15")},
                         {"Pranie", "Posprzątać kuchnię", "Umyć zmywarkę"})
        self.assertEqual(copy_day(self.db, "2026-10-14", True), (0, 3, 0))

    def test_same_task_title_for_different_people_not_blocked(self):
        a, b = member(self.db, "Ala"), member(self.db, "Ola")
        add_task(self.db, "Wstawić pranie", member_id=a)
        add_task(self.db, "Wstawić pranie", member_id=b)
        self.assertEqual(copy_day(self.db, "2026-10-14", True), (2, 0, 0))
        self.assertEqual(len(day_rows(self.db, "2026-10-15")), 2)

    def test_existing_destination_task_is_not_duplicated(self):
        add_task(self.db, "Wynieść śmieci")
        add_task(self.db, "Wynieść śmieci", day="2026-10-15")
        self.assertEqual(copy_day(self.db, "2026-10-14", True), (0, 1, 0))
        self.assertEqual(len(day_rows(self.db, "2026-10-15")), 1)

    def test_completed_task_still_copies_as_undone_when_requested(self):
        tid = add_task(self.db, "Zamówić paczkę")
        self.db.execute("INSERT INTO completions VALUES (?,?,?,?)", (tid, "2026-10-14", 1, "now"))
        self.assertEqual(copy_day(self.db, "2026-10-14", True), (1, 0, 0))
        self.assertEqual(day_rows(self.db, "2026-10-15")[0]["done"], 0)

    def test_new_ui_components_integrated(self):
        qml = Path(__file__).resolve().parents[1] / "qml"
        for filename in ("QuickTaskPopup.qml", "AssignmentDialog.qml", "CopyDayDialog.qml",
                         "TaskEditor.qml", "TaskActions.qml", "DayTemplatesDialog.qml"):
            self.assertTrue((qml / "components" / filename).is_file())
        today = (qml / "pages" / "TodayPage.qml").read_text(encoding="utf-8")
        for expected in ("QuickTaskPopup", "AssignmentDialog", "CopyDayDialog", "backend.assignees"):
            self.assertIn(expected, today)
        week = (qml / "pages" / "WeekPage.qml").read_text(encoding="utf-8")
        for expected in ("QuickTaskPopup", "CopyDayDialog", "TaskEditor", "DayTemplatesDialog"):
            self.assertIn(expected, week)
        backend = (Path(__file__).resolve().parents[1] / "src" / "Backend.cpp").read_text(encoding="utf-8")
        for function in ("Backend::setTaskAssignee", "Backend::copyOccurrence", "Backend::copyDayToNextDay"):
            self.assertIn(function, backend)
        features = (Path(__file__).resolve().parents[1] / "src" / "BackendFeatures.cpp").read_text(encoding="utf-8")
        for method in ("Backend::editTask", "Backend::copyDayToDate", "Backend::quickTemplates"):
            self.assertIn(method, features)


if __name__ == "__main__":
    unittest.main()
