"""Non-identifying retention heartbeat for the isolated pilot."""
from alembic import op
import sqlalchemy as sa

revision = "4eb3f01961c1"
down_revision = "7fd2a18b4d03"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("map_pilot_retention_runs",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=False))


def downgrade():
    op.drop_table("map_pilot_retention_runs")
