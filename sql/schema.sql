CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE COLLATE NOCASE,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  start_date TEXT NOT NULL,
  recurrence TEXT NOT NULL CHECK (recurrence IN ('once','daily','weekly')),
  weekdays INTEGER NOT NULL DEFAULT 0,
  member_id INTEGER REFERENCES members(id) ON DELETE SET NULL,
  archived_at TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS completions (
  task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  day TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0,1)),
  completed_at TEXT,
  PRIMARY KEY (task_id, day)
);
CREATE TABLE IF NOT EXISTS shopping (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  quantity TEXT NOT NULL DEFAULT '',
  bought INTEGER NOT NULL DEFAULT 0 CHECK (bought IN (0,1)),
  created_at TEXT NOT NULL,
  bought_at TEXT
);
CREATE TABLE IF NOT EXISTS task_moves (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  from_date TEXT NOT NULL,
  to_date TEXT NOT NULL,
  moved_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tasks_start ON tasks(start_date);
CREATE INDEX IF NOT EXISTS idx_completion_day ON completions(day);
CREATE INDEX IF NOT EXISTS idx_shopping_bought ON shopping(bought);
CREATE INDEX IF NOT EXISTS idx_moves_task ON task_moves(task_id);
