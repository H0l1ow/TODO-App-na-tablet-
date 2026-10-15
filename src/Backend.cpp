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

namespace {
const QLocale polish(QLocale::Polish, QLocale::Poland);
const QString isoDateFormat = QStringLiteral("yyyy-MM-dd");

struct BackupTable {
    QString name;
    QStringList columns;
};

QList<BackupTable> backupTables() {
    // Explicit allowlist: imported JSON cannot inject a table or column name.
    return {
        {QStringLiteral("members"), {"id", "name", "created_at"}},
        {QStringLiteral("tasks"), {"id", "title", "start_date", "recurrence", "weekdays", "member_id", "archived_at", "created_at"}},
        {QStringLiteral("completions"), {"task_id", "day", "done", "completed_at"}},
        {QStringLiteral("shopping"), {"id", "name", "quantity", "bought", "created_at", "bought_at"}},
        {QStringLiteral("task_moves"), {"id", "task_id", "from_date", "to_date", "moved_at"}},
        {QStringLiteral("settings"), {"key", "value"}}
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
    m_lastDark = darkMode();

    m_clock.setInterval(30000);
    connect(&m_clock, &QTimer::timeout, this, [this]() {
        const QDate now = QDate::currentDate();
        if (now != m_lastDate) {
            m_lastDate = now;
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
                              int weekdayMask, const QDate &on) {
    if (!start.isValid() || !on.isValid() || on < start) return false;
    if (recurrence == QLatin1String("once")) return on == start;
    if (recurrence == QLatin1String("daily")) return true;
    if (recurrence == QLatin1String("weekly")) return (weekdayMask & (1 << (on.dayOfWeek() - 1))) != 0;
    return false;
}

QVariantList Backend::tasksOn(const QDate &date) const {
    QVariantList rows;
    if (!m_ready || !date.isValid()) return rows;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT t.id, t.title, t.start_date, t.recurrence, t.weekdays, "
        "COALESCE(t.member_id,-1), COALESCE(m.name,''), "
        "COALESCE(c.done,0), COALESCE(c.completed_at,'') "
        "FROM tasks t "
        "LEFT JOIN members m ON m.id=t.member_id "
        "LEFT JOIN completions c ON c.task_id=t.id AND c.day=? "
        "WHERE t.start_date<=? AND (t.archived_at IS NULL OR t.archived_at>?) "
        "AND ((t.recurrence='once' AND t.start_date=?) OR t.recurrence='daily' "
        "OR (t.recurrence='weekly' AND (t.weekdays & ?) != 0)) "
        "ORDER BY COALESCE(c.done,0) ASC, t.id DESC"));
    const QString day = date.toString(isoDateFormat);
    q.addBindValue(day);
    q.addBindValue(day);
    q.addBindValue(day);
    q.addBindValue(day);
    q.addBindValue(1 << (date.dayOfWeek() - 1));
    if (!q.exec()) { reportError(q.lastError().text()); return rows; }
    while (q.next()) {
        QVariantMap task;
        task.insert("id", q.value(0));
        task.insert("title", q.value(1));
        task.insert("startDate", q.value(2));
        task.insert("recurrence", q.value(3));
        task.insert("weekdays", q.value(4));
        task.insert("memberId", q.value(5));
        task.insert("memberName", q.value(6));
        task.insert("done", q.value(7).toInt() == 1);
        task.insert("completedAt", q.value(8));
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
        "WHERE c.task_id=t.id AND c.day=t.start_date AND c.done=1)"));
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
    QSqlQuery q(QStringLiteral("SELECT id,name,quantity,bought FROM shopping "
                               "ORDER BY bought ASC, id DESC"), m_db);
    if (!q.isActive()) { reportError(q.lastError().text()); return rows; }
    while (q.next()) rows.append(QVariantMap{
        {"id", q.value(0)}, {"name", q.value(1)}, {"quantity", q.value(2)},
        {"bought", q.value(3).toInt() == 1}
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

QVariantList Backend::historyDays() const {
    QVariantList days;
    for (int i = 13; i >= 0; --i) {
        const QDate day = QDate::currentDate().addDays(-i);
        const QVariantList scheduled = tasksOn(day);
        int done = 0;
        for (const QVariant &v : scheduled) if (v.toMap().value("done").toBool()) ++done;
        days.append(QVariantMap{{"date", day.toString(isoDateFormat)},
                                {"label", polish.toString(day, "ddd d.MM")},
                                {"planned", scheduled.size()}, {"done", done},
                                {"percent", scheduled.size() ? 100 * done / scheduled.size() : 0}});
    }
    return days;
}

QVariantMap Backend::historyStats() const {
    int done7 = 0, planned7 = 0, done30 = 0;
    for (int i = 0; i < 30; ++i) {
        const QVariantList tasks = tasksOn(QDate::currentDate().addDays(-i));
        for (const QVariant &v : tasks) {
            if (v.toMap().value("done").toBool()) {
                ++done30;
                if (i < 7) ++done7;
            }
        }
        if (i < 7) planned7 += tasks.size();
    }
    return {{"done7", done7}, {"done30", done30}, {"planned7", planned7},
            {"percent7", planned7 ? (100 * done7 / planned7) : 0}};
}

QVariantList Backend::recentActivity() const {
    QVariantList result;
    QSqlQuery q(QStringLiteral(
        "SELECT t.title, c.day, c.completed_at, COALESCE(m.name,'') "
        "FROM completions c JOIN tasks t ON t.id=c.task_id "
        "LEFT JOIN members m ON m.id=t.member_id "
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
    const QString name = normalized(title);
    if (name.isEmpty() || name.size() > 160) {
        reportError(QStringLiteral("Nazwa zadania musi mieć 1–160 znaków.")); return false;
    }
    if (!parsedDate(startDate).isValid()) {
        reportError(QStringLiteral("Niepoprawna data zadania.")); return false;
    }
    if (recurrence != "once" && recurrence != "daily" && recurrence != "weekly") {
        reportError(QStringLiteral("Nieznany typ powtarzania.")); return false;
    }
    if (recurrence == "weekly" && (weekdayMask < 1 || weekdayMask > 127)) {
        reportError(QStringLiteral("Wybierz co najmniej jeden dzień tygodnia.")); return false;
    }
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO tasks (title,start_date,recurrence,weekdays,member_id,created_at) "
                             "VALUES (?,?,?,?,?,?)"));
    q.addBindValue(name);
    q.addBindValue(startDate);
    q.addBindValue(recurrence);
    q.addBindValue(recurrence == "weekly" ? weekdayMask : 0);
    q.addBindValue(memberId > 0 ? QVariant(memberId) : QVariant(QVariant::Int));
    q.addBindValue(isoNow());
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    changed();
    return true;
}

bool Backend::setTaskDone(int taskId, const QString &date, bool done) {
    const QDate day = parsedDate(date);
    if (!day.isValid()) { reportError(QStringLiteral("Niepoprawna data.")); return false; }
    QSqlQuery task(m_db);
    task.prepare(QStringLiteral("SELECT start_date,recurrence,weekdays,archived_at FROM tasks WHERE id=?"));
    task.addBindValue(taskId);
    if (!task.exec() || !task.next()) { reportError(QStringLiteral("Nie znaleziono zadania.")); return false; }
    const QDate start = parsedDate(task.value(0).toString());
    const QDate archive = parsedDate(task.value(3).toString());
    if (!scheduleMatches(task.value(1).toString(), start, task.value(2).toInt(), day)
        || (archive.isValid() && day >= archive)) {
        reportError(QStringLiteral("Zadanie nie występuje w tym dniu.")); return false;
    }
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT OR REPLACE INTO completions (task_id,day,done,completed_at) "
                             "VALUES (?,?,?,?)"));
    q.addBindValue(taskId);
    q.addBindValue(date);
    q.addBindValue(done ? 1 : 0);
    q.addBindValue(done ? QVariant(isoNow()) : QVariant(QVariant::String));
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
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
    QSqlQuery exists(m_db);
    exists.prepare(QStringLiteral(
        "SELECT 1 FROM tasks t WHERE t.title = ? COLLATE NOCASE "
        "AND COALESCE(t.member_id,-1)=? AND t.start_date<=? "
        "AND (t.archived_at IS NULL OR t.archived_at>?) "
        "AND ((t.recurrence='once' AND t.start_date=?) OR t.recurrence='daily' "
        "OR (t.recurrence='weekly' AND (t.weekdays & ?) != 0)) LIMIT 1"));
    exists.addBindValue(sourceTask.value("title"));
    exists.addBindValue(sourceTask.value("memberId"));
    exists.addBindValue(target);
    exists.addBindValue(target);
    exists.addBindValue(target);
    exists.addBindValue(1 << (targetDate.dayOfWeek() - 1));
    if (!exists.exec()) {
        reportError(exists.lastError().text());
        return CopyResult::Error;
    }
    if (exists.next()) return CopyResult::AlreadyPresent;
    exists.finish();

    QSqlQuery insert(m_db);
    insert.prepare(QStringLiteral(
        "INSERT INTO tasks (title,start_date,recurrence,weekdays,member_id,created_at) "
        "VALUES (?,?,'once',0,?,?)"));
    insert.addBindValue(sourceTask.value("title"));
    insert.addBindValue(target);
    const int memberId = sourceTask.value("memberId").toInt();
    insert.addBindValue(memberId > 0 ? QVariant(memberId) : QVariant(QVariant::Int));
    insert.addBindValue(isoNow());
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
        "AND c.day=t.start_date AND c.done=1)"));
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

bool Backend::addShoppingItem(const QString &name, const QString &quantity) {
    const QString product = normalized(name);
    if (product.isEmpty() || product.size() > 120 || quantity.size() > 40) {
        reportError(QStringLiteral("Sprawdź nazwę lub ilość produktu.")); return false;
    }
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO shopping (name,quantity,created_at) VALUES (?,?,?)"));
    q.addBindValue(product);
    q.addBindValue(quantity.trimmed());
    q.addBindValue(isoNow());
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    changed();
    return true;
}

bool Backend::setShoppingDone(int itemId, bool done) {
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE shopping SET bought=?, bought_at=? WHERE id=?"));
    q.addBindValue(done ? 1 : 0);
    q.addBindValue(done ? QVariant(isoNow()) : QVariant(QVariant::String));
    q.addBindValue(itemId);
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    changed();
    return true;
}

bool Backend::removeShoppingItem(int itemId) {
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM shopping WHERE id=?"));
    q.addBindValue(itemId);
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    changed();
    return true;
}

bool Backend::clearPurchased() {
    if (!runSql(QStringLiteral("DELETE FROM shopping WHERE bought=1"))) return false;
    changed();
    return true;
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
    root.insert("version", 1);
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
    QDir backupDir(backupDirectory());
    const QFileInfoList files = backupDir.entryInfoList(
        QStringList() << "domowy-plan-*.json", QDir::Files, QDir::Time);
    if (files.isEmpty()) { reportError(QStringLiteral("Brak kopii zapasowej w folderze Dokumenty/DomowyPlan.")); return false; }
    QFile file(files.first().absoluteFilePath());
    if (!file.open(QIODevice::ReadOnly) || file.size() > 20 * 1024 * 1024) {
        reportError(QStringLiteral("Nie można odczytać kopii lub jest zbyt duża.")); return false;
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        reportError(QStringLiteral("Uszkodzony plik kopii zapasowej.")); return false;
    }
    const QJsonObject root = document.object();
    if (root.value("format").toString() != "domowy-plan-backup" || root.value("version").toInt() != 1) {
        reportError(QStringLiteral("Nieobsługiwany format kopii zapasowej.")); return false;
    }
    const QList<BackupTable> tables = backupTables();
    for (const BackupTable &table : tables) {
        if (!root.contains(table.name) || !root.value(table.name).isArray()) {
            reportError(QStringLiteral("Kopia nie zawiera tabeli: ") + table.name); return false;
        }
    }
    if (!m_db.transaction()) { reportError(m_db.lastError().text()); return false; }
    const QStringList deletionOrder = {"task_moves", "completions", "shopping", "tasks", "members", "settings"};
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
