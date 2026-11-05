"""The legacy deployment entrypoints must not mutate a real Docker project."""

import os
import subprocess
from pathlib import Path

import pytest


@pytest.mark.parametrize("command", ["deploy", "rollback", "cleanup"])
def test_unverified_deployment_commands_fail_before_calling_docker(tmp_path, command):
    marker = tmp_path / "docker-was-called"
    for binary in ("docker", "docker-compose"):
        fake_docker = tmp_path / binary
        fake_docker.write_text(f"#!/bin/sh\ntouch '{marker}'\n")
        fake_docker.chmod(0o755)
    script = Path(__file__).resolve().parents[2] / "scripts" / "deploy.sh"
    env = {**os.environ, "PATH": f"{tmp_path}:{os.environ['PATH']}"}
    result = subprocess.run(["bash", str(script), command], cwd=tmp_path,
                            env=env, capture_output=True, text=True, check=False)
    assert result.returncode != 0
    assert "disabled" in result.stderr
    assert not marker.exists()
