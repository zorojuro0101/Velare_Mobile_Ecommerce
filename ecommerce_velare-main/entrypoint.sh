#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting Velare Application"
echo "=========================================="
echo "📍 Port: ${PORT:-5000}"
echo "🔑 Supabase URL: ${SUPABASE_URL:0:30}..."
echo "🐍 Python version: $(python --version)"
echo "📦 Gunicorn version: $(gunicorn --version)"
echo "=========================================="

# Test if app can be imported
echo "🧪 Testing app import..."
python -c "import app; print('✅ App imported successfully')" || {
    echo "❌ Failed to import app"
    exit 1
}

# Test database connection
echo "🔌 Testing database connection..."
python -c "from database.db_config import get_supabase_client; client = get_supabase_client(); print('✅ Database connected')" || {
    echo "⚠️ Database connection warning (continuing anyway)"
}

echo "🚀 Starting Gunicorn..."
echo "=========================================="

# Start gunicorn with less verbose logging
exec gunicorn \
    --bind 0.0.0.0:${PORT:-5000} \
    --workers 2 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    --capture-output \
    app:app
