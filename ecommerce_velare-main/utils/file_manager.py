"""
File Manager Utility
Handles organized file uploads for users with separate folders per user and document type
"""
import os
from werkzeug.utils import secure_filename

# Base upload directory
BASE_UPLOAD_DIR = 'static/uploads'

# Document type folders
DOCUMENT_TYPES = {
    'seller': {
        'id': 'seller_ids',
        'business_permit': 'seller_permits'
    },
    'rider': {
        'orcr': 'rider_orcr',
        'driver_license': 'rider_dl'
    },
    'buyer': {
        'id': 'buyer_ids'
    }
}

def get_user_document_path(user_type, user_id, document_type):
    """
    Get the organized path for a user's document
    
    Args:
        user_type: 'seller', 'rider', or 'buyer'
        user_id: The user's ID
        document_type: Type of document (e.g., 'id', 'business_permit', 'orcr', 'driver_license')
    
    Returns:
        Tuple of (full_path, db_path)
        - full_path: Full filesystem path for saving
        - db_path: Path to store in database (with /static/ prefix)
    """
    if user_type not in DOCUMENT_TYPES:
        raise ValueError(f"Invalid user_type: {user_type}")
    
    if document_type not in DOCUMENT_TYPES[user_type]:
        raise ValueError(f"Invalid document_type '{document_type}' for user_type '{user_type}'")
    
    # Get the document folder name
    doc_folder = DOCUMENT_TYPES[user_type][document_type]
    
    # Create path: uploads/{doc_type}/user_{id}/
    relative_path = os.path.join('uploads', doc_folder, f'user_{user_id}')
    full_path = os.path.join(BASE_UPLOAD_DIR, doc_folder, f'user_{user_id}')
    db_path = f"/static/uploads/{doc_folder}/user_{user_id}"
    
    return full_path, db_path

def save_user_document(file, user_type, user_id, document_type, original_filename=None):
    """
    Save a user document to the organized folder structure
    
    Args:
        file: The file object from request.files
        user_type: 'seller', 'rider', or 'buyer'
        user_id: The user's ID
        document_type: Type of document
        original_filename: Optional original filename (if not using file.filename)
    
    Returns:
        Tuple of (success, db_path, error_message)
    """
    try:
        if not file or not file.filename:
            return False, None, "No file provided"
        
        # Get the organized path
        full_path, db_path = get_user_document_path(user_type, user_id, document_type)
        
        # Create directory if it doesn't exist
        os.makedirs(full_path, exist_ok=True)
        
        # Generate secure filename
        filename = original_filename or file.filename
        secure_name = secure_filename(filename)
        
        # Add timestamp to avoid conflicts
        import time
        timestamp = str(int(time.time() * 1000))
        final_filename = f"{document_type}_{timestamp}_{secure_name}"
        
        # Save the file
        file_full_path = os.path.join(full_path, final_filename)
        file.save(file_full_path)
        
        # Return database path
        final_db_path = f"{db_path}/{final_filename}"
        
        return True, final_db_path, None
        
    except Exception as e:
        return False, None, str(e)

def allowed_file(filename, allowed_extensions=None):
    """Check if file extension is allowed"""
    if allowed_extensions is None:
        allowed_extensions = {'png', 'jpg', 'jpeg', 'pdf', 'gif', 'webp'}
    
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in allowed_extensions
