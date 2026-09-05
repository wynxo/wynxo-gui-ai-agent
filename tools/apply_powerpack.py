from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path):
    return (ROOT / path).read_text(encoding="utf-8")


def save(path, text):
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(path, old, new):
    text = load(path)
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected exactly one match, found {count}: {old[:80]!r}")
    save(path, text.replace(old, new, 1))


def insert_before(path, marker, insertion):
    text = load(path)
    if text.count(marker) != 1:
        raise RuntimeError(f"{path}: marker count for {marker[:80]!r} is {text.count(marker)}")
    save(path, text.replace(marker, insertion + marker, 1))


def replace_between(path, start, end, replacement):
    text = load(path)
    i = text.find(start)
    if i < 0:
        raise RuntimeError(f"{path}: missing start marker {start!r}")
    j = text.find(end, i + len(start))
    if j < 0:
        raise RuntimeError(f"{path}: missing end marker {end!r}")
    save(path, text[:i] + replacement + text[j:])


# --- SQLite: pinned conversations, backward-compatible migration. ---
replace_once(
    "wynxo/storage.py",
    "        self._db.commit()\n\n    def create_conversation",
    "        self._db.commit()\n        columns = {row[\"name\"] for row in self._db.execute(\"PRAGMA table_info(conversations)\")}\n        if \"pinned\" not in columns:\n            self._db.execute(\"ALTER TABLE conversations ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0\")\n            self._db.commit()\n\n    def create_conversation",
)
replace_once(
    "wynxo/storage.py",
    "        item = {\"id\": uuid.uuid4().hex, \"title\": title.strip()[:200] or \"New conversation\",\n                \"model\": model, \"created_at\": now, \"updated_at\": now}\n        with self._lock, self._db:\n            self._db.execute(\"INSERT INTO conversations VALUES (:id,:title,:model,:created_at,:updated_at)\", item)",
    "        item = {\"id\": uuid.uuid4().hex, \"title\": title.strip()[:200] or \"New conversation\",\n                \"model\": model, \"created_at\": now, \"updated_at\": now, \"pinned\": 0}\n        with self._lock, self._db:\n            self._db.execute(\"INSERT INTO conversations (id,title,model,created_at,updated_at,pinned) \"\n                             \"VALUES (:id,:title,:model,:created_at,:updated_at,:pinned)\", item)",
)
replace_once(
    "wynxo/storage.py",
    "SELECT * FROM conversations ORDER BY updated_at DESC, id DESC",
    "SELECT * FROM conversations ORDER BY pinned DESC, updated_at DESC, id DESC",
)
insert_before(
    "wynxo/storage.py",
    "    def delete_conversation(self, conversation_id: str) -> None:\n",
    "    def set_pinned(self, conversation_id: str, pinned: bool) -> None:\n        with self._lock, self._db:\n            self._db.execute(\"UPDATE conversations SET pinned=?,updated_at=? WHERE id=?\",\n                             (1 if pinned else 0, time.time(), conversation_id))\n\n",
)


# --- Engine: real Ollama runtime controls + richer generation metrics. ---
replace_once(
    "wynxo/engine.py",
    "            emit: Callable[[dict], None], think: bool = False, max_steps: int = 20) -> list[dict]:",
    "            emit: Callable[[dict], None], think: bool = False, max_steps: int = 20,\n            num_ctx: int = 16384, temperature: float = 0.7, keep_alive: str = \"5m\") -> list[dict]:",
)
replace_once(
    "wynxo/engine.py",
    "        max_steps = max(1, min(int(max_steps), 100))\n        active_message: dict | None = None",
    "        max_steps = max(1, min(int(max_steps), 100))\n        num_ctx = max(2048, min(int(num_ctx), 131072))\n        temperature = max(0.0, min(float(temperature), 2.0))\n        keep_alive = str(keep_alive).strip()[:32] or \"5m\"\n        active_message: dict | None = None",
)
replace_once(
    "wynxo/engine.py",
    "                payload = {\"model\": model, \"messages\": [{\"role\": \"system\", \"content\": system}] + history,\n                           \"options\": {\"num_ctx\": 16384}, \"keep_alive\": \"5m\"}",
    "                payload = {\"model\": model, \"messages\": [{\"role\": \"system\", \"content\": system}] + history,\n                           \"options\": {\"num_ctx\": num_ctx, \"temperature\": temperature},\n                           \"keep_alive\": keep_alive}",
)
replace_once(
    "wynxo/engine.py",
    "                        event(\"metrics\", tokens=tokens, tokens_per_second=round(tokens * 1e9 / duration, 1) if duration else 0)",
    "                        event(\"metrics\", tokens=tokens,\n                              prompt_tokens=chunk.get(\"prompt_eval_count\") or 0,\n                              cached_prompt_tokens=chunk.get(\"prompt_eval_cached_count\") or 0,\n                              load_ms=round((chunk.get(\"load_duration\") or 0) / 1e6, 1),\n                              total_ms=round((chunk.get(\"total_duration\") or 0) / 1e6, 1),\n                              tokens_per_second=round(tokens * 1e9 / duration, 1) if duration else 0)",
)


# --- Controller: presets, tuning, retry, duplicate, clear, pin, metrics. ---
replace_once(
    "wynxo/controller.py",
    "from .storage import Store\n\n\nclass Messages",
    "from .storage import Store\n\n\ndef _bounded_int(value, low, high, default):\n    try:\n        return max(low, min(int(value), high))\n    except (TypeError, ValueError):\n        return default\n\n\ndef _bounded_float(value, low, high, default):\n    try:\n        return max(low, min(float(value), high))\n    except (TypeError, ValueError):\n        return default\n\n\nclass Messages",
)
insert_before(
    "wynxo/controller.py",
    "    def __init__(self, store=None, desktop=None, autoconnect=True):\n",
    "    RUNTIME_PRESETS = {\n        \"Fast\": {\"num_ctx\": 8192, \"temperature\": 0.35, \"keep_alive\": \"2m\", \"max_steps\": 12},\n        \"Balanced\": {\"num_ctx\": 16384, \"temperature\": 0.7, \"keep_alive\": \"5m\", \"max_steps\": 20},\n        \"Deep\": {\"num_ctx\": 32768, \"temperature\": 0.8, \"keep_alive\": \"15m\", \"max_steps\": 40},\n    }\n\n",
)
replace_once(
    "wynxo/controller.py",
    "        self._solid_background = bool(self.store.get_setting(\"solid_background\", True))\n        self._models = []",
    "        self._solid_background = bool(self.store.get_setting(\"solid_background\", True))\n        self._num_ctx = _bounded_int(self.store.get_setting(\"num_ctx\", 16384), 2048, 131072, 16384)\n        self._temperature = _bounded_float(self.store.get_setting(\"temperature\", 0.7), 0.0, 2.0, 0.7)\n        self._keep_alive = str(self.store.get_setting(\"keep_alive\", \"5m\")).strip()[:32] or \"5m\"\n        self._max_steps = _bounded_int(self.store.get_setting(\"max_steps\", 20), 1, 100, 20)\n        self._runtime_preset = str(self.store.get_setting(\"runtime_preset\", \"Balanced\"))\n        if self._runtime_preset not in self.RUNTIME_PRESETS and self._runtime_preset != \"Custom\":\n            self._runtime_preset = \"Custom\"\n        self._run_metrics = {\"tokens\": 0, \"prompt_tokens\": 0, \"cached_prompt_tokens\": 0,\n                             \"load_ms\": 0.0, \"total_ms\": 0.0, \"tokens_per_second\": 0.0}\n        self._models = []",
)
insert_before(
    "wynxo/controller.py",
    "    @Property(\"QVariantList\", notify=tasksChanged)\n    def tasks(self): return self._tasks\n",
    "    @Property(int, notify=changed)\n    def numCtx(self): return self._num_ctx\n    @Property(float, notify=changed)\n    def temperature(self): return self._temperature\n    @Property(str, notify=changed)\n    def keepAlive(self): return self._keep_alive\n    @Property(int, notify=changed)\n    def maxSteps(self): return self._max_steps\n    @Property(str, notify=changed)\n    def runtimePreset(self): return self._runtime_preset\n    @Property(str, notify=changed)\n    def runtimeSummary(self):\n        return f\"{self._runtime_preset} · {self._num_ctx // 1024}K ctx · T{self._temperature:g} · {self._max_steps} actions\"\n    @Property(str, notify=changed)\n    def runMetricSummary(self):\n        metrics = self._run_metrics\n        if not metrics.get(\"tokens\") and not metrics.get(\"prompt_tokens\"):\n            return \"No generation metrics yet\"\n        seconds = metrics.get(\"total_ms\", 0.0) / 1000.0\n        return (f\"{metrics.get('tokens', 0)} out · {metrics.get('prompt_tokens', 0)} prompt · \"\n                f\"{metrics.get('tokens_per_second', 0.0):.1f} tok/s · {seconds:.1f}s\")\n    @Property(bool, notify=changed)\n    def canRegenerate(self):\n        return bool(self._task_id and self._history and not self._busy and self._online and not self.desktopEnabled)\n    @Property(bool, notify=changed)\n    def taskPinned(self):\n        return any(item.get(\"id\") == self._task_id and bool(item.get(\"pinned\")) for item in self._tasks)\n",
)
insert_before(
    "wynxo/controller.py",
    "    @staticmethod\n    def _normalise_accent(value):\n",
    "    def _persist_runtime(self):\n        for key, value in ((\"num_ctx\", self._num_ctx), (\"temperature\", self._temperature),\n                           (\"keep_alive\", self._keep_alive), (\"max_steps\", self._max_steps),\n                           (\"runtime_preset\", self._runtime_preset)):\n            self.store.set_setting(key, value)\n\n    @Slot(str)\n    def applyRuntimePreset(self, name):\n        if self._busy or name not in self.RUNTIME_PRESETS:\n            return\n        preset = self.RUNTIME_PRESETS[name]\n        self._num_ctx = preset[\"num_ctx\"]\n        self._temperature = preset[\"temperature\"]\n        self._keep_alive = preset[\"keep_alive\"]\n        self._max_steps = preset[\"max_steps\"]\n        self._runtime_preset = name\n        self._persist_runtime()\n        self.changed.emit()\n        self.toast.emit(f\"{name} runtime preset applied\")\n\n    @Slot(str, str, str, str, result=bool)\n    def saveRuntimeSettings(self, num_ctx, temperature, keep_alive, max_steps):\n        if self._busy:\n            self.toast.emit(\"Stop the current task before changing runtime settings.\")\n            return False\n        try:\n            ctx = int(str(num_ctx).strip())\n            temp = float(str(temperature).strip())\n            steps = int(str(max_steps).strip())\n        except ValueError:\n            self._show_error(\"Runtime values must be valid numbers.\")\n            return False\n        keep = str(keep_alive).strip()\n        if not 2048 <= ctx <= 131072:\n            self._show_error(\"Context size must be between 2048 and 131072 tokens.\")\n            return False\n        if not 0.0 <= temp <= 2.0:\n            self._show_error(\"Temperature must be between 0 and 2.\")\n            return False\n        if not 1 <= steps <= 100:\n            self._show_error(\"Desktop action budget must be between 1 and 100.\")\n            return False\n        if not keep or len(keep) > 32 or any(ch.isspace() for ch in keep):\n            self._show_error(\"Keep-alive must look like 5m, 30s, 0, or -1.\")\n            return False\n        self._num_ctx, self._temperature, self._keep_alive, self._max_steps = ctx, temp, keep, steps\n        self._runtime_preset = \"Custom\"\n        self._persist_runtime()\n        self._error = \"\"\n        self.changed.emit()\n        self.toast.emit(\"Runtime settings saved\")\n        return True\n\n",
)
replace_once(
    "wynxo/controller.py",
    "        self._thinking_text = \"\"\n        self.activityChanged.emit()\n        self.changed.emit()\n        self.focusComposer.emit()",
    "        self._thinking_text = \"\"\n        self._run_metrics = {\"tokens\": 0, \"prompt_tokens\": 0, \"cached_prompt_tokens\": 0,\n                             \"load_ms\": 0.0, \"total_ms\": 0.0, \"tokens_per_second\": 0.0}\n        self.activityChanged.emit()\n        self.changed.emit()\n        self.focusComposer.emit()",
)
replace_once(
    "wynxo/controller.py",
    "        self._thinking_text = \"\"\n        self._status = \"Ready when you are\"\n        self.activityChanged.emit()\n        self.changed.emit()",
    "        self._thinking_text = \"\"\n        self._run_metrics = {\"tokens\": 0, \"prompt_tokens\": 0, \"cached_prompt_tokens\": 0,\n                             \"load_ms\": 0.0, \"total_ms\": 0.0, \"tokens_per_second\": 0.0}\n        self._status = \"Ready when you are\"\n        self.activityChanged.emit()\n        self.changed.emit()",
)
replace_between(
    "wynxo/controller.py",
    "    @Slot(str)\n    def send(self, text):\n",
    "    def _on_event(self, event):\n",
    '''    def _start_run(self, history):
        self._busy = True
        self._error = ""
        self._status = "Thinking about your task"
        self._token_rate = "—"
        self._thinking_text = ""
        self._turn_had_message = False
        self._activity = []
        self._run_metrics = {"tokens": 0, "prompt_tokens": 0, "cached_prompt_tokens": 0,
                             "load_ms": 0.0, "total_ms": 0.0, "tokens_per_second": 0.0}
        self.activityChanged.emit()
        self._refresh_tasks()
        self.changed.emit()
        engine = AgentEngine(OllamaClient(self._endpoint), self.desktop)
        model, enabled, think = self._model, self.desktopEnabled, self._think
        num_ctx, temperature = self._num_ctx, self._temperature
        keep_alive, max_steps = self._keep_alive, self._max_steps
        self._run_job = self._job(
            lambda cancel, emit: engine.run(list(history), model, enabled, cancel, emit, think=think,
                max_steps=max_steps, num_ctx=num_ctx, temperature=temperature, keep_alive=keep_alive),
            self._run_done, self._run_failed, self._on_event,
        )

    @Slot(str)
    def send(self, text):
        text = text.strip()
        if not text or self._busy or self._connecting: return
        if not self._online:
            self._show_error("Connect to Ollama in Settings before sending a task.")
            return
        if not self._task_id:
            task = self.store.create_conversation(text[:64], self._model)
            self._task_id, self._task_title = task["id"], task["title"]
        self._history.append({"role": "user", "content": text})
        self.store.set_messages(self._task_id, self._history, self._model)
        self.messages.append("user", text)
        self._start_run(list(self._history))

    @Slot()
    def regenerate(self):
        if self._busy or not self._task_id or not self._online:
            return
        if self.desktopEnabled:
            self.toast.emit("Disable desktop control before regenerating so actions are not repeated.")
            return
        history = list(self._history)
        while history and history[-1].get("role") != "user":
            history.pop()
        if not history:
            self.toast.emit("There is no user message to regenerate.")
            return
        self._history = history
        self.store.set_messages(self._task_id, history, self._model)
        self.messages.replace(history)
        self._start_run(history)

    @Slot()
    def duplicateTask(self):
        if self._busy or not self._task_id:
            return
        task = self.store.create_conversation(f"{self._task_title} copy"[:200], self._model)
        self.store.set_messages(task["id"], list(self._history), self._model)
        self._refresh_tasks()
        self.openTask(task["id"])
        self.toast.emit("Task duplicated")

    @Slot()
    def clearTask(self):
        if self._busy or not self._task_id:
            return
        self._history = []
        self.store.set_messages(self._task_id, [], self._model)
        self.messages.replace([])
        self._activity = []
        self._thinking_text = ""
        self._token_rate = "—"
        self._run_metrics = {"tokens": 0, "prompt_tokens": 0, "cached_prompt_tokens": 0,
                             "load_ms": 0.0, "total_ms": 0.0, "tokens_per_second": 0.0}
        self._status = "Ready when you are"
        self.activityChanged.emit()
        self._refresh_tasks()
        self.changed.emit()
        self.toast.emit("Conversation cleared")

    @Slot(str)
    def togglePin(self, task_id):
        task = self.store.get_conversation(task_id)
        if not task:
            return
        self.store.set_pinned(task_id, not bool(task.get("pinned")))
        self._refresh_tasks()
        self.changed.emit()

''',
)
replace_once(
    "wynxo/controller.py",
    "        elif kind == \"metrics\":\n            rate = event.get(\"tokens_per_second\", 0)\n            self._token_rate = f\"{rate:.1f} tok/s\" if isinstance(rate, (int, float)) else \"—\"",
    "        elif kind == \"metrics\":\n            rate = event.get(\"tokens_per_second\", 0)\n            previous = self._run_metrics\n            self._run_metrics = {\n                \"tokens\": previous.get(\"tokens\", 0) + int(event.get(\"tokens\", 0) or 0),\n                \"prompt_tokens\": int(event.get(\"prompt_tokens\", 0) or 0),\n                \"cached_prompt_tokens\": int(event.get(\"cached_prompt_tokens\", 0) or 0),\n                \"load_ms\": previous.get(\"load_ms\", 0.0) + float(event.get(\"load_ms\", 0.0) or 0.0),\n                \"total_ms\": previous.get(\"total_ms\", 0.0) + float(event.get(\"total_ms\", 0.0) or 0.0),\n                \"tokens_per_second\": float(rate) if isinstance(rate, (int, float)) else 0.0,\n            }\n            self._token_rate = f\"{rate:.1f} tok/s\" if isinstance(rate, (int, float)) else \"—\"",
)


# --- Icon vocabulary for the new controls. ---
replace_once(
    "wynxo/ui/Icon.qml",
    "        case \"sun\": circle(12,12,4);for(let i=0;i<8;i++){let a=i*Math.PI/4;line([[12+7*Math.cos(a),12+7*Math.sin(a)],[12+10*Math.cos(a),12+10*Math.sin(a)]]);}break;\n        default:",
    "        case \"sun\": circle(12,12,4);for(let i=0;i<8;i++){let a=i*Math.PI/4;line([[12+7*Math.cos(a),12+7*Math.sin(a)],[12+10*Math.cos(a),12+10*Math.sin(a)]]);}break;\n        case \"pin\": line([[8,4],[16,4],[15,9],[19,13],[13,13],[12,21],[11,13],[5,13],[9,9],[8,4]]);break;\n        case \"retry\": line([[5,8],[5,3],[10,3]]);c.beginPath();c.arc(12,12,8,-2.5,2.2);c.stroke();break;\n        case \"duplicate\": rect(7,7,13,14);rect(3,3,13,14);break;\n        default:",
)


# --- QML: expose all of the powerpack without cluttering the main composer. ---
replace_once(
    "wynxo/ui/Main.qml",
    "    Shortcut { sequence: \"Ctrl+Shift+S\"; onActivated: bridge && bridge.stop() }\n",
    "    Shortcut { sequence: \"Ctrl+Shift+S\"; onActivated: bridge && bridge.stop() }\n    Shortcut { sequence: \"Ctrl+R\"; onActivated: bridge && bridge.regenerate() }\n    Shortcut { sequence: \"Ctrl+D\"; onActivated: bridge && bridge.duplicateTask() }\n",
)
replace_once(
    "wynxo/ui/Main.qml",
    "                        Icon { x: 9; anchors.verticalCenter: parent.verticalCenter; name: \"chat\"; width: 16; height: 16; ink: modelData.id === (bridge && bridge.taskId) ? accent : \"#727f76\" }\n                        Text { x: 35; anchors.verticalCenter: parent.verticalCenter; width: parent.width-62; text: modelData.title; elide: Text.ElideRight; color: modelData.id === (bridge && bridge.taskId) ? \"#dce8de\" : \"#9ea9a1\"; font.pixelSize: 12 }\n                        MouseArea { id: taskMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bridge && bridge.openTask(taskDelegate.modelData.id) }\n                        ActionButton { visible: taskMouse.containsMouse || hovered; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 30; iconName: \"trash\"; quiet: true; onClicked: { deleteDialog.taskToDelete = taskDelegate.modelData.id; deleteDialog.open(); } }",
    "                        Icon { x: 9; anchors.verticalCenter: parent.verticalCenter; name: modelData.pinned ? \"pin\" : \"chat\"; width: 16; height: 16; ink: modelData.pinned ? accent : modelData.id === (bridge && bridge.taskId) ? accent : \"#727f76\" }\n                        Text { x: 35; anchors.verticalCenter: parent.verticalCenter; width: parent.width-88; text: modelData.title; elide: Text.ElideRight; color: modelData.id === (bridge && bridge.taskId) ? \"#dce8de\" : \"#9ea9a1\"; font.pixelSize: 12 }\n                        MouseArea { id: taskMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bridge && bridge.openTask(taskDelegate.modelData.id) }\n                        ActionButton { z: 2; visible: modelData.pinned || taskMouse.containsMouse || hovered; anchors.right: parent.right; anchors.rightMargin: 28; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 30; iconName: \"pin\"; quiet: true; foreground: modelData.pinned ? accent : \"#839188\"; onClicked: bridge && bridge.togglePin(taskDelegate.modelData.id); ToolTip.visible: hovered; ToolTip.text: modelData.pinned ? \"Unpin task\" : \"Pin task\" }\n                        ActionButton { z: 2; visible: taskMouse.containsMouse || hovered; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 30; iconName: \"trash\"; quiet: true; onClicked: { deleteDialog.taskToDelete = taskDelegate.modelData.id; deleteDialog.open(); } }",
)
replace_once(
    "wynxo/ui/Main.qml",
    "                    ActionButton { iconName: \"download\"; quiet: true; width: 33; height: 33; visible: bridge && bridge.hasMessages; onClicked: bridge && bridge.exportTask(); ToolTip.visible: hovered; ToolTip.text: \"Export conversation\" }\n                    ActionButton { iconName: \"bolt\"; quiet: true; width: 33; height: 33; onClicked: commandPalette.open(); ToolTip.visible: hovered; ToolTip.text: \"Command palette · Ctrl+Shift+P\" }",
    "                    ActionButton { iconName: \"download\"; quiet: true; width: 33; height: 33; visible: bridge && bridge.hasMessages; onClicked: bridge && bridge.exportTask(); ToolTip.visible: hovered; ToolTip.text: \"Export conversation\" }\n                    ActionButton { iconName: \"retry\"; quiet: true; width: 33; height: 33; visible: bridge && bridge.hasMessages; enabled: bridge && bridge.canRegenerate; onClicked: bridge && bridge.regenerate(); ToolTip.visible: hovered; ToolTip.text: bridge && bridge.desktopEnabled ? \"Disable desktop control to regenerate safely\" : \"Regenerate · Ctrl+R\" }\n                    ActionButton { iconName: \"duplicate\"; quiet: true; width: 33; height: 33; visible: bridge && bridge.hasMessages; enabled: bridge && !bridge.busy; onClicked: bridge && bridge.duplicateTask(); ToolTip.visible: hovered; ToolTip.text: \"Duplicate task · Ctrl+D\" }\n                    ActionButton { iconName: \"pin\"; quiet: true; width: 33; height: 33; visible: bridge && bridge.taskId.length > 0; foreground: bridge && bridge.taskPinned ? accent : \"#839188\"; onClicked: bridge && bridge.togglePin(bridge.taskId); ToolTip.visible: hovered; ToolTip.text: bridge && bridge.taskPinned ? \"Unpin task\" : \"Pin task\" }\n                    ActionButton { iconName: \"bolt\"; quiet: true; width: 33; height: 33; onClicked: commandPalette.open(); ToolTip.visible: hovered; ToolTip.text: \"Command palette · Ctrl+Shift+P\" }",
)
replace_once(
    "wynxo/ui/Main.qml",
    "                                    Rectangle { width: 1; height: 14; color: \"#425448\" }\n                                    ComboBox {\n                                        id: modelPicker",
    "                                    Rectangle { width: 1; height: 14; color: \"#425448\" }\n                                    ComboBox {\n                                        id: runtimePreset\n                                        Layout.preferredWidth: 104; Layout.preferredHeight: 30\n                                        model: [\"Fast\", \"Balanced\", \"Deep\", \"Custom\"]\n                                        currentIndex: Math.max(0, model.indexOf(bridge && bridge.runtimePreset))\n                                        enabled: bridge && !bridge.busy\n                                        font.pixelSize: 10\n                                        contentItem: Text { text: runtimePreset.displayText; color: \"#a9bfb0\"; verticalAlignment: Text.AlignVCenter; leftPadding: 7; rightPadding: 19; elide: Text.ElideRight; font: runtimePreset.font }\n                                        indicator: Icon { name: \"down\"; width: 13; height: 13; x: runtimePreset.width-17; y: 8; ink: \"#8da996\" }\n                                        background: Rectangle { color: runtimePreset.hovered ? \"#2b3930\" : \"transparent\"; radius: 6 }\n                                        onActivated: { if(currentText !== \"Custom\") bridge && bridge.applyRuntimePreset(currentText); }\n                                        ToolTip.visible: hovered; ToolTip.text: bridge && bridge.runtimeSummary\n                                    }\n                                    ComboBox {\n                                        id: modelPicker",
)
replace_once(
    "wynxo/ui/Main.qml",
    "                                        Layout.preferredWidth: Math.min(230, composer.width * .44); Layout.preferredHeight: 30",
    "                                        Layout.preferredWidth: Math.min(205, composer.width * .34); Layout.preferredHeight: 30",
)
replace_once(
    "wynxo/ui/Main.qml",
    "                        Rectangle { Layout.fillWidth: true; height: 1; color: \"#2b382e\" }\n                        RowLayout { Text { text: \"ACTIVITY\"; color: \"#8da693\"; font.pixelSize: 9; font.letterSpacing: 1.8 }",
    "                        Rectangle {\n                            Layout.fillWidth: true; Layout.preferredHeight: 78\n                            radius: 9; color: \"#18231b\"; border.color: \"#304437\"\n                            ColumnLayout { anchors.fill: parent; anchors.margins: 11; spacing: 6\n                                RowLayout { Layout.fillWidth: true\n                                    Text { text: \"RUNTIME\"; color: \"#78917f\"; font.pixelSize: 8; font.letterSpacing: 1.3; Layout.fillWidth: true }\n                                    Text { text: bridge && bridge.runtimePreset; color: accent; font.pixelSize: 9 }\n                                }\n                                Text { Layout.fillWidth: true; text: bridge && bridge.runtimeSummary; color: \"#9cb0a2\"; font.pixelSize: 10; elide: Text.ElideRight }\n                                Text { Layout.fillWidth: true; text: bridge && bridge.runMetricSummary; color: \"#70897a\"; font.pixelSize: 9; elide: Text.ElideRight }\n                            }\n                        }\n                        Rectangle { Layout.fillWidth: true; height: 1; color: \"#2b382e\" }\n                        RowLayout { Text { text: \"ACTIVITY\"; color: \"#8da693\"; font.pixelSize: 9; font.letterSpacing: 1.8 }",
)
replace_once(
    "wynxo/ui/Main.qml",
    "        width: 560; height: Math.min(window.height-60, 675)",
    "        width: 590; height: Math.min(window.height-50, 760)",
)
replace_once(
    "wynxo/ui/Main.qml",
    "            solidCheck.checked = bridge && bridge.solidBackground;\n        }",
    "            solidCheck.checked = bridge && bridge.solidBackground;\n            ctxField.text = bridge && bridge.numCtx;\n            tempField.text = bridge && bridge.temperature;\n            keepAliveField.text = bridge && bridge.keepAlive;\n            stepsField.text = bridge && bridge.maxSteps;\n            runtimeSettingsPreset.currentIndex = Math.max(0, runtimeSettingsPreset.model.indexOf(bridge && bridge.runtimePreset));\n        }",
)
replace_once(
    "wynxo/ui/Main.qml",
    "                Text { Layout.fillWidth: true; text: bridge && bridge.pullProgress || \"Downloads from Ollama’s registry. Large models need substantial memory and disk space.\"; color: \"#849e8d\"; font.pixelSize: 11; wrapMode: Text.WordWrap }\n                Rectangle { Layout.fillWidth: true; height: 1; color: \"#34473a\" }\n                Text { text: \"APPEARANCE\"; color: \"#8fae99\"; font.pixelSize: 10; font.letterSpacing: 2 }",
    "                Text { Layout.fillWidth: true; text: bridge && bridge.pullProgress || \"Downloads from Ollama’s registry. Large models need substantial memory and disk space.\"; color: \"#849e8d\"; font.pixelSize: 11; wrapMode: Text.WordWrap }\n                Rectangle { Layout.fillWidth: true; height: 1; color: \"#34473a\" }\n                Text { text: \"RUNTIME\"; color: \"#8fae99\"; font.pixelSize: 10; font.letterSpacing: 2 }\n                Text { text: \"How the local model runs\"; color: \"#cbdacf\"; font.pixelSize: 12 }\n                ComboBox {\n                    id: runtimeSettingsPreset\n                    Layout.fillWidth: true; Layout.preferredHeight: 40\n                    model: [\"Fast\", \"Balanced\", \"Deep\", \"Custom\"]\n                    contentItem: Text { text: runtimeSettingsPreset.displayText; color: bright; verticalAlignment: Text.AlignVCenter; leftPadding: 11; font.pixelSize: 12 }\n                    indicator: Icon { name: \"down\"; width: 15; height: 15; x: runtimeSettingsPreset.width-22; y: 12; ink: \"#8da996\" }\n                    background: Rectangle { radius: 8; color: \"#141d17\"; border.color: \"#415647\" }\n                    onActivated: {\n                        if(currentText !== \"Custom\") {\n                            bridge && bridge.applyRuntimePreset(currentText);\n                            ctxField.text = bridge && bridge.numCtx; tempField.text = bridge && bridge.temperature;\n                            keepAliveField.text = bridge && bridge.keepAlive; stepsField.text = bridge && bridge.maxSteps;\n                        }\n                    }\n                }\n                GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 10\n                    TextField { id: ctxField; Layout.fillWidth: true; placeholderText: \"Context tokens\"; color: bright; inputMethodHints: Qt.ImhDigitsOnly; padding: 10; background: Rectangle { radius: 8; color: \"#141d17\"; border.color: \"#415647\" } }\n                    TextField { id: tempField; Layout.fillWidth: true; placeholderText: \"Temperature\"; color: bright; padding: 10; background: Rectangle { radius: 8; color: \"#141d17\"; border.color: \"#415647\" } }\n                    TextField { id: keepAliveField; Layout.fillWidth: true; placeholderText: \"Keep alive (5m)\"; color: bright; padding: 10; background: Rectangle { radius: 8; color: \"#141d17\"; border.color: \"#415647\" } }\n                    TextField { id: stepsField; Layout.fillWidth: true; placeholderText: \"Action budget\"; color: bright; inputMethodHints: Qt.ImhDigitsOnly; padding: 10; background: Rectangle { radius: 8; color: \"#141d17\"; border.color: \"#415647\" } }\n                }\n                Text { Layout.fillWidth: true; text: \"Context controls memory window, temperature controls variation, keep-alive controls how long Ollama keeps the model loaded, and action budget caps one desktop run.\"; color: \"#849e8d\"; font.pixelSize: 10; wrapMode: Text.WordWrap; lineHeight: 1.35 }\n                ActionButton { Layout.fillWidth: true; text: \"Apply runtime settings\"; iconName: \"sliders\"; enabled: bridge && !bridge.busy; onClicked: bridge && bridge.saveRuntimeSettings(ctxField.text, tempField.text, keepAliveField.text, stepsField.text) }\n                Rectangle { Layout.fillWidth: true; height: 1; color: \"#34473a\" }\n                Text { text: \"APPEARANCE\"; color: \"#8fae99\"; font.pixelSize: 10; font.letterSpacing: 2 }",
)
replace_once(
    "wynxo/ui/Main.qml",
    "                Text { text: \"WYNXO  0.2.0   ·   LOCAL DESKTOP COPILOT\"; font.pixelSize: 8; font.letterSpacing: 1.5; color: \"#718e7c\"; Layout.alignment: Qt.AlignHCenter }",
    "                Text { text: \"WYNXO  0.3.0   ·   OLLAMA-ONLY LOCAL COPILOT\"; font.pixelSize: 8; font.letterSpacing: 1.5; color: \"#718e7c\"; Layout.alignment: Qt.AlignHCenter }",
)
replace_once(
    "wynxo/ui/Main.qml",
    "        property int matchingCount: 7",
    "        property int matchingCount: 11",
)
replace_once(
    "wynxo/ui/Main.qml",
    "                    {label: \"Open settings\", detail: \"Models, thinking, themes, and appearance\", shortcut: \"Ctrl+,\", icon: \"sliders\", action: \"settings\"},\n                    {label: \"Stop current task\", detail: \"Cancel generation and desktop actions\", shortcut: \"Esc\", icon: \"stop\", action: \"stop\"}",
    "                    {label: \"Open settings\", detail: \"Models, runtime, thinking, themes, and appearance\", shortcut: \"Ctrl+,\", icon: \"sliders\", action: \"settings\"},\n                    {label: \"Regenerate response\", detail: \"Run the last user prompt again in chat mode\", shortcut: \"Ctrl+R\", icon: \"retry\", action: \"regenerate\"},\n                    {label: \"Duplicate task\", detail: \"Copy this conversation into a new local task\", shortcut: \"Ctrl+D\", icon: \"duplicate\", action: \"duplicate\"},\n                    {label: \"Pin or unpin task\", detail: \"Keep important conversations at the top\", shortcut: \"\", icon: \"pin\", action: \"pin\"},\n                    {label: \"Clear conversation\", detail: \"Remove messages but keep this task\", shortcut: \"\", icon: \"trash\", action: \"clear\"},\n                    {label: \"Stop current task\", detail: \"Cancel generation and desktop actions\", shortcut: \"Esc\", icon: \"stop\", action: \"stop\"}",
)
replace_once(
    "wynxo/ui/Main.qml",
    "    Dialog { id: deleteDialog; property string taskToDelete: \"\"; anchors.centerIn: parent; modal: true; title: \"Delete this task?\"; standardButtons: Dialog.Yes | Dialog.Cancel; onAccepted: bridge && bridge.deleteTask(taskToDelete); Label { text: \"This removes its saved conversation from this computer.\"; color: \"#c6d5ca\" } background: Rectangle { radius: 12; color: \"#28352c\"; border.color: \"#526d59\" } }\n",
    "    Dialog { id: deleteDialog; property string taskToDelete: \"\"; anchors.centerIn: parent; modal: true; title: \"Delete this task?\"; standardButtons: Dialog.Yes | Dialog.Cancel; onAccepted: bridge && bridge.deleteTask(taskToDelete); Label { text: \"This removes its saved conversation from this computer.\"; color: \"#c6d5ca\" } background: Rectangle { radius: 12; color: \"#28352c\"; border.color: \"#526d59\" } }\n    Dialog { id: clearDialog; anchors.centerIn: parent; modal: true; title: \"Clear this conversation?\"; standardButtons: Dialog.Yes | Dialog.Cancel; onAccepted: bridge && bridge.clearTask(); Label { text: \"The task stays, but all messages are removed from local history.\"; color: \"#c6d5ca\" } background: Rectangle { radius: 12; color: \"#28352c\"; border.color: \"#526d59\" } }\n",
)
replace_once(
    "wynxo/ui/Main.qml",
    "        else if (action === \"settings\") settings.open();\n        else if (action === \"stop\") bridge && bridge.stop();",
    "        else if (action === \"settings\") settings.open();\n        else if (action === \"regenerate\") bridge && bridge.regenerate();\n        else if (action === \"duplicate\") bridge && bridge.duplicateTask();\n        else if (action === \"pin\") { if(bridge && bridge.taskId.length > 0) bridge.togglePin(bridge.taskId); }\n        else if (action === \"clear\") { if(bridge && bridge.taskId.length > 0) clearDialog.open(); }\n        else if (action === \"stop\") bridge && bridge.stop();",
)


# --- Tests for the new runtime/persistence/controller behavior. ---
(ROOT / "tests/test_powerpack.py").write_text(r'''import threading

from PySide6.QtCore import QCoreApplication

from wynxo.controller import Controller
from wynxo.engine import AgentEngine
from wynxo.storage import Store


APP = QCoreApplication.instance() or QCoreApplication([])


class IdleDesktop:
    def status(self):
        return {"connected": False, "available": True, "backend": "test", "detail": "Off"}

    def disconnect(self):
        return None


class CaptureClient:
    def __init__(self):
        self.requests = []

    def capabilities(self, model):
        return ["completion"]

    def stream_chat(self, payload, cancel):
        self.requests.append(payload)
        yield {"message": {"role": "assistant", "content": "ok"}, "done": True,
               "eval_count": 8, "eval_duration": 400000000,
               "prompt_eval_count": 120, "prompt_eval_cached_count": 80,
               "load_duration": 50000000, "total_duration": 600000000}


def test_engine_passes_local_runtime_controls_and_emits_rich_metrics():
    client = CaptureClient()
    events = []
    history = AgentEngine(client, IdleDesktop()).run(
        [{"role": "user", "content": "hello"}], "local:test", False,
        threading.Event(), events.append, num_ctx=24576, temperature=0.25,
        keep_alive="9m", max_steps=7,
    )
    assert history[-1]["content"] == "ok"
    payload = client.requests[0]
    assert payload["options"] == {"num_ctx": 24576, "temperature": 0.25}
    assert payload["keep_alive"] == "9m"
    metrics = next(event for event in events if event["type"] == "metrics")
    assert metrics["tokens"] == 8
    assert metrics["prompt_tokens"] == 120
    assert metrics["cached_prompt_tokens"] == 80
    assert metrics["tokens_per_second"] == 20.0


def test_store_migrates_and_sorts_pinned_conversations(tmp_path):
    store = Store(tmp_path / "history.sqlite3")
    first = store.create_conversation("First")
    second = store.create_conversation("Second")
    store.set_pinned(first["id"], True)
    items = store.list_conversations()
    assert items[0]["id"] == first["id"]
    assert items[0]["pinned"] == 1
    assert next(item for item in items if item["id"] == second["id"])["pinned"] == 0
    store.close()


def test_runtime_presets_are_persisted(tmp_path):
    store = Store(tmp_path / "history.sqlite3")
    bridge = Controller(store=store, desktop=IdleDesktop(), autoconnect=False)
    bridge.applyRuntimePreset("Fast")
    assert bridge.runtimePreset == "Fast"
    assert bridge.numCtx == 8192
    assert bridge.temperature == 0.35
    assert bridge.maxSteps == 12
    assert store.get_setting("runtime_preset") == "Fast"
    assert bridge.saveRuntimeSettings("20000", "0.55", "7m", "24") is True
    assert bridge.runtimePreset == "Custom"
    assert bridge.numCtx == 20000
    assert bridge.keepAlive == "7m"
    bridge.shutdown()


def test_duplicate_clear_and_regenerate_chat_only(tmp_path, monkeypatch):
    store = Store(tmp_path / "history.sqlite3")
    original = store.create_conversation("Original", "local:test")
    messages = [{"role": "user", "content": "hello"}, {"role": "assistant", "content": "old"}]
    store.set_messages(original["id"], messages, "local:test")
    bridge = Controller(store=store, desktop=IdleDesktop(), autoconnect=False)
    bridge._online = True
    bridge.openTask(original["id"])

    captured = []
    monkeypatch.setattr(bridge, "_start_run", lambda history: captured.append(list(history)))
    bridge.regenerate()
    assert captured == [[{"role": "user", "content": "hello"}]]

    bridge._history = messages
    bridge.messages.replace(messages)
    bridge.duplicateTask()
    assert bridge.taskTitle == "Original copy"
    assert store.get_messages(bridge.taskId) == messages
    bridge.clearTask()
    assert store.get_messages(bridge.taskId) == []
    bridge.shutdown()
''', encoding="utf-8")

print("Powerpack transformations applied successfully")
