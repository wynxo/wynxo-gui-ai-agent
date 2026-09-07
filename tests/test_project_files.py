"""The workspace file tree and the file viewer's reader.

The rule these tests exist for: nothing outside the project the user chose ever
reaches the UI, and nothing the viewer cannot render is claimed as text.
"""
import os
from pathlib import Path

import pytest

from wynxo import project_files as files


@pytest.fixture
def project(tmp_path):
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "main.py").write_text("print('hi')\n" * 10)
    (tmp_path / "src" / "notes.md").write_text("# Notes\n")
    (tmp_path / "node_modules").mkdir()
    (tmp_path / "node_modules" / "junk.js").write_text("x")
    (tmp_path / ".hidden").write_text("secret")
    (tmp_path / ".github").mkdir()
    (tmp_path / "README.md").write_text("# Project\n")
    (tmp_path / "binary.bin").write_bytes(bytes(range(256)) * 8)
    return tmp_path


# ------------------------------------------------------------------ listing
def test_a_listing_puts_folders_first_and_sorts_by_name(project):
    """Case-insensitively, so README does not jump above the `a` files."""
    names = [entry["name"] for entry in files.list_directory(project)]
    assert names == ["src", "binary.bin", "README.md"]


def test_noise_folders_never_appear(project):
    assert "node_modules" not in [e["name"] for e in files.list_directory(project)]


def test_hidden_entries_are_opt_in(project):
    visible = {e["name"] for e in files.list_directory(project)}
    assert ".hidden" not in visible and ".github" not in visible
    shown = {e["name"] for e in files.list_directory(project, show_hidden=True)}
    assert ".hidden" in shown and ".github" in shown


def test_entries_carry_the_shape_the_tree_draws(project):
    entry = next(e for e in files.list_directory(project) if e["name"] == "README.md")
    assert entry["isDir"] is False
    assert entry["kind"] == "doc"
    assert entry["sizeLabel"]
    assert Path(entry["path"]).is_file()


def test_a_listing_is_bounded(tmp_path, monkeypatch):
    monkeypatch.setattr(files, "MAX_ENTRIES", 5)
    for index in range(20):
        (tmp_path / f"file{index}.txt").write_text("x")
    entries = files.list_directory(tmp_path)
    assert len(entries) <= 6                      # five, plus the "and more" row
    assert entries[-1].get("placeholder") is True


# ------------------------------------------------------------- containment
def test_a_path_outside_the_project_is_refused(project):
    with pytest.raises(ValueError):
        files.resolve_within(project, "/etc/passwd")
    with pytest.raises(ValueError):
        files.resolve_within(project, "../../etc/passwd")


def test_a_symlink_pointing_out_of_the_project_is_refused(project, tmp_path):
    outside = tmp_path.parent / "outside.txt"
    outside.write_text("not yours")
    link = project / "escape"
    try:
        os.symlink(outside, link)
    except (OSError, NotImplementedError):
        pytest.skip("this platform cannot create symlinks")
    with pytest.raises(ValueError):
        files.resolve_within(project, link)


def test_a_path_inside_the_project_resolves(project):
    assert files.resolve_within(project, "src/main.py").name == "main.py"
    assert files.resolve_within(project, project / "README.md").name == "README.md"


# ----------------------------------------------------------------- reading
def test_reading_a_text_file_reports_its_language_and_line_count(project):
    record = files.read_file(project, "src/main.py")
    assert record["language"] == "python"
    assert record["lines"] == 10
    assert record["text"].startswith("print")
    assert record["binary"] is False


def test_a_binary_file_is_named_as_one_rather_than_mangled(project):
    record = files.read_file(project, "binary.bin")
    assert record["binary"] is True
    assert record["text"] == ""
    assert "Binary" in record["error"]


def test_a_large_file_is_truncated_on_a_line_boundary(project):
    big = project / "big.txt"
    big.write_text("".join(f"line {n}\n" for n in range(5000)))
    record = files.read_file(project, "big.txt", max_bytes=1000)
    assert record["truncated"] is True
    assert record["text"].endswith("\n") or "\n" in record["text"]
    assert len(record["text"]) <= 1000


def test_reading_refuses_a_path_outside_the_project(project):
    with pytest.raises(ValueError):
        files.read_file(project, "/etc/hostname")


# ----------------------------------------------------------------- writing
def test_saving_replaces_the_file_and_leaves_no_temporary(project):
    files.write_file(project, "src/main.py", "print('changed')\n")
    assert (project / "src" / "main.py").read_text() == "print('changed')\n"
    assert not list(project.glob("**/*.wynxo-tmp"))


def test_saving_preserves_executable_permissions(project):
    target = project / "src" / "run.sh"
    target.write_text("#!/bin/sh\necho before\n")
    target.chmod(0o751)

    files.write_file(project, target, "#!/bin/sh\necho after\n")

    assert target.read_text() == "#!/bin/sh\necho after\n"
    assert target.stat().st_mode & 0o777 == 0o751


def test_saving_a_truncated_large_file_is_refused_without_data_loss(project, monkeypatch):
    monkeypatch.setattr(files, "MAX_TEXT_BYTES", 64)
    target = project / "large.txt"
    original = "first line\n" + ("tail that must survive\n" * 20)
    target.write_text(original)

    preview = files.read_file(project, target)
    assert preview["truncated"] is True
    with pytest.raises(ValueError, match="read-only"):
        files.write_file(project, target, preview["text"] + "edited\n")

    assert target.read_text() == original
    assert not list(project.glob("**/*.wynxo-tmp"))


def test_saving_refuses_a_path_outside_the_project(project, tmp_path):
    target = tmp_path.parent / "victim.txt"
    target.write_text("original")
    with pytest.raises(ValueError):
        files.write_file(project, target, "overwritten")
    assert target.read_text() == "original"


def test_saving_refuses_a_file_that_is_no_longer_there(project):
    with pytest.raises(ValueError):
        files.write_file(project, "src/gone.py", "x")


# ---------------------------------------------------------------- searching
def test_search_finds_files_at_any_depth_and_skips_noise(project):
    hits = {entry["relative"] for entry in files.search_tree(project, "main")}
    assert "src/main.py" in hits
    assert not any("node_modules" in entry for entry in hits)


def test_search_is_bounded_and_case_insensitive(project):
    assert files.search_tree(project, "README")
    assert files.search_tree(project, "readme")
    assert files.search_tree(project, "", limit=5) == []
    assert len(files.search_tree(project, "e", limit=2)) <= 2


# ---------------------------------------------------------------- messages
def test_an_os_error_is_explained_rather_than_printed(project):
    """`[Errno 2] No such file or directory: '/home/you/…'` tells the user the
    thing they clicked on is gone, in the least useful possible words."""
    try:
        files.read_file(project, "not-there.txt")
    except OSError as error:
        message = files.explain(error, "“notes.md”")
    assert message == "“notes.md” is no longer there."
    assert "Errno" not in message

    assert "permissions" in files.explain(PermissionError(13, "Permission denied"))
    assert files.explain(ValueError("That path is outside the project folder")) \
        == "That path is outside the project folder"
    assert files.explain(OSError("something odd")).endswith(".")