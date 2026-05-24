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
    print(f"\n{'='*80}")
    print(f"💬 [RIDER CHAT] Loading chat page...")
    print(f"{'='*80}\n")
    
    # Check if user is logged in and is a rider
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return redirect(url_for('auth.login'))
    
    try:
        # Get rider information from Supabase
        rider_data = get_rider_by_user_id(session['user_id'])
        
        if not rider_data:
            print("❌ Rider profile not found")
            return render_template('rider/rider_chat.html', error='Rider profile not found')
        
        print(f"✅ Rider: {rider_data.get('first_name')} {rider_data.get('last_name')}")
        print(f"{'='*80}\n")
        return render_template('rider/rider_chat.html', rider=rider_data)
        
    except Exception as e:
        print(f"❌ Error fetching rider data: {e}")
        return render_template('rider/rider_chat.html', error='Failed to load rider data')

@rider_chat_bp.route('/rider/chat/api/conversations', methods=['GET'])
def get_rider_conversations_api():
    """Get all conversations for the logged-in rider (grouped by buyer AND seller)"""
    print(f"\n{'='*80}")
    print(f"💬 [CONVERSATIONS] Loading conversations...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Get rider_id
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}")
        
        supabase = get_supabase()
        
        # Get ALL conversations for this rider (not just active deliveries)
        # We'll show conversations that have either:
        # 1. Active deliveries (assigned, in_transit)
        # 2. Recent messages (within last 7 days) even if delivered
        
        # First, get all existing conversations
        all_conversations_response = supabase.table('conversations').select('''
            conversation_id,
            buyer_id,
            seller_id,
            last_message,
            last_message_at,
            rider_unread_count
        ''').eq('rider_id', rider_id).execute()
        
        existing_conversations = all_conversations_response.data if all_conversations_response.data else []
        print(f"💬 Found {len(existing_conversations)} existing conversations")
        
        # Get active deliveries for this rider
        deliveries_response = supabase.table('deliveries').select('''
            delivery_id,
            order_id,
            status,
            delivery_address,
            assigned_at,
            delivered_at,
            orders (
                order_number,
                buyer_id,
                seller_id,
                created_at,
                sellers (
                    seller_id,
                    shop_name,
                    first_name,
                    last_name,
                    shop_logo,
                    phone_number
                )
            )
        ''').eq('rider_id', rider_id).in_('status', ['assigned', 'in_transit', 'delivered']).order('assigned_at', desc=True).execute()
        
        deliveries_data = clean_supabase_data(deliveries_response.data) if deliveries_response.data else []
        print(f"📦 Found {len(deliveries_data)} deliveries (including delivered)")
        
        # DEBUG: Print all deliveries
        for d in deliveries_data:
            order = d.get('orders', {})
            print(f"  - Delivery {d.get('delivery_id')}: Order {order.get('order_number')} (Buyer {order.get('buyer_id')}, Seller {order.get('seller_id')}) - Status: {d.get('status')}")
        
        # Group deliveries by buyer_id AND seller_id
        buyers_map = {}
        sellers_map = {}
        
        for delivery in deliveries_data:
            order = delivery.get('orders', {})
            buyer_id = order.get('buyer_id')
            seller_id = order.get('seller_id')
            status = delivery.get('status')
            
            # Group by buyer
            if buyer_id:
                if buyer_id not in buyers_map:
                    buyers_map[buyer_id] = {
                        'buyer_id': buyer_id,
                        'deliveries': [],
                        'active_deliveries': [],
                        'last_activity': delivery.get('assigned_at')
                    }
                    print(f"  ➕ Created buyer group for buyer_id {buyer_id}")
                
                delivery_info = {
                    'delivery_id': delivery['delivery_id'],
                    'order_number': order.get('order_number'),
                    'shop_name': order.get('sellers', {}).get('shop_name'),
                    'status': status,
                    'address': delivery['delivery_address'],
                    'delivered_at': delivery.get('delivered_at')
                }
                
                buyers_map[buyer_id]['deliveries'].append(delivery_info)
                
                # Track active deliveries separately
                if status in ['assigned', 'in_transit']:
                    buyers_map[buyer_id]['active_deliveries'].append(delivery_info)
                
                print(f"  ✅ Added order {order.get('order_number')} to buyer {buyer_id} group (status: {status})")
            
            # Group by seller
            if seller_id:
                if seller_id not in sellers_map:
                    sellers_map[seller_id] = {
                        'seller_id': seller_id,
                        'seller_info': order.get('sellers', {}),
                        'deliveries': [],
                        'active_deliveries': [],
                        'last_activity': delivery.get('assigned_at')
                    }
                    print(f"  ➕ Created seller group for seller_id {seller_id}")
                
                delivery_info = {
                    'delivery_id': delivery['delivery_id'],
                    'order_number': order.get('order_number'),
                    'status': status,
                    'address': delivery['delivery_address'],
                    'delivered_at': delivery.get('delivered_at')
                }
                
                sellers_map[seller_id]['deliveries'].append(delivery_info)
                
                # Track active deliveries separately
                if status in ['assigned', 'in_transit']:
                    sellers_map[seller_id]['active_deliveries'].append(delivery_info)
                
                print(f"  ✅ Added order {order.get('order_number')} to seller {seller_id} group (status: {status})")
        
        print(f"👥 Found {len(buyers_map)} unique buyers, {len(sellers_map)} unique sellers")
        
        # Get buyer conversations
        buyer_conversations = []
        for buyer_id, buyer_data in buyers_map.items():
            print(f"\n  🔍 Processing buyer {buyer_id}...")
            
            # Get buyer info
            buyer_response = supabase.table('buyers').select('''
                buyer_id,
                first_name,
                last_name,
                profile_image,
                phone_number
            ''').eq('buyer_id', buyer_id).execute()
            
            print(f"  📊 Buyer query response: {buyer_response.data}")
            
            if not buyer_response.data:
                print(f"  ❌ No buyer data found for buyer_id {buyer_id} - SKIPPING")
                continue
            
            buyer = buyer_response.data[0]
            print(f"  ✅ Buyer found: {buyer.get('first_name')} {buyer.get('last_name')}")
            
            # Check if conversation exists
            conv_response = supabase.table('conversations').select('''
                conversation_id,
                last_message,
                last_message_at,
                rider_unread_count
            ''').eq('rider_id', rider_id).eq('buyer_id', buyer_id).is_('seller_id', 'null').execute()
            
            # Get conversation details or use defaults
            if conv_response.data and len(conv_response.data) > 0:
                conv = conv_response.data[0]
                conversation_id = conv['conversation_id']
                last_message = conv.get('last_message', 'Start conversation')
                last_message_time = conv.get('last_message_at', buyer_data['last_activity'])
                unread_count = conv.get('rider_unread_count', 0)
            else:
                conversation_id = f"new_buyer_{buyer_id}"
                last_message = 'Start conversation'
                last_message_time = buyer_data['last_activity']
                unread_count = 0
            
            # Parse last message time
            formatted_time = None
            if last_message_time:
                try:
                    formatted_time = datetime.fromisoformat(str(last_message_time).replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M:%S')
                except:
                    formatted_time = None
            
            # Get buyer profile image (Supabase URL)
            buyer_profile_image = buyer.get('profile_image')
            print(f"  📸 Profile image from DB: {buyer_profile_image}")
            
            # Use Supabase URL directly or default avatar
            if buyer_profile_image and (buyer_profile_image.startswith('http://') or buyer_profile_image.startswith('https://')):
                buyer_avatar = buyer_profile_image
            else:
                # No valid Supabase URL - use default
                buyer_avatar = '/static/images/default-avatar.png'
            
            print(f"  ✅ Avatar URL: {buyer_avatar}")
            
            # Create context message - show active deliveries first, then delivered
            if buyer_data['active_deliveries']:
                order_details = []
                for d in buyer_data['active_deliveries']:
                    status_emoji = '📦' if d['status'] == 'assigned' else '🚚'
                    order_details.append(f"{status_emoji} {d['order_number']}")
                context_message = " • ".join(order_details)
                
                # Add delivered count if any
                delivered_count = len([d for d in buyer_data['deliveries'] if d['status'] == 'delivered'])
                if delivered_count > 0:
                    context_message += f" • ✅ {delivered_count} delivered"
            else:
                # No active deliveries, show delivered ones
                delivered_deliveries = [d for d in buyer_data['deliveries'] if d['status'] == 'delivered']
                if delivered_deliveries:
                    context_message = f"✅ {len(delivered_deliveries)} order(s) delivered"
                else:
                    context_message = "No active deliveries"
            
            buyer_conversations.append({
                'conversation_id': conversation_id,
                'contact_id': buyer_id,
                'buyer_id': buyer_id,
                'contact_name': f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}",
                'contact_avatar': buyer_avatar,
                'contact_phone': buyer.get('phone_number'),
                'active_deliveries': buyer_data['active_deliveries'],
                'all_deliveries': buyer_data['deliveries'],
                'has_active_orders': len(buyer_data['active_deliveries']) > 0,
                'context_message': context_message,
                'last_message': last_message,
                'last_message_time': formatted_time,
                'unread_count': unread_count,
                'contact_type': 'buyer'
            })
        
        # Get seller conversations
        seller_conversations = []
        for seller_id, seller_data in sellers_map.items():
            seller = seller_data['seller_info']
            
            # Check if conversation exists
            conv_response = supabase.table('conversations').select('''
                conversation_id,
                last_message,
                last_message_at,
                rider_unread_count
            ''').eq('rider_id', rider_id).eq('seller_id', seller_id).is_('buyer_id', 'null').execute()
            
            # Get conversation details or use defaults
            if conv_response.data and len(conv_response.data) > 0:
                conv = conv_response.data[0]
                conversation_id = conv['conversation_id']
                last_message = conv.get('last_message', 'Start conversation')
                last_message_time = conv.get('last_message_at', seller_data['last_activity'])
                unread_count = conv.get('rider_unread_count', 0)
            else:
                conversation_id = f"new_seller_{seller_id}"
                last_message = 'Start conversation'
                last_message_time = seller_data['last_activity']
                unread_count = 0
            
            # Parse last message time
            formatted_time = None
            if last_message_time:
                try:
                    formatted_time = datetime.fromisoformat(str(last_message_time).replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M:%S')
                except:
                    formatted_time = None
            
            # Get seller shop logo (Supabase URL)
            seller_profile_image = seller.get('shop_logo')
            
            # Use Supabase URL directly or default avatar
            if seller_profile_image and (seller_profile_image.startswith('http://') or seller_profile_image.startswith('https://')):
                seller_avatar = seller_profile_image
            else:
                # No valid Supabase URL - use default
                seller_avatar = '/static/images/default-avatar.png'
            
            # Create context message - show active deliveries first, then delivered
            if seller_data['active_deliveries']:
                order_details = []
                for d in seller_data['active_deliveries']:
                    status_emoji = '📦' if d['status'] == 'assigned' else '🚚'
                    order_details.append(f"{status_emoji} {d['order_number']}")
                context_message = " • ".join(order_details)
                
                # Add delivered count if any
                delivered_count = len([d for d in seller_data['deliveries'] if d['status'] == 'delivered'])
                if delivered_count > 0:
                    context_message += f" • ✅ {delivered_count} delivered"
            else:
                # No active deliveries, show delivered ones
                delivered_deliveries = [d for d in seller_data['deliveries'] if d['status'] == 'delivered']
                if delivered_deliveries:
                    context_message = f"✅ {len(delivered_deliveries)} order(s) delivered"
                else:
                    context_message = "No active deliveries"
            
            seller_conversations.append({
                'conversation_id': conversation_id,
                'contact_id': seller_id,
                'seller_id': seller_id,
                'contact_name': seller.get('shop_name') or f"{seller.get('first_name', '')} {seller.get('last_name', '')}",
                'contact_avatar': seller_avatar,
                'contact_phone': seller.get('phone_number'),
                'active_deliveries': seller_data['active_deliveries'],
                'all_deliveries': seller_data['deliveries'],
                'has_active_orders': len(seller_data['active_deliveries']) > 0,
                'context_message': context_message,
                'last_message': last_message,
                'last_message_time': formatted_time,
                'unread_count': unread_count,
                'contact_type': 'seller'
            })
        
        # Sort both by last activity
        buyer_conversations.sort(key=lambda x: x['last_message_time'] or '', reverse=True)
        seller_conversations.sort(key=lambda x: x['last_message_time'] or '', reverse=True)
        
        print(f"✅ Returning {len(buyer_conversations)} buyer conversations, {len(seller_conversations)} seller conversations")
        print(f"{'='*80}\n")
        
        return jsonify({
            'success': True,
            'buyer_conversations': buyer_conversations,
            'seller_conversations': seller_conversations
        }), 200
        
    except Exception as e:
        print(f"❌ Error getting rider conversations: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@rider_chat_bp.route('/rider/chat/api/messages/<int:buyer_id>', methods=['GET'])
def get_buyer_messages(buyer_id):
    """Get messages for a specific buyer (profile-based conversation) - OPTIMIZED"""
    print(f"\n{'='*80}")
    print(f"💬 [MESSAGES] Loading messages for buyer {buyer_id}...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Verify rider
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}, Buyer ID: {buyer_id}")
        
        supabase = get_supabase()
        
        # OPTIMIZATION: Single query to check conversation and get messages
        conversation_response = supabase.table('conversations').select('conversation_id').eq('rider_id', rider_id).eq('buyer_id', buyer_id).is_('seller_id', 'null').limit(1).execute()
        
        if not conversation_response.data:
            # No conversation yet - return empty messages
            # Conversation will be created when first message is sent
            print(f"📋 No conversation yet - will be created on first message")
            return jsonify({'success': True, 'messages': []}), 200
        
        conversation_id = conversation_response.data[0]['conversation_id']
        print(f"📋 Conversation ID: {conversation_id}")
        
        # Get messages (limit to last 100 for performance)
        messages_response = supabase.table('messages').select('message_id, sender_id, sender_type, message_text, is_read, created_at').eq('conversation_id', conversation_id).order('created_at', desc=False).limit(100).execute()
        
        messages = messages_response.data if messages_response.data else []
        print(f"💬 Found {len(messages)} messages")
        
        # Mark messages as read (async - don't wait for response)
        if messages:
            try:
                supabase.table('messages').update({'is_read': True}).eq('conversation_id', conversation_id).eq('is_read', False).neq('sender_type', 'rider').execute()
            except:
                pass  # Don't fail if marking as read fails
        
        # Format messages
        formatted_messages = []
        for msg in messages:
            # Parse created_at
            created_at = None
            if msg.get('created_at'):
                try:
                    created_at = datetime.fromisoformat(str(msg['created_at']).replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M:%S')
                except:
                    created_at = str(msg['created_at'])
            
            formatted_messages.append({
                'message_id': msg['message_id'],
                'sender_id': msg['sender_id'],
                'sender_type': msg['sender_type'],
                'message_text': msg['message_text'],
                'is_read': bool(msg.get('is_read')),
                'created_at': created_at
            })
        
        print(f"✅ Returning {len(formatted_messages)} messages")
        print(f"{'='*80}\n")
        return jsonify({'success': True, 'messages': formatted_messages}), 200
        
    except Exception as e:
        print(f"❌ Error getting buyer messages: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@rider_chat_bp.route('/rider/chat/api/seller-messages/<int:seller_id>', methods=['GET'])
def get_seller_messages(seller_id):
    """Get messages for a specific seller (profile-based conversation) - OPTIMIZED"""
    print(f"\n{'='*80}")
    print(f"💬 [MESSAGES] Loading messages for seller {seller_id}...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        # Verify rider
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}, Seller ID: {seller_id}")
        
        supabase = get_supabase()
        
        # OPTIMIZATION: Single query to check conversation and get messages
        conversation_response = supabase.table('conversations').select('conversation_id').eq('rider_id', rider_id).eq('seller_id', seller_id).is_('buyer_id', 'null').limit(1).execute()
        
        if not conversation_response.data:
            # No conversation yet - return empty messages
            print(f"📋 No conversation yet - will be created on first message")
            return jsonify({'success': True, 'messages': []}), 200
        
        conversation_id = conversation_response.data[0]['conversation_id']
        print(f"📋 Conversation ID: {conversation_id}")
        
        # Get messages (limit to last 100 for performance)
        messages_response = supabase.table('messages').select('message_id, sender_id, sender_type, message_text, is_read, created_at').eq('conversation_id', conversation_id).order('created_at', desc=False).limit(100).execute()
        
        messages = messages_response.data if messages_response.data else []
        print(f"💬 Found {len(messages)} messages")
        
        # Mark messages as read (async - don't wait for response)
        if messages:
            try:
                supabase.table('messages').update({'is_read': True}).eq('conversation_id', conversation_id).eq('is_read', False).neq('sender_type', 'rider').execute()
            except:
                pass
        
        # Format messages
        formatted_messages = []
        for msg in messages:
            created_at = None
            if msg.get('created_at'):
                try:
                    created_at = datetime.fromisoformat(str(msg['created_at']).replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M:%S')
                except:
                    created_at = str(msg['created_at'])
            
            formatted_messages.append({
                'message_id': msg['message_id'],
                'sender_id': msg['sender_id'],
                'sender_type': msg['sender_type'],
                'message_text': msg['message_text'],
                'is_read': bool(msg.get('is_read')),
                'created_at': created_at
            })
        
        print(f"✅ Returning {len(formatted_messages)} messages")
        print(f"{'='*80}\n")
        return jsonify({'success': True, 'messages': formatted_messages}), 200
        
    except Exception as e:
        print(f"❌ Error getting seller messages: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@rider_chat_bp.route('/rider/chat/api/send-message', methods=['POST'])
def send_rider_message():
    """Send a message from rider to buyer OR seller (profile-based conversation) - OPTIMIZED"""
    print(f"\n{'='*80}")
    print(f"📤 [SEND MESSAGE] Sending message...")
    print(f"{'='*80}\n")
    
    if 'user_id' not in session or session.get('user_type') != 'rider':
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.get_json()
    buyer_id = data.get('buyer_id')
    seller_id = data.get('seller_id')
    message_text = data.get('message')
    
    if (not buyer_id and not seller_id) or not message_text:
        return jsonify({'error': 'Missing required fields'}), 400
    
    if buyer_id and seller_id:
        return jsonify({'error': 'Cannot send to both buyer and seller'}), 400
    
    contact_type = 'buyer' if buyer_id else 'seller'
    contact_id = buyer_id if buyer_id else seller_id
    
    print(f"👤 {contact_type.capitalize()} ID: {contact_id}")
    print(f"💬 Message: {message_text[:50]}...")
    
    try:
        # Get rider info
        rider = get_rider_by_user_id(session['user_id'])
        
        if not rider:
            return jsonify({'error': 'Rider not found'}), 404
        
        rider_id = rider['rider_id']
        print(f"🔍 Rider ID: {rider_id}")
        
        supabase = get_supabase()
        
        # OPTIMIZATION: Check if conversation exists, create if not
        if contact_type == 'buyer':
            conversation_response = supabase.table('conversations').select('conversation_id').eq('rider_id', rider_id).eq('buyer_id', buyer_id).is_('seller_id', 'null').limit(1).execute()
        else:
            conversation_response = supabase.table('conversations').select('conversation_id').eq('rider_id', rider_id).eq('seller_id', seller_id).is_('buyer_id', 'null').limit(1).execute()
        
        if not conversation_response.data:
            # Create new conversation
            print(f"💬 Creating new conversation with {contact_type}...")
            if contact_type == 'buyer':
                conversation_id = create_conversation(buyer_id, None, message_text, rider_id, None)
            else:
                conversation_id = create_conversation(None, seller_id, message_text, rider_id, None)
            
            if not conversation_id:
                return jsonify({'error': 'Failed to create conversation'}), 500
        else:
            conversation_id = conversation_response.data[0]['conversation_id']
            print(f"📋 Using conversation ID: {conversation_id}")
            
            # Update last message (quick update)
            try:
                supabase.table('conversations').update({
                    'last_message': message_text,
                    'last_message_at': datetime.now().isoformat()
                }).eq('conversation_id', conversation_id).execute()
            except:
                pass  # Don't fail if update fails
        
        # Insert message
        message_id = insert_message(conversation_id, 'rider', session['user_id'], message_text)
        
        if not message_id:
            return jsonify({'error': 'Failed to send message'}), 500
        
        print(f"✅ Message sent (ID: {message_id})")
        
        # Increment unread count (async - don't wait)
        try:
            if contact_type == 'buyer':
                supabase.table('conversations').update({
                    'buyer_unread_count': supabase.table('conversations').select('buyer_unread_count').eq('conversation_id', conversation_id).execute().data[0].get('buyer_unread_count', 0) + 1
                }).eq('conversation_id', conversation_id).execute()
            else:
                supabase.table('conversations').update({
                    'seller_unread_count': supabase.table('conversations').select('seller_unread_count').eq('conversation_id', conversation_id).execute().data[0].get('seller_unread_count', 0) + 1
                }).eq('conversation_id', conversation_id).execute()
        except:
            pass  # Don't fail if increment fails
        
        print(f"{'='*80}\n")
        return jsonify({
            'success': True,
            'message': {
                'message_id': message_id,
                'sender_id': session['user_id'],
                'sender_type': 'rider',
                'message_text': message_text,
                'created_at': datetime.utcnow().isoformat() + 'Z',
                'is_read': False
            }
        }), 200
        
    except Exception as e:
        print(f"❌ Error sending message: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500
