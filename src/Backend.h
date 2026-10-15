#pragma once

#include <QObject>
#include <QDate>
#include <QSqlDatabase>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>

// All data stays in one local SQLite database. No networking or cloud SDKs.
class Backend final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready CONSTANT)
    Q_PROPERTY(QString today READ today NOTIFY dataChanged)
    Q_PROPERTY(QString todayLabel READ todayLabel NOTIFY dataChanged)
    Q_PROPERTY(QVariantList todayTasks READ todayTasks NOTIFY dataChanged)
    Q_PROPERTY(QVariantList shoppingItems READ shoppingItems NOTIFY dataChanged)
    Q_PROPERTY(QVariantList members READ members NOTIFY dataChanged)
    Q_PROPERTY(QVariantList assignees READ assignees NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap dashboard READ dashboard NOTIFY dataChanged)
    Q_PROPERTY(QVariantList weekDays READ weekDays NOTIFY dataChanged)
    Q_PROPERTY(QVariantList historyDays READ historyDays NOTIFY dataChanged)
    Q_PROPERTY(QVariantList recentActivity READ recentActivity NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap historyStats READ historyStats NOTIFY dataChanged)
    Q_PROPERTY(QString themeMode READ themeMode NOTIFY appearanceChanged)
    Q_PROPERTY(bool darkMode READ darkMode NOTIFY appearanceChanged)
    Q_PROPERTY(QString databasePath READ databasePath CONSTANT)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)
public:
    explicit Backend(const QString &dataDirectory = {}, QObject *parent = nullptr);
    ~Backend() override;

    bool ready() const { return m_ready; }
    QString today() const;
    QString todayLabel() const;
    QVariantList todayTasks() const;
    QVariantList tasksForDate(const QString &dateString) const;
    QVariantList shoppingItems() const;
    QVariantList members() const;
    QVariantList assignees() const;
    QVariantMap dashboard() const;
    QVariantList weekDays() const;
    QVariantList historyDays() const;
    QVariantList recentActivity() const;
    QVariantMap historyStats() const;
    QString themeMode() const { return m_themeMode; }
    bool darkMode() const;
    QString databasePath() const { return m_dbPath; }
    QString errorMessage() const { return m_error; }

    Q_INVOKABLE bool addTask(const QString &title, const QString &startDate,
                             const QString &recurrence = QStringLiteral("once"),
                             int weekdayMask = 0, int memberId = -1);
    Q_INVOKABLE bool setTaskDone(int taskId, const QString &date, bool done);
    Q_INVOKABLE bool setTaskAssignee(int taskId, int memberId);
    Q_INVOKABLE bool copyTaskToNextDay(int taskId, const QString &sourceDate);
    Q_INVOKABLE QVariantMap copyDayToNextDay(const QString &sourceDate, bool includeCompleted);
    Q_INVOKABLE bool archiveTask(int taskId);
    Q_INVOKABLE bool moveOverdueToToday();
    Q_INVOKABLE bool addShoppingItem(const QString &name, const QString &quantity);
    Q_INVOKABLE bool setShoppingDone(int itemId, bool done);
    Q_INVOKABLE bool removeShoppingItem(int itemId);
    Q_INVOKABLE bool clearPurchased();
    Q_INVOKABLE bool addMember(const QString &name);
    Q_INVOKABLE bool removeMember(int memberId);
    Q_INVOKABLE void setThemeMode(const QString &mode);
    Q_INVOKABLE QString dateOffset(const QString &date, int offset) const;
    Q_INVOKABLE int weekdayBit(const QString &date) const;
    Q_INVOKABLE QString dateLabel(const QString &date) const;
    Q_INVOKABLE QString backupNow();
    Q_INVOKABLE bool restoreLatestBackup();
    Q_INVOKABLE bool showOnScreenKeyboard();
    Q_INVOKABLE void exitApplication();

signals:
    void dataChanged();
    void appearanceChanged();
    void errorChanged();

private:
    bool openDatabase();
    bool initializeSchema();
    bool runSql(const QString &statement);
    void reportError(const QString &message) const;
    void changed();
    QVariantList tasksOn(const QDate &date) const;
    int overdueCount(const QDate &date) const;
    int shoppingOpenCount() const;
    static QDate parsedDate(const QString &value);
    static QString isoNow();
    static bool scheduleMatches(const QString &frequency, const QDate &start,
                                int weekdayMask, const QDate &on);
    enum class CopyResult { Copied, AlreadyPresent, Error };
    CopyResult copyOccurrence(const QVariantMap &sourceTask, const QDate &targetDate);
    QString backupDirectory() const;

    QSqlDatabase m_db;
    QString m_dbPath;
    QString m_themeMode = QStringLiteral("light");
    mutable QString m_error;
    bool m_ready = false;
    QDate m_lastDate;
    bool m_lastDark = false;
    QTimer m_clock;
};
