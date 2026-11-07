"""Add disabled publication guard and immutable aggregate storage."""
import uuid
from alembic import op
import sqlalchemy as sa

revision = "d0247a31e998"
down_revision = "08c37d61faaa"
branch_labels = None
depends_on = None


def columns():
    return [sa.Column('id', sa.Uuid(), primary_key=True),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False)]


def upgrade():
    guard = op.create_table('map_pilot_publication_guard', *columns(),
                            sa.Column('name', sa.String(16), nullable=False, unique=True),
                            sa.Column('enabled', sa.Boolean(), nullable=False))
    op.create_table('map_pilot_published_weeks', *columns(),
                    sa.Column('week_start', sa.Date(), nullable=False, unique=True),
                    sa.Column('band', sa.String(6), nullable=False),
                    sa.Column('suppressed', sa.Boolean(), nullable=False))
    op.create_table('map_pilot_verified_participants', *columns(),
                    sa.Column('user_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, unique=True),
                    sa.Column('verified_at', sa.DateTime(timezone=True), nullable=False))
    op.bulk_insert(guard, [{'id': uuid.uuid4(), 'name': 'pilot', 'enabled': False}])


def downgrade():
    connection = op.get_bind()
    if (connection.scalar(sa.text('SELECT count(*) FROM map_pilot_published_weeks')) or
            connection.scalar(sa.text('SELECT count(*) FROM map_pilot_verified_participants'))):
        raise RuntimeError('Pilot publication data exists; preserve it and plan an explicit migration')
    op.drop_table('map_pilot_verified_participants')
    op.drop_table('map_pilot_published_weeks')
    op.drop_table('map_pilot_publication_guard')
