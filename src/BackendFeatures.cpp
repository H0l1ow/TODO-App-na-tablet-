#include "Backend.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QFile>
#include <QSet>
#include <QTime>
#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTextStream>
#include <QLocale>

namespace {
QString tidy(const QString &input) { return input.simplified(); }
QVariant nullableId(int id) { return id > 0 ? QVariant(id) : QVariant(QVariant::Int); }
QString dateIso(const QDate &d) { return d.toString(QStringLiteral("yyyy-MM-dd")); }
QString quoteCsv(QString value) {
    value.replace('"', QStringLiteral("\"\""));
    return QStringLiteral("\"") + value + QStringLiteral("\"");
}
}

qint64 Backend::databaseBytes() const { return QFileInfo(m_dbPath).size(); }

bool Backend::ensureColumn(const QString &table, const QString &column, const QString &definition) {
    // Names come from the constant migration list, never from user input.
    QSqlQuery query(m_db);
    if (!query.exec(QStringLiteral("PRAGMA table_info(") + table + QLatin1Char(')'))) {
        reportError(query.lastError().text()); return false;
    }
    while (query.next()) if (query.value(1).toString() == column) return true;
    return runSql(QStringLiteral("ALTER TABLE ") + table + QStringLiteral(" ADD COLUMN ") + column + QLatin1Char(' ') + definition);
}

void Backend::seedDefaults() {
    QSqlQuery check(m_db);
    if (!check.exec(QStringLiteral("SELECT value FROM settings WHERE key='seed_v4'")) || check.next()) return;
    if (!m_db.transaction()) return;
    const QList<QPair<QString, QStringList>> initial = {
        {"Pranie", {"Wstawić pranie", "Rozwiesić pranie", "Poskładać pranie", "Wyprasować ubrania", "Zmienić pościel"}},
        {"Sprzątanie", {"Odkurzyć mieszkanie", "Umyć podłogę", "Zetrzeć kurze", "Wynieść śmieci", "Umyć łazienkę"}},
        {"Kuchnia", {"Opróżnić zmywarkę", "Wstawić zmywarkę", "Przygotować obiad", "Umyć blaty", "Posprzątać kuchnię"}},
        {"Zakupy", {"Zrobić zakupy", "Uzupełnić listę zakupów", "Odebrać paczkę", "Kupić środki czystości"}},
        {"Ogród", {"Podlać rośliny", "Skosić trawnik", "Posprzątać ogród", "Wynieść odpady zielone"}},
        {"Organizacja", {"Opłacić rachunki", "Przejrzeć pocztę", "Posprzątać szafę", "Przygotować rzeczy na jutro"}}
    };
    const QStringList icons = {"◉", "✦", "▤", "▣", "❀", "◎"};
    for (int index = 0; index < initial.size(); ++index) {
        QSqlQuery insert(m_db);
        insert.prepare(QStringLiteral("INSERT OR IGNORE INTO categories(name,symbol,position) VALUES(?,?,?)"));
        insert.addBindValue(initial.at(index).first); insert.addBindValue(icons.at(index)); insert.addBindValue(index);
        if (!insert.exec()) { m_db.rollback(); reportError(insert.lastError().text()); return; }
        QSqlQuery lookup(m_db);
        lookup.prepare(QStringLiteral("SELECT id FROM categories WHERE name=?"));
        lookup.addBindValue(initial.at(index).first);
        if (!lookup.exec() || !lookup.next()) { m_db.rollback(); return; }
        const int id = lookup.value(0).toInt();
        int position = 0;
        for (const QString &name : initial.at(index).second) {
            QSqlQuery item(m_db);
            item.prepare(QStringLiteral("INSERT OR IGNORE INTO quick_tasks(category_id,title,favorite,position) VALUES(?,?,?,?)"));
            item.addBindValue(id); item.addBindValue(name);
            const bool favorite = name == "Wstawić pranie" || name == "Wynieść śmieci"
                || name == "Opróżnić zmywarkę" || name == "Odkurzyć mieszkanie" || name == "Zrobić zakupy";
            item.addBindValue(favorite ? 1 : 0); item.addBindValue(position++);
            if (!item.exec()) { m_db.rollback(); reportError(item.lastError().text()); return; }
        }
    }
    const QStringList groceries = {"Mleko", "Chleb", "Masło", "Jajka", "Woda", "Pomidory", "Jabłka", "Ser", "Jogurt", "Makaron", "Ryż", "Papier toaletowy"};
    for (int i = 0; i < groceries.size(); ++i) {
        QSqlQuery product(m_db);
        product.prepare(QStringLiteral("INSERT OR IGNORE INTO shopping_catalog(name,category,favorite) VALUES(?,?,?)"));
        product.addBindValue(groceries.at(i));
        product.addBindValue(i < 5 ? QStringLiteral("Podstawowe") : QStringLiteral("Inne"));
        product.addBindValue(i < 5 ? 1 : 0);
        if (!product.exec()) { m_db.rollback(); reportError(product.lastError().text()); return; }
    }
    QSqlQuery flag(m_db);
    if (!flag.exec(QStringLiteral("INSERT INTO settings(key,value) VALUES('seed_v4','1')"))) {
        m_db.rollback(); reportError(flag.lastError().text()); return;
    }
    if (!m_db.commit()) reportError(m_db.lastError().text());
}

void Backend::snapshotToday() {
    if (!m_ready) return;
    const QVariantList tasks = tasksOn(QDate::currentDate());
    QSqlQuery q(m_db);
    if (!q.prepare(QStringLiteral("INSERT OR IGNORE INTO plan_snapshots(task_id,day,title,member_name,member_id,captured_at) VALUES(?,?,?,?,?,?)"))) return;
    for (const QVariant &item : tasks) {
        const QVariantMap m = item.toMap();
        q.bindValue(0, m.value("id")); q.bindValue(1, today());
        q.bindValue(2, m.value("title")); q.bindValue(3, m.value("memberName"));
        q.bindValue(4, nullableId(m.value("memberId").toInt())); q.bindValue(5, isoNow());
        if (!q.exec()) { reportError(q.lastError().text()); break; }
    }
}

void Backend::setUndo(const QString &kind, const QVariantMap &details, const QString &label) {
    m_undoKind = kind; m_undoDetails = details; m_undoLabel = label;
}

bool Backend::undoLast() {
    if (m_undoKind.isEmpty()) return false;
    const QString kind = m_undoKind;
    const QVariantMap d = m_undoDetails;
    if (!m_db.transaction()) return false;
    if (kind == "copy_tasks" || kind == "clear_purchased") {
        if (kind == "copy_tasks") {
            for (const QVariant &id : d.value("ids").toList()) {
                QSqlQuery deletion(m_db);
                deletion.prepare(QStringLiteral("DELETE FROM tasks WHERE id=?"));
                deletion.addBindValue(id);
                if (!deletion.exec()) { m_db.rollback(); reportError(deletion.lastError().text()); return false; }
            }
        } else {
            for (const QVariant &row : d.value("rows").toList()) {
                const QVariantMap r = row.toMap();
                QSqlQuery insert(m_db);
                insert.prepare(QStringLiteral("INSERT INTO shopping(id,name,quantity,bought,created_at,bought_at,category) VALUES(?,?,?,?,?,?,?)"));
                for (const QString &key : {"id", "name", "quantity", "bought", "createdAt", "boughtAt", "category"})
                    insert.addBindValue(r.value(key));
                if (!insert.exec()) { m_db.rollback(); reportError(insert.lastError().text()); return false; }
            }
        }
        if (!m_db.commit()) return false;
        m_undoKind.clear(); m_undoDetails.clear(); m_undoLabel.clear(); changed(); return true;
    }
    QSqlQuery q(m_db);
    if (kind == "add_task" || kind == "add_shopping") {
        q.prepare(QStringLiteral("DELETE FROM ") + (kind == "add_task" ? QStringLiteral("tasks") : QStringLiteral("shopping")) + QStringLiteral(" WHERE id=?"));
        q.addBindValue(d.value("id"));
    } else if (kind == "completion") {
        if (!d.value("existed").toBool()) {
            q.prepare(QStringLiteral("DELETE FROM completions WHERE task_id=? AND day=?"));
            q.addBindValue(d.value("taskId")); q.addBindValue(d.value("date"));
        } else {
            q.prepare(QStringLiteral("INSERT OR REPLACE INTO completions(task_id,day,done,completed_at,done_by) VALUES(?,?,?,?,?)"));
            q.addBindValue(d.value("taskId")); q.addBindValue(d.value("date"));
            q.addBindValue(d.value("done")); q.addBindValue(d.value("completedAt")); q.addBindValue(d.value("doneBy"));
        }
    } else if (kind == "shopping_status") {
        q.prepare(QStringLiteral("UPDATE shopping SET bought=?,bought_at=? WHERE id=?"));
        q.addBindValue(d.value("bought")); q.addBindValue(d.value("boughtAt")); q.addBindValue(d.value("id"));
    } else if (kind == "archive") {
        q.prepare(QStringLiteral("UPDATE tasks SET archived_at=NULL WHERE id=?")); q.addBindValue(d.value("id"));
    } else if (kind == "move") {
        q.prepare(QStringLiteral("UPDATE tasks SET start_date=? WHERE id=?"));
        q.addBindValue(d.value("oldDate")); q.addBindValue(d.value("id"));
    } else if (kind == "delete_shopping") {
        q.prepare(QStringLiteral("INSERT INTO shopping(id,name,quantity,bought,created_at,bought_at,category) VALUES(?,?,?,?,?,?,?)"));
        for (const QString &key : {"id", "name", "quantity", "bought", "createdAt", "boughtAt", "category"}) q.addBindValue(d.value(key));
    } else {
        m_db.rollback(); return false;
    }
    if (!q.exec()) { m_db.rollback(); reportError(q.lastError().text()); return false; }
    if (kind == "move") {
        QSqlQuery log(m_db);
        log.prepare(QStringLiteral("DELETE FROM task_moves WHERE id=?"));
        log.addBindValue(d.value("logId"));
        if (!log.exec()) { m_db.rollback(); reportError(log.lastError().text()); return false; }
    }
    if (kind == "shopping_status" && d.value("historyId").isValid()) {
        QSqlQuery hist(m_db);
        hist.prepare(QStringLiteral("DELETE FROM shopping_history WHERE id=?"));
        hist.addBindValue(d.value("historyId"));
        if (!hist.exec()) { m_db.rollback(); return false; }
    }
    if (kind == "completion" && d.value("priorSkipped").toBool()) {
        QSqlQuery skip(m_db);
        skip.prepare(QStringLiteral("INSERT OR IGNORE INTO task_skips(task_id,day,skipped_at) VALUES(?,?,?)"));
        skip.addBindValue(d.value("taskId")); skip.addBindValue(d.value("date")); skip.addBindValue(isoNow());
        if (!skip.exec()) { m_db.rollback(); return false; }
    }
    if (!m_db.commit()) { reportError(m_db.lastError().text()); return false; }
    m_undoKind.clear(); m_undoDetails.clear(); m_undoLabel.clear();
    changed(); return true;
}

bool Backend::memberExists(int memberId) const {
    if (memberId == -1) return true;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT 1 FROM members WHERE id=?"));
    q.addBindValue(memberId);
    return q.exec() && q.next();
}

bool Backend::recurrenceValid(const QString &rec, int mask, int every,
                              const QString &endDate, const QString &startDate) const {
    const QDate start = parsedDate(startDate);
    const QDate end = parsedDate(endDate);
    if (!start.isValid() || (!endDate.isEmpty() && (!end.isValid() || end < start))) return false;
    if (rec == "weekly") return mask > 0 && mask <= 127;
    if (rec == "interval") return every >= 1 && every <= 365;
    return rec == "once" || rec == "daily" || rec == "monthly";
}

bool Backend::createTask(const QString &title, const QString &startDate, const QString &recurrence,
                         int weekdayMask, int memberId, int intervalDays, const QString &endDate,
                         const QString &note, int categoryId, const QString &dueTime) {
    const QString name = tidy(title);
    if (name.isEmpty() || name.size() > 160 || note.size() > 1000
        || (!dueTime.isEmpty() && !QTime::fromString(dueTime, "HH:mm").isValid())
        || !memberExists(memberId)
        || !recurrenceValid(recurrence, weekdayMask, intervalDays, endDate, startDate)) {
        reportError(QStringLiteral("Sprawdź nazwę, osobę, datę i harmonogram zadania.")); return false;
    }
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO tasks(title,start_date,recurrence,weekdays,member_id,created_at,interval_days,end_date,note,category_id,schedule_kind,due_time) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)"));
    q.addBindValue(name); q.addBindValue(startDate);
    q.addBindValue(recurrence == "interval" || recurrence == "monthly" ? QStringLiteral("daily") : recurrence);
    q.addBindValue(recurrence == "weekly" ? weekdayMask : 0);
    q.addBindValue(nullableId(memberId)); q.addBindValue(isoNow());
    q.addBindValue(intervalDays > 0 ? intervalDays : 1);
    q.addBindValue(endDate.isEmpty() ? QVariant(QVariant::String) : QVariant(endDate));
    q.addBindValue(note.isNull() ? QStringLiteral("") : note); q.addBindValue(nullableId(categoryId));
    // schedule_kind has NOT NULL constraint: QString() is a NULL QString in Qt.
    // Use a real empty string for ordinary schedules.
    q.addBindValue(recurrence == "interval" || recurrence == "monthly" ? recurrence : QStringLiteral(""));
    q.addBindValue(dueTime.isNull() ? QStringLiteral("") : dueTime);
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    setUndo("add_task", {{"id", q.lastInsertId()}}, QStringLiteral("Cofnij dodanie zadania"));
    changed(); return true;
}

bool Backend::editTask(int taskId, const QString &title, const QString &startDate,
                       const QString &recurrence, int weekdayMask, int memberId,
                       int intervalDays, const QString &endDate, const QString &note, int categoryId, const QString &dueTime) {
    const QString name = tidy(title);
    if (name.isEmpty() || name.size() > 160 || note.size() > 1000
        || (!dueTime.isEmpty() && !QTime::fromString(dueTime, "HH:mm").isValid())
        || !memberExists(memberId)
        || !recurrenceValid(recurrence, weekdayMask, intervalDays, endDate, startDate)) {
        reportError(QStringLiteral("Sprawdź dane zadania.")); return false;
    }
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE tasks SET title=?,start_date=?,recurrence=?,weekdays=?,member_id=?,interval_days=?,end_date=?,note=?,category_id=?,schedule_kind=?,due_time=? WHERE id=? AND archived_at IS NULL"));
    q.addBindValue(name); q.addBindValue(startDate);
    q.addBindValue(recurrence == "interval" || recurrence == "monthly" ? QStringLiteral("daily") : recurrence);
    q.addBindValue(recurrence == "weekly" ? weekdayMask : 0);
    q.addBindValue(nullableId(memberId)); q.addBindValue(intervalDays > 0 ? intervalDays : 1);
    q.addBindValue(endDate.isEmpty() ? QVariant(QVariant::String) : QVariant(endDate));
    q.addBindValue(note.isNull() ? QStringLiteral("") : note); q.addBindValue(nullableId(categoryId));
    // schedule_kind has NOT NULL constraint: QString() is a NULL QString in Qt.
    // Use a real empty string for ordinary schedules.
    q.addBindValue(recurrence == "interval" || recurrence == "monthly" ? recurrence : QStringLiteral(""));
    q.addBindValue(dueTime.isNull() ? QStringLiteral("") : dueTime);
    q.addBindValue(taskId);
    if (!q.exec() || q.numRowsAffected() != 1) { reportError(QStringLiteral("Nie można edytować zadania.")); return false; }
    m_undoLabel.clear(); m_undoKind.clear();
    changed(); return true;
}

QVariantMap Backend::taskDetails(int taskId) const {
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT title,start_date,CASE WHEN schedule_kind<>'' THEN schedule_kind ELSE recurrence END,weekdays,COALESCE(member_id,-1),interval_days,COALESCE(end_date,''),COALESCE(note,''),COALESCE(category_id,-1),COALESCE(due_time,'') FROM tasks WHERE id=?"));
    q.addBindValue(taskId);
    if (!q.exec() || !q.next()) return {};
    return {{"id", taskId}, {"title", q.value(0)}, {"startDate", q.value(1)},
            {"recurrence", q.value(2)}, {"weekdays", q.value(3)}, {"memberId", q.value(4)},
            {"intervalDays", q.value(5)}, {"endDate", q.value(6)}, {"note", q.value(7)},
            {"categoryId", q.value(8)}, {"dueTime", q.value(9)}};
}

QVariantList Backend::tasksForDateFiltered(const QString &date, int memberId) const {
    const QVariantList all = tasksOn(parsedDate(date));
    if (memberId == -2) return all;
    QVariantList filtered;
    for (const QVariant &v : all) {
        const QVariantMap task = v.toMap();
        if (task.value("memberId").toInt() == memberId) filtered.append(task);
    }
    return filtered;
}

QVariantList Backend::overdueTasks() const {
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT t.id,t.title,t.start_date,COALESCE(t.member_id,-1),COALESCE(m.name,'') "
        "FROM tasks t LEFT JOIN members m ON m.id=t.member_id "
        "WHERE t.recurrence='once' AND t.start_date<? AND (t.archived_at IS NULL OR t.archived_at>?) "
        "AND NOT EXISTS (SELECT 1 FROM completions c WHERE c.task_id=t.id AND c.day=t.start_date AND c.done=1) "
        "AND NOT EXISTS (SELECT 1 FROM task_skips s WHERE s.task_id=t.id AND s.day=t.start_date) "
        "ORDER BY t.start_date,t.id"));
    q.addBindValue(today()); q.addBindValue(today());
    if (!q.exec()) { reportError(q.lastError().text()); return result; }
    while (q.next()) result.append(QVariantMap{{"id", q.value(0)}, {"title", q.value(1)},
        {"startDate", q.value(2)}, {"memberId", q.value(3)}, {"memberName", q.value(4)}});
    return result;
}

bool Backend::moveTaskToDate(int taskId, const QString &targetDate) {
    if (!parsedDate(targetDate).isValid()) { reportError(QStringLiteral("Błędna data docelowa.")); return false; }
    QSqlQuery previous(m_db);
    previous.prepare(QStringLiteral("SELECT start_date,recurrence FROM tasks WHERE id=? AND archived_at IS NULL"));
    previous.addBindValue(taskId);
    if (!previous.exec() || !previous.next() || previous.value(1).toString() != "once") {
        reportError(QStringLiteral("Przenosić można tylko zadania jednorazowe.")); return false;
    }
    const QString oldDate = previous.value(0).toString();
    if (oldDate == targetDate) return true;
    if (!m_db.transaction()) return false;
    QSqlQuery move(m_db);
    move.prepare(QStringLiteral("INSERT INTO task_moves(task_id,from_date,to_date,moved_at) VALUES(?,?,?,?)"));
    move.addBindValue(taskId); move.addBindValue(oldDate); move.addBindValue(targetDate); move.addBindValue(isoNow());
    if (!move.exec()) { m_db.rollback(); reportError(move.lastError().text()); return false; }
    QSqlQuery update(m_db);
    update.prepare(QStringLiteral("UPDATE tasks SET start_date=? WHERE id=?"));
    update.addBindValue(targetDate); update.addBindValue(taskId);
    if (!update.exec()) { m_db.rollback(); reportError(update.lastError().text()); return false; }
    if (!m_db.commit()) return false;
    setUndo("move", {{"id", taskId}, {"oldDate", oldDate}, {"target", targetDate},
        {"logId", move.lastInsertId()}}, QStringLiteral("Cofnij przeniesienie"));
    changed(); return true;
}

bool Backend::moveOverdueSelection(const QVariantList &taskIds, const QString &targetDate) {
    if (!parsedDate(targetDate).isValid() || taskIds.isEmpty()) return false;
    const QVariantList overdue = overdueTasks();
    QSet<int> eligible;
    for (const QVariant &v : overdue) eligible.insert(v.toMap().value("id").toInt());
    for (const QVariant &v : taskIds) if (!eligible.contains(v.toInt())) {
        reportError(QStringLiteral("Zaznaczono nieaktualne lub wykonane zadanie.")); return false;
    }
    if (!m_db.transaction()) return false;
    for (const QVariant &id : taskIds) {
        QSqlQuery select(m_db);
        select.prepare(QStringLiteral("SELECT start_date FROM tasks WHERE id=?")); select.addBindValue(id);
        if (!select.exec() || !select.next()) { m_db.rollback(); return false; }
        QSqlQuery log(m_db);
        log.prepare(QStringLiteral("INSERT INTO task_moves(task_id,from_date,to_date,moved_at) VALUES(?,?,?,?)"));
        log.addBindValue(id); log.addBindValue(select.value(0)); log.addBindValue(targetDate); log.addBindValue(isoNow());
        if (!log.exec()) { m_db.rollback(); reportError(log.lastError().text()); return false; }
        QSqlQuery update(m_db);
        update.prepare(QStringLiteral("UPDATE tasks SET start_date=? WHERE id=?"));
        update.addBindValue(targetDate); update.addBindValue(id);
        if (!update.exec()) { m_db.rollback(); reportError(update.lastError().text()); return false; }
    }
    if (!m_db.commit()) return false;
    changed(); return true;
}

bool Backend::copyTaskToDate(int taskId, const QString &sourceDate, const QString &targetDate) {
    const QDate source = parsedDate(sourceDate), target = parsedDate(targetDate);
    if (!source.isValid() || !target.isValid() || source == target) return false;
    for (const QVariant &task : tasksOn(source)) {
        const QVariantMap m = task.toMap();
        if (m.value("id").toInt() != taskId) continue;
        if (!m_db.transaction()) return false;
        const CopyResult result = copyOccurrence(m, target);
        if (result != CopyResult::Copied) {
            m_db.rollback(); reportError(result == CopyResult::AlreadyPresent
                ? QStringLiteral("To zadanie już występuje w wybranym dniu.")
                : QStringLiteral("Nie udało się skopiować zadania.")); return false;
        }
        QSqlQuery key(QStringLiteral("SELECT last_insert_rowid()"), m_db);
        const QVariant id = key.next() ? key.value(0) : QVariant();
        if (!m_db.commit()) return false;
        if (id.isValid()) setUndo("copy_tasks", {{"ids", QVariantList{id}}}, QStringLiteral("Cofnij kopiowanie"));
        changed(); return true;
    }
    reportError(QStringLiteral("Nie znaleziono zadania w tym dniu.")); return false;
}

QVariantMap Backend::copyDayToDate(const QString &source, const QString &target,
                                    bool includeCompleted, int memberFilter) {
    const QDate from = parsedDate(source), to = parsedDate(target);
    if (!from.isValid() || !to.isValid() || from == to) return {{"ok", false}};
    int copied = 0, duplicates = 0, excluded = 0;
    QVariantList inserted;
    if (!m_db.transaction()) return {{"ok", false}};
    for (const QVariant &v : tasksOn(from)) {
        const QVariantMap m = v.toMap();
        if ((m.value("done").toBool() && !includeCompleted) || m.value("skipped").toBool()
            || (memberFilter != -2 && m.value("memberId").toInt() != memberFilter)) { ++excluded; continue; }
        const CopyResult res = copyOccurrence(m, to);
        if (res == CopyResult::Error) { m_db.rollback(); return {{"ok", false}}; }
        if (res == CopyResult::Copied) {
            QSqlQuery key(QStringLiteral("SELECT last_insert_rowid()"), m_db);
            if (key.next()) inserted.append(key.value(0));
            ++copied;
        } else ++duplicates;
    }
    if (!m_db.commit()) return {{"ok", false}};
    if (copied) setUndo("copy_tasks", {{"ids",inserted}}, QStringLiteral("Cofnij kopiowanie dnia"));
    if (copied) changed();
    return {{"ok", true}, {"copied", copied}, {"alreadyPresent", duplicates},
        {"excluded", excluded}, {"targetDate", target}};
}

bool Backend::setTaskSkipped(int taskId, const QString &date, bool skipped) {
    bool found = false;
    for (const QVariant &v : tasksOn(parsedDate(date))) if (v.toMap().value("id").toInt() == taskId) found = true;
    if (!found) return false;
    QSqlQuery q(m_db);
    if (skipped) {
        q.prepare(QStringLiteral("INSERT OR REPLACE INTO task_skips(task_id,day,skipped_at) VALUES(?,?,?)"));
        q.addBindValue(taskId); q.addBindValue(date); q.addBindValue(isoNow());
    } else {
        q.prepare(QStringLiteral("DELETE FROM task_skips WHERE task_id=? AND day=?"));
        q.addBindValue(taskId); q.addBindValue(date);
    }
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    if (skipped) {
        QSqlQuery done(m_db);
        done.prepare(QStringLiteral("DELETE FROM completions WHERE task_id=? AND day=?"));
        done.addBindValue(taskId); done.addBindValue(date);
        if (!done.exec()) { reportError(done.lastError().text()); return false; }
    }
    changed(); return true;
}

QVariantList Backend::categories() const {
    QVariantList list;
    QSqlQuery q(QStringLiteral("SELECT id,name,symbol FROM categories ORDER BY position,id"), m_db);
    while (q.next()) list.append(QVariantMap{{"id", q.value(0)}, {"name", q.value(1)}, {"symbol", q.value(2)}});
    return list;
}

bool Backend::saveCategory(int id, const QString &name, const QString &symbol) {
    const QString label = tidy(name);
    if (label.isEmpty() || label.size() > 42 || symbol.size() > 5) return false;
    QSqlQuery q(m_db);
    if (id > 0) { q.prepare(QStringLiteral("UPDATE categories SET name=?,symbol=? WHERE id=?"));
        q.addBindValue(label); q.addBindValue(symbol); q.addBindValue(id); }
    else { q.prepare(QStringLiteral("INSERT INTO categories(name,symbol,position) VALUES(?,?,(SELECT COALESCE(MAX(position),0)+1 FROM categories))"));
        q.addBindValue(label); q.addBindValue(symbol); }
    if (!q.exec()) { reportError(QStringLiteral("Kategoria o tej nazwie już istnieje.")); return false; }
    changed(); return true;
}

bool Backend::deleteCategory(int id) {
    if (!m_db.transaction()) return false;
    QSqlQuery unlink(m_db);
    unlink.prepare(QStringLiteral("UPDATE tasks SET category_id=NULL WHERE category_id=?")); unlink.addBindValue(id);
    if (!unlink.exec()) { m_db.rollback(); return false; }
    QSqlQuery q(m_db); q.prepare(QStringLiteral("DELETE FROM categories WHERE id=?")); q.addBindValue(id);
    if (!q.exec()) { m_db.rollback(); reportError(q.lastError().text()); return false; }
    if (!m_db.commit()) return false;
    changed(); return true;
}

QVariantList Backend::quickTemplates(int categoryId) const {
    QVariantList result;
    QSqlQuery q(m_db);
    const QString base = QStringLiteral("SELECT q.id,q.category_id,q.title,COALESCE(q.member_id,-1),q.favorite,q.uses,COALESCE(c.name,'') FROM quick_tasks q LEFT JOIN categories c ON c.id=q.category_id ");
    if (categoryId == 0) q.prepare(base + QStringLiteral("WHERE q.favorite=1 OR q.uses>0 ORDER BY q.favorite DESC,q.uses DESC,q.last_used DESC,q.id LIMIT 20"));
    else { q.prepare(base + QStringLiteral("WHERE q.category_id=? ORDER BY q.position,q.id")); q.addBindValue(categoryId); }
    if (!q.exec()) { reportError(q.lastError().text()); return result; }
    while (q.next()) result.append(QVariantMap{{"id", q.value(0)}, {"categoryId", q.value(1)},
        {"title", q.value(2)}, {"memberId", q.value(3)}, {"favorite", q.value(4).toInt() != 0},
        {"uses", q.value(5)}, {"categoryName", q.value(6)}});
    return result;
}

bool Backend::saveQuickTemplate(int id, int categoryId, const QString &title, int defaultMemberId, bool favorite) {
    const QString name = tidy(title);
    if (name.isEmpty() || name.size() > 160 || !memberExists(defaultMemberId)) return false;
    QSqlQuery q(m_db);
    if (id > 0) {
        q.prepare(QStringLiteral("UPDATE quick_tasks SET title=?,category_id=?,member_id=?,favorite=? WHERE id=?"));
        q.addBindValue(name); q.addBindValue(categoryId); q.addBindValue(nullableId(defaultMemberId));
        q.addBindValue(favorite ? 1 : 0); q.addBindValue(id);
    } else {
        q.prepare(QStringLiteral("INSERT INTO quick_tasks(title,category_id,member_id,favorite,position) VALUES(?,?,?,?,(SELECT COALESCE(MAX(position),0)+1 FROM quick_tasks WHERE category_id=?))"));
        q.addBindValue(name); q.addBindValue(categoryId); q.addBindValue(nullableId(defaultMemberId));
        q.addBindValue(favorite ? 1 : 0); q.addBindValue(categoryId);
    }
    if (!q.exec()) { reportError(QStringLiteral("Nie można zapisać szablonu. Sprawdź kategorię i nazwę.")); return false; }
    changed(); return true;
}

bool Backend::deleteQuickTemplate(int id) {
    QSqlQuery q(m_db); q.prepare(QStringLiteral("DELETE FROM quick_tasks WHERE id=?")); q.addBindValue(id);
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    changed(); return true;
}

bool Backend::toggleQuickFavorite(int id) {
    QSqlQuery q(m_db); q.prepare(QStringLiteral("UPDATE quick_tasks SET favorite=1-favorite WHERE id=?")); q.addBindValue(id);
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    changed(); return true;
}

bool Backend::addFromQuickTemplate(int templateId, const QString &date, int chosenMemberId) {
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT title,category_id,COALESCE(member_id,-1) FROM quick_tasks WHERE id=?"));
    q.addBindValue(templateId);
    if (!q.exec() || !q.next()) return false;
    const QString name = q.value(0).toString(); const int category = q.value(1).toInt();
    const int assignee = chosenMemberId == -2 ? q.value(2).toInt() : chosenMemberId;
    if (!createTask(name, date, "once", 0, assignee, 1, QString(), QString(), category)) return false;
    QSqlQuery used(m_db);
    used.prepare(QStringLiteral("UPDATE quick_tasks SET uses=uses+1,last_used=? WHERE id=?"));
    used.addBindValue(isoNow()); used.addBindValue(templateId);
    if (!used.exec()) reportError(used.lastError().text());
    changed(); return true;
}

QVariantList Backend::dayTemplates() const {
    QVariantList result;
    QSqlQuery q(QStringLiteral("SELECT t.id,t.name,COUNT(i.id) FROM day_templates t LEFT JOIN day_template_items i ON i.template_id=t.id GROUP BY t.id ORDER BY t.name"), m_db);
    while (q.next()) result.append(QVariantMap{{"id", q.value(0)}, {"name", q.value(1)}, {"count", q.value(2)}});
    return result;
}

bool Backend::saveDayTemplate(const QString &name, const QString &date) {
    const QString label = tidy(name);
    if (label.isEmpty() || label.size() > 70) return false;
    const QVariantList tasks = tasksOn(parsedDate(date));
    if (tasks.isEmpty() || !m_db.transaction()) return false;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO day_templates(name,created_at) VALUES(?,?)"));
    q.addBindValue(label); q.addBindValue(isoNow());
    if (!q.exec()) { m_db.rollback(); reportError(QStringLiteral("Szablon o tej nazwie już istnieje.")); return false; }
    const int id = q.lastInsertId().toInt();
    int pos = 0;
    for (const QVariant &v : tasks) {
        const QVariantMap t = v.toMap();
        QSqlQuery insert(m_db);
        insert.prepare(QStringLiteral("INSERT INTO day_template_items(template_id,title,member_id,position) VALUES(?,?,?,?)"));
        insert.addBindValue(id); insert.addBindValue(t.value("title"));
        insert.addBindValue(nullableId(t.value("memberId").toInt())); insert.addBindValue(pos++);
        if (!insert.exec()) { m_db.rollback(); reportError(insert.lastError().text()); return false; }
    }
    if (!m_db.commit()) return false;
    changed(); return true;
}

QVariantMap Backend::applyDayTemplate(int id, const QString &date) {
    const QDate target = parsedDate(date);
    if (!target.isValid()) return {{"ok", false}};
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT title,COALESCE(member_id,-1) FROM day_template_items WHERE template_id=? ORDER BY position"));
    q.addBindValue(id);
    if (!q.exec()) return {{"ok", false}};
    QVariantList source;
    while (q.next()) source.append(QVariantMap{{"title", q.value(0)}, {"memberId", q.value(1)}});
    q.finish();
    if (!m_db.transaction()) return {{"ok", false}};
    int copied = 0, duplicates = 0;
    QVariantList inserted;
    for (const QVariant &v : source) {
        const CopyResult res = copyOccurrence(v.toMap(), target);
        if (res == CopyResult::Error) { m_db.rollback(); return {{"ok", false}}; }
        if (res == CopyResult::Copied) {
            QSqlQuery key(QStringLiteral("SELECT last_insert_rowid()"), m_db);
            if (key.next()) inserted.append(key.value(0));
            ++copied;
        } else ++duplicates;
    }
    if (!m_db.commit()) return {{"ok", false}};
    if (copied) setUndo("copy_tasks", {{"ids",inserted}}, QStringLiteral("Cofnij wstawienie szablonu"));
    changed(); return {{"ok", true}, {"copied", copied}, {"alreadyPresent", duplicates}};
}

bool Backend::deleteDayTemplate(int id) {
    QSqlQuery q(m_db); q.prepare(QStringLiteral("DELETE FROM day_templates WHERE id=?")); q.addBindValue(id);
    if (!q.exec()) return false; changed(); return true;
}

QVariantList Backend::shoppingCatalog() const {
    QVariantList rows;
    QSqlQuery q(QStringLiteral("SELECT id,name,category,quantity,favorite,uses FROM shopping_catalog ORDER BY favorite DESC,uses DESC,name COLLATE NOCASE"), m_db);
    while (q.next()) rows.append(QVariantMap{{"id", q.value(0)}, {"name", q.value(1)},
        {"category", q.value(2)}, {"quantity", q.value(3)},
        {"favorite", q.value(4).toInt() != 0}, {"uses", q.value(5)}});
    return rows;
}

bool Backend::saveCatalogProduct(const QString &name, const QString &category, const QString &quantity, bool favorite) {
    const QString label = tidy(name);
    if (label.isEmpty() || label.size() > 120 || quantity.size() > 40) return false;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO shopping_catalog(name,category,quantity,favorite) VALUES(?,?,?,?) "
        "ON CONFLICT(name) DO UPDATE SET category=excluded.category,quantity=excluded.quantity,favorite=excluded.favorite"));
    q.addBindValue(label); q.addBindValue(tidy(category).isEmpty() ? "Inne" : tidy(category));
    q.addBindValue(quantity.trimmed()); q.addBindValue(favorite ? 1 : 0);
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    changed(); return true;
}

bool Backend::deleteCatalogProduct(int id) {
    QSqlQuery q(m_db); q.prepare(QStringLiteral("DELETE FROM shopping_catalog WHERE id=?")); q.addBindValue(id);
    if (!q.exec()) return false; changed(); return true;
}

bool Backend::toggleCatalogFavorite(int id) {
    QSqlQuery q(m_db); q.prepare(QStringLiteral("UPDATE shopping_catalog SET favorite=1-favorite WHERE id=?")); q.addBindValue(id);
    if (!q.exec()) return false; changed(); return true;
}

bool Backend::addShoppingFromCatalog(int id) {
    QSqlQuery catalog(m_db);
    catalog.prepare(QStringLiteral("SELECT name,quantity,category FROM shopping_catalog WHERE id=?"));
    catalog.addBindValue(id);
    if (!catalog.exec() || !catalog.next()) return false;
    const QString name = catalog.value(0).toString();
    QSqlQuery exists(m_db);
    exists.prepare(QStringLiteral("SELECT 1 FROM shopping WHERE name=? COLLATE NOCASE AND bought=0"));
    exists.addBindValue(name);
    if (exists.exec() && exists.next()) { reportError(QStringLiteral("Produkt jest już na liście.")); return false; }
    if (!m_db.transaction()) return false;
    QSqlQuery insert(m_db);
    insert.prepare(QStringLiteral("INSERT INTO shopping(name,quantity,category,created_at) VALUES(?,?,?,?)"));
    insert.addBindValue(name); insert.addBindValue(catalog.value(1));
    insert.addBindValue(catalog.value(2)); insert.addBindValue(isoNow());
    if (!insert.exec()) { m_db.rollback(); reportError(insert.lastError().text()); return false; }
    const QVariant addedId = insert.lastInsertId();
    QSqlQuery used(m_db);
    used.prepare(QStringLiteral("UPDATE shopping_catalog SET uses=uses+1,last_used=? WHERE id=?"));
    used.addBindValue(isoNow()); used.addBindValue(id);
    if (!used.exec()) { m_db.rollback(); return false; }
    if (!m_db.commit()) return false;
    setUndo("add_shopping", {{"id", addedId}}, QStringLiteral("Cofnij dodanie produktu"));
    changed(); return true;
}

bool Backend::setShoppingQuantity(int id, const QString &quantity) {
    if (quantity.size() > 40) return false;
    QSqlQuery q(m_db); q.prepare(QStringLiteral("UPDATE shopping SET quantity=? WHERE id=?"));
    q.addBindValue(quantity.trimmed()); q.addBindValue(id);
    if (!q.exec()) return false; changed(); return true;
}

QVariantMap Backend::repeatRecentShopping(int days) {
    if (days < 1 || days > 365) return {{"ok", false}};
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT name,MAX(quantity),MAX(category) FROM shopping_history WHERE bought_at>=? GROUP BY name COLLATE NOCASE ORDER BY MAX(bought_at) DESC LIMIT 120"));
    q.addBindValue(QDateTime::currentDateTime().addDays(-days).toString(Qt::ISODateWithMs));
    if (!q.exec() || !m_db.transaction()) return {{"ok", false}};
    int added = 0, skipped = 0;
    while (q.next()) {
        QSqlQuery existing(m_db);
        existing.prepare(QStringLiteral("SELECT 1 FROM shopping WHERE name=? COLLATE NOCASE AND bought=0"));
        existing.addBindValue(q.value(0));
        if (!existing.exec()) { m_db.rollback(); return {{"ok", false}}; }
        if (existing.next()) { ++skipped; continue; }
        QSqlQuery insert(m_db);
        insert.prepare(QStringLiteral("INSERT INTO shopping(name,quantity,category,created_at) VALUES(?,?,?,?)"));
        insert.addBindValue(q.value(0)); insert.addBindValue(q.value(1)); insert.addBindValue(q.value(2)); insert.addBindValue(isoNow());
        if (!insert.exec()) { m_db.rollback(); return {{"ok", false}}; }
        ++added;
    }
    if (!m_db.commit()) return {{"ok", false}};
    changed(); return {{"ok", true}, {"added", added}, {"alreadyPresent", skipped}};
}

QVariantList Backend::shoppingSets() const {
    QVariantList list;
    QSqlQuery q(QStringLiteral("SELECT s.id,s.name,COUNT(i.id) FROM shopping_sets s LEFT JOIN shopping_set_items i ON i.set_id=s.id GROUP BY s.id ORDER BY s.name"), m_db);
    while (q.next()) list.append(QVariantMap{{"id", q.value(0)}, {"name", q.value(1)}, {"count", q.value(2)}});
    return list;
}

bool Backend::saveShoppingSet(const QString &name) {
    const QString label = tidy(name);
    if (label.isEmpty() || label.size() > 70 || !m_db.transaction()) return false;
    QSqlQuery q(m_db); q.prepare(QStringLiteral("INSERT INTO shopping_sets(name,created_at) VALUES(?,?)"));
    q.addBindValue(label); q.addBindValue(isoNow());
    if (!q.exec()) { m_db.rollback(); reportError(QStringLiteral("Zestaw o tej nazwie już istnieje.")); return false; }
    const int id = q.lastInsertId().toInt();
    QSqlQuery items(m_db);
    if (!items.exec(QStringLiteral("SELECT name,quantity,category FROM shopping WHERE bought=0"))) { m_db.rollback(); return false; }
    while (items.next()) {
        QSqlQuery insert(m_db);
        insert.prepare(QStringLiteral("INSERT INTO shopping_set_items(set_id,name,quantity,category) VALUES(?,?,?,?)"));
        insert.addBindValue(id); insert.addBindValue(items.value(0)); insert.addBindValue(items.value(1)); insert.addBindValue(items.value(2));
        if (!insert.exec()) { m_db.rollback(); return false; }
    }
    if (!m_db.commit()) return false;
    changed(); return true;
}

QVariantMap Backend::applyShoppingSet(int id) {
    QSqlQuery items(m_db);
    items.prepare(QStringLiteral("SELECT name,quantity,category FROM shopping_set_items WHERE set_id=?"));
    items.addBindValue(id);
    if (!items.exec() || !m_db.transaction()) return {{"ok", false}};
    int added = 0, skipped = 0;
    while (items.next()) {
        QSqlQuery exists(m_db);
        exists.prepare(QStringLiteral("SELECT 1 FROM shopping WHERE name=? COLLATE NOCASE AND bought=0"));
        exists.addBindValue(items.value(0));
        if (!exists.exec()) { m_db.rollback(); return {{"ok", false}}; }
        if (exists.next()) { ++skipped; continue; }
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("INSERT INTO shopping(name,quantity,category,created_at) VALUES(?,?,?,?)"));
        q.addBindValue(items.value(0)); q.addBindValue(items.value(1)); q.addBindValue(items.value(2)); q.addBindValue(isoNow());
        if (!q.exec()) { m_db.rollback(); return {{"ok", false}}; }
        ++added;
    }
    if (!m_db.commit()) return {{"ok", false}};
    changed(); return {{"ok", true}, {"added", added}, {"alreadyPresent", skipped}};
}

bool Backend::deleteShoppingSet(int id) {
    QSqlQuery q(m_db); q.prepare(QStringLiteral("DELETE FROM shopping_sets WHERE id=?")); q.addBindValue(id);
    if (!q.exec()) return false; changed(); return true;
}

QVariantList Backend::subTasks(int taskId, const QString &day) const {
    QVariantList rows;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT s.id,s.title,COALESCE(c.done,0) FROM subtasks s LEFT JOIN subtask_checks c ON c.subtask_id=s.id AND c.day=? WHERE s.task_id=? ORDER BY s.position,s.id"));
    q.addBindValue(day); q.addBindValue(taskId);
    if (!q.exec()) return rows;
    while (q.next()) rows.append(QVariantMap{{"id", q.value(0)}, {"title", q.value(1)}, {"done", q.value(2).toInt() == 1}});
    return rows;
}

bool Backend::addSubTask(int taskId, const QString &title) {
    const QString text = tidy(title);
    if (text.isEmpty() || text.size() > 130) return false;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO subtasks(task_id,title,position) VALUES(?,?,(SELECT COUNT(*) FROM subtasks WHERE task_id=?))"));
    q.addBindValue(taskId); q.addBindValue(text); q.addBindValue(taskId);
    if (!q.exec()) { reportError(q.lastError().text()); return false; }
    changed(); return true;
}

bool Backend::setSubTaskDone(int id, const QString &day, bool done) {
    if (!parsedDate(day).isValid()) return false;
    QSqlQuery q(m_db);
    if (done) { q.prepare(QStringLiteral("INSERT OR REPLACE INTO subtask_checks(subtask_id,day,done) VALUES(?,?,1)"));
        q.addBindValue(id); q.addBindValue(day); }
    else { q.prepare(QStringLiteral("DELETE FROM subtask_checks WHERE subtask_id=? AND day=?"));
        q.addBindValue(id); q.addBindValue(day); }
    if (!q.exec()) return false; changed(); return true;
}

bool Backend::deleteSubTask(int id) {
    QSqlQuery q(m_db); q.prepare(QStringLiteral("DELETE FROM subtasks WHERE id=?")); q.addBindValue(id);
    if (!q.exec()) return false; changed(); return true;
}

QVariantList Backend::notes() const {
    QVariantList result;
    QSqlQuery q(QStringLiteral("SELECT id,text,created_at FROM notes ORDER BY id DESC LIMIT 50"), m_db);
    while (q.next()) result.append(QVariantMap{{"id", q.value(0)}, {"text", q.value(1)}, {"createdAt", q.value(2)}});
    return result;
}

bool Backend::addNote(const QString &text) {
    if (tidy(text).isEmpty() || text.size() > 600) return false;
    QSqlQuery q(m_db); q.prepare(QStringLiteral("INSERT INTO notes(text,created_at) VALUES(?,?)"));
    q.addBindValue(tidy(text)); q.addBindValue(isoNow());
    if (!q.exec()) return false; changed(); return true;
}

bool Backend::removeNote(int id) {
    QSqlQuery q(m_db); q.prepare(QStringLiteral("DELETE FROM notes WHERE id=?")); q.addBindValue(id);
    if (!q.exec()) return false; changed(); return true;
}

void Backend::setActiveMemberId(int id) {
    if (!memberExists(id)) return;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT OR REPLACE INTO settings(key,value) VALUES('active_member',?)"));
    q.addBindValue(QString::number(id));
    if (!q.exec()) return;
    m_activeMemberId = id; changed();
}

void Backend::setFontScale(int scale) {
    scale = qBound(85, scale, 135);
    QSqlQuery q(m_db); q.prepare(QStringLiteral("INSERT OR REPLACE INTO settings(key,value) VALUES('font_scale',?)"));
    q.addBindValue(QString::number(scale));
    if (!q.exec()) return;
    m_fontScale = scale; emit appearanceChanged();
}

QVariantList Backend::historyForDay(const QString &date, int memberFilter) const {
    QVariantList result;
    const QDate day = parsedDate(date);
    if (!day.isValid()) return result;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT p.task_id,p.title,p.member_name,COALESCE(c.done,0),"
        "CASE WHEN s.task_id IS NULL THEN 0 ELSE 1 END,COALESCE(c.completed_at,''),"
        "COALESCE(doneBy.name,''),COALESCE(p.member_id,t.member_id,-1) "
        "FROM plan_snapshots p LEFT JOIN tasks t ON t.id=p.task_id "
        "LEFT JOIN completions c ON c.task_id=p.task_id AND c.day=p.day "
        "LEFT JOIN task_skips s ON s.task_id=p.task_id AND s.day=p.day "
        "LEFT JOIN members doneBy ON doneBy.id=c.done_by WHERE p.day=? ORDER BY COALESCE(c.done,0) DESC,p.task_id"));
    q.addBindValue(date);
    if (!q.exec()) return result;
    while (q.next()) {
        const int memberId = q.value(7).toInt();
        if (memberFilter != -2 && memberFilter != memberId) continue;
        const bool done = q.value(3).toInt() == 1;
        const bool skipped = q.value(4).toInt() == 1;
        result.append(QVariantMap{{"id", q.value(0)}, {"title", q.value(1)}, {"memberName", q.value(2)},
            {"done", done}, {"skipped", skipped}, {"status", done ? "Wykonane" : skipped ? "Pominięte" : "Niewykonane"},
            {"completedAt", q.value(5)}, {"doneByName", q.value(6)}, {"date", date}});
    }
    // Legacy database: only days after the migration have frozen snapshots.
    QSqlQuery snapshotCount(m_db);
    snapshotCount.prepare(QStringLiteral("SELECT 1 FROM plan_snapshots WHERE day=? LIMIT 1"));
    snapshotCount.addBindValue(date);
    const bool hasSnapshots = snapshotCount.exec() && snapshotCount.next();
    if (!hasSnapshots && day <= QDate::currentDate()) {
        for (const QVariant &v : tasksForDateFiltered(date, memberFilter)) {
            const QVariantMap m = v.toMap();
            const bool done = m.value("done").toBool(), skipped = m.value("skipped").toBool();
            result.append(QVariantMap{{"id", m.value("id")}, {"title", m.value("title")},
                {"memberName", m.value("memberName")}, {"done", done}, {"skipped", skipped},
                {"status", done ? "Wykonane" : skipped ? "Pominięte" : "Niewykonane"},
                {"doneByName", m.value("doneByName")}, {"date", date}});
        }
    }
    return result;
}

QVariantList Backend::historyForRange(int days, int memberFilter) const {
    QVariantList result;
    if (days < 1 || days > 365) return result;
    for (int i = days - 1; i >= 0; --i) {
        const QDate day = QDate::currentDate().addDays(-i);
        const QVariantList tasks = historyForDay(dateIso(day), memberFilter);
        int done = 0, skipped = 0;
        for (const QVariant &v : tasks) {
            if (v.toMap().value("done").toBool()) ++done;
            if (v.toMap().value("skipped").toBool()) ++skipped;
        }
        result.append(QVariantMap{{"date", dateIso(day)},
            {"label", QLocale(QLocale::Polish).toString(day, "ddd d.MM")},
            {"planned", tasks.size()}, {"done", done}, {"skipped", skipped},
            {"percent", tasks.size() ? 100 * done / tasks.size() : -1}});
    }
    return result;
}

QString Backend::exportHistoryCsv(const QString &directory) {
    const QString root = directory.isEmpty()
        ? QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) : directory;
    if (!QDir(root).exists() || !QFileInfo(root).isWritable()) {
        reportError(QStringLiteral("Wybierz istniejący katalog do eksportu historii.")); return QString();
    }
    const QString path = QDir(root).filePath(QStringLiteral("DomowyPlan-Historia-") + dateIso(QDate::currentDate()) + QStringLiteral(".csv"));
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) { reportError(file.errorString()); return QString(); }
    QTextStream stream(&file); stream.setCodec("UTF-8"); stream << QChar(0xFEFF);
    stream << "Data;Zadanie;Przypisanie;Status;Wykonał\r\n";
    for (int i = 364; i >= 0; --i) {
        const QString date = dateIso(QDate::currentDate().addDays(-i));
        for (const QVariant &v : historyForDay(date)) {
            const QVariantMap m = v.toMap();
            stream << quoteCsv(date) << ';' << quoteCsv(m.value("title").toString()) << ';'
                << quoteCsv(m.value("memberName").toString()) << ';'
                << quoteCsv(m.value("status").toString()) << ';'
                << quoteCsv(m.value("doneByName").toString()) << "\r\n";
        }
    }
    stream.flush();
    if (stream.status() != QTextStream::Ok || !file.commit()) {
        reportError(QStringLiteral("Nie udało się zapisać CSV.")); return QString();
    }
    return path;
}

QVariantList Backend::monthCalendar(const QString &monthDate) const {
    QVariantList result;
    const QDate date = parsedDate(monthDate);
    if (!date.isValid()) return result;
    const QDate first(date.year(), date.month(), 1);
    const QDate gridStart = first.addDays(1-first.dayOfWeek());
    for (int i = 0; i < 42; ++i) {
        const QDate d = gridStart.addDays(i);
        const QVariantList tasks = tasksOn(d);
        int done = 0;
        for (const QVariant &v : tasks) if (v.toMap().value("done").toBool()) ++done;
        result.append(QVariantMap{{"date", dateIso(d)}, {"day", d.day()},
            {"currentMonth", d.month() == date.month()}, {"today", d == QDate::currentDate()},
            {"planned", tasks.size()}, {"done", done}});
    }
    return result;
}

QString Backend::backupToDirectory(const QString &directory) {
    if (directory.isEmpty()) return backupNow();
    // A user-provided external path is intentionally limited to existing folders.
    if (!QFileInfo(directory).isDir() || !QFileInfo(directory).isWritable()) {
        reportError(QStringLiteral("Nie można zapisać do wybranego folderu USB.")); return QString();
    }
    // Use the existing manual JSON export, then copy it atomically to USB.
    const QString source = backupNow();
    if (source.isEmpty()) return QString();
    QFile input(source);
    if (!input.open(QIODevice::ReadOnly)) return QString();
    const QString destination = QDir(directory).filePath(QFileInfo(source).fileName());
    QSaveFile output(destination);
    if (!output.open(QIODevice::WriteOnly)) { reportError(output.errorString()); return QString(); }
    while (!input.atEnd()) {
        const QByteArray chunk = input.read(64 * 1024);
        if (output.write(chunk) != chunk.size()) { output.cancelWriting(); reportError(QStringLiteral("Błąd zapisu na USB.")); return QString(); }
    }
    if (!output.commit()) { reportError(QStringLiteral("Nie można zakończyć zapisu kopii na USB.")); return QString(); }
    return destination;
}

QVariantList Backend::availableBackups() const {
    QVariantList result;
    QDir folder(backupDirectory());
    const QFileInfoList files = folder.entryInfoList(QStringList() << "domowy-plan-*.json", QDir::Files, QDir::Time);
    for (const QFileInfo &file : files) {
        result.append(QVariantMap{{"path", file.absoluteFilePath()}, {"name", file.fileName()},
            {"size", file.size()}, {"modified", file.lastModified().toString("yyyy-MM-dd HH:mm")}});
    }
    return result;
}

QVariantMap Backend::copyTaskForDays(int id, const QString &sourceDate, int days) {
    if (days < 1 || days > 31) return {{"ok", false}};
    const QDate source = parsedDate(sourceDate);
    if (!source.isValid()) return {{"ok", false}};
    QVariantMap templateTask;
    for (const QVariant &v : tasksOn(source)) if (v.toMap().value("id").toInt() == id) templateTask = v.toMap();
    if (templateTask.isEmpty() || !m_db.transaction()) return {{"ok", false}};
    int copied = 0, duplicates = 0;
    QVariantList inserted;
    for (int i = 1; i <= days; ++i) {
        const CopyResult result = copyOccurrence(templateTask, source.addDays(i));
        if (result == CopyResult::Error) { m_db.rollback(); return {{"ok", false}}; }
        if (result == CopyResult::Copied) {
            QSqlQuery key(QStringLiteral("SELECT last_insert_rowid()"), m_db);
            if (key.next()) inserted.append(key.value(0));
            ++copied;
        } else ++duplicates;
    }
    if (!m_db.commit()) return {{"ok", false}};
    if (copied) setUndo("copy_tasks", {{"ids",inserted}}, QStringLiteral("Cofnij kopiowanie"));
    changed(); return {{"ok", true}, {"copied", copied}, {"alreadyPresent", duplicates}};
}

bool Backend::batchAssignTasks(const QVariantList &ids, int memberId) {
    if (ids.isEmpty() || !memberExists(memberId) || !m_db.transaction()) return false;
    for (const QVariant &id : ids) {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("UPDATE tasks SET member_id=? WHERE id=? AND archived_at IS NULL"));
        q.addBindValue(nullableId(memberId)); q.addBindValue(id);
        if (!q.exec() || q.numRowsAffected() != 1) { m_db.rollback(); return false; }
    }
    if (!m_db.commit()) return false;
    changed(); return true;
}
