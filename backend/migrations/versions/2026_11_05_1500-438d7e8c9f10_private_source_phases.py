"""Private source phases with idempotent revisions and deletion tombstones."""

import sqlalchemy as sa
from alembic import op

revision = "438d7e8c9f10"
down_revision = "94a38b0e8f12"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "source_phases",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "device_id",
            sa.Uuid(),
            sa.ForeignKey("devices.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("phase_uuid", sa.Uuid(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("digest", sa.String(64), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("deleted", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.UniqueConstraint(
            "device_id", "phase_uuid", name="uq_source_phase_device_uuid"
        ),
    )
    op.create_index("ix_source_phases_device_id", "source_phases", ["device_id"])


def downgrade():
    op.drop_table("source_phases")
