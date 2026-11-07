"""Track key continuity without storing the encryption key."""
import uuid
from alembic import op
import sqlalchemy as sa

revision = 'fa1942b90531'
down_revision = 'd0247a31e998'
branch_labels = None
depends_on = None


def upgrade():
    table = op.create_table('map_pilot_key_state',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('name', sa.String(16), nullable=False, unique=True),
        sa.Column('key_check', sa.LargeBinary(), nullable=True))
    op.bulk_insert(table, [{'id': uuid.uuid4(), 'name': 'pilot', 'key_check': None}])


def downgrade():
    if op.get_bind().scalar(sa.text('SELECT count(*) FROM map_pilot_contributions')):
        raise RuntimeError('Pilot contributions exist; preserve key continuity and data')
    op.drop_table('map_pilot_key_state')
