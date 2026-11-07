"""Use encrypted pilot payloads; preserve existing rows by refusing migration."""
from alembic import op
import sqlalchemy as sa

revision = "08c37d61faaa"
down_revision = "4eb3f01961c1"
branch_labels = None
depends_on = None


def upgrade():
    if op.get_bind().scalar(sa.text("SELECT count(*) FROM map_pilot_contributions")):
        raise RuntimeError("Pilot contributions exist; preserve them and plan an explicit migration")
    op.drop_column("map_pilot_contributions", "cell_id")
    op.drop_column("map_pilot_contributions", "level_band")
    op.add_column("map_pilot_contributions", sa.Column("payload_nonce", sa.LargeBinary(), nullable=False))
    op.add_column("map_pilot_contributions", sa.Column("payload_ciphertext", sa.LargeBinary(), nullable=False))


def downgrade():
    if op.get_bind().scalar(sa.text("SELECT count(*) FROM map_pilot_contributions")):
        raise RuntimeError("Pilot contributions exist; preserve them and plan an explicit migration")
    op.add_column("map_pilot_contributions", sa.Column("cell_id", sa.String(32), nullable=False))
    op.add_column("map_pilot_contributions", sa.Column("level_band", sa.String(16), nullable=False))
    op.drop_column("map_pilot_contributions", "payload_nonce")
    op.drop_column("map_pilot_contributions", "payload_ciphertext")
