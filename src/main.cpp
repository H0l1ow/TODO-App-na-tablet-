#include "Backend.h"

#include <QGuiApplication>
#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QMutex>
#include <QMutexLocker>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <cstdlib>

namespace {
void writeDiagnostic(QtMsgType type, const QMessageLogContext &context, const QString &message) {
    Q_UNUSED(context)
    if (type == QtDebugMsg) return;
    static QMutex mutex;
    const QMutexLocker locker(&mutex);
    const QString base = qEnvironmentVariable("LOCALAPPDATA", QDir::tempPath());
    const QString folder = QDir(base).filePath(QStringLiteral("DomowyPlan"));
    if (!QDir().mkpath(folder)) return;
    QFile file(QDir(folder).filePath(QStringLiteral("diagnostyka.log")));
    if (!file.open(QIODevice::ReadWrite | QIODevice::Append | QIODevice::Text)) return;
    if (file.size() > 1024 * 1024) {
        file.resize(0);
    }
    const char *label = (type == QtCriticalMsg || type == QtFatalMsg) ? "ERROR" : "WARN";
    const QByteArray entry = (QDateTime::currentDateTime().toString(Qt::ISODate) +
                              QStringLiteral(" [") + QString::fromLatin1(label) +
                              QStringLiteral("] ") + message + QStringLiteral("\n")).toUtf8();
    file.write(entry);
    file.close();
    if (type == QtFatalMsg) std::abort();
}
} // namespace

int main(int argc, char *argv[]) {
    // Logs also capture Qt QML and platform-plugin initialization warnings.
    // The log is local and does not contain telemetry or network reporting.
    qInstallMessageHandler(writeDiagnostic);
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QCoreApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("DomowyPlan"));
    QCoreApplication::setApplicationName(QStringLiteral("DomowyPlan"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.3.0"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Domowy Plan - offline TODO na tablet"));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption fullScreen(QStringList() << "f" << "fullscreen", "Uruchom w pelnym ekranie");
    const QCommandLineOption dataDirectory("data-dir", "Folder lokalnej bazy (testy/portable)", "folder");
    parser.addOption(fullScreen);
    parser.addOption(dataDirectory);
    parser.process(app);

    Backend backend(parser.value(dataDirectory));
    if (!backend.ready()) {
        qCritical().noquote() << "Nie mozna uruchomic bazy:" << backend.errorMessage();
        return 1;
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.rootContext()->setContextProperty("startFullscreen", parser.isSet(fullScreen));
    engine.load(QUrl(QStringLiteral("qrc:/qml/App.qml")));
    if (engine.rootObjects().isEmpty()) return 2;
    return app.exec();
}
