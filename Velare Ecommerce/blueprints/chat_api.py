from flask import Blueprint, jsonify, request, session
from datetime import datetime
from database.supabase_helper import (
    get_buyer_conversations,
    get_seller_conversations,
    get_conversation_messages,
    mark_messages_as_read_buyer,
    mark_messages_as_read_seller,
    reset_buyer_unread_count,
    reset_seller_unread_count,
    get_buyer_by_user_id,
    get_seller_by_user_id,
    create_conversation,
    update_conversation_last_message,
    insert_message,
    get_message_by_id,
    search_sellers_by_shop_name,
    get_conversation_by_buyer_seller,
    increment_seller_unread_count,
    increment_buyer_unread_count
)

chat_api_bp = Blueprint('chat_api', __name__)

@chat_api_bp.route('/api/chat/conversations', methods=['GET'])
def get_conversations():
    """Get all conversations for the logged-in user"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    user_id = session['user_id']
    user_type = session.get('user_type', 'buyer')
    
    try:
        if user_type == 'buyer':
            # Get all conversations for buyer (both seller and rider)
            conversations = get_buyer_conversations(user_id)
            
            # Debug: Print conversations
            print(f"=== DEBUG: Loaded {len(conversations)} conversations for buyer ===")
            for conv in conversations:
                print(f"  - {conv.get('contact_type')}: '{conv.get('contact_name')}' (ID: {conv.get('contact_id')})")
            
        elif user_type == 'seller':
            # Get buyer conversations for seller
            conversations = get_seller_conversations(user_id)
        else:
            conversations = []
        
        return jsonify({'conversations': conversations}), 200
        
    except Exception as e:
        print(f"Error getting conversations: {e}")
        return jsonify({'error': str(e)}), 500

@chat_api_bp.route('/api/chat/messages/<int:conversation_id>', methods=['GET'])
def get_messages(conversation_id):
    """Get all messages for a specific conversation"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    user_id = session['user_id']
    user_type = session.get('user_type', 'buyer')
    
    try:
        # Get chat messages
        messages = get_conversation_messages(conversation_id)
        
        # Mark messages as read based on user type
        if user_type == 'buyer':
            mark_messages_as_read_buyer(conversation_id)
            reset_buyer_unread_count(conversation_id)
            
        elif user_type == 'seller':
            mark_messages_as_read_seller(conversation_id)
            reset_seller_unread_count(conversation_id)
        
        return jsonify({'messages': messages}), 200
        
    except Exception as e:
        print(f"Error getting messages: {e}")
        return jsonify({'error': str(e)}), 500

@chat_api_bp.route('/api/chat/send', methods=['POST'])
def send_message():
    """Send a new message"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    conversation_id = data.get('conversation_id')
    contact_id = data.get('contact_id')
    message_text = data.get('message_text', '').strip()
    
    if not message_text:
        return jsonify({'error': 'Message cannot be empty'}), 400
    
    user_id = session['user_id']
    user_type = session.get('user_type', 'buyer')
    
    try:
        # Handle buyer-seller chat messages
        if user_type == 'buyer':
            buyer = get_buyer_by_user_id(user_id)
            if not buyer:
                return jsonify({'error': 'Buyer profile not found'}), 404
            sender_id = buyer['buyer_id']
            
            if not conversation_id:
                # Create new conversation
                conversation_id = create_conversation(sender_id, contact_id, message_text)
                if not conversation_id:
                    return jsonify({'error': 'Failed to create conversation'}), 500
            else:
                # Update existing conversation
                update_conversation_last_message(conversation_id, message_text)
                increment_seller_unread_count(conversation_id)
            
            # Insert message
            message_id = insert_message(conversation_id, 'buyer', sender_id, message_text)
            if not message_id:
                return jsonify({'error': 'Failed to send message'}), 500
            
        elif user_type == 'seller':
            seller = get_seller_by_user_id(user_id)
            if not seller:
                return jsonify({'error': 'Seller profile not found'}), 404
            sender_id = seller['seller_id']
            
            if not conversation_id:
                # Create new conversation
                conversation_id = create_conversation(contact_id, sender_id, message_text)
                if not conversation_id:
                    return jsonify({'error': 'Failed to create conversation'}), 500
            else:
                # Update existing conversation
                update_conversation_last_message(conversation_id, message_text)
                increment_buyer_unread_count(conversation_id)
            
            # Insert message
            message_id = insert_message(conversation_id, 'seller', sender_id, message_text)
            if not message_id:
                return jsonify({'error': 'Failed to send message'}), 500
        else:
            return jsonify({'error': 'Invalid user type'}), 400
        
        # Get the created message
        message = get_message_by_id(message_id)
        
        return jsonify({
            'success': True,
            'message': message,
            'conversation_id': conversation_id
        }), 200
        
    except Exception as e:
        print(f"Error sending message: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@chat_api_bp.route('/api/chat/search-sellers', methods=['GET'])
def search_sellers():
    """Search all sellers by shop name"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    query = request.args.get('q', '').strip()
    
    if not query:
        return jsonify({'sellers': []}), 200
    
    try:
        # Search sellers by shop name
        sellers = search_sellers_by_shop_name(query)
        
        return jsonify({'sellers': sellers}), 200
        
    except Exception as e:
        print(f"Error searching sellers: {e}")
        return jsonify({'error': str(e)}), 500

@chat_api_bp.route('/api/chat/start-conversation', methods=['POST'])
def start_conversation():
    """Start a new conversation with a seller"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    seller_id = data.get('seller_id')
    
    if not seller_id:
        return jsonify({'error': 'Seller ID required'}), 400
    
    user_id = session['user_id']
    
    try:
        # Get buyer_id
        buyer = get_buyer_by_user_id(user_id)
        if not buyer:
            return jsonify({'error': 'Buyer profile not found'}), 404
        buyer_id = buyer['buyer_id']
        
        # Check if conversation already exists
        existing = get_conversation_by_buyer_seller(buyer_id, seller_id)
        
        if existing:
            conversation_id = existing['conversation_id']
        else:
            # Create new conversation
            conversation_id = create_conversation(buyer_id, seller_id, '')
        
        return jsonify({
            'success': True,
            'conversation_id': conversation_id
        }), 200
        
    except Exception as e:
        print(f"Error starting conversation: {e}")
        return jsonify({'error': str(e)}), 500
