// Rider Chat JavaScript

let currentConversation = null;
let buyerConversations = [];
let sellerConversations = [];
let activeTab = 'buyers'; // 'buyers' or 'sellers'
let lastMessageId = 0;
let isSendingMessage = false;

document.addEventListener('DOMContentLoaded', function() {
    initializeChat();
    setupEventListeners();
});

// Initialize chat
function initializeChat() {
    loadConversations();
    updateStatusText();
}

// Setup event listeners
function setupEventListeners() {
    // Online/Offline status toggle
    const statusToggle = document.getElementById('onlineStatus');
    const statusText = document.getElementById('statusText');
    
    if (statusToggle && statusText) {
        statusToggle.addEventListener('change', function() {
            if (this.checked) {
                statusText.textContent = 'Online';
            } else {
                statusText.textContent = 'Offline';
            }
        });
    }

    // Sidebar profile click
    const sidebarProfile = document.getElementById('sidebarProfile');
    if (sidebarProfile) {
        sidebarProfile.addEventListener('click', function(e) {
            e.preventDefault();
            window.location.href = '/rider/profile';
        });
    }

    // Delivery Management toggle
    const deliveryManagementToggle = document.getElementById('deliveryManagementToggle');
    if (deliveryManagementToggle) {
        deliveryManagementToggle.addEventListener('click', function(e) {
            e.preventDefault();
            window.location.href = '/rider/pickup';
        });
    }

    // Tab switching
    const buyersTab = document.getElementById('buyersTab');
    const sellersTab = document.getElementById('sellersTab');
    
    if (buyersTab) {
        buyersTab.addEventListener('click', function() {
            switchTab('buyers');
        });
    }
    
    if (sellersTab) {
        sellersTab.addEventListener('click', function() {
            switchTab('sellers');
        });
    }

    // Search input
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
        searchInput.addEventListener('input', handleSearch);
    }

    // Message input
    const messageInput = document.getElementById('messageInput');
    if (messageInput) {
        messageInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        });
    }

    // Send button
    const sendBtn = document.getElementById('sendBtn');
    if (sendBtn) {
        sendBtn.addEventListener('click', sendMessage);
    }
}

// Switch between Buyers and Sellers tabs
function switchTab(tab) {
    activeTab = tab;
    
    // Update tab UI
    const buyersTab = document.getElementById('buyersTab');
    const sellersTab = document.getElementById('sellersTab');
    
    if (tab === 'buyers') {
        buyersTab.classList.add('active');
        sellersTab.classList.remove('active');
        displayConversations(buyerConversations);
    } else {
        sellersTab.classList.add('active');
        buyersTab.classList.remove('active');
        displayConversations(sellerConversations);
    }
}

// Update status text
function updateStatusText() {
    const statusToggle = document.getElementById('onlineStatus');
    const statusText = document.getElementById('statusText');
    
    if (statusToggle && statusText) {
        if (statusToggle.checked) {
            statusText.textContent = 'Online';
        } else {
            statusText.textContent = 'Offline';
        }
    }
}

// Load conversations
function loadConversations() {
    fetch('/rider/chat/api/conversations')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                buyerConversations = data.buyer_conversations || [];
                sellerConversations = data.seller_conversations || [];
                
                // Display conversations based on active tab
                if (activeTab === 'buyers') {
                    displayConversations(buyerConversations);
                } else {
                    displayConversations(sellerConversations);
                }
            } else {
                console.error('Error loading conversations:', data.error);
                displayEmptyConversations();
            }
        })
        .catch(error => {
            console.error('Error fetching conversations:', error);
            displayEmptyConversations();
        });
}

// Display conversations
function displayConversations(convs) {
    const conversationsList = document.getElementById('conversationsList');
    
    if (!conversationsList) return;
    
    if (!convs || convs.length === 0) {
        displayEmptyConversations();
        return;
    }
    
    conversationsList.innerHTML = convs.map(conv => createConversationItem(conv)).join('');
    
    // Add click handlers - support both buyer_id and seller_id
    document.querySelectorAll('.conversation-item').forEach(item => {
        item.addEventListener('click', function() {
            const convId = this.dataset.conversationId;
            const contactType = this.dataset.contactType;
            const contactId = parseInt(this.dataset.contactId);
            selectConversation(convId, contactId, contactType);
        });
    });
}

// Create conversation item HTML
function createConversationItem(conv) {
    const time = formatTime(conv.last_message_time);
    const unreadBadge = conv.unread_count > 0 ? `<span class="unread-badge">${conv.unread_count}</span>` : '';
    
    // Get first letter of contact name for initial
    const initial = conv.contact_name ? conv.contact_name.charAt(0).toUpperCase() : 'U';
    
    // Debug: Log avatar info
    console.log(`🖼️ Avatar for ${conv.contact_name}:`, conv.contact_avatar);
    
    // Check if avatar is a valid Supabase URL
    const hasAvatar = conv.contact_avatar && 
                     conv.contact_avatar.trim() !== '' &&
                     (conv.contact_avatar.startsWith('http://') || conv.contact_avatar.startsWith('https://')) &&
                     !conv.contact_avatar.includes('default-avatar');
    
    console.log(`  Has valid Supabase avatar: ${hasAvatar}`);
    
    let avatarHTML;
    if (hasAvatar) {
        console.log(`  Avatar URL: ${conv.contact_avatar}`);
        avatarHTML = `<img src="${conv.contact_avatar}" alt="${conv.contact_name}" onerror="this.style.display='none'; this.parentElement.innerHTML='<div class=\\'avatar-initial\\'>${initial}</div>';">`;
    } else {
        console.log(`  Using initial: ${initial}`);
        avatarHTML = `<div class="avatar-initial">${initial}</div>`;
    }
    
    // Show context message (active deliveries)
    const contextText = conv.context_message || 'No active deliveries';
    
    return `
        <div class="conversation-item" data-conversation-id="${conv.conversation_id}" data-contact-id="${conv.contact_id}" data-contact-type="${conv.contact_type}">
            <div class="conversation-avatar">
                ${avatarHTML}
            </div>
            <div class="conversation-details">
                <div class="conversation-header">
                    <span class="conversation-name">${conv.contact_name}</span>
                    <span class="conversation-time">${time}</span>
                </div>
                <div class="conversation-message">
                    ${conv.last_message || 'Start conversation'}
                    ${unreadBadge}
                </div>
                <div style="font-size: 11px; color: #65676b; margin-top: 2px;">
                    ${contextText}
                </div>
            </div>
        </div>
    `;
}

// Display empty conversations
function displayEmptyConversations() {
    const conversationsList = document.getElementById('conversationsList');
    
    if (!conversationsList) return;
    
    const emptyMessage = activeTab === 'buyers' ? 
        'No active deliveries with buyers' : 
        'No active deliveries with sellers';
    
    conversationsList.innerHTML = `
        <div class="empty-conversations">
            <i class="bi bi-chat-dots"></i>
            <p>${emptyMessage}</p>
            <p class="empty-subtitle">Accept deliveries to start chatting</p>
        </div>
    `;
}

// Select conversation
function selectConversation(convId, contactId, contactType) {
    // Find conversation from appropriate list
    const conversations = contactType === 'buyer' ? buyerConversations : sellerConversations;
    currentConversation = conversations.find(c => c.contact_id === contactId);
    
    if (!currentConversation) {
        console.error('❌ Conversation not found for contact_id:', contactId, 'type:', contactType);
        return;
    }
    
    console.log('✅ Selected conversation:', currentConversation);
    
    // Reset last message ID when switching conversations
    lastMessageId = 0;
    
    // Update active state
    document.querySelectorAll('.conversation-item').forEach(item => {
        item.classList.remove('active');
    });
    
    // Find and activate the conversation item
    const conversationItem = document.querySelector(`[data-contact-id="${contactId}"][data-contact-type="${contactType}"]`);
    if (conversationItem) {
        conversationItem.classList.add('active');
    }
    
    // Show chat header and input
    document.getElementById('chatHeader').style.display = 'flex';
    document.getElementById('messageInputContainer').style.display = 'flex';
    
    // Check if there are active orders
    const messageInput = document.getElementById('messageInput');
    const sendBtn = document.getElementById('sendBtn');
    
    if (currentConversation.has_active_orders) {
        // Has active orders - enable messaging
        if (messageInput) {
            messageInput.disabled = false;
            messageInput.placeholder = 'Type a message...';
        }
        if (sendBtn) sendBtn.disabled = false;
    } else {
        // No active orders - disable messaging
        if (messageInput) {
            messageInput.disabled = true;
            messageInput.placeholder = 'No active deliveries. Messaging is disabled.';
        }
        if (sendBtn) sendBtn.disabled = true;
    }
    
    // Update contact info
    const contactAvatarDiv = document.querySelector('.contact-avatar');
    const contactAvatarImg = document.getElementById('contactAvatar');
    
    const hasAvatar = currentConversation.contact_avatar && 
                     !currentConversation.contact_avatar.includes('default-avatar') && 
                     currentConversation.contact_avatar !== '/static/images/default-avatar.png';
    
    if (hasAvatar) {
        let avatarSrc;
        if (currentConversation.contact_avatar.startsWith('http://') || currentConversation.contact_avatar.startsWith('https://')) {
            avatarSrc = currentConversation.contact_avatar;
        } else if (currentConversation.contact_avatar.startsWith('/static/')) {
            avatarSrc = currentConversation.contact_avatar;
        } else if (currentConversation.contact_avatar.startsWith('static/')) {
            avatarSrc = `/${currentConversation.contact_avatar}`;
        } else {
            avatarSrc = `/static/${currentConversation.contact_avatar}`;
        }
        
        contactAvatarImg.src = avatarSrc;
        contactAvatarImg.style.display = 'block';
        
        const existingInitial = contactAvatarDiv.querySelector('.avatar-initial');
        if (existingInitial) existingInitial.remove();
    } else {
        contactAvatarImg.style.display = 'none';
        const initial = currentConversation.contact_name ? currentConversation.contact_name.charAt(0).toUpperCase() : 'U';
        
        const existingInitial = contactAvatarDiv.querySelector('.avatar-initial');
        if (existingInitial) existingInitial.remove();
        
        const initialDiv = document.createElement('div');
        initialDiv.className = 'avatar-initial';
        initialDiv.textContent = initial;
        contactAvatarDiv.appendChild(initialDiv);
    }
    
    document.getElementById('contactName').textContent = currentConversation.contact_name;
    
    // Update status to show active deliveries context
    const contextMessage = currentConversation.context_message || 'No active deliveries';
    document.getElementById('contactStatus').textContent = contextMessage;
    
    // Load messages - use appropriate endpoint based on contact type
    loadMessages(contactId, contactType, true);
}

// Load messages
function loadMessages(contactId, contactType, isInitialLoad = false) {
    const endpoint = contactType === 'buyer' ? 
        `/rider/chat/api/messages/${contactId}` : 
        `/rider/chat/api/seller-messages/${contactId}`;
    
    fetch(endpoint)
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                if (isInitialLoad) {
                    displayMessages(data.messages);
                    if (data.messages.length > 0) {
                        lastMessageId = data.messages[data.messages.length - 1].message_id;
                    }
                } else {
                    const newMessages = data.messages.filter(msg => msg.message_id > lastMessageId);
                    if (newMessages.length > 0) {
                        appendNewMessages(newMessages);
                        lastMessageId = newMessages[newMessages.length - 1].message_id;
                    }
                }
            } else {
                console.error('Error loading messages:', data.error);
                if (isInitialLoad) displayEmptyChat();
            }
        })
        .catch(error => {
            console.error('Error fetching messages:', error);
            if (isInitialLoad) displayEmptyChat();
        });
}

// Display messages
function displayMessages(messages) {
    const messagesArea = document.getElementById('messagesArea');
    
    if (!messagesArea) return;
    
    if (messages.length === 0) {
        messagesArea.innerHTML = `
            <div style="text-align: center; padding: 40px; color: #666666;">
                <i class="bi bi-chat-text" style="font-size: 48px; margin-bottom: 16px; display: block;"></i>
                <p>No messages yet</p>
                <p style="font-size: 13px; color: #999999; margin-top: 8px;">Start the conversation with the buyer</p>
            </div>
        `;
        return;
    }
    
    messagesArea.innerHTML = messages.map(msg => createMessageBubble(msg)).join('');
    
    // Note: We no longer disable chat based on delivery status
    // Profile-based conversations remain active even after deliveries complete
    
    // Scroll to bottom
    messagesArea.scrollTop = messagesArea.scrollHeight;
}

// Append new messages (for real-time updates)
function appendNewMessages(newMessages) {
    const messagesArea = document.getElementById('messagesArea');
    if (!messagesArea) return;
    
    // Remove empty state if exists
    const emptyState = messagesArea.querySelector('div[style*="text-align: center"]');
    if (emptyState) {
        messagesArea.innerHTML = '';
    }
    
    // Add new messages
    newMessages.forEach(msg => {
        const messageHTML = createMessageBubble(msg);
        messagesArea.insertAdjacentHTML('beforeend', messageHTML);
    });
    
    // Scroll to bottom smoothly
    messagesArea.scrollTo({
        top: messagesArea.scrollHeight,
        behavior: 'smooth'
    });
    
    // Play notification sound (optional)
    playNotificationSound();
}

// Play notification sound for new messages
function playNotificationSound() {
    // Simple beep using Web Audio API
    try {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const oscillator = audioContext.createOscillator();
        const gainNode = audioContext.createGain();
        
        oscillator.connect(gainNode);
        gainNode.connect(audioContext.destination);
        
        oscillator.frequency.value = 800;
        oscillator.type = 'sine';
        
        gainNode.gain.setValueAtTime(0.1, audioContext.currentTime);
        gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.1);
        
        oscillator.start(audioContext.currentTime);
        oscillator.stop(audioContext.currentTime + 0.1);
    } catch (e) {
        // Silently fail if audio not supported
    }
}

// Create message bubble HTML
function createMessageBubble(msg) {
    const isSent = msg.sender_type === 'rider';
    const messageClass = isSent ? 'sent' : 'received';
    const time = formatMessageTime(msg.created_at); // Use 12-hour format for messages
    
    return `
        <div class="message ${messageClass}">
            <div class="message-bubble">${escapeHtml(msg.message_text)}</div>
            <div class="message-time" data-timestamp="${msg.created_at}">${time}</div>
        </div>
    `;
}

// Send message
function sendMessage() {
    // Prevent double sending
    if (isSendingMessage) {
        console.log('⏳ Already sending a message, please wait...');
        return;
    }
    
    const messageInput = document.getElementById('messageInput');
    
    if (!messageInput || !currentConversation) return;
    
    const messageText = messageInput.value.trim();
    
    if (!messageText) return;
    
    // Set flag to prevent double sending
    isSendingMessage = true;
    console.log('📤 Sending message...');
    
    // Clear input immediately
    messageInput.value = '';
    
    // Add temporary "sending" message with loading animation
    const messagesArea = document.getElementById('messagesArea');
    const tempMessageId = 'temp-' + Date.now();
    if (messagesArea) {
        const tempMessageHTML = `
            <div class="message sent" id="${tempMessageId}">
                <div class="message-bubble">${escapeHtml(messageText)}</div>
                <div class="message-time">
                    <div class="message-sending-indicator">
                        <span class="dot"></span>
                        <span class="dot"></span>
                        <span class="dot"></span>
                    </div>
                </div>
            </div>
        `;
        messagesArea.insertAdjacentHTML('beforeend', tempMessageHTML);
        messagesArea.scrollTop = messagesArea.scrollHeight;
    }
    
    // Prepare request body based on contact type
    const requestBody = {
        message: messageText
    };
    
    if (currentConversation.contact_type === 'buyer') {
        requestBody.buyer_id = currentConversation.contact_id;
    } else {
        requestBody.seller_id = currentConversation.contact_id;
    }
    
    // Send to server
    fetch('/rider/chat/api/send-message', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestBody)
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Remove temporary message
            const tempMsg = document.getElementById(tempMessageId);
            if (tempMsg) tempMsg.remove();
            
            // Add actual message to UI
            addMessageToUI(data.message);
            
            // Update conversation list
            updateConversationLastMessage(currentConversation.conversation_id, messageText);
            
            console.log('✅ Message sent successfully');
        } else {
            // Remove temporary message and show error
            const tempMsg = document.getElementById(tempMessageId);
            if (tempMsg) tempMsg.remove();
            
            console.error('Error sending message:', data.error);
            alert('Failed to send message. Please try again.');
            
            // Restore message text
            messageInput.value = messageText;
        }
    })
    .catch(error => {
        // Remove temporary message and show error
        const tempMsg = document.getElementById(tempMessageId);
        if (tempMsg) tempMsg.remove();
        
        console.error('Error sending message:', error);
        alert('Failed to send message. Please try again.');
        
        // Restore message text
        messageInput.value = messageText;
    })
    .finally(() => {
        // Reset flag after sending (success or failure)
        isSendingMessage = false;
    });
}

// Add message to UI
function addMessageToUI(message) {
    const messagesArea = document.getElementById('messagesArea');
    
    if (!messagesArea) return;
    
    // Remove empty state if exists
    const emptyState = messagesArea.querySelector('div[style*="text-align: center"]');
    if (emptyState) {
        emptyState.remove();
    }
    
    // Add new message
    const messageHTML = createMessageBubble(message);
    messagesArea.insertAdjacentHTML('beforeend', messageHTML);
    
    // Update lastMessageId to prevent duplicate on next load
    if (message.message_id) {
        lastMessageId = message.message_id;
    }
    
    // Scroll to bottom
    messagesArea.scrollTop = messagesArea.scrollHeight;
}

// Update conversation last message
function updateConversationLastMessage(convId, message) {
    // Update in appropriate list
    const conversations = activeTab === 'buyers' ? buyerConversations : sellerConversations;
    const conv = conversations.find(c => c.conversation_id === convId);
    if (conv) {
        conv.last_message = message;
        conv.last_message_time = new Date().toISOString();
    }
    
    // Re-render conversations
    displayConversations(conversations);
}

// Handle search
function handleSearch(e) {
    const searchTerm = e.target.value.toLowerCase();
    const conversations = activeTab === 'buyers' ? buyerConversations : sellerConversations;
    
    if (!searchTerm) {
        displayConversations(conversations);
        return;
    }
    
    const filtered = conversations.filter(conv => 
        conv.contact_name.toLowerCase().includes(searchTerm) ||
        (conv.active_deliveries && conv.active_deliveries.some(d => 
            d.order_number.toLowerCase().includes(searchTerm) ||
            (d.shop_name && d.shop_name.toLowerCase().includes(searchTerm))
        ))
    );
    
    displayConversations(filtered);
}

// Display empty chat
function displayEmptyChat() {
    const messagesArea = document.getElementById('messagesArea');
    
    if (!messagesArea) return;
    
    messagesArea.innerHTML = `
        <div class="empty-chat">
            <i class="bi bi-chat-text"></i>
            <h3>Select a conversation</h3>
            <p>Choose a delivery from the list to start messaging with the buyer</p>
        </div>
    `;
}

// Format time
// Format time for conversation list (relative time)
function formatTime(dateString) {
    if (!dateString) return '';
    
    console.log('🕐 formatTime input:', dateString);
    
    // Parse timestamp directly (format: YYYY-MM-DD HH:MM:SS)
    const date = new Date(dateString);
    const now = new Date();
    const diff = now - date;
    
    console.log('🕐 Date:', date, 'Now:', now, 'Diff (ms):', diff);
    
    // Less than 1 minute
    if (diff < 60000) {
        return 'Just now';
    }
    
    // Less than 1 hour
    if (diff < 3600000) {
        const minutes = Math.floor(diff / 60000);
        return `${minutes}m`;
    }
    
    // Less than 24 hours
    if (diff < 86400000) {
        const hours = Math.floor(diff / 3600000);
        return `${hours}h`;
    }
    
    // Less than 7 days
    if (diff < 604800000) {
        const days = Math.floor(diff / 86400000);
        return `${days}d`;
    }
    
    // More than 7 days
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

// Format time for message bubbles (12-hour format with AM/PM)
function formatMessageTime(dateString) {
    if (!dateString) return '';
    
    // Parse timestamp directly (format: YYYY-MM-DD HH:MM:SS)
    const date = new Date(dateString);
    
    // Format as 12-hour time with AM/PM (e.g., 3:50 PM)
    let hours = date.getHours();
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12 || 12; // Convert to 12-hour format
    
    return `${hours}:${minutes} ${ampm}`;
}

// Escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Update message times every second
function updateMessageTimes() {
    const messageTimes = document.querySelectorAll('.message-time');
    messageTimes.forEach(timeElement => {
        const timestamp = timeElement.dataset.timestamp;
        if (timestamp) {
            timeElement.textContent = formatTime(timestamp);
        }
    });
}

// Auto-refresh conversations every 15 seconds (reduced from 5 seconds)
// Only refresh if page is visible to save resources
let conversationRefreshInterval = setInterval(() => {
    if (!document.hidden) {
        loadConversations();
    }
}, 15000);

// Auto-refresh messages every 10 seconds if conversation is open (reduced from 5 seconds)
// Only refresh if page is visible
let messageRefreshInterval = setInterval(() => {
    if (!document.hidden && currentConversation && currentConversation.contact_id) {
        loadMessages(currentConversation.contact_id, currentConversation.contact_type);
    }
}, 10000);

// Update message times every 30 seconds for real-time display (reduced from 10 seconds)
let timeUpdateInterval = setInterval(() => {
    updateMessageTimes();
}, 30000);

// Pause auto-refresh when page is hidden, resume when visible
document.addEventListener('visibilitychange', function() {
    if (document.hidden) {
        console.log('💤 Page hidden - pausing auto-refresh');
    } else {
        console.log('👁️ Page visible - resuming auto-refresh');
        // Immediately refresh when page becomes visible
        loadConversations();
        if (currentConversation && currentConversation.contact_id) {
            loadMessages(currentConversation.contact_id, currentConversation.contact_type);
        }
    }
});
