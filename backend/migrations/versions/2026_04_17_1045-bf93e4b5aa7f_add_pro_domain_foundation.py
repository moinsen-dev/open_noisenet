"""Add Pro domain foundation

Revision ID: bf93e4b5aa7f
Revises: 6f6d9f7b8a2c
Create Date: 2026-04-17 10:45:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "bf93e4b5aa7f"
down_revision = "6f6d9f7b8a2c"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "organizations",
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("slug", sa.String(length=255), nullable=False),
        sa.Column("plan_tier", sa.String(length=32), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("billing_state", sa.String(length=32), nullable=False),
        sa.Column("created_by_id", sa.UUID(), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_organizations_slug"), "organizations", ["slug"], unique=True)

    op.create_table(
        "sites",
        sa.Column("organization_id", sa.UUID(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("timezone", sa.String(length=64), nullable=False),
        sa.Column("address", sa.Text(), nullable=True),
        sa.Column("location_lat", sa.Float(), nullable=True),
        sa.Column("location_lng", sa.Float(), nullable=True),
        sa.Column("is_public", sa.Boolean(), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_sites_organization_id"), "sites", ["organization_id"], unique=False)

    op.create_table(
        "organization_memberships",
        sa.Column("organization_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("role", sa.String(length=32), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("organization_id", "user_id", name="uq_org_membership_org_user"),
    )
    op.create_index(op.f("ix_organization_memberships_organization_id"), "organization_memberships", ["organization_id"], unique=False)
    op.create_index(op.f("ix_organization_memberships_user_id"), "organization_memberships", ["user_id"], unique=False)

    op.create_table(
        "zones",
        sa.Column("site_id", sa.UUID(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("quiet_hours_start", sa.String(length=5), nullable=True),
        sa.Column("quiet_hours_end", sa.String(length=5), nullable=True),
        sa.Column("is_public", sa.Boolean(), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["site_id"], ["sites.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("site_id", "name", name="uq_zone_site_name"),
    )
    op.create_index(op.f("ix_zones_site_id"), "zones", ["site_id"], unique=False)

    op.create_table(
        "policies",
        sa.Column("organization_id", sa.UUID(), nullable=True),
        sa.Column("site_id", sa.UUID(), nullable=True),
        sa.Column("zone_id", sa.UUID(), nullable=True),
        sa.Column("scope_type", sa.String(length=32), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("evidence_mode", sa.String(length=32), nullable=False),
        sa.Column("retention_days", sa.Integer(), nullable=False),
        sa.Column("quiet_hours_start", sa.String(length=5), nullable=True),
        sa.Column("quiet_hours_end", sa.String(length=5), nullable=True),
        sa.Column("day_threshold_db", sa.Float(), nullable=True),
        sa.Column("night_threshold_db", sa.Float(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["site_id"], ["sites.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["zone_id"], ["zones.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_policies_organization_id"), "policies", ["organization_id"], unique=False)
    op.create_index(op.f("ix_policies_site_id"), "policies", ["site_id"], unique=False)
    op.create_index(op.f("ix_policies_zone_id"), "policies", ["zone_id"], unique=False)

    op.create_table(
        "calibration_profiles",
        sa.Column("organization_id", sa.UUID(), nullable=False),
        sa.Column("site_id", sa.UUID(), nullable=True),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("offset_db", sa.Float(), nullable=False),
        sa.Column("method", sa.String(length=255), nullable=True),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["site_id"], ["sites.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_calibration_profiles_organization_id"), "calibration_profiles", ["organization_id"], unique=False)
    op.create_index(op.f("ix_calibration_profiles_site_id"), "calibration_profiles", ["site_id"], unique=False)

    op.add_column("devices", sa.Column("site_id", sa.UUID(), nullable=True))
    op.add_column("devices", sa.Column("zone_id", sa.UUID(), nullable=True))
    op.add_column("devices", sa.Column("calibration_profile_id", sa.UUID(), nullable=True))
    op.create_foreign_key(None, "devices", "sites", ["site_id"], ["id"], ondelete="SET NULL")
    op.create_foreign_key(None, "devices", "zones", ["zone_id"], ["id"], ondelete="SET NULL")
    op.create_foreign_key(
        None,
        "devices",
        "calibration_profiles",
        ["calibration_profile_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(None, "devices", type_="foreignkey")
    op.drop_constraint(None, "devices", type_="foreignkey")
    op.drop_constraint(None, "devices", type_="foreignkey")
    op.drop_column("devices", "calibration_profile_id")
    op.drop_column("devices", "zone_id")
    op.drop_column("devices", "site_id")

    op.drop_index(op.f("ix_calibration_profiles_site_id"), table_name="calibration_profiles")
    op.drop_index(op.f("ix_calibration_profiles_organization_id"), table_name="calibration_profiles")
    op.drop_table("calibration_profiles")

    op.drop_index(op.f("ix_policies_zone_id"), table_name="policies")
    op.drop_index(op.f("ix_policies_site_id"), table_name="policies")
    op.drop_index(op.f("ix_policies_organization_id"), table_name="policies")
    op.drop_table("policies")

    op.drop_index(op.f("ix_zones_site_id"), table_name="zones")
    op.drop_table("zones")

    op.drop_index(op.f("ix_organization_memberships_user_id"), table_name="organization_memberships")
    op.drop_index(op.f("ix_organization_memberships_organization_id"), table_name="organization_memberships")
    op.drop_table("organization_memberships")

    op.drop_index(op.f("ix_sites_organization_id"), table_name="sites")
    op.drop_table("sites")

    op.drop_index(op.f("ix_organizations_slug"), table_name="organizations")
    op.drop_table("organizations")
