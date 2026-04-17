"""Add case audit history and status tracking

Revision ID: 94a38b0e8f12
Revises: c3e9d4f7ab21
Create Date: 2026-04-17 16:00:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "94a38b0e8f12"
down_revision = "c3e9d4f7ab21"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("cases", sa.Column("audit_history", sa.JSON(), nullable=True))
    op.add_column("cases", sa.Column("closed_by_id", sa.UUID(), nullable=True))
    op.add_column(
        "cases", sa.Column("last_status_changed_by_id", sa.UUID(), nullable=True)
    )
    op.add_column(
        "cases",
        sa.Column("last_status_changed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_foreign_key(
        op.f("fk_cases_closed_by_id_users"),
        "cases",
        "users",
        ["closed_by_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_foreign_key(
        op.f("fk_cases_last_status_changed_by_id_users"),
        "cases",
        "users",
        ["last_status_changed_by_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(op.f("ix_cases_closed_by_id"), "cases", ["closed_by_id"], unique=False)
    op.create_index(
        op.f("ix_cases_last_status_changed_by_id"),
        "cases",
        ["last_status_changed_by_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_cases_last_status_changed_by_id"), table_name="cases")
    op.drop_index(op.f("ix_cases_closed_by_id"), table_name="cases")
    op.drop_constraint(
        op.f("fk_cases_last_status_changed_by_id_users"),
        "cases",
        type_="foreignkey",
    )
    op.drop_constraint(op.f("fk_cases_closed_by_id_users"), "cases", type_="foreignkey")
    op.drop_column("cases", "last_status_changed_at")
    op.drop_column("cases", "last_status_changed_by_id")
    op.drop_column("cases", "closed_by_id")
    op.drop_column("cases", "audit_history")
