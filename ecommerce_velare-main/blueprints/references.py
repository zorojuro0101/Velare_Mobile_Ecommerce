from flask import Blueprint, render_template, session

references_bp = Blueprint('references', __name__)

@references_bp.route('/references')
def references():
    is_logged_in = 'user_id' in session
    return render_template('references.html', is_logged_in=is_logged_in)
