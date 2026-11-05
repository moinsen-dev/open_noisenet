#!/usr/bin/env python3
"""Start a dedicated HTTP test server on a pre-created disposable loopback DB.

Never point this at a user database. Requires the exact source_phase_qa name,
an explicit disposable marker and matching Docker QA ownership label.
"""

import argparse
import asyncio
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", type=Path, required=True)
    args = ap.parse_args()
    cfg = json.loads(args.config.read_text())
    if cfg.get("disposable") is not True or cfg["database"] != "source_phase_qa":
        raise ValueError("Disposable QA database required")
    label = subprocess.run(
        [
            "docker",
            "inspect",
            cfg["container"],
            "--format",
            '{{index .Config.Labels "opennoisenet.purpose"}}',
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    if label != "source-phase-qa-20261105":
        raise ValueError("Not the owned QA container")
    port = int(cfg["port"])
    actual = subprocess.run(
        ["docker", "port", cfg["container"], "5432/tcp"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    if actual != f"127.0.0.1:{port}":
        raise ValueError("QA port mismatch")
    os.environ.update(
        SECRET_KEY=secrets.token_hex(32),
        ENVIRONMENT="test",
        DATABASE_URL=f'postgresql+asyncpg://postgres:{cfg["password"]}@127.0.0.1:{port}/source_phase_qa',
    )
    repo = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(repo / "backend"))
    from app.db.base import Base
    from app.db.models import SourcePhase  # imports all models
    from app.db.session import engine
    from alembic import command
    from alembic.config import Config

    async def prepare():
        async with engine.begin() as conn:
            # Fresh disposable DB: create the previous schema then apply the
            # actual migration, instead of silently testing create_all(head).
            await conn.run_sync(
                lambda c: Base.metadata.create_all(
                    c,
                    tables=[
                        t
                        for t in Base.metadata.sorted_tables
                        if t is not SourcePhase.__table__
                    ],
                )
            )

    asyncio.run(prepare())
    migration = Config()
    migration.set_main_option("script_location", str(repo / "backend/migrations"))
    command.stamp(migration, "94a38b0e8f12")
    command.upgrade(migration, "head")
    # Also exercise downgrade/re-upgrade on an empty, synthetic-only table.
    command.downgrade(migration, "94a38b0e8f12")
    command.upgrade(migration, "head")
    import uvicorn
    from app.main import app

    @app.get("/__qa_marker")
    async def marker():
        return {
            "database": "source_phase_qa",
            "purpose": "source-phase-upload-validation",
        }

    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    sock.listen(128)
    http_port = sock.getsockname()[1]
    (args.config.parent / "server-info.json").write_text(
        json.dumps(
            {
                "pid": os.getpid(),
                "url": f"http://127.0.0.1:{http_port}/api/v1",
                "migration": "438d7e8c9f10",
                "database": "source_phase_qa",
            }
        )
    )
    print("QA server port", http_port, flush=True)
    uvicorn.Server(uvicorn.Config(app, log_level="warning")).run(sockets=[sock])


if __name__ == "__main__":
    main()
