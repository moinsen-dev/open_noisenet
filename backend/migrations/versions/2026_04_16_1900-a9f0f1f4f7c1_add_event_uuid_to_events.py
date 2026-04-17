"""add event_uuid to events

Revision ID: a9f0f1f4f7c1
Revises: 20265cdcb4f1
Create Date: 2026-04-16 19:00:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "a9f0f1f4f7c1"
down_revision = "20265cdcb4f1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("event_uuid", sa.String(length=36), nullable=True))
    op.create_index(op.f("ix_events_event_uuid"), "events", ["event_uuid"], unique=True)


def downgrade() -> None:
    op.drop_index(op.f("ix_events_event_uuid"), table_name="events")
    op.drop_column("events", "event_uuid")
