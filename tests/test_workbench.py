"""The side panel's three surfaces, tested without Qt."""
from pathlib import Path

import pytest

from wynxo import workbench as wb


# --------------------------------------------------------------- the terminal
def test_a_command_reads_back_as_prompt_output_and_result():
    session = wb.TerminalSession()
    session.start("ls -la", "/tmp", wb.USER)
    session.open_output()
    session.write("one\n")
    session.write("two\n")
    session.finish(code=0, ms=120)

    kinds = [block["kind"] for block in session.blocks]
    assert kinds == [wb.COMMAND, wb.OUTPUT, wb.EXIT]
    assert session.blocks[0]["source"] == "you"
    assert session.blocks[1]["text"] == "one\ntwo\n"
    assert session.blocks[2]["text"] == "Done · 120ms"
    # The command row is closed too, so a finished command stops looking live.
    assert session.blocks[0]["status"] == "ok"
    assert not session.running


def test_a_failure_keeps_the_reason_rather_than_the_exit_code_alone():
    session = wb.TerminalSession()
    session.start("false")
    session.finish(code=1, ms=5)
    assert session.blocks[-1]["text"].startswith("Exited with status 1")
    assert session.blocks[-1]["status"] == "failed"

    session.start("sleep 30")
    session.finish(error="Stopped; the command may have made partial changes", status="stopped")
    assert session.blocks[-1]["status"] == "stopped"
    assert "partial changes" in session.blocks[-1]["text"]


def test_a_command_that_never_reports_back_is_closed_by_the_next_one():
    session = wb.TerminalSession()
    session.start("first")
    session.start("second")
    assert [b["kind"] for b in session.blocks] == [wb.COMMAND, wb.EXIT, wb.COMMAND]
    assert session.blocks[0]["status"] == "stopped"
    assert session.blocks[2]["text"] == "second"


def test_output_is_capped_and_says_so():
    session = wb.TerminalSession()
    session.start("yes")
    session.open_output()
    session.write("x" * (wb.MAX_OUTPUT + 500))
    block = session.blocks[1]
    assert len(block["text"]) == wb.MAX_OUTPUT
    assert block["truncated"] is True


def test_the_transcript_scrolls_out_of_history_instead_of_growing():
    session = wb.TerminalSession()
    for index in range(wb.MAX_BLOCKS + 30):
        session.note(f"line {index}")
    assert session.overflow() == 30
    session.drop_front(session.overflow())
    assert len(session.blocks) == wb.MAX_BLOCKS
    assert session.blocks[0]["text"] == "line 30"


def test_dropping_the_front_keeps_the_open_command_addressable():
    session = wb.TerminalSession()
    session.note("old")
    session.start("tail -f log")
    session.open_output()
    session.drop_front(1)
    session.write("still arriving")
    assert session.blocks[session.output_index]["text"] == "still arriving"
    session.finish(code=0)
    assert session.blocks[0]["status"] == "ok"


def test_the_transcript_copies_as_something_you_could_paste():
    session = wb.TerminalSession()
    session.start("echo hi")
    session.open_output()
    session.write("hi\n")
    session.finish(code=0)
    assert session.transcript() == "$ echo hi\nhi\nDone\n"


def test_clearing_forgets_the_open_command_too():
    session = wb.TerminalSession()
    session.start("sleep 1")
    session.clear()
    assert session.blocks == []
    assert not session.running


# ------------------------------------------------------------------ the files
@pytest.fixture
def project(tmp_path):
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "app.py").write_text("print('hi')\n", encoding="utf-8")
    (tmp_path / "src" / "deep").mkdir()
    (tmp_path / "src" / "deep" / "inner.txt").write_text("inner\n", encoding="utf-8")
    (tmp_path / "README.md").write_text("# Title\n", encoding="utf-8")
    (tmp_path / ".env").write_text("SECRET=1\n", encoding="utf-8")
    (tmp_path / "__pycache__").mkdir()
    (tmp_path / "__pycache__" / "app.pyc").write_bytes(b"\x00\x01")
    return tmp_path


def test_the_tree_lists_folders_first_and_leaves_out_caches(project):
    rows = wb.build_tree(project)
    assert [row["name"] for row in rows] == ["src", "README.md"]
    assert rows[0]["dir"] is True
    assert rows[0]["expanded"] is False


def test_only_folders_you_opened_are_walked_into(project):
    rows = wb.build_tree(project, expanded={"src"})
    names = [(row["name"], row["depth"]) for row in rows]
    assert names == [("src", 0), ("deep", 1), ("app.py", 1), ("README.md", 0)]
    assert not any(row["name"] == "inner.txt" for row in rows)

    deeper = wb.build_tree(project, expanded={"src", "src/deep"})
    assert ("inner.txt", 2) in [(row["name"], row["depth"]) for row in deeper]


def test_dotfiles_stay_hidden_until_asked_for(project):
    assert not any(row["name"] == ".env" for row in wb.build_tree(project))
    assert any(row["name"] == ".env" for row in wb.build_tree(project, show_hidden=True))


def test_a_text_file_reads_back_with_its_language(project):
    result = wb.read_preview(project / "src" / "app.py", project)
    assert result["ok"] and result["language"] == "python"
    assert result["text"] == "print('hi')\n"
    assert result["lines"] == 1
    assert "1 line" in result["subtitle"]


def test_a_binary_file_says_so_instead_of_showing_noise(project):
    blob = project / "blob.bin"
    blob.write_bytes(b"\x00\x01\x02" * 40)
    result = wb.read_preview(blob, project)
    assert result["binary"] is True and not result["ok"]
    assert "binary" in result["error"]


def test_a_huge_file_is_cut_on_a_line_boundary(project):
    big = project / "big.log"
    big.write_text("a line of text\n" * 40000, encoding="utf-8")
    result = wb.read_preview(big, project)
    assert result["truncated"] is True
    assert result["text"].endswith("\n")
    assert len(result["text"]) <= wb.PREVIEW_BYTES


def test_a_path_outside_the_workspace_is_refused(project, tmp_path):
    outside = tmp_path.parent / "elsewhere.txt"
    outside.write_text("secrets\n", encoding="utf-8")
    result = wb.read_preview(outside, project)
    assert not result["ok"] and "outside" in result["error"]
    assert result["text"] == ""


def test_a_symlink_out_of_the_workspace_is_refused(project, tmp_path):
    target = tmp_path.parent / "outside-target.txt"
    target.write_text("secrets\n", encoding="utf-8")
    link = project / "shortcut.txt"
    try:
        link.symlink_to(target)
    except (OSError, NotImplementedError):
        pytest.skip("symlinks are unavailable here")
    assert not wb.inside(project, link)
    assert not wb.read_preview(link, project)["ok"]


def test_a_missing_file_reports_the_reason(project):
    result = wb.read_preview(project / "nope.txt", project)
    assert not result["ok"] and result["error"]


def test_the_root_falls_back_to_home_when_the_project_is_gone(tmp_path):
    assert wb.resolve_root(tmp_path / "not-here") == Path.home()
    assert wb.resolve_root("") == Path.home()
    assert wb.resolve_root(tmp_path) == tmp_path.resolve()


# ---------------------------------------------------------------- the browser
@pytest.mark.parametrize("typed, expected", [
    ("example.com", "https://example.com"),
    ("  example.com/docs  ", "https://example.com/docs"),
    ("http://127.0.0.1:8000", "http://127.0.0.1:8000"),
    ("https://docs.python.org/3/", "https://docs.python.org/3/"),
    ("localhost:8080/health", "https://localhost:8080/health"),
    ("", ""),
])
def test_an_address_is_completed_rather_than_guessed_at(typed, expected):
    assert wb.normalise_url(typed) == expected


@pytest.mark.parametrize("typed", [
    "file:///etc/passwd",
    "javascript:alert(1)",
    "data:text/html,<script>alert(1)</script>",
    "about:config",
    "ftp://files.example.com",
    "what is a portal",
    "https://",
])
def test_anything_that_is_not_a_web_page_is_refused(typed):
    with pytest.raises(ValueError):
        wb.normalise_url(typed)


def test_the_site_name_is_what_an_activity_row_shows():
    assert wb.url_label("https://www.example.com/a/b") == "example.com"
    assert wb.url_label("http://127.0.0.1:8000/") == "127.0.0.1:8000"
    assert wb.url_label("") == ""
