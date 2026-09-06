# Wynxo

**A local desktop copilot for Linux, powered entirely by Ollama.**

Wynxo is a native Python + Qt Quick application. Chat with a model running on
your own machine, attach files, folders and screenshots as context, and — when
you turn it on — let a capable model see your screen and drive your mouse and
keyboard.

No browser, no Node.js, no account, no API key, no cloud AI. Ollama does the
inference; Wynxo is the interface.

![Wynxo, mid-conversation](docs/screenshots/02-conversation.png)

---

## Contents

- [What it does](#what-it-does)
- [Screenshots](#screenshots)
- [Requirements](#requirements)
- [Install](#install)
- [Connecting Ollama](#connecting-ollama)
- [Screen control](#screen-control)
- [Wayland and X11](#wayland-and-x11)
- [Keyboard](#keyboard)
- [Privacy](#privacy)
- [Development](#development)
- [Testing and screenshots](#testing-and-screenshots)
- [Update or remove](#update-or-remove)
- [Troubleshooting](#troubleshooting)

---

## What it does

**Conversation**
Streamed replies with real Markdown: headings, tables, quotes, lists and links
set in the app's own type scale. Fenced code becomes a card with syntax
highlighting, copy, and save. Reasoning from a thinking model collapses to a
single line — *Thought for 8.2s* — instead of burying the answer.

**Local context**
Attach files, folders, images, the clipboard, a whole screen, a screen region
you drag out, or the active window. Everything appears as a removable chip
above the composer and as a preview in the inspector, so you always know
exactly what the model can see. Drag and drop works too. Capturing for context
uses the screenshot path only — it never asks for control of your input.

**Screen control**
When enabled, a model with vision and tool calling can open applications,
click, type, scroll and drag. Every action appears in an inline timeline with
its status, duration and result. Escape stops everything, instantly.

**Permission modes**
Screen control is not a single switch:

| Mode | Behaviour |
| --- | --- |
| Ask | Approve every desktop action before it runs |
| Safe auto *(default)* | Run low-risk actions; confirm typing and key presses |
| Auto | Run desktop actions without interrupting you |

Reading the screen and moving the pointer never prompt — they change nothing.
Typing and key chords can save, send or delete in whatever has focus, so they
stay behind a prompt unless you choose Auto.

**Models**
Browse what Ollama has installed with parameter size, quantisation, disk usage,
native context window and capabilities. Favourite the ones you use, download
new tags, delete old ones. Wynxo reads capabilities from Ollama rather than
guessing from names, and warns you *before* you send if the model cannot do
what you are asking — no vision for the image you attached, no tool calling for
the desktop task, or a conversation that has nearly filled the context window.

**Quick bar**
A floating command bar (`Ctrl+Space`) that sits above other windows for a fast
question, a screen capture, or a jump back into the full app.

**Everything else**
Command palette, conversation search, pin, rename, duplicate, branch from any
message, edit and resend, export to Markdown, runtime presets, generation
metrics, desktop notifications for long unattended runs, an optional tray icon,
five accent themes, a compact density, and a reduced-motion setting.

---

## Screenshots

Every image below is a real capture of the running Qt application, produced by
`python -m wynxo --snapshot` (see [Testing and screenshots](#testing-and-screenshots)).

| | |
| --- | --- |
| **New chat** — useful immediately, no marketing copy<br>![](docs/screenshots/01-new-chat.png) | **Local context** — files, folders and captures as chips<br>![](docs/screenshots/09-context.png) |
| **Screen control** — inline activity timeline and a permission prompt<br>![](docs/screenshots/03-desktop-control.png) | **Settings** — eight pages, organised by intent<br>![](docs/screenshots/04-settings.png) |
| **Models** — capabilities, size, favourites, downloads<br>![](docs/screenshots/05-model-picker.png) | **Command palette** — every action, one keystroke away<br>![](docs/screenshots/06-command-palette.png) |
| **First run** — four steps, then out of your way<br>![](docs/screenshots/07-welcome.png) | **Quick bar** — `Ctrl+Space`, above everything else<br>![](docs/screenshots/08-quick-bar.png) |

---

## Requirements

- Linux with a graphical session (Wayland or X11)
- Python 3.10 or newer, and Git
- [Ollama](https://docs.ollama.com/linux) running locally
- At least one local model — a vision + tools model for screen control

---

## Install

```bash
git clone https://github.com/wynxo/wynxo-gui-ai-agent.git
cd wynxo-gui-ai-agent
python3 install.py
```

`./install` does the same thing. Then open **Wynxo** from your application menu,
or run `~/.local/bin/wynxo`.

The installer builds its own Python environment, installs dependencies, and
registers a launcher, an icon and a desktop entry. It copies the app, so the
checkout can be moved or deleted afterwards. It does not need `sudo`, touch
your system Python, start a background service, install Ollama, or download a
model. The first install needs internet access for the Python packages.

If Debian or Ubuntu reports missing `venv` support:

```bash
sudo apt install python3-venv
python3 install.py
```

---

## Connecting Ollama

1. Install [Ollama for Linux](https://docs.ollama.com/linux) if you have not already.
2. Make sure it is running. If it is not managed by a service, run `ollama serve`.
3. Open Wynxo. The default address is `http://127.0.0.1:11434`; change it under
   **Settings → General** if yours differs.
4. Pick a model in the model manager (`Ctrl+M`), or download one by tag.

What a model can do depends on the capabilities Ollama reports for it:

| Capability | What Wynxo can do |
| --- | --- |
| Chat | Stream answers and save conversations |
| Tools | Discover and launch installed applications |
| Vision | Read screenshots and images you attach |
| Vision + tools | Full screen control: click, type, scroll, drag |
| Thinking | Show the model's reasoning before its answer |

A large text-only model cannot see a button or a canvas; Wynxo disables the
visual tools rather than letting the model guess where to click. Model size
alone does not determine these abilities. See Ollama's
[API introduction](https://docs.ollama.com/api/introduction) and
[tool calling documentation](https://docs.ollama.com/capabilities/tool-calling).

Only loopback addresses are accepted, `localhost` is resolved by Wynxo itself
rather than trusted to DNS, proxy environment variables are ignored, redirects
are refused, and models that forward to a remote host are rejected.

---

## Screen control

Start with something small:

> Open KolourPaint and draw a simple smiley face in the middle of a new canvas.

Turn on **Screen control** first, from the inspector, the composer, or
**Settings → Screen control**. On Wayland, allow the screen-sharing and input
permissions your desktop asks for. Install the application you want it to use
first — Wynxo discovers apps through their desktop entries and never runs a
shell command.

While it works, the timeline shows each action, whether it succeeded, and how
long it took. Screenshots feed a vision model; pointer motion and keyboard
input affect your real desktop.

Safety, unchanged from earlier releases and extended in this one:

- Screen control starts **off** every time Wynxo opens.
- **Escape** stops generation and desktop actions immediately.
- Turning screen control off revokes input access at the backend, not just in
  the UI, even while an action is in flight.
- Every run has an action budget (20 by default); Wynxo stops and asks rather
  than running indefinitely.
- The model is never given a shell. Applications are launched through `gio`
  from their installed desktop entry.
- Screen text and tool results are treated as untrusted data, never as
  instructions.
- A permission prompt that times out, is dismissed, or is interrupted by
  Escape counts as a refusal.

An action that already happened is not undone by stopping.

---

## Wayland and X11

| Session | Backend | Notes |
| --- | --- | --- |
| KDE / GNOME Wayland | XDG RemoteDesktop, ScreenCast and Screenshot portals | Select every monitor; the compositor owns the permission dialog |
| X11 | XTEST input, Pillow capture | Needs XTEST; typed characters must exist in the active keymap |
| No graphical session | Chat only | Input and capture are unavailable |

On Wayland, select every monitor in the permission dialog so Wynxo can map
screenshot pixels to the right input stream. It prefers the position metadata
the portal exposes, then monitor sizes, then the compositor's stable stream
order. Capturing the screen *for context* uses the Screenshot portal alone and
never asks for input control. Per-window capture is X11-only; Wayland
compositors do not expose it.

On Debian KDE:

```bash
sudo apt install xdg-desktop-portal xdg-desktop-portal-kde libglib2.0-bin
```

Use the matching portal backend on other desktops. `libglib2.0-bin` provides
`gio`, which launches applications. Wayland support still needs testing on your
specific compositor and version.

---

## Keyboard

| Shortcut | Action |
| --- | --- |
| Enter / Shift+Enter | Send / new line |
| Escape | Stop generation and desktop actions |
| Ctrl+N | New chat |
| Ctrl+K | Search chats |
| Ctrl+Shift+P | Command palette |
| Ctrl+Space | Quick bar |
| Ctrl+M | Model manager |
| Ctrl+B / Ctrl+I | Toggle sidebar / inspector |
| Ctrl+R | Regenerate |
| Ctrl+D | Duplicate chat |
| Alt+Up / Alt+Down | Previous / next chat |
| Ctrl+Shift+V | Paste an image as context |
| Ctrl+, | Settings |

These are window shortcuts, active while Wynxo has keyboard focus. Linux gives
applications no portable way to claim a system-wide hotkey, so for a real
global quick bar, bind your desktop's custom shortcut to:

```
wynxo --quick
```

A running Wynxo picks that up over a local socket and raises the bar; if none is
running, it starts one.

---

## Privacy

- Inference runs through your local Ollama server. Nothing is sent anywhere else.
- Conversations live in a private SQLite file at
  `~/.local/share/wynxo/history.sqlite3` (or `$XDG_DATA_HOME/wynxo`), created
  with `0600` permissions.
- Screenshots go to your local model and are **not** written into chat history.
  The Wayland portal may create its own temporary capture files.
- No account, no API key, no telemetry, no hosted backend.

---

## Development

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -e . pytest
.venv/bin/python -m wynxo
.venv/bin/python -m pytest -q
```

Layout:

| Path | Responsibility |
| --- | --- |
| `wynxo/ui/Main.qml` | The application shell: layout, shortcuts, overlays |
| `wynxo/ui/Wynxo/` | The QML module — `Theme.qml` plus ~30 components |
| `wynxo/controller.py` | Qt bridge; owns UI, Ollama, task and desktop state |
| `wynxo/engine.py` | Ollama transport and the bounded desktop tool loop |
| `wynxo/desktop.py` | Wayland portal and X11 backends |
| `wynxo/markdown.py` | Message segmentation, highlighting, Markdown rendering |
| `wynxo/context.py` | Composer attachments |
| `wynxo/storage.py` | SQLite history and settings |
| `wynxo/notify.py` | Desktop notifications and system integration |
| `wynxo/demo.py` | Fixed state for previews and screenshots |

`Theme.qml` is the only place colour, spacing, radius, type and motion are
defined; a test fails the build if a component hard-codes a colour. The
installer uses only the standard library, so it runs before dependencies exist.

---

## Testing and screenshots

```bash
.venv/bin/python -m pytest -q
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software .venv/bin/python -m wynxo --smoke-test
```

To see the interface without any real history, Ollama, or desktop access:

```bash
.venv/bin/python -m wynxo --ui-preview              # a full conversation
.venv/bin/python -m wynxo --ui-preview context      # attachments
.venv/bin/python -m wynxo --ui-preview desktop      # screen control mid-task
.venv/bin/python -m wynxo --ui-preview welcome      # first run
```

To regenerate every screenshot in `docs/screenshots/` — real captures of the
real renderer, never mock-ups:

```bash
xvfb-run -a -s "-screen 0 1600x1000x24" \
  .venv/bin/python -m wynxo --snapshot docs/screenshots
```

Add `--size 980x760` to check a narrower layout. CI runs the same command and
uploads the results as a build artifact.

Tests cover a full turn streamed from a real local HTTP server through the real
controller into the message model, desktop action validation with test
backends, permission modes and the approval gate, message segmentation and
rendering, attachments and region cropping, conversation storage and search,
and install/uninstall transactions. They do not establish end-to-end reliability of an arbitrary
model or compositor — a real screenshot → model → drawing task still depends on
your installed model, your Ollama server, the target application, and your
desktop's permissions.

---

## Update or remove

```bash
git pull
python3 install.py
```

An upgrade builds a new environment before switching the active release, so a
failed install leaves the previous version working. Restart Wynxo to use an
update.

```bash
~/.local/bin/wynxo --uninstall            # keeps conversations and settings
~/.local/bin/wynxo --uninstall --purge    # removes them too
```

Uninstall never removes Ollama or your downloaded models. Modified launchers,
modified desktop entries, unknown files and user-data symlinks are preserved
and reported.

| Item | Location |
| --- | --- |
| App and isolated environments | `$XDG_DATA_HOME/wynxo-app` (default `~/.local/share/wynxo-app`) |
| Launcher | `~/.local/bin/wynxo` |
| Desktop entry | `$XDG_DATA_HOME/applications/io.github.wynxo.Wynxo.desktop` |
| Icon | `$XDG_DATA_HOME/icons/hicolor/scalable/apps/io.github.wynxo.Wynxo.svg` |
| Conversations and settings | `$XDG_DATA_HOME/wynxo/history.sqlite3` |

Advanced: `python3 install.py --install-root /path --bin-dir /path`. Pass the
same install root to `uninstall.py`, or use that installation's launcher.

---

## Troubleshooting

**Ollama is not responding.** Check `ollama list` and
`curl http://127.0.0.1:11434/api/tags`. The Settings address is the server
origin, without `/api`. If Ollama already runs as a service, do not start a
second one on the same port.

**A model tag cannot be found.** Use a tag from `ollama list` or the Ollama
library. A failed download leaves your existing models alone.

**Qt cannot load the xcb plugin.** A minimal desktop may need:

```bash
sudo apt install libxcb-cursor0 libxkbcommon-x11-0 libegl1 libgl1
```

Run the launcher from a terminal to see the missing-library diagnostics.
Package names vary by distribution; see
[Qt's Linux requirements](https://doc.qt.io/qt-6/linux-requirements.html).

**Rendering looks wrong.** Try `QT_QUICK_BACKEND=software ~/.local/bin/wynxo`.
Reduced motion is also available under Settings → Appearance.

**The `wynxo` command is missing.** Use `~/.local/bin/wynxo` or the application
menu, and add `~/.local/bin` to your `PATH` if you want the short form. The
installer does not edit your shell configuration.

**Screen control is unavailable.** Read the backend explanation in
Settings → Screen control, grant your desktop's permission prompt, select every
monitor, and confirm portal support. X11 is an alternative when your login
screen offers it.

---

Wynxo is an independent project, not affiliated with Ollama or any AI vendor.
MIT licensed. Inter and JetBrains Mono are bundled under the SIL Open Font
License; other dependencies keep their own licences.
