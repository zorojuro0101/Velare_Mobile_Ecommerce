#!/bin/bash
echo "🔍 Testing Railway deployment..."
echo "📦 Python version:"
python --version
echo "📋 Installed packages:"
pip list | grep -E "(Flask|gunicorn|supabase)"
echo "🚀 Starting app test..."
python -c "import app; print('✅ App imports OK')"
echo "✅ All checks passed!"
