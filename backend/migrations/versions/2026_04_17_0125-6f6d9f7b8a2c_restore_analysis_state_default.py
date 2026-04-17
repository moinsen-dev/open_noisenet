"""restore analysis_state server default

Revision ID: 6f6d9f7b8a2c
Revises: 2b7f9e3a4c11
Create Date: 2026-04-17 01:25:00.000000
"""

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "6f6d9f7b8a2c"
down_revision: Union[str, None] = "2b7f9e3a4c11"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column("events", "analysis_state", server_default="not_started")


def downgrade() -> None:
    op.alter_column("events", "analysis_state", server_default=None)
