"""Add episode, case, and export workflow

Revision ID: c3e9d4f7ab21
Revises: bf93e4b5aa7f
Create Date: 2026-04-17 13:05:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "c3e9d4f7ab21"
down_revision = "bf93e4b5aa7f"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "episodes",
        sa.Column("organization_id", sa.UUID(), nullable=False),
        sa.Column("site_id", sa.UUID(), nullable=False),
        sa.Column("zone_id", sa.UUID(), nullable=True),
        sa.Column("device_id", sa.UUID(), nullable=True),
        sa.Column("policy_id", sa.UUID(), nullable=True),
        sa.Column("primary_class", sa.String(length=128), nullable=False),
        sa.Column("class_family", sa.String(length=128), nullable=True),
        sa.Column("review_label", sa.String(length=128), nullable=True),
        sa.Column("classification_confidence", sa.Float(), nullable=True),
        sa.Column("severity", sa.String(length=32), nullable=False),
        sa.Column("reviewed_severity", sa.String(length=32), nullable=True),
        sa.Column("nuisance_score", sa.Float(), nullable=False),
        sa.Column("quiet_hours_triggered", sa.Boolean(), nullable=False),
        sa.Column("evidence_mode", sa.String(length=32), nullable=False),
        sa.Column("review_state", sa.String(length=32), nullable=False),
        sa.Column("lifecycle_state", sa.String(length=32), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("event_count", sa.Integer(), nullable=False),
        sa.Column("review_notes", sa.Text(), nullable=True),
        sa.Column("review_metadata", sa.JSON(), nullable=True),
        sa.Column("model_bundle_id", sa.String(length=128), nullable=True),
        sa.Column("reviewed_by_id", sa.UUID(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("exported_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["site_id"], ["sites.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["zone_id"], ["zones.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["device_id"], ["devices.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["policy_id"], ["policies.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["reviewed_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_episodes_organization_id"), "episodes", ["organization_id"], unique=False)
    op.create_index(op.f("ix_episodes_site_id"), "episodes", ["site_id"], unique=False)
    op.create_index(op.f("ix_episodes_zone_id"), "episodes", ["zone_id"], unique=False)
    op.create_index(op.f("ix_episodes_device_id"), "episodes", ["device_id"], unique=False)
    op.create_index(op.f("ix_episodes_policy_id"), "episodes", ["policy_id"], unique=False)
    op.create_index(op.f("ix_episodes_reviewed_by_id"), "episodes", ["reviewed_by_id"], unique=False)

    op.add_column("events", sa.Column("episode_id", sa.UUID(), nullable=True))
    op.create_index(op.f("ix_events_episode_id"), "events", ["episode_id"], unique=False)
    op.create_foreign_key(
        "fk_events_episode_id_episodes",
        "events",
        "episodes",
        ["episode_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "cases",
        sa.Column("organization_id", sa.UUID(), nullable=False),
        sa.Column("site_id", sa.UUID(), nullable=False),
        sa.Column("zone_id", sa.UUID(), nullable=True),
        sa.Column("opened_by_id", sa.UUID(), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("opened_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["site_id"], ["sites.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["zone_id"], ["zones.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["opened_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_cases_organization_id"), "cases", ["organization_id"], unique=False)
    op.create_index(op.f("ix_cases_site_id"), "cases", ["site_id"], unique=False)
    op.create_index(op.f("ix_cases_zone_id"), "cases", ["zone_id"], unique=False)
    op.create_index(op.f("ix_cases_opened_by_id"), "cases", ["opened_by_id"], unique=False)

    op.create_table(
        "case_episode_links",
        sa.Column("case_id", sa.UUID(), nullable=False),
        sa.Column("episode_id", sa.UUID(), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["case_id"], ["cases.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["episode_id"], ["episodes.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("case_id", "episode_id", name="uq_case_episode_link"),
    )
    op.create_index(op.f("ix_case_episode_links_case_id"), "case_episode_links", ["case_id"], unique=False)
    op.create_index(op.f("ix_case_episode_links_episode_id"), "case_episode_links", ["episode_id"], unique=False)

    op.create_table(
        "export_jobs",
        sa.Column("case_id", sa.UUID(), nullable=False),
        sa.Column("created_by_id", sa.UUID(), nullable=True),
        sa.Column("format", sa.String(length=16), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("file_name", sa.String(length=255), nullable=False),
        sa.Column("content_type", sa.String(length=128), nullable=False),
        sa.Column("output_text", sa.Text(), nullable=True),
        sa.Column("output_encoding", sa.String(length=32), nullable=False),
        sa.Column("exported_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["case_id"], ["cases.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_export_jobs_case_id"), "export_jobs", ["case_id"], unique=False)
    op.create_index(op.f("ix_export_jobs_created_by_id"), "export_jobs", ["created_by_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_export_jobs_created_by_id"), table_name="export_jobs")
    op.drop_index(op.f("ix_export_jobs_case_id"), table_name="export_jobs")
    op.drop_table("export_jobs")

    op.drop_index(op.f("ix_case_episode_links_episode_id"), table_name="case_episode_links")
    op.drop_index(op.f("ix_case_episode_links_case_id"), table_name="case_episode_links")
    op.drop_table("case_episode_links")

    op.drop_index(op.f("ix_cases_opened_by_id"), table_name="cases")
    op.drop_index(op.f("ix_cases_zone_id"), table_name="cases")
    op.drop_index(op.f("ix_cases_site_id"), table_name="cases")
    op.drop_index(op.f("ix_cases_organization_id"), table_name="cases")
    op.drop_table("cases")

    op.drop_constraint("fk_events_episode_id_episodes", "events", type_="foreignkey")
    op.drop_index(op.f("ix_events_episode_id"), table_name="events")
    op.drop_column("events", "episode_id")

    op.drop_index(op.f("ix_episodes_reviewed_by_id"), table_name="episodes")
    op.drop_index(op.f("ix_episodes_policy_id"), table_name="episodes")
    op.drop_index(op.f("ix_episodes_device_id"), table_name="episodes")
    op.drop_index(op.f("ix_episodes_zone_id"), table_name="episodes")
    op.drop_index(op.f("ix_episodes_site_id"), table_name="episodes")
    op.drop_index(op.f("ix_episodes_organization_id"), table_name="episodes")
    op.drop_table("episodes")
