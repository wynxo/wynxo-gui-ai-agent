"""Real subprocess checks for the local copilot command runner."""
import shlex
import sys
import threading
import time

import pytest

from wynxo.commands import OUTPUT_LIMIT, run_command


def python_command(source):
    return shlex.join([sys.executable, "-c", source])


def test_captures_stdout_stderr_exit_status_and_working_directory(tmp_path):
    result = run_command("printf hello; printf error >&2; pwd; exit 7", str(tmp_path))
    assert result["ok"] is False
    assert result["exit_code"] == 7
    assert "helloerror" in result["output"]
    assert str(tmp_path) in result["output"]


def test_output_is_bounded_without_deadlocking():
    result = run_command(python_command("print('x' * 200000)"))
    assert result["ok"] and result["truncated"]
    assert len(result["output"]) == OUTPUT_LIMIT


def test_timeout_stops_a_command_and_returns_partial_output():
    started = time.monotonic()
    result = run_command("printf started; sleep 20", timeout=1)
    assert "timed out" in result["error"]
    assert result["output"] == "started"
    assert time.monotonic() - started < 3


def test_stop_interrupts_a_command(tmp_path):
    cancel = threading.Event()
    timer = threading.Timer(0.15, cancel.set)
    timer.start()
    try:
        result = run_command("sleep 10; touch late", str(tmp_path), cancel=cancel)
        assert "Stopped" in result["error"]
        assert not (tmp_path / "late").exists()
    finally:
        timer.join()


def test_closed_stdout_does_not_hide_a_running_command():
    result = run_command("exec 1>&- 2>&-; sleep 10", timeout=1)
    assert "timed out" in result["error"]


def test_invalid_working_directory_fails_before_execution(tmp_path):
    with pytest.raises(FileNotFoundError):
        run_command("touch unexpected", str(tmp_path / "missing"))
    assert not (tmp_path / "unexpected").exists()


def test_output_is_published_while_the_command_is_still_running():
    """The panel shows a long command's progress; it does not wait for the exit."""
    seen = []
    result = run_command("echo one; sleep 0.2; echo two", timeout=5, on_output=seen.append)
    assert result["ok"] is True
    assert "".join(seen) == "one\ntwo\n"
    # Two reads, because the second line arrives after the sleep.
    assert len(seen) >= 2


def test_a_character_split_across_two_reads_is_still_one_character():
    source = ("import sys, time\n"
              "sys.stdout.buffer.write(b'a\\xc3'); sys.stdout.buffer.flush()\n"
              "time.sleep(0.3)\n"
              "sys.stdout.buffer.write(b'\\xa9b'); sys.stdout.buffer.flush()\n")
    seen = []
    run_command(python_command(source), timeout=10, on_output=seen.append)
    assert len(seen) >= 2, "the halves arrived together, so nothing was split"
    assert "".join(seen) == "aéb"
    assert "\ufffd" not in "".join(seen)


def test_a_failing_listener_does_not_take_the_command_down():
    def explode(_fragment):
        raise RuntimeError("the view is gone")

    result = run_command("echo still fine", timeout=5, on_output=explode)
    assert result["ok"] is True and result["output"] == "still fine\n"


def test_published_output_never_exceeds_what_the_result_carries():
    seen = []
    result = run_command("yes hello | head -c 60000", timeout=10, on_output=seen.append)
    assert len("".join(seen)) == len(result["output"]) == OUTPUT_LIMIT
