#!/bin/bash

# Database Migration Script for OpenNoiseNet
# This script handles database migrations and seeding

set -e

echo "🗄️  OpenNoiseNet Database Migration"
echo "=================================="

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "❌ .env file not found. Please run setup.sh first."
    exit 1
fi

# Check if backend environment is activated
activate_backend() {
    cd backend
    if [ ! -d ".venv" ]; then
        echo "❌ Backend virtual environment not found. Please run setup.sh first."
        exit 1
    fi
    source .venv/bin/activate
}

# Wait for database to be available
wait_for_db() {
    echo "⏳ Waiting for database to be available..."
    
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose exec -T postgres pg_isready -h localhost -p 5432 -U $POSTGRES_USER > /dev/null 2>&1; then
            echo "✅ Database is ready"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo "   Attempt $attempt/$max_attempts..."
        sleep 2
    done
    
    echo "❌ Database failed to become available"
    exit 1
}

# Create initial migration
create_migration() {
    echo "📝 Creating initial database migration..."
    
    if [ ! -f "migrations/versions/001_initial_migration.py" ]; then
        alembic revision --autogenerate -m "Initial migration"
        echo "✅ Initial migration created"
    else
        echo "✅ Initial migration already exists"
    fi
}

# Run migrations
run_migrations() {
    echo "🔄 Running database migrations..."
    
    # Upgrade to latest
    alembic upgrade head
    
    echo "✅ Database migrations completed"
}

# Seed initial data
seed_data() {
    echo "🌱 Seeding initial data..."
    
    # Create a simple Python script to seed data
    cat << 'EOF' > seed_data.py
import asyncio
import sys
import os

# Add the app directory to the path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import AsyncSessionLocal
from app.db.models.user import User
from app.core.config import settings
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

async def create_superuser():
    async with AsyncSessionLocal() as session:
        # Check if superuser already exists
        result = await session.execute(
            "SELECT id FROM users WHERE is_superuser = TRUE LIMIT 1"
        )
        if result.fetchone():
            print("✅ Superuser already exists")
            return
        
        # Create superuser if configured
        if settings.FIRST_SUPERUSER_EMAIL and settings.FIRST_SUPERUSER_PASSWORD:
            hashed_password = pwd_context.hash(settings.FIRST_SUPERUSER_PASSWORD)
            
            user = User(
                email=settings.FIRST_SUPERUSER_EMAIL,
                hashed_password=hashed_password,
                full_name="System Administrator",
                is_active=True,
                is_superuser=True,
                is_verified=True,
            )
            
            session.add(user)
            await session.commit()
            print(f"✅ Superuser created: {settings.FIRST_SUPERUSER_EMAIL}")
        else:
            print("⚠️  No superuser credentials configured in .env")

async def create_sample_data():
    async with AsyncSessionLocal() as session:
        # Add sample system configuration if needed
        result = await session.execute("SELECT COUNT(*) FROM system_config")
        count = result.fetchone()[0]
        
        if count == 0:
            print("🔧 Adding sample system configuration...")
            # System config was added in the database init script
            print("✅ System configuration initialized")
        else:
            print("✅ System configuration already exists")

async def main():
    await create_superuser()
    await create_sample_data()

if __name__ == "__main__":
    asyncio.run(main())
EOF

    # Run the seeding script
    python seed_data.py
    
    # Clean up
    rm seed_data.py
    
    echo "✅ Initial data seeded"
}

# Create a new migration
new_migration() {
    if [ -z "$1" ]; then
        echo "❌ Please provide a migration name"
        echo "Usage: $0 new <migration_name>"
        exit 1
    fi
    
    echo "📝 Creating new migration: $1..."
    alembic revision --autogenerate -m "$1"
    echo "✅ Migration created successfully"
}

# Reset database (WARNING: Destructive)
reset_database() {
    echo "⚠️  WARNING: This will completely reset the database!"
    echo "   All data will be lost. Are you sure? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "🔄 Resetting database..."
        
        # Stop services
        docker-compose down
        
        # Remove database volume
        docker volume rm open_noisenet_postgres_data 2>/dev/null || true
        
        # Start database service
        docker-compose up -d postgres redis
        
        # Wait for database
        wait_for_db
        
        # Run migrations
        run_migrations
        
        # Seed data
        seed_data
        
        # Start all services
        docker-compose up -d
        
        echo "✅ Database reset completed"
    else
        echo "❌ Database reset cancelled"
    fi
}

# Show database status
show_status() {
    echo "📊 Database Status"
    echo "=================="
    
    # Show current migration
    echo "Current migration:"
    alembic current
    
    echo ""
    echo "Migration history:"
    alembic history
    
    echo ""
    echo "Database connection test:"
    python -c "
import asyncio
from app.db.session import engine

async def test_connection():
    try:
        async with engine.begin() as conn:
            result = await conn.execute('SELECT version()')
            version = result.fetchone()[0]
        print(f'✅ Connected to PostgreSQL: {version}')
    except Exception as e:
        print(f'❌ Connection failed: {e}')
    finally:
        await engine.dispose()

asyncio.run(test_connection())
"
}

# Main script logic
main() {
    case "${1:-}" in
        "new")
            activate_backend
            new_migration "$2"
            ;;
        "reset")
            activate_backend
            reset_database
            ;;
        "status")
            activate_backend
            show_status
            ;;
        *)
            # Default: run migrations
            activate_backend
            wait_for_db
            create_migration
            run_migrations
            seed_data
            ;;
    esac
    
    cd ..
}

# Show usage if requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "Commands:"
    echo "  (default)     Run database migrations and seed data"
    echo "  new <name>    Create a new database migration"
    echo "  reset         Reset database (WARNING: destructive)"
    echo "  status        Show database and migration status"
    echo "  --help        Show this help message"
    echo ""
    exit 0
fi

# Run main function
main "$@"