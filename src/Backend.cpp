#include "Backend.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QSaveFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QStandardPaths>
#include <QProcess>
#include <QTime>
#include <QDebug>
#include <QSqlField>
#include <QSet>
#include <QTextStream>

namespace {
const QLocale polish(QLocale::Polish, QLocale::Poland);
const QString isoDateFormat = QStringLiteral("yyyy-MM-dd");

struct BackupTable {
    QString name;
    QStringList columns;
};

QList<BackupTable> legacyBackupTables() {
    return {
        {"members", {"id", "name", "created_at"}},
        {"tasks", {"id", "title", "start_date", "recurrence", "weekdays", "member_id", "archived_at", "created_at"}},
        {"completions", {"task_id", "day", "done", "completed_at"}},
        {"shopping", {"id", "name", "quantity", "bought", "created_at", "bought_at"}},
        {"task_moves", {"id", "task_id", "from_date", "to_date", "moved_at"}},
        {"settings", {"key", "value"}}
    };
}
QList<BackupTable> backupTables() {
    return {
        {"members", {"id", "name", "created_at"}},
        {"categories", {"id", "name", "symbol", "position"}},
        {"tasks", {"id", "title", "start_date", "recurrence", "weekdays", "member_id", "archived_at", "created_at", "interval_days", "end_date", "note", "category_id", "due_time", "schedule_kind"}},
        {"quick_tasks", {"id", "category_id", "title", "member_id", "favorite", "uses", "last_used", "position"}},
        {"completions", {"task_id", "day", "done", "completed_at", "done_by"}},
        {"shopping", {"id", "name", "quantity", "bought", "created_at", "bought_at", "category"}},
        {"shopping_catalog", {"id", "name", "category", "quantity", "favorite", "uses", "last_used"}},
        {"task_moves", {"id", "task_id", "from_date", "to_date", "moved_at"}},
        {"task_skips", {"task_id", "day", "skipped_at"}},
        {"plan_snapshots", {"task_id", "day", "title", "member_name", "member_id", "captured_at"}},
        {"shopping_history", {"id", "name", "quantity", "category", "bought_at"}},
        {"subtasks", {"id", "task_id", "title", "position"}},
        {"subtask_checks", {"subtask_id", "day", "done"}},
        {"day_templates", {"id", "name", "created_at"}},
        {"day_template_items", {"id", "template_id", "title", "member_id", "position"}},
        {"shopping_sets", {"id", "name", "created_at"}},
        {"shopping_set_items", {"id", "set_id", "name", "quantity", "category"}},
        {"notes", {"id", "text", "created_at"}},
        {"settings", {"key", "value"}}
    };
}

QString normalized(const QString &s) { return s.simplified(); }
} // namespace

Backend::Backend(const QString &dataDirectory, QObject *parent)
    : QObject(parent), m_lastDate(QDate::currentDate()) {
    const QString dir = dataDirectory.isEmpty()
        ? QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
        : QFileInfo(dataDirectory).absoluteFilePath();
    if (!QDir().mkpath(dir)) {
        reportError(QStringLiteral("Nie można utworzyć folderu: ") + dir);
        return;
    }
    m_dbPath = QDir(dir).filePath(QStringLiteral("domowy_plan.sqlite"));
    if (!openDatabase() || !initializeSchema()) return;
    m_ready = true;
    seedDefaults();
    snapshotToday();
    m_lastDark = darkMode();

    m_clock.setInterval(30000);
    connect(&m_clock, &QTimer::timeout, this, [this]() {
        const QDate now = QDate::currentDate();
        if (now != m_lastDate) {
            m_lastDate = now;
            snapshotToday();
            emit dataChanged();
        }
        const bool nowDark = darkMode();
        if (nowDark != m_lastDark) {
            m_lastDark = nowDark;
            emit appearanceChanged();
        }
    });
    m_clock.start();
}

Backend::~Backend() {
    m_clock.stop();
    const QString connection = m_db.connectionName();
    if (m_db.isValid()) m_db.close();
    m_db = QSqlDatabase();
    if (!connection.isEmpty()) QSqlDatabase::removeDatabase(connection);
}

void Backend::reportError(const QString &message) const {
    qWarning().noquote() << "DomowyPlan:" << message;
    m_error = message;
    emit const_cast<Backend *>(this)->errorChanged();
}

void Backend::changed() {
    if (!m_error.isEmpty()) {
        m_error.clear();
        emit errorChanged();
    }
    if (m_ready) snapshotToday();
    emit dataChanged();
}

bool Backend::runSql(const QString &statement) {
    QSqlQuery query(m_db);
    if (!query.exec(statement)) {
        reportError(query.lastError().text() + QStringLiteral(" [") + statement + QStringLiteral("]"));
        return false;
    }
    return true;
}

bool Backend::openDatabase() {
    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("domowyplan"));
    m_db.setDatabaseName(m_dbPath);
    if (!m_db.open()) {
        reportError(m_db.lastError().text());
        return false;
    }
    return runSql(QStringLiteral("PRAGMA foreign_keys = ON"))
        && runSql(QStringLiteral("PRAGMA journal_mode = WAL"))
        && runSql(QStringLiteral("PRAGMA busy_timeout = 3000"));
}

bool Backend::initializeSchema() {
    QFile schemaFile(QStringLiteral(":/sql/schema.sql"));
    if (!schemaFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        reportError(QStringLiteral("Brak zasobu schema.sql w aplikacji."));
        return false;
    }
    const QStringList statements = QString::fromUtf8(schemaFile.readAll()).split(';', Qt::SkipEmptyParts);
    for (const QString &statement : statements) {
        if (!statement.trimmed().isEmpty() && !runSql(statement.trimmed())) return false;
    }

    // SQLite cannot ADD COLUMN IF NOT EXISTS. Detect every v0.4 column
    // instead of recreating tables (existing rows and IDs must survive).
    const struct { const char *table; const char *name; const char *definition; } additions[] = {
        {"tasks", "interval_days", "INTEGER NOT NULL DEFAULT 1"},
        {"tasks", "end_date", "TEXT"},
        {"tasks", "note", "TEXT NOT NULL DEFAULT ''"},
        {"tasks", "category_id", "INTEGER"},
        {"tasks", "due_time", "TEXT NOT NULL DEFAULT ''"},
        {"tasks", "schedule_kind", "TEXT NOT NULL DEFAULT ''"},
        {"completions", "done_by", "INTEGER"},
        {"shopping", "category", "TEXT NOT NULL DEFAULT 'Inne'"},
        {"plan_snapshots", "member_id", "INTEGER"}
    };
    for (const auto &addition : additions) {
        if (!ensureColumn(QLatin1String(addition.table), QLatin1String(addition.name), QLatin1String(addition.definition))) return false;
    }
    if (!runSql(QStringLiteral("PRAGMA user_version=4"))) return false;
    QSqlQuery active(m_db);
    if (active.exec(QStringLiteral("SELECT value FROM settings WHERE key='active_member'")) && active.next())
        m_activeMemberId = active.value(0).toInt();
    QSqlQuery scale(m_db);
    if (scale.exec(QStringLiteral("SELECT value FROM settings WHERE key='font_scale'")) && scale.next())
        m_fontScale = qBound(85, scale.value(0).toInt(), 135);
    QSqlQuery settings(m_db);
    if (settings.exec(QStringLiteral("SELECT value FROM settings WHERE key='theme'")) && settings.next()) {
        const QString value = settings.value(0).toString();
        if (value == "light" || value == "dark" || value == "auto") m_themeMode = value;
    }
    return true;
}

QDate Backend::parsedDate(const QString &value) {
    return QDate::fromString(value, isoDateFormat);
}
QString Backend::isoNow() { return QDateTime::currentDateTime().toString(Qt::ISODateWithMs); }
QString Backend::today() const { return QDate::currentDate().toString(isoDateFormat); }
QString Backend::todayLabel() const { return polish.toString(QDate::currentDate(), "dddd, d MMMM yyyy"); }
QString Backend::dateLabel(const QString &date) const {
    const QDate d = parsedDate(date);
    return d.isValid() ? polish.toString(d, "dddd, d MMMM yyyy") : QString();
}
QString Backend::dateOffset(const QString &date, int offset) const {
    const QDate d = parsedDate(date);
    return d.isValid() && offset >= -3660 && offset <= 3660
        ? d.addDays(offset).toString(isoDateFormat) : QString();
}
int Backend::weekdayBit(const QString &date) const {
    const QDate d = parsedDate(date);
    return d.isValid() ? (1 << (d.dayOfWeek() - 1)) : 0;
}

bool Backend::scheduleMatches(const QString &recurrence, const QDate &start,
                              int weekdayMask, const QDate &on,
                              int intervalDays, const QDate &endDate) {
    if (!start.isValid() || !on.isValid() || on < start || (endDate.isValid() && on > endDate)) return false;
    if (recurrence == QLatin1String("once")) return on == start;
    if (recurrence == QLatin1String("daily")) return true;
    if (recurrence == QLatin1String("weekly")) return (weekdayMask & (1 << (on.dayOfWeek() - 1))) != 0;
    if (recurrence == QLatin1String("interval"))
        return intervalDays > 0 && (start.daysTo(on) % intervalDays) == 0;
    if (recurrence == QLatin1String("monthly"))
        return on.day() == qMin(start.day(), on.daysInMonth());
    return false;
}

QVariantList Backend::tasksOn(const QDate &date) const {
    QVariantList rows;
    if (!m_ready || !date.isValid()) return rows;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT t.id,t.title,t.start_date,CASE WHEN t.schedule_kind<>'' THEN t.schedule_kind ELSE t.recurrence END,t.weekdays,"
        "COALESCE(t.member_id,-1),COALESCE(m.name,''),COALESCE(c.done,0),"
        "COALESCE(c.completed_at,''),t.interval_days,COALESCE(t.end_date,''),"
        "COALESCE(t.note,''),COALESCE(t.category_id,-1),COALESCE(t.due_time,''),"
        "CASE WHEN s.task_id IS NULL THEN 0 ELSE 1 END,COALESCE(c.done_by,-1),"
        "COALESCE(who.name,''),COALESCE(cat.name,'') "
        "FROM tasks t LEFT JOIN members m ON m.id=t.member_id "
        "LEFT JOIN completions c ON c.task_id=t.id AND c.day=? "
        "LEFT JOIN task_skips s ON s.task_id=t.id AND s.day=? "
        "LEFT JOIN members who ON who.id=c.done_by "
        "LEFT JOIN categories cat ON cat.id=t.category_id "
        "WHERE t.start_date<=? AND (t.archived_at IS NULL OR t.archived_at>?) "
        "ORDER BY COALESCE(c.done,0) ASC,t.id DESC"));
    const QString day = date.toString(isoDateFormat);
    for (int i = 0; i < 4; ++i) q.addBindValue(day);
    if (!q.exec()) { reportError(q.lastError().text()); return rows; }
    while (q.next()) {
        if (!scheduleMatches(q.value(3).toString(), parsedDate(q.value(2).toString()),
                             q.value(4).toInt(), date, q.value(9).toInt(), parsedDate(q.value(10).toString()))) continue;
        QVariantMap task;
        task.insert("id", q.value(0)); task.insert("title", q.value(1));
        task.insert("startDate", q.value(2)); task.insert("recurrence", q.value(3));
        task.insert("weekdays", q.value(4)); task.insert("memberId", q.value(5));
        task.insert("memberName", q.value(6)); task.insert("done", q.value(7).toInt() == 1);
        task.insert("completedAt", q.value(8)); task.insert("intervalDays", q.value(9));
        task.insert("endDate", q.value(10)); task.insert("note", q.value(11));
        task.insert("categoryId", q.value(12)); task.insert("dueTime", q.value(13));
        task.insert("skipped", q.value(14).toInt() == 1); task.insert("doneBy", q.value(15));
        task.insert("doneByName", q.value(16)); task.insert("categoryName", q.value(17));
        task.insert("date", day);
        rows.append(task);
    }
    return rows;
}
QVariantList Backend::todayTasks() const { return tasksOn(QDate::currentDate()); }
QVariantList Backend::tasksForDate(const QString &day) const { return tasksOn(parsedDate(day)); }

int Backend::overdueCount(const QDate &date) const {
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM tasks t WHERE t.recurrence='once' AND t.start_date<? "
        "AND (t.archived_at IS NULL OR t.archived_at>?) "
        "AND NOT EXISTS (SELECT 1 FROM completions c "
        "WHERE c.task_id=t.id AND c.day=t.start_date AND c.done=1) "
        "AND NOT EXISTS (SELECT 1 FROM task_skips s WHERE s.task_id=t.id AND s.day=t.start_date)"));
    const QString day = date.toString(isoDateFormat);
    q.addBindValue(day);
    q.addBindValue(day);
    if (!q.exec()) { reportError(q.lastError().text()); return 0; }
    return q.next() ? q.value(0).toInt() : 0;
}
int Backend::shoppingOpenCount() const {
    QSqlQuery q(QStringLiteral("SELECT COUNT(*) FROM shopping WHERE bought=0"), m_db);
    return q.next() ? q.value(0).toInt() : 0;
}

QVariantMap Backend::dashboard() const {
    const QVariantList tasks = todayTasks();
    int completed = 0;
    for (const QVariant &v : tasks) if (v.toMap().value("done").toBool()) ++completed;
    return {{"total", tasks.size()}, {"done", completed}, {"remaining", tasks.size() - completed},
            {"overdue", overdueCount(QDate::currentDate())}, {"shopping", shoppingOpenCount()}};
}

QVariantList Backend::shoppingItems() const {
    QVariantList rows;
    QSqlQuery q(QStringLiteral("SELECT id,name,quantity,bought,category FROM shopping "
                               "ORDER BY bought ASC, id DESC"), m_db);
    if (!q.isActive()) { reportError(q.lastError().text()); return rows; }
    while (q.next()) rows.append(QVariantMap{
        {"id", q.value(0)}, {"name", q.value(1)}, {"quantity", q.value(2)},
        {"bought", q.value(3).toInt() == 1}, {"category", q.value(4)}
    });
    return rows;
}

QVariantList Backend::members() const {
    QVariantList rows;
    const QVariantList tasks = todayTasks();
    QSqlQuery q(QStringLiteral("SELECT id,name FROM members ORDER BY id"), m_db);
    if (!q.isActive()) { reportError(q.lastError().text()); return rows; }
    const QStringList colors = {"#EADCD7", "#DBE7F0", "#E7E7D3", "#E8DDF0", "#F0E6D9"};
    while (q.next()) {
        const int id = q.value(0).toInt();
        int assigned = 0, done = 0;
        for (const QVariant &v : tasks) {
            const QVariantMap item = v.toMap();
            if (item.value("memberId").toInt() == id) {
                ++assigned;
                if (item.value("done").toBool()) ++done;
            }
        }
        const QString name = q.value(1).toString();
        rows.append(QVariantMap{{"id", id}, {"name", name}, {"initial", name.left(1).toUpper()},
                                {"color", colors.at((id - 1) % colors.size())},
                                {"assigned", assigned}, {"remaining", assigned - done}, {"done", done}});
    }
    return rows;
}

QVariantList Backend::assignees() const {
    QVariantList choices;
    choices.append(QVariantMap{{"id", -1}, {"name", QStringLiteral("Wszyscy")}});
    QSqlQuery q(QStringLiteral("SELECT id,name FROM members ORDER BY id"), m_db);
    if (!q.isActive()) { reportError(q.lastError().text()); return choices; }
    while (q.next()) {
        choices.append(QVariantMap{{"id", q.value(0)}, {"name", q.value(1)}});
    }
    return choices;
}

QVariantList Backend::weekDays() const {
    QVariantList days;
    for (int i = 0; i < 7; ++i) {
        const QDate day = QDate::currentDate().addDays(i);
        const QVariantList tasks = tasksOn(day);
        int done = 0;
        for (const QVariant &v : tasks) if (v.toMap().value("done").toBool()) ++done;
        days.append(QVariantMap{{"date", day.toString(isoDateFormat)},
                                {"label", polish.toString(day, "ddd")},
                                {"day", day.day()}, {"total", tasks.size()}, {"done", done},
                                {"isToday", i == 0}});
    }
    return days;
}

QVariantList Backend::historyDays() const { return historyForRange(14); }

QVariantMap Backend::historyStats() const {
    int done7 = 0, done30 = 0, planned7 = 0, skipped7 = 0, skipped30 = 0;
    for (const QVariant &v : historyForRange(30)) {
        const QVariantMap day = v.toMap();
        const QDate d = parsedDate(day.value("date").toString());
        done30 += day.value("done").toInt();
        skipped30 += day.value("skipped").toInt();
        if (d >= QDate::currentDate().addDays(-6)) {
            done7 += day.value("done").toInt();
            skipped7 += day.value("skipped").toInt();
            planned7 += day.value("planned").toInt();
        }
    }
    return {{"done7", done7}, {"done30", done30}, {"planned7", planned7},
        {"skipped7", skipped7}, {"skipped30", skipped30},
        {"percent7", planned7 ? 100*done7/planned7 : -1}};
}

QVariantList Backend::recentActivity() const {
    QVariantList result;
    QSqlQuery q(QStringLiteral(
        "SELECT t.title, c.day, c.completed_at, COALESCE(who.name,m.name,'') "
        "FROM completions c JOIN tasks t ON t.id=c.task_id "
        "LEFT JOIN members m ON m.id=t.member_id "
        "LEFT JOIN members who ON who.id=c.done_by "
        "WHERE c.done=1 ORDER BY c.completed_at DESC LIMIT 20"), m_db);
    if (!q.isActive()) { reportError(q.lastError().text()); return result; }
    while (q.next()) result.append(QVariantMap{
        {"title", q.value(0)}, {"day", q.value(1)},
        {"completedAt", q.value(2)}, {"memberName", q.value(3)}
    });
    return result;
}

bool Backend::addTask(const QString &title, const QString &startDate,
                      const QString &recurrence, int weekdayMask, int memberId) {
    return createTask(title, startDate, recurrence, weekdayMask, memberId, 1, QString(), QString(), -1);
}

bool Backend::setTaskDone(int taskId, const QString &date, bool done, int doneBy) {
    const QDate day = parsedDate(date);
    if (!day.isValid()) { reportError(QStringLiteral("Niepoprawna data.")); return false; }
    QSqlQuery task(m_db);
    task.prepare(QStringLiteral("SELECT start_date,CASE WHEN schedule_kind<>'' THEN schedule_kind ELSE recurrence END,weekdays,archived_at FROM tasks WHERE id=?"));
    task.addBindValue(taskId);
    if (!task.exec() || !task.next()) { reportError(QStringLiteral("Nie znaleziono zadania.")); return false; }
    const QDate start = parsedDate(task.value(0).toString());
    QSqlQuery previous(m_db);
    previous.prepare(QStringLiteral("SELECT done,completed_at,done_by FROM completions WHERE task_id=? AND day=?"));
    previous.addBindValue(taskId); previous.addBindValue(date);
    if (!previous.exec()) { reportError(previous.lastError().text()); return false; }
    const bool existed = previous.next();
    const QVariant priorDone = existed ? previous.value(0) : QVariant();
    const QVariant priorTime = existed ? previous.value(1) : QVariant();
    const QVariant priorBy = existed ? previous.value(2) : QVariant();
    QSqlQuery priorSkip(m_db);
    priorSkip.prepare(QStringLiteral("SELECT 1 FROM task_skips WHERE task_id=? AND day=?"));
    priorSkip.addBindValue(taskId); priorSkip.addBindValue(date);
    const bool wasSkipped = priorSkip.exec() && priorSkip.next();
    if (doneBy <= 0) doneBy = m_activeMemberId;
    const QDate archive = parsedDate(task.value(3).toString());
    QSqlQuery interval(m_db);
    interval.prepare(QStringLiteral("SELECT interval_days,end_date FROM tasks WHERE id=?"));
    interval.addBindValue(taskId);
    if (!interval.exec() || !interval.next()) return false;
    if (!scheduleMatches(task.value(1).toString(), start, task.value(2).toInt(), day,
                          interval.value(0).toInt(), parsedDate(interval.value(1).toString()))
        || (archive.isValid() && day >= archive)) {
        reportError(QStringLiteral("Zadanie nie występuje w tym dniu.")); return false;
    }
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT OR REPLACE INTO completions (task_id,day,done,completed_at,done_by) "
                             "VALUES (?,?,?,?,?)"));
    q.addBindValue(taskId);
    q.addBindValue(date);
    q.addBindValue(done ? 1 : 0);
    q.addBindValue(done ? QVariant(isoNow()) : QVariant(QVariant::String));
    q.addBindValue(done && doneBy > 0 ? QVariant(doneBy) : QVariant(QVariant::Int));
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    if (done) {
        QSqlQuery removeSkip(m_db);
        removeSkip.prepare(QStringLiteral("DELETE FROM task_skips WHERE task_id=? AND day=?"));
        removeSkip.addBindValue(taskId); removeSkip.addBindValue(date);
        if (!removeSkip.exec()) { reportError(removeSkip.lastError().text()); return false; }
    }
    setUndo("completion", {{"taskId", taskId}, {"date", date}, {"existed", existed},
                           {"done", priorDone}, {"completedAt", priorTime}, {"doneBy", priorBy},
                           {"priorSkipped", wasSkipped}},
            QStringLiteral("Cofnij zmianę wykonania"));
    changed();
    return true;
}

bool Backend::setTaskAssignee(int taskId, int memberId) {
    // -1 represents a shared task. Never treat an invalid positive id as shared.
    if (memberId != -1) {
        if (memberId <= 0) {
            reportError(QStringLiteral("Niepoprawny domownik."));
            return false;
        }
        QSqlQuery member(m_db);
        member.prepare(QStringLiteral("SELECT 1 FROM members WHERE id=?"));
        member.addBindValue(memberId);
        if (!member.exec() || !member.next()) {
            reportError(QStringLiteral("Wybrany domownik już nie istnieje."));
            return false;
        }
    }
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE tasks SET member_id=? WHERE id=? AND archived_at IS NULL"));
    q.addBindValue(memberId == -1 ? QVariant(QVariant::Int) : QVariant(memberId));
    q.addBindValue(taskId);
    if (!q.exec() || q.numRowsAffected() != 1) {
        reportError(QStringLiteral("Nie udało się zmienić przypisania zadania."));
        return false;
    }
    changed();
    return true;
}

// Duplicate prevention is by title + assignee on the destination date.
// Daily and weekly tasks already scheduled tomorrow count as present.
Backend::CopyResult Backend::copyOccurrence(const QVariantMap &sourceTask, const QDate &targetDate) {
    const QString target = targetDate.toString(isoDateFormat);
    const QVariantList tomorrow = tasksOn(targetDate);
    for (const QVariant &row : tomorrow) {
        const QVariantMap item = row.toMap();
        if (item.value("title").toString().compare(sourceTask.value("title").toString(), Qt::CaseInsensitive) == 0
                && item.value("memberId").toInt() == sourceTask.value("memberId").toInt())
            return CopyResult::AlreadyPresent;
    }

    QSqlQuery insert(m_db);
    insert.prepare(QStringLiteral(
        "INSERT INTO tasks (title,start_date,recurrence,weekdays,member_id,created_at,note,category_id,due_time) "
        "VALUES (?,?,'once',0,?,?,?,?,?)"));
    insert.addBindValue(sourceTask.value("title"));
    insert.addBindValue(target);
    const int memberId = sourceTask.value("memberId").toInt();
    insert.addBindValue(memberId > 0 ? QVariant(memberId) : QVariant(QVariant::Int));
    insert.addBindValue(isoNow());
    insert.addBindValue(sourceTask.value("note").toString());
    const int categoryId = sourceTask.value("categoryId", -1).toInt();
    insert.addBindValue(categoryId > 0 ? QVariant(categoryId) : QVariant(QVariant::Int));
    insert.addBindValue(sourceTask.value("dueTime").toString());
    if (!insert.exec()) {
        reportError(insert.lastError().text());
        return CopyResult::Error;
    }
    return CopyResult::Copied;
}

bool Backend::copyTaskToNextDay(int taskId, const QString &sourceDate) {
    const QDate day = parsedDate(sourceDate);
    if (!day.isValid() || !day.addDays(1).isValid()) {
        reportError(QStringLiteral("Niepoprawna data kopiowania."));
        return false;
    }
    QVariantMap sourceTask;
    // Only an occurrence really displayed on the source day may be copied.
    for (const QVariant &item : tasksOn(day)) {
        if (item.toMap().value("id").toInt() == taskId) {
            sourceTask = item.toMap();
            break;
        }
    }
    if (sourceTask.isEmpty()) {
        reportError(QStringLiteral("Nie znaleziono zadania w wybranym dniu."));
        return false;
    }
    if (!m_db.transaction()) { reportError(m_db.lastError().text()); return false; }
    const CopyResult outcome = copyOccurrence(sourceTask, day.addDays(1));
    if (outcome == CopyResult::Error) { m_db.rollback(); return false; }
    if (!m_db.commit()) { reportError(m_db.lastError().text()); return false; }
    if (outcome == CopyResult::AlreadyPresent) {
        reportError(QStringLiteral("To zadanie jest już zaplanowane na następny dzień."));
        return false;
    }
    changed();
    return true;
}

QVariantMap Backend::copyDayToNextDay(const QString &sourceDate, bool includeCompleted) {
    const QDate day = parsedDate(sourceDate);
    if (!day.isValid() || !day.addDays(1).isValid()) {
        reportError(QStringLiteral("Niepoprawna data kopiowania."));
        return {{"ok", false}};
    }
    const QVariantList sources = tasksOn(day);
    int copied = 0, alreadyPresent = 0, excluded = 0;
    if (!m_db.transaction()) {
        reportError(m_db.lastError().text());
        return {{"ok", false}};
    }
    for (const QVariant &v : sources) {
        const QVariantMap item = v.toMap();
        if (item.value("done").toBool() && !includeCompleted) {
            ++excluded;
            continue;
        }
        const CopyResult outcome = copyOccurrence(item, day.addDays(1));
        if (outcome == CopyResult::Error) {
            m_db.rollback();
            return {{"ok", false}};
        }
        if (outcome == CopyResult::Copied) ++copied;
        else ++alreadyPresent;
    }
    if (!m_db.commit()) {
        reportError(m_db.lastError().text());
        return {{"ok", false}};
    }
    if (copied > 0) changed();
    return {{"ok", true}, {"copied", copied}, {"alreadyPresent", alreadyPresent},
            {"excludedCompleted", excluded}, {"total", sources.size()},
            {"targetDate", day.addDays(1).toString(isoDateFormat)}};
}

bool Backend::archiveTask(int taskId) {
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE tasks SET archived_at=? WHERE id=? AND archived_at IS NULL"));
    q.addBindValue(today());
    q.addBindValue(taskId);
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    setUndo("archive", {{"id", taskId}}, QStringLiteral("Cofnij archiwizację"));
    changed();
    return true;
}

bool Backend::moveOverdueToToday() {
    const QString now = today();
    if (!m_db.transaction()) { reportError(m_db.lastError().text()); return false; }
    QSqlQuery ids(m_db);
    ids.prepare(QStringLiteral(
        "SELECT t.id,t.start_date FROM tasks t WHERE t.recurrence='once' "
        "AND t.start_date<? AND (t.archived_at IS NULL OR t.archived_at>?) "
        "AND NOT EXISTS (SELECT 1 FROM completions c WHERE c.task_id=t.id "
        "AND c.day=t.start_date AND c.done=1) "
        "AND NOT EXISTS (SELECT 1 FROM task_skips s WHERE s.task_id=t.id AND s.day=t.start_date)"));
    ids.addBindValue(now);
    ids.addBindValue(now);
    if (!ids.exec()) { m_db.rollback(); reportError(ids.lastError().text()); return false; }
    QList<QPair<int,QString>> overdue;
    while (ids.next()) overdue.append(qMakePair(ids.value(0).toInt(), ids.value(1).toString()));
    ids.finish();
    for (const auto &item : overdue) {
        QSqlQuery move(m_db);
        move.prepare(QStringLiteral("INSERT INTO task_moves (task_id,from_date,to_date,moved_at) "
                                    "VALUES (?,?,?,?)"));
        move.addBindValue(item.first);
        move.addBindValue(item.second);
        move.addBindValue(now);
        move.addBindValue(isoNow());
        if (!move.exec()) { m_db.rollback(); reportError(move.lastError().text()); return false; }
        QSqlQuery update(m_db);
        update.prepare(QStringLiteral("UPDATE tasks SET start_date=? WHERE id=?"));
        update.addBindValue(now);
        update.addBindValue(item.first);
        if (!update.exec()) { m_db.rollback(); reportError(update.lastError().text()); return false; }
    }
    if (!m_db.commit()) { reportError(m_db.lastError().text()); return false; }
    changed();
    return true;
}

bool Backend::addShoppingItem(const QString &name, const QString &quantity, const QString &category) {
    const QString product = normalized(name);
    if (product.isEmpty() || product.size() > 120 || quantity.size() > 40) {
        reportError(QStringLiteral("Sprawdź nazwę lub ilość produktu.")); return false;
    }
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO shopping (name,quantity,created_at,category) VALUES (?,?,?,?)"));
    q.addBindValue(product);
    q.addBindValue(quantity.trimmed());
    q.addBindValue(isoNow());
    q.addBindValue(category.trimmed().isEmpty() ? QStringLiteral("Inne") : category.trimmed().left(50));
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    setUndo("add_shopping", {{"id", q.lastInsertId()}}, QStringLiteral("Cofnij dodanie produktu"));
    changed();
    return true;
}

bool Backend::setShoppingDone(int itemId, bool done) {
    QSqlQuery before(m_db);
    before.prepare(QStringLiteral("SELECT name,quantity,category,bought,bought_at FROM shopping WHERE id=?"));
    before.addBindValue(itemId);
    if (!before.exec() || !before.next()) { reportError(QStringLiteral("Nie znaleziono produktu.")); return false; }
    const bool wasBought = before.value(3).toInt() == 1;
    const QVariant oldTime = before.value(4);
    if (!m_db.transaction()) return false;
    QVariant historyId;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE shopping SET bought=?,bought_at=? WHERE id=?"));
    const QString now = isoNow();
    q.addBindValue(done ? 1 : 0);
    q.addBindValue(done ? QVariant(now) : QVariant(QVariant::String));
    q.addBindValue(itemId);
    if (!q.exec()) { m_db.rollback(); reportError(q.lastError().text()); return false; }
    if (done && !wasBought) {
        QSqlQuery history(m_db);
        history.prepare(QStringLiteral("INSERT INTO shopping_history(name,quantity,category,bought_at) VALUES(?,?,?,?)"));
        history.addBindValue(before.value(0)); history.addBindValue(before.value(1));
        history.addBindValue(before.value(2)); history.addBindValue(now);
        if (!history.exec()) { m_db.rollback(); reportError(history.lastError().text()); return false; }
        historyId = history.lastInsertId();
    }
    if (!m_db.commit()) return false;
    setUndo("shopping_status", {{"id", itemId}, {"bought", wasBought}, {"boughtAt", oldTime}, {"historyId", historyId}},
            QStringLiteral("Cofnij zmianę zakupów"));
    changed();
    return true;
}

bool Backend::removeShoppingItem(int itemId) {
    QSqlQuery old(m_db);
    old.prepare(QStringLiteral("SELECT id,name,quantity,bought,created_at,bought_at,category FROM shopping WHERE id=?"));
    old.addBindValue(itemId);
    if (!old.exec() || !old.next()) return false;
    const QVariantMap undo = {{"id", old.value(0)}, {"name", old.value(1)}, {"quantity", old.value(2)},
        {"bought", old.value(3)}, {"createdAt", old.value(4)}, {"boughtAt", old.value(5)},
        {"category", old.value(6)}};
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM shopping WHERE id=?"));
    q.addBindValue(itemId);
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    setUndo("delete_shopping", undo, QStringLiteral("Przywróć usunięty produkt"));
    changed(); return true;
}

bool Backend::clearPurchased() {
    QVariantList removed;
    QSqlQuery old(QStringLiteral("SELECT id,name,quantity,bought,created_at,bought_at,category FROM shopping WHERE bought=1"), m_db);
    while (old.next()) removed.append(QVariantMap{{"id",old.value(0)},{"name",old.value(1)},
        {"quantity",old.value(2)},{"bought",old.value(3)},{"createdAt",old.value(4)},
        {"boughtAt",old.value(5)},{"category",old.value(6)}});
    if (!runSql(QStringLiteral("DELETE FROM shopping WHERE bought=1"))) return false;
    if (!removed.isEmpty()) setUndo("clear_purchased", {{"rows", removed}}, QStringLiteral("Cofnij czyszczenie zakupów"));
    changed(); return true;
}

bool Backend::addMember(const QString &name) {
    const QString member = normalized(name);
    if (member.isEmpty() || member.size() > 48) {
        reportError(QStringLiteral("Nazwa domownika musi mieć 1–48 znaków.")); return false;
    }
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO members (name,created_at) VALUES (?,?)"));
    q.addBindValue(member);
    q.addBindValue(isoNow());
    if (!q.exec()) { reportError(QStringLiteral("Nie można dodać domownika (może już istnieje?).")); return false; }
    changed();
    return true;
}

bool Backend::removeMember(int memberId) {
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM members WHERE id=?"));
    q.addBindValue(memberId);
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    if (memberId == m_activeMemberId) {
        m_activeMemberId = -1;
        QSqlQuery setting(m_db);
        setting.exec(QStringLiteral("INSERT OR REPLACE INTO settings(key,value) VALUES('active_member','-1')"));
    }
    changed();
    return true;
}

bool Backend::darkMode() const {
    if (m_themeMode == "dark") return true;
    if (m_themeMode != "auto") return false;
    const int hour = QTime::currentTime().hour();
    return hour >= 21 || hour < 7;
}

void Backend::setThemeMode(const QString &mode) {
    if (mode != "light" && mode != "dark" && mode != "auto") return;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT OR REPLACE INTO settings (key,value) VALUES ('theme',?)"));
    q.addBindValue(mode);
    if (!q.exec()) { reportError(q.lastError().text()); return; }
    m_themeMode = mode;
    m_lastDark = darkMode();
    emit appearanceChanged();
    changed();
}

QString Backend::backupDirectory() const {
    QString path = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (path.isEmpty()) path = QFileInfo(m_dbPath).absolutePath();
    return QDir(path).filePath(QStringLiteral("DomowyPlan"));
}

QString Backend::backupNow() {
    const QString directory = backupDirectory();
    if (!QDir().mkpath(directory)) {
        reportError(QStringLiteral("Nie można utworzyć folderu kopii: ") + directory);
        return QString();
    }
    QJsonObject root;
    root.insert("format", "domowy-plan-backup");
    root.insert("version", 2);
    root.insert("exportedAt", isoNow());
    for (const BackupTable &table : backupTables()) {
        QSqlQuery query(m_db);
        if (!query.exec(QStringLiteral("SELECT * FROM ") + table.name)) {
            reportError(query.lastError().text()); return QString();
        }
        QJsonArray rows;
        const QSqlRecord record = query.record();
        while (query.next()) {
            QJsonObject row;
            for (int column = 0; column < record.count(); ++column) {
                row.insert(record.fieldName(column), QJsonValue::fromVariant(query.value(column)));
            }
            rows.append(row);
        }
        root.insert(table.name, rows);
    }
    const QString fileName = QStringLiteral("domowy-plan-")
        + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-hhmmss-zzz"))
        + QStringLiteral(".json");
    const QString output = QDir(directory).filePath(fileName);
    QSaveFile file(output);
    if (!file.open(QIODevice::WriteOnly)) { reportError(file.errorString()); return QString(); }
    const QByteArray contents = QJsonDocument(root).toJson(QJsonDocument::Indented);
    if (file.write(contents) != contents.size() || !file.commit()) {
        reportError(QStringLiteral("Nie udało się zapisać kopii zapasowej.")); return QString();
    }
    changed();
    return output;
}

bool Backend::restoreLatestBackup() {
    const QVariantList choices = availableBackups();
    if (choices.isEmpty()) {
        reportError(QStringLiteral("Brak kopii w folderze Dokumenty/DomowyPlan.")); return false;
    }
    return restoreBackup(choices.first().toMap().value("path").toString());
}

bool Backend::restoreBackup(const QString &path) {
    if (!QFileInfo(path).isFile() || !path.endsWith(QStringLiteral(".json"), Qt::CaseInsensitive)) {
        reportError(QStringLiteral("Nie znaleziono wybranej kopii JSON.")); return false;
    }
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly) || file.size() > 20 * 1024 * 1024) {
        reportError(QStringLiteral("Nie można odczytać kopii lub jest zbyt duża.")); return false;
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        reportError(QStringLiteral("Uszkodzony plik kopii zapasowej.")); return false;
    }
    const QJsonObject root = document.object();
    const int backupVersion = root.value("version").toInt();
    if (root.value("format").toString() != "domowy-plan-backup" || (backupVersion != 1 && backupVersion != 2)) {
        reportError(QStringLiteral("Nieobsługiwany format kopii zapasowej.")); return false;
    }
    const QList<BackupTable> tables = backupVersion == 1 ? legacyBackupTables() : backupTables();
    for (const BackupTable &table : tables) {
        if (!root.contains(table.name) || !root.value(table.name).isArray()) {
            reportError(QStringLiteral("Kopia nie zawiera tabeli: ") + table.name); return false;
        }
    }
    if (!m_db.transaction()) { reportError(m_db.lastError().text()); return false; }
    const QStringList deletionOrder = {
        "subtask_checks", "subtasks", "plan_snapshots", "task_skips", "task_moves", "completions",
        "day_template_items", "day_templates", "shopping_set_items", "shopping_sets", "shopping_history",
        "quick_tasks", "shopping_catalog", "shopping", "notes", "tasks", "categories", "members", "settings"
    };
    for (const QString &table : deletionOrder) {
        QSqlQuery deletion(m_db);
        if (!deletion.exec(QStringLiteral("DELETE FROM ") + table)) {
            m_db.rollback(); reportError(deletion.lastError().text()); return false;
        }
    }
    for (const BackupTable &table : tables) {
        QStringList placeholders;
        for (int i = 0; i < table.columns.size(); ++i) placeholders << QStringLiteral("?");
        const QString sql = QStringLiteral("INSERT INTO ") + table.name
            + QStringLiteral(" (") + table.columns.join(",") + QStringLiteral(") VALUES (")
            + placeholders.join(",") + QStringLiteral(")");
        const QJsonArray rows = root.value(table.name).toArray();
        for (const QJsonValue &value : rows) {
            if (!value.isObject()) { m_db.rollback(); reportError("Niepoprawny rekord kopii."); return false; }
            const QJsonObject row = value.toObject();
            QSqlQuery insert(m_db);
            if (!insert.prepare(sql)) { m_db.rollback(); reportError(insert.lastError().text()); return false; }
            for (const QString &column : table.columns) {
                if (!row.contains(column)) {
                    m_db.rollback(); reportError(QStringLiteral("Brak pola ") + column); return false;
                }
                insert.addBindValue(row.value(column).toVariant());
            }
            if (!insert.exec()) { m_db.rollback(); reportError(insert.lastError().text()); return false; }
        }
    }
    QSqlQuery check(m_db);
    if (!check.exec(QStringLiteral("PRAGMA foreign_key_check")) || check.next()) {
        m_db.rollback(); reportError(QStringLiteral("Niespójne powiązania w kopii zapasowej.")); return false;
    }
    if (!m_db.commit()) { reportError(m_db.lastError().text()); return false; }
    m_themeMode = "light";
    QSqlQuery theme(QStringLiteral("SELECT value FROM settings WHERE key='theme'"), m_db);
    if (theme.next()) {
        const QString candidate = theme.value(0).toString();
        if (candidate == "light" || candidate == "dark" || candidate == "auto") m_themeMode = candidate;
    }
    if (backupVersion == 1) seedDefaults();
    m_lastDark = darkMode();
    emit appearanceChanged();
    changed();
    return true;
}

bool Backend::showOnScreenKeyboard() {
#ifdef Q_OS_WIN
    // Windows ships the on-screen keyboard (osk.exe) on x86 as well as x64.
    // It is a reliable manual fallback when the touch keyboard does not
    // appear automatically for a Qt Quick TextField.
    if (QProcess::startDetached(QStringLiteral("osk.exe"), QStringList())) return true;
    reportError(QStringLiteral("Nie udało się otworzyć klawiatury ekranowej Windows."));
    return false;
#else
    reportError(QStringLiteral("Przycisk klawiatury działa tylko w Windows."));
    return false;
#endif
}

void Backend::exitApplication() { QCoreApplication::quit(); }
