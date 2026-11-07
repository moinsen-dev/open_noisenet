"""Replace unrestricted numeric cell channels with allowlisted area IDs."""
from alembic import op
import sqlalchemy as sa

revision = "7fd2a18b4d03"
down_revision = "53ce6edb0321"
branch_labels = None
depends_on = None


def upgrade():
    if op.get_bind().scalar(sa.text("SELECT count(*) FROM map_pilot_contributions")):
        raise RuntimeError("Pilot contributions exist; preserve them and plan an explicit migration")
    op.drop_column("map_pilot_contributions", "cell_x")
    op.drop_column("map_pilot_contributions", "cell_y")
    op.add_column("map_pilot_contributions", sa.Column("cell_id", sa.String(32), nullable=False))


def downgrade():
    if op.get_bind().scalar(sa.text("SELECT count(*) FROM map_pilot_contributions")):
        raise RuntimeError("Pilot contributions exist; preserve them and plan an explicit migration")
    op.add_column("map_pilot_contributions", sa.Column("cell_x", sa.Integer(), nullable=False))
    op.add_column("map_pilot_contributions", sa.Column("cell_y", sa.Integer(), nullable=False))
    op.drop_column("map_pilot_contributions", "cell_id")
