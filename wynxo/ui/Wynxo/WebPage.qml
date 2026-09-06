import QtQuick
import QtWebEngine

/*!
    The rendering half of the browser panel, kept separate on purpose.

    Qt WebEngine ships with the full PySide6 distribution but not with
    PySide6-Essentials, and `import QtWebEngine` fails the whole file when it is
    missing. Isolating it here means an installation without it loses this one
    component and keeps the rest of the panel; BrowserView loads it through a
    Loader and shows its fallback when the load fails.

    The profile is Qt's default, which is off the record: no cookies, cache or
    history are written to disk, matching the rest of the application.
*/
Item {
    id: page
    property url target: ""

    readonly property bool canGoBack: view.canGoBack
    readonly property bool canGoForward: view.canGoForward
    readonly property bool loading: view.loading
    readonly property real progress: view.loadProgress / 100
    readonly property string title: view.title

    function back() { view.goBack(); }
    function forward() { view.goForward(); }
    function reload() { view.reload(); }
    function stopLoading() { view.stop(); }

    WebEngineView {
        id: view
        anchors.fill: parent
        url: page.target
        backgroundColor: Theme.surface

        // Nothing on a page needs to reach the rest of the machine: this is a
        // window onto the web, not a way into the user's files.
        settings.localContentCanAccessFileUrls: false
        settings.localContentCanAccessRemoteUrls: false
        settings.screenCaptureEnabled: false
        settings.javascriptCanOpenWindows: false
        settings.javascriptCanAccessClipboard: false
        settings.allowWindowActivationFromJavaScript: false

        // A link that wants a new window opens here instead, so a page can
        // never put a chromeless window on the user's screen.
        onNewWindowRequested: function(request) { request.openIn(view); }
    }
}
