"""Keep shared organizations when their creator deletes their account."""
from alembic import op
import sqlalchemy as sa

revision = "dc6312a49e15"
down_revision = "438d7e8c9f10"
branch_labels = None
depends_on = None


def _change(action, nullable):
    bind = op.get_bind()
    matches = [fk for fk in sa.inspect(bind).get_foreign_keys("organizations")
               if fk["constrained_columns"] == ["created_by_id"] and fk["referred_table"] == "users"]
    if len(matches) != 1:
        raise RuntimeError("Expected one organizations.created_by_id foreign key")
    op.drop_constraint(matches[0]["name"], "organizations", type_="foreignkey")
    op.alter_column("organizations", "created_by_id", nullable=nullable)
    op.create_foreign_key("fk_org_creator", "organizations", "users", ["created_by_id"], ["id"], ondelete=action)


def upgrade():
    _change("SET NULL", True)
    op.create_table("revoked_device_keys",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("fingerprint", sa.String(64), unique=True, nullable=False))


def downgrade():
    if op.get_bind().scalar(sa.text("SELECT count(*) FROM organizations WHERE created_by_id IS NULL")):
        raise RuntimeError("Cannot restore required creator without assigning existing shared organizations")
    _change("CASCADE", False)
    op.drop_table("revoked_device_keys")
