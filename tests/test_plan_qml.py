import json
import os
from pathlib import Path
import subprocess
import sys


PROBE = Path(__file__).with_name("plan_probe.py")


def test_real_shell_opens_agent_authored_plan():
    environment = {
        **os.environ,
        "QT_QPA_PLATFORM": "offscreen",
        "QT_QUICK_BACKEND": "software",
    }
    result = subprocess.run(
        [sys.executable, str(PROBE)],
        capture_output=True,
        text=True,
        timeout=30,
        env=environment,
    )
    assert result.returncode == 0, result.stderr
    assert "ReferenceError" not in result.stderr, result.stderr
    assert "Binding loop" not in result.stderr, result.stderr

    state = json.loads(result.stdout.strip().splitlines()[-1])
    assert state == {
        "loaded": True,
        "visible": True,
        "count": 3,
        "dock_visible": True,
        "summary": "1 of 3 complete",
    }
