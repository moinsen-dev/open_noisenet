"""Private opt-in pilot intake, disabled by default."""
from alembic import op
import sqlalchemy as sa

revision = "53ce6edb0321"
down_revision = "dc6312a49e15"
branch_labels = None
depends_on = None


def common():
    return [sa.Column("id", sa.Uuid(), primary_key=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False)]


def upgrade():
    op.create_table("map_pilot_consents", *common(),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("generation", sa.Uuid(), nullable=False),
        sa.Column("consented_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("notice_version", sa.String(32), nullable=False))
    op.create_table("map_pilot_contributions", *common(),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("cell_x", sa.Integer(), nullable=False),
        sa.Column("cell_y", sa.Integer(), nullable=False),
        sa.Column("level_band", sa.String(16), nullable=False),
        sa.UniqueConstraint("user_id", "day", name="uq_map_pilot_user_day"))


def downgrade():
    op.drop_table("map_pilot_contributions")
    op.drop_table("map_pilot_consents")
