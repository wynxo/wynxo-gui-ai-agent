"""Composer attachments. Nothing here reads outside the temporary directory."""
import base64
import pytest

from wynxo import context as ctx


def test_text_file_is_attached_with_a_readable_summary(tmp_path):
    target = tmp_path / "main.py"
    target.write_text("print('hello')\nprint('again')\n", encoding="utf-8")
    attachment = ctx.load_path(target)
    assert attachment["kind"] == ctx.FILE
    assert attachment["title"] == "main.py"
    assert "print('hello')" in attachment["text"]
    assert "lines" in attachment["subtitle"]
    assert attachment["tokens"] > 0


def test_binary_files_are_refused_rather_than_mangled(tmp_path):
    target = tmp_path / "blob.bin"
    target.write_bytes(b"\x00\x01\x02" * 64)
    with pytest.raises(ctx.ContextError, match="binary"):
        ctx.load_path(target)


def test_oversized_text_is_refused_with_its_size(tmp_path):
    target = tmp_path / "big.txt"
    target.write_text("x" * (ctx.MAX_TEXT_BYTES + 10), encoding="utf-8")
    with pytest.raises(ctx.ContextError, match="limited to"):
        ctx.load_path(target)


def test_missing_paths_report_clearly(tmp_path):
    with pytest.raises(ctx.ContextError, match="does not exist"):
        ctx.load_path(tmp_path / "nope.txt")


def test_images_are_detected_and_base64_encoded(tmp_path):
    pillow = pytest.importorskip("PIL.Image")
    target = tmp_path / "shot.png"
    pillow.new("RGB", (12, 7), "black").save(target)
    attachment = ctx.load_path(target)
    assert attachment["kind"] == ctx.IMAGE
    assert attachment["width"] == 12 and attachment["height"] == 7
    assert base64.b64decode(attachment["image"])[:4] == b"\x89PNG"
    assert "12 × 7" in attachment["subtitle"]


def test_folders_become_a_listing_not_a_recursive_read(tmp_path):
    (tmp_path / "src").mkdir()
    (tmp_path / "notes.md").write_text("hi", encoding="utf-8")
    (tmp_path / ".hidden").write_text("secret", encoding="utf-8")
    attachment = ctx.load_path(tmp_path)
    assert attachment["kind"] == ctx.FOLDER
    assert "src/" in attachment["text"]
    assert "notes.md" in attachment["text"]
    assert ".hidden" not in attachment["text"]


def test_clipboard_text_and_images():
    text = ctx.from_clipboard("  some copied text  ")
    assert text["kind"] == ctx.CLIPBOARD
    assert text["text"].strip() == "some copied text"
    image = ctx.from_clipboard(image_png=b"\x89PNG fake")
    assert image["kind"] == ctx.IMAGE
    with pytest.raises(ctx.ContextError, match="empty"):
        ctx.from_clipboard("   ")


def test_capture_results_become_image_attachments():
    attachment = ctx.from_capture({"ok": True, "image": "AAA", "width": 1920, "height": 1080},
                                  ctx.WINDOW, title="Firefox", detail="Firefox")
    assert attachment["kind"] == ctx.WINDOW
    assert attachment["title"] == "Firefox"
    assert "1920 × 1080" in attachment["subtitle"]
    with pytest.raises(ctx.ContextError, match="denied"):
        ctx.from_capture({"ok": False, "error": "Permission denied"})


def test_build_messages_separates_text_from_images_and_frames_it_as_data():
    attachments = [
        ctx.make(ctx.FILE, "a.py", path="/tmp/a.py", text="print(1)"),
        ctx.make(ctx.IMAGE, "shot.png", image="AAA", width=800, height=600),
    ]
    messages = ctx.build_messages(attachments)
    assert len(messages) == 2
    assert "untrusted data" in messages[0]["content"]
    assert "/tmp/a.py" in messages[0]["content"]
    assert messages[1]["images"] == ["AAA"]
    assert "800 × 600" in messages[1]["content"]
    assert ctx.build_messages([]) == []


def test_vision_requirement_and_description():
    images = [ctx.make(ctx.IMAGE, "a.png", image="AAA")]
    assert ctx.needs_vision(images) is True
    assert ctx.needs_vision([ctx.make(ctx.FILE, "a.py", text="x")]) is False
    names = [ctx.make(ctx.FILE, f"f{i}.py", text="x") for i in range(4)]
    assert ctx.describe(names) == "f0.py, f1.py and 2 more"
    assert ctx.describe([]) == ""


def test_working_directory_label_uses_a_tilde(monkeypatch, tmp_path):
    monkeypatch.setenv("HOME", str(tmp_path))
    assert ctx.working_directory_label(str(tmp_path / "code")) == "~/code"
    assert ctx.working_directory_label("/opt/thing") == "/opt/thing"
    assert ctx.working_directory_label("") == ""
