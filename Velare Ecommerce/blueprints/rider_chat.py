from flask import Blueprint, render_template, session, redirect, url_for, jsonify, request
import sys
import os
from datetime import datetime

# Add the parent directory to the path to import db_config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.supabase_helper import *

rider_chat_bp = Blueprint('rider_chat', __name__)

@rider_chat_bp.route('/rider/chat')
def rider_chat():
    # Check if user is logged in and is a rider
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return redirect(url_for('auth.login'))
    
    try:
        # Get rider information from Supabase
        rider_data = get_rider_by_user_id(session['user_id'])
        
        if not rider_data:
            return render_template('rider/rider_chat.html', error='Rider profile not found')
        
        return render_template('rider/rider_chat.html', rider=rider_data)
        
    except Exception as e:
        print(f"Error fetching rider data: {e}")
        return render_template('rider/rider_chat.html', error='Failed to load rider data')

@rider_chat_bp.route('/rider/chat/api/conversations', methods=['GET'])
def get_rider_conversations_api():
    """Get all conversations for the logged-in rider (with buyers and sellers)"""
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Get rider_id
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        
        # Get conversations from deliveries (riders communicate with buyers about deliveries)
        supabase = get_supabase()
        response = supabase.table('deliveries').select('''
            order_id,
            delivery_id,
            status,
            delivery_address,
            assigned_at,
            orders (
                order_number,
                created_at,
                buyer_id,
                seller_id,
                buyers (
                    buyer_id,
                    first_name,
                    last_name,
                    profile_image,
                    phone_number
                ),
                sellers (
                    shop_name
                )
            )
        ''').eq('rider_id', rider_id).in_('status', ['assigned', 'picked_up', 'in_transit', 'delivered']).order('assigned_at', desc=True).execute()
        
        conversations_data = clean_supabase_data(response.data) if response.data else []
        conversations_data = fix_image_urls_in_data(conversations_data)
        
        # Format the data
        formatted_conversations = []
        for conv in conversations_data:
            order = conv.get('orders', {})
            buyer = order.get('buyers', {})
            seller = order.get('sellers', {})
            
            # Parse order date
            order_date = None
            if order.get('created_at'):
                try:
                    order_date = datetime.fromisoformat(order['created_at'].replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M:%S')
                except:
                    order_date = None
            
            formatted_conversations.append({
                'conversation_id': f"delivery_{conv['delivery_id']}",
                'delivery_id': conv['delivery_id'],
                'order_id': conv['order_id'],
                'order_number': order.get('order_number'),
                'contact_id': buyer.get('buyer_id'),
                'contact_name': f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}",
                'contact_avatar': buyer.get('profile_image') or '/static/images/default-avatar.png',
                'contact_phone': buyer.get('phone_number'),
                'seller_shop': seller.get('shop_name'),
                'delivery_status': conv['status'],
                'delivery_address': conv['delivery_address'],
                'last_message': f"Delivery for Order #{order.get('order_number')}",
                'last_message_time': order_date,
                'unread_count': 0,
                'contact_type': 'buyer'
            })
        
        return jsonify({'success': True, 'conversations': formatted_conversations}), 200
        
    except Exception as e:
        print(f"Error getting rider conversations: {e}")
        return jsonify({'error': str(e)}), 500

@rider_chat_bp.route('/rider/chat/api/messages/<int:delivery_id>', methods=['GET'])
def get_delivery_messages(delivery_id):
    """Get messages for a specific delivery"""
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Verify rider owns this delivery
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        # Get delivery info
        supabase = get_supabase()
        delivery_response = supabase.table('deliveries').select('''
            delivery_id,
            rider_id,
            orders (
                order_id,
                buyer_id,
                order_number,
                sellers (
                    shop_name
                )
            )
        ''').eq('delivery_id', delivery_id).eq('rider_id', rider['rider_id']).execute()
        
        if not delivery_response.data:
            return jsonify({'error': 'Delivery not found'}), 404
        
        delivery = clean_supabase_data(delivery_response.data[0])
        order = delivery.get('orders', {})
        buyer_id = order.get('buyer_id')
        
        # Get or create conversation
        conversation_response = supabase.table('conversations').select('conversation_id').eq('delivery_id', delivery_id).eq('rider_id', rider['rider_id']).eq('buyer_id', buyer_id).execute()
        
        if not conversation_response.data:
            # Create new conversation with initial message
            seller = order.get('sellers', {})
            initial_message = f"Hi! I'm your rider for Order #{order.get('order_number')} from {seller.get('shop_name')}. I'll keep you updated on your delivery."
            
            conversation_id = create_conversation(buyer_id, None, initial_message, rider['rider_id'], delivery_id)
            
            # Insert initial system message
            insert_message(conversation_id, 'rider', session['user_id'], initial_message)
        else:
            conversation_id = conversation_response.data[0]['conversation_id']
        
        # Get messages
        messages = get_conversation_messages(conversation_id)
        
        # Mark messages as read
        mark_messages_as_read_rider(conversation_id)
        
        # Format messages
        formatted_messages = []
        for msg in messages:
            # Parse created_at
            created_at = None
            if msg.get('created_at'):
                try:
                    created_at = datetime.fromisoformat(msg['created_at'].replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M:%S')
                except:
                    created_at = None
            
            formatted_messages.append({
                'message_id': msg['message_id'],
                'sender_id': msg['sender_id'],
                'sender_type': msg['sender_type'],
                'message_text': msg['message_text'],
                'is_read': bool(msg.get('is_read')),
                'created_at': created_at
            })
        
        return jsonify({'success': True, 'messages': formatted_messages}), 200
        
    except Exception as e:
        print(f"Error getting delivery messages: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@rider_chat_bp.route('/rider/chat/api/send-message', methods=['POST'])
def send_rider_message():
    """Send a message from rider to buyer"""
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.get_json()
    delivery_id = data.get('delivery_id')
    message_text = data.get('message')
    
    if not delivery_id or not message_text:
        return jsonify({'error': 'Missing required fields'}), 400
    
    try:
        # Get rider info
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        # Verify delivery belongs to rider
        supabase = get_supabase()
        delivery_response = supabase.table('deliveries').select('''
            delivery_id,
            orders (
                buyer_id
            )
        ''').eq('delivery_id', delivery_id).eq('rider_id', rider['rider_id']).execute()
        
        if not delivery_response.data:
            return jsonify({'error': 'Delivery not found or unauthorized'}), 403
        
        delivery = clean_supabase_data(delivery_response.data[0])
        buyer_id = delivery.get('orders', {}).get('buyer_id')
        
        # Get or create conversation
        conversation_response = supabase.table('conversations').select('conversation_id').eq('delivery_id', delivery_id).eq('rider_id', rider['rider_id']).eq('buyer_id', buyer_id).execute()
        
        if not conversation_response.data:
            # Create new conversation
            conversation_id = create_conversation(buyer_id, None, message_text, rider['rider_id'], delivery_id)
        else:
            conversation_id = conversation_response.data[0]['conversation_id']
            # Update last message
            update_conversation_last_message(conversation_id, message_text)
        
        # Insert message
        message_id = insert_message(conversation_id, 'rider', session['user_id'], message_text)
        
        # Increment buyer unread count
        increment_buyer_unread_count(conversation_id)
        
        return jsonify({
            'success': True,
            'message': {
                'message_id': message_id,
                'sender_id': session['user_id'],
                'sender_type': 'rider',
                'message_text': message_text,
                'created_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'is_read': False
            }
        }), 200
        
    except Exception as e:
        print(f"Error sending message: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500
