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
    Q_PROPERTY(QVariantList categories READ categories NOTIFY dataChanged)
    Q_PROPERTY(QVariantList dayTemplates READ dayTemplates NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap dashboard READ dashboard NOTIFY dataChanged)
    Q_PROPERTY(QVariantList weekDays READ weekDays NOTIFY dataChanged)
    Q_PROPERTY(QVariantList historyDays READ historyDays NOTIFY dataChanged)
    Q_PROPERTY(QVariantList recentActivity READ recentActivity NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap historyStats READ historyStats NOTIFY dataChanged)
    Q_PROPERTY(QString themeMode READ themeMode NOTIFY appearanceChanged)
    Q_PROPERTY(bool darkMode READ darkMode NOTIFY appearanceChanged)
    Q_PROPERTY(QString databasePath READ databasePath CONSTANT)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)
    Q_PROPERTY(QString undoLabel READ undoLabel NOTIFY dataChanged)
    Q_PROPERTY(int activeMemberId READ activeMemberId NOTIFY dataChanged)
    Q_PROPERTY(int fontScale READ fontScale NOTIFY appearanceChanged)
    Q_PROPERTY(qint64 databaseBytes READ databaseBytes NOTIFY dataChanged)
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
    QString undoLabel() const { return m_undoLabel; }
    int activeMemberId() const { return m_activeMemberId; }
    int fontScale() const { return m_fontScale; }
    qint64 databaseBytes() const;

    Q_INVOKABLE bool addTask(const QString &title, const QString &startDate,
                             const QString &recurrence = QStringLiteral("once"),
                             int weekdayMask = 0, int memberId = -1);
    Q_INVOKABLE bool setTaskDone(int taskId, const QString &date, bool done, int doneBy = -1);
    Q_INVOKABLE bool setTaskSkipped(int taskId, const QString &date, bool skipped);
    Q_INVOKABLE bool createTask(const QString &title, const QString &startDate, const QString &recurrence,
                     int weekdayMask, int memberId, int intervalDays, const QString &endDate,
                     const QString &note, int categoryId, const QString &dueTime = QString());
    Q_INVOKABLE bool editTask(int taskId, const QString &title, const QString &startDate,
                     const QString &recurrence, int weekdayMask, int memberId,
                     int intervalDays, const QString &endDate, const QString &note, int categoryId,
                     const QString &dueTime = QString());
    Q_INVOKABLE QVariantMap taskDetails(int taskId) const;
    Q_INVOKABLE QVariantList tasksForDateFiltered(const QString &date, int memberId) const;
    Q_INVOKABLE QVariantList overdueTasks() const;
    Q_INVOKABLE bool moveTaskToDate(int taskId, const QString &targetDate);
    Q_INVOKABLE bool moveOverdueSelection(const QVariantList &taskIds, const QString &targetDate);
    Q_INVOKABLE QVariantMap copyDayToDate(const QString &source, const QString &target,
                                          bool includeCompleted, int memberFilter = -2);
    Q_INVOKABLE bool copyTaskToDate(int taskId, const QString &sourceDate, const QString &targetDate);
    Q_INVOKABLE QVariantMap copyTaskForDays(int taskId, const QString &sourceDate, int days);
    Q_INVOKABLE bool batchAssignTasks(const QVariantList &ids, int memberId);
    Q_INVOKABLE bool setTaskAssignee(int taskId, int memberId);
    Q_INVOKABLE bool copyTaskToNextDay(int taskId, const QString &sourceDate);
    Q_INVOKABLE QVariantMap copyDayToNextDay(const QString &sourceDate, bool includeCompleted);
    Q_INVOKABLE bool archiveTask(int taskId);
    Q_INVOKABLE bool moveOverdueToToday();
    Q_INVOKABLE bool addShoppingItem(const QString &name, const QString &quantity, const QString &category = QStringLiteral("Inne"));
    Q_INVOKABLE bool setShoppingDone(int itemId, bool done);
    Q_INVOKABLE bool removeShoppingItem(int itemId);
    Q_INVOKABLE bool clearPurchased();
    Q_INVOKABLE bool setShoppingQuantity(int itemId, const QString &quantity);
    Q_INVOKABLE QVariantList shoppingCatalog() const;
    Q_INVOKABLE bool saveCatalogProduct(const QString &name, const QString &category,
                                        const QString &quantity, bool favorite);
    Q_INVOKABLE bool deleteCatalogProduct(int id);
    Q_INVOKABLE bool toggleCatalogFavorite(int id);
    Q_INVOKABLE bool addShoppingFromCatalog(int id);
    Q_INVOKABLE QVariantMap repeatRecentShopping(int days);
    Q_INVOKABLE QVariantList shoppingSets() const;
    Q_INVOKABLE bool saveShoppingSet(const QString &name);
    Q_INVOKABLE QVariantMap applyShoppingSet(int id);
    Q_INVOKABLE bool deleteShoppingSet(int id);
    Q_INVOKABLE QVariantList categories() const;
    Q_INVOKABLE bool saveCategory(int id, const QString &name, const QString &symbol);
    Q_INVOKABLE bool deleteCategory(int id);
    Q_INVOKABLE QVariantList quickTemplates(int categoryId) const;
    Q_INVOKABLE bool saveQuickTemplate(int id, int categoryId, const QString &title,
                                       int defaultMemberId, bool favorite);
    Q_INVOKABLE bool deleteQuickTemplate(int id);
    Q_INVOKABLE bool toggleQuickFavorite(int id);
    Q_INVOKABLE bool addFromQuickTemplate(int templateId, const QString &date, int chosenMemberId);
    Q_INVOKABLE QVariantList dayTemplates() const;
    Q_INVOKABLE bool saveDayTemplate(const QString &name, const QString &date);
    Q_INVOKABLE QVariantMap applyDayTemplate(int templateId, const QString &date);
    Q_INVOKABLE bool deleteDayTemplate(int id);
    Q_INVOKABLE QVariantList subTasks(int taskId, const QString &day) const;
    Q_INVOKABLE bool addSubTask(int taskId, const QString &title);
    Q_INVOKABLE bool setSubTaskDone(int subTaskId, const QString &day, bool done);
    Q_INVOKABLE bool deleteSubTask(int subTaskId);
    Q_INVOKABLE QVariantList notes() const;
    Q_INVOKABLE bool addNote(const QString &text);
    Q_INVOKABLE bool removeNote(int id);
    Q_INVOKABLE bool addMember(const QString &name);
    Q_INVOKABLE bool removeMember(int memberId);
    Q_INVOKABLE void setThemeMode(const QString &mode);
    Q_INVOKABLE void setActiveMemberId(int memberId);
    Q_INVOKABLE void setFontScale(int scale);
    Q_INVOKABLE bool undoLast();
    Q_INVOKABLE QVariantList historyForDay(const QString &date, int memberFilter = -2) const;
    Q_INVOKABLE QVariantList historyForRange(int days, int memberFilter = -2) const;
    Q_INVOKABLE QString exportHistoryCsv(const QString &directory = QString());
    Q_INVOKABLE QVariantList monthCalendar(const QString &monthDate) const;
    Q_INVOKABLE QString dateOffset(const QString &date, int offset) const;
    Q_INVOKABLE int weekdayBit(const QString &date) const;
    Q_INVOKABLE QString dateLabel(const QString &date) const;
    Q_INVOKABLE QString backupNow();
    Q_INVOKABLE QString backupToDirectory(const QString &directory);
    Q_INVOKABLE bool restoreLatestBackup();
    Q_INVOKABLE QVariantList availableBackups() const;
    Q_INVOKABLE bool restoreBackup(const QString &path);
    Q_INVOKABLE bool showOnScreenKeyboard();
    Q_INVOKABLE void exitApplication();

signals:
    void dataChanged();
    void appearanceChanged();
    void errorChanged();

private:
    bool openDatabase();
    bool initializeSchema();
    bool ensureColumn(const QString &table, const QString &column, const QString &definition);
    void seedDefaults();
    void snapshotToday();
    void setUndo(const QString &kind, const QVariantMap &details, const QString &label);
    bool memberExists(int memberId) const;
    bool recurrenceValid(const QString &recurrence, int mask, int every, const QString &endDate, const QString &startDate) const;
    bool runSql(const QString &statement);
    void reportError(const QString &message) const;
    void changed();
    QVariantList tasksOn(const QDate &date) const;
    int overdueCount(const QDate &date) const;
    int shoppingOpenCount() const;
    static QDate parsedDate(const QString &value);
    static QString isoNow();
    static bool scheduleMatches(const QString &frequency, const QDate &start,
                                int weekdayMask, const QDate &on,
                                int intervalDays = 1, const QDate &endDate = QDate());
    enum class CopyResult { Copied, AlreadyPresent, Error };
    CopyResult copyOccurrence(const QVariantMap &sourceTask, const QDate &targetDate);
    QString backupDirectory() const;

    QSqlDatabase m_db;
    QString m_dbPath;
    QString m_themeMode = QStringLiteral("light");
    QString m_undoKind;
    QVariantMap m_undoDetails;
    QString m_undoLabel;
    int m_activeMemberId = -1;
    int m_fontScale = 100;
    mutable QString m_error;
    bool m_ready = false;
    QDate m_lastDate;
    bool m_lastDark = false;
    QTimer m_clock;
};
