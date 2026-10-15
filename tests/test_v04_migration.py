"""SQL migration and source-level regression tests. Does not replace native Qt x86 testing."""
import sqlite3
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL = (ROOT / "sql" / "schema.sql").read_text(encoding="utf-8")
HEADER = (ROOT / "src" / "Backend.h").read_text(encoding="utf-8")
FEATURES = (ROOT / "src" / "BackendFeatures.cpp").read_text(encoding="utf-8")
BACKEND = (ROOT / "src" / "Backend.cpp").read_text(encoding="utf-8")


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.connection = sqlite3.connect(":memory:")
        self.connection.execute("PRAGMA foreign_keys=ON")

    def tearDown(self):
        self.connection.close()

    def old_data(self):
        """Create enough of a 0.3-era DB to reproduce the legacy CHECK constraint."""
        self.connection.executescript("""
            CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);
            CREATE TABLE members(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL UNIQUE,
                                 created_at TEXT NOT NULL);
            CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,
                 start_date TEXT NOT NULL,recurrence TEXT NOT NULL
                 CHECK(recurrence IN ('once','daily','weekly')),
                 weekdays INTEGER NOT NULL DEFAULT 0, member_id INTEGER REFERENCES members(id) ON DELETE SET NULL,
                 archived_at TEXT, created_at TEXT NOT NULL);
            CREATE TABLE completions(task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
                 day TEXT NOT NULL,done INTEGER NOT NULL DEFAULT 0,completed_at TEXT,
                 PRIMARY KEY(task_id,day));
            CREATE TABLE shopping(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,
                 quantity TEXT NOT NULL DEFAULT '',bought INTEGER NOT NULL DEFAULT 0,
                 created_at TEXT NOT NULL,bought_at TEXT);
            CREATE TABLE task_moves(id INTEGER PRIMARY KEY AUTOINCREMENT,
                 task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
                 from_date TEXT NOT NULL,to_date TEXT NOT NULL,moved_at TEXT NOT NULL);
            INSERT INTO members(name,created_at) VALUES('Osoba A','2026-10-01');
            INSERT INTO tasks(title,start_date,recurrence,weekdays,member_id,created_at)
              VALUES('Stare pranie','2026-10-14','weekly',8,1,'2026-10-01');
            INSERT INTO shopping(name,quantity,bought,created_at) VALUES('Mleko','2',0,'2026-10-01');
            INSERT INTO completions(task_id,day,done,completed_at)
              VALUES(1,'2026-10-14',1,'2026-10-14T12:00:00');
        """)

    def _run_schema_and_migration(self):
        self.connection.executescript(SQL)
        columns = {
            "tasks": [("interval_days", "INTEGER NOT NULL DEFAULT 1"),
                      ("end_date", "TEXT"), ("note", "TEXT NOT NULL DEFAULT ''"),
                      ("category_id", "INTEGER"), ("due_time", "TEXT NOT NULL DEFAULT ''"),
                      ("schedule_kind", "TEXT NOT NULL DEFAULT ''")],
            "completions": [("done_by", "INTEGER")],
            "shopping": [("category", "TEXT NOT NULL DEFAULT 'Inne'")],
            "plan_snapshots": [("member_id", "INTEGER")],
        }
        for table, additions in columns.items():
            present = {r[1] for r in self.connection.execute(f"PRAGMA table_info({table})")}
            for column, definition in additions:
                if column not in present:
                    self.connection.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")

    def test_legacy_data_survives_migration(self):
        self.old_data()
        self._run_schema_and_migration()
        self._run_schema_and_migration()
        self.assertEqual(self.connection.execute("SELECT title,member_id,weekdays FROM tasks").fetchall(),
                         [("Stare pranie", 1, 8)])
        self.assertEqual(self.connection.execute("SELECT name,quantity FROM shopping").fetchall(), [("Mleko", "2")])
        self.assertEqual(self.connection.execute("SELECT done,done_by FROM completions").fetchall(), [(1, None)])
        self.assertEqual(self.connection.execute("PRAGMA foreign_key_check").fetchall(), [])

    def test_new_schedule_works_with_legacy_recurrence_check(self):
        self.old_data()
        self._run_schema_and_migration()
        self.connection.execute("""
            INSERT INTO tasks(title,start_date,recurrence,weekdays,created_at,interval_days,schedule_kind)
            VALUES('Co trzy dni','2026-10-14','daily',0,'2026-10-14',3,'interval')
        """)
        self.connection.execute("""
            INSERT INTO tasks(title,start_date,recurrence,weekdays,created_at,schedule_kind)
            VALUES('Co miesiąc','2026-10-15','daily',0,'2026-10-15','monthly')
        """)
        actual = self.connection.execute("""
            SELECT title,CASE WHEN schedule_kind<>'' THEN schedule_kind ELSE recurrence END
            FROM tasks ORDER BY id
        """).fetchall()
        self.assertEqual(actual, [("Stare pranie", "weekly"), ("Co trzy dni", "interval"), ("Co miesiąc", "monthly")])

    def test_new_schema_contains_all_local_features(self):
        self._run_schema_and_migration()
        tables = {r[0] for r in self.connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        required = {"categories", "quick_tasks", "day_templates", "day_template_items",
                    "shopping_catalog", "shopping_sets", "shopping_set_items", "task_skips",
                    "plan_snapshots", "shopping_history", "subtasks", "subtask_checks", "notes"}
        self.assertTrue(required.issubset(tables), required - tables)
        self.assertEqual(self.connection.execute("PRAGMA foreign_key_check").fetchall(), [])

    def test_new_monthly_and_interval_are_marked_by_compatibility_column(self):
        self.assertIn("recurrence == \"interval\" || recurrence == \"monthly\"", FEATURES)
        self.assertIn('QStringLiteral("daily") : recurrence', FEATURES)
        self.assertIn('schedule_kind', BACKEND)

    def test_backend_exposes_live_lists_as_properties(self):
        self.assertIn("Q_PROPERTY(QVariantList categories READ categories NOTIFY dataChanged)", HEADER)
        self.assertIn("Q_PROPERTY(QVariantList dayTemplates READ dayTemplates NOTIFY dataChanged)", HEADER)

    def test_new_qml_dialogs_and_sources_packaged(self):
        qml = ROOT / "qml"
        for component in ("TaskEditor", "TaskActions", "QuickTaskPopup", "DayTemplatesDialog", "SubtasksDialog"):
            self.assertTrue((qml / "components" / (component + ".qml")).exists())
        for page in ("TodayPage", "WeekPage", "ShoppingPage", "QuickTemplatesPage", "HistoryPage", "SettingsPage"):
            self.assertTrue((qml / "pages" / (page + ".qml")).exists())
        self.assertIn("src/BackendFeatures.cpp", (ROOT / "CMakeLists.txt").read_text())
        self.assertTrue((ROOT / "qml" / "resources.qrc").exists())

    def test_offline_without_automated_backup(self):
        self.assertNotIn("QtNetwork", (ROOT / "CMakeLists.txt").read_text())
        self.assertNotIn("backupNow();", BACKEND.split("connect(&m_clock", 1)[1].split("m_clock.start();", 1)[0])
        self.assertIn('Backend::backupNow()', BACKEND)
        self.assertIn('"version", 2', BACKEND)
        self.assertIn('backupVersion != 1 && backupVersion != 2', BACKEND)

    def test_day_and_shopping_copy_are_deduplicated(self):
        self.assertIn("Backend::copyDayToDate", FEATURES)
        self.assertIn("Backend::copyTaskForDays", FEATURES)
        self.assertIn("Backend::applyShoppingSet", FEATURES)
        self.assertIn("Backend::applyDayTemplate", FEATURES)
        self.assertIn("CopyResult::AlreadyPresent", FEATURES)


if __name__ == "__main__":
    unittest.main()
