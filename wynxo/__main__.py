"""Native desktop entry point: python -m wynxo."""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Wynxo — local desktop copilot")
    parser.add_argument("--version", action="store_true")
    parser.add_argument("--screenshot", metavar="PNG", help=argparse.SUPPRESS)
    parser.add_argument("--smoke-test", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.version:
        from . import __version__
        print(__version__)
        return 0
    from PySide6.QtCore import QTimer, QUrl
    from PySide6.QtGui import QFont, QIcon
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtQuickControls2 import QQuickStyle
    from PySide6.QtWidgets import QApplication
    from .controller import Controller
    QQuickStyle.setStyle("Basic")
    app = QApplication(sys.argv[:1])
    app.setApplicationName("Wynxo")
    app.setOrganizationName("Wynxo")
    app.setDesktopFileName("io.github.wynxo.Wynxo")
    app.setFont(QFont("Inter", 10))
    icon = Path(__file__).parent / "ui" / "wynxo.svg"
    if icon.exists(): app.setWindowIcon(QIcon(str(icon)))
    controller = Controller(autoconnect=not args.smoke_test)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("bridge", controller)
    engine.load(QUrl.fromLocalFile(str(Path(__file__).parent / "ui" / "Main.qml")))
    if not engine.rootObjects():
        controller.shutdown()
        return 1
    if args.screenshot:
        def capture():
            root = engine.rootObjects()[0]
            if not root.grabWindow().save(args.screenshot):
                print("Could not save screenshot", file=sys.stderr)
                app.exit(1)
            else:
                # Close the QML window while the context bridge is still alive;
                # this avoids evaluating bindings against a cleared context on
                # headless smoke runs and follows the same path as user exit.
                root.close()
                QTimer.singleShot(0, app.quit)
        QTimer.singleShot(1600, capture)
    elif args.smoke_test:
        def finish_smoke():
            root = engine.rootObjects()[0]
            root.close()
            QTimer.singleShot(0, app.quit)
        QTimer.singleShot(800, finish_smoke)
    # Tear down after Qt has destroyed the QML object tree. Closing the Python
    # bridge while bindings are still live makes QML briefly evaluate it as null
    # during shutdown and produces noisy TypeError diagnostics.
    exit_code = app.exec()
    controller.shutdown()
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
