#!/bin/bash
# OpenNoiseNet Coolify Deployment Script

echo "🚀 Deploying OpenNoiseNet with Coolify..."

# Copy Coolify environment
cp .env.coolify .env

# Use Coolify-specific docker-compose
docker-compose -f docker-compose.coolify.yml down --remove-orphans
docker-compose -f docker-compose.coolify.yml up -d --build

echo "✅ Deployment complete!"
echo "📋 Services started:"
echo "   - Landing Page (main): Available on your Coolify domain"
echo "   - Backend API: /api/*"
echo "   - React App: /app/*" 
echo "   - Documentation: /docs and /redoc"
echo "   - Health Check: /health"

# Show service status
echo "📊 Service Status:"
docker-compose -f docker-compose.coolify.yml ps