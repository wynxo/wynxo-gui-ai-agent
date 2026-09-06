"""Measure the real application shell across sidebar and window states."""
import json
from pathlib import Path

from PySide6.QtCore import QObject, QPointF, QUrl, QMetaObject
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication

from wynxo.demo import DemoController

QQuickStyle.setStyle('Basic')
app = QApplication([])
controller = DemoController('empty')
engine = QQmlApplicationEngine()
ui = Path(__file__).resolve().parents[1] / 'wynxo' / 'ui'
engine.addImportPath(str(ui))
engine.rootContext().setContextProperty('bridge', controller)
engine.load(QUrl.fromLocalFile(str(ui / 'Main.qml')))
window = engine.rootObjects()[0]
result = []

def record(label):
    QTest.qWait(250)
    controls = [item for item in window.findChildren(QObject)
                if item.objectName() in {'headerSidebarToggle', 'sidebarCollapseButton'}
                and item.property('visible')]
    composer = window.findChild(QObject, 'mainComposer')
    viewport = window.findChild(QObject, 'conversationViewport')
    panel = window.findChild(QObject, 'sidePanel')
    position = composer.mapToScene(QPointF(0, 0))
    viewport_position = viewport.mapToScene(QPointF(0, 0))
    panel_position = panel.mapToScene(QPointF(0, 0)) if panel else QPointF(0, 0)
    result.append({'state': label, 'toggles': len(controls),
                   'composer_inside': position.x() >= 0 and position.y() >= 0
                    and position.x() + composer.width() <= window.width()
                    and position.y() + composer.height() <= window.height(),
                   'no_overlap': viewport_position.y() + viewport.height() <= position.y(),
                   'panel_docked': bool(panel and panel.property('visible')),
                   'panel_inside': not (panel and panel.property('visible'))
                    or panel_position.x() + panel.width() <= window.width() + 1,
                   'clear_of_panel': not (panel and panel.property('visible'))
                    or position.x() + composer.width() <= panel_position.x()})

try:
    record('expanded')
    # The panel is the third column; it must not push the conversation out of
    # the window, and it has to give up its dock when there is no room for it.
    controller.setPanelOpen(True)
    record('panel-open')
    controller.setSidebarCollapsed(True)
    record('collapsed')
    window.setWidth(560)
    window.setHeight(520)
    record('narrow')
    QMetaObject.invokeMethod(window, 'toggleSidebar')
    record('drawer')
    window.setWidth(1400)
    window.setHeight(900)
    record('resized-with-drawer-open')
    controller.setSidebarCollapsed(False)
    record('expanded-again')
    print(json.dumps(result))
finally:
    window.close()
    controller.shutdown()
