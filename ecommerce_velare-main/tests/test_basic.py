"""
Basic tests for the Flask application
"""
import pytest
from app import app


def test_app_exists():
    """Test that the Flask app exists"""
    assert app is not None


def test_app_is_flask():
    """Test that app is a Flask instance"""
    assert hasattr(app, 'route')


# Add more tests as needed
# Example:
# def test_home_page():
#     client = app.test_client()
#     response = client.get('/')
#     assert response.status_code == 200
