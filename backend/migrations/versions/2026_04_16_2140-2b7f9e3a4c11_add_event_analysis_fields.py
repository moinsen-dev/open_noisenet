"""add event analysis fields

Revision ID: 2b7f9e3a4c11
Revises: a9f0f1f4f7c1
Create Date: 2026-04-16 21:40:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "2b7f9e3a4c11"
down_revision: Union[str, None] = "a9f0f1f4f7c1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "events",
        sa.Column(
            "analysis_state",
            sa.String(length=64),
            nullable=False,
            server_default="not_started",
        ),
    )
    op.add_column(
        "events", sa.Column("classification_label", sa.String(length=100), nullable=True)
    )
    op.add_column(
        "events",
        sa.Column("classification_confidence", sa.Float(), nullable=True),
    )
    op.add_column(
        "events", sa.Column("classification_source", sa.String(length=64), nullable=True)
    )
    op.add_column("events", sa.Column("segment_type", sa.String(length=64), nullable=True))
    op.add_column("events", sa.Column("reportability_score", sa.Float(), nullable=True))
    op.add_column(
        "events", sa.Column("reportability_reason", sa.String(length=255), nullable=True)
    )
    op.add_column(
        "events", sa.Column("peak_to_average_delta_db", sa.Float(), nullable=True)
    )
    op.add_column("events", sa.Column("variability_db", sa.Float(), nullable=True))
    op.add_column(
        "events", sa.Column("threshold_exceedance_ratio", sa.Float(), nullable=True)
    )
    op.add_column(
        "events",
        sa.Column("analysis_updated_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_index(
        op.f("ix_events_analysis_state"), "events", ["analysis_state"], unique=False
    )
    op.create_index(
        op.f("ix_events_classification_label"),
        "events",
        ["classification_label"],
        unique=False,
    )

    op.alter_column("events", "analysis_state", server_default=None)


def downgrade() -> None:
    op.drop_index(op.f("ix_events_classification_label"), table_name="events")
    op.drop_index(op.f("ix_events_analysis_state"), table_name="events")
    op.drop_column("events", "analysis_updated_at")
    op.drop_column("events", "threshold_exceedance_ratio")
    op.drop_column("events", "variability_db")
    op.drop_column("events", "peak_to_average_delta_db")
    op.drop_column("events", "reportability_reason")
    op.drop_column("events", "reportability_score")
    op.drop_column("events", "segment_type")
    op.drop_column("events", "classification_source")
    op.drop_column("events", "classification_confidence")
    op.drop_column("events", "classification_label")
    op.drop_column("events", "analysis_state")
