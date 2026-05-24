// Seller Messages Page JavaScript - Three-way Communication (Buyer, Seller, Rider)

// State management
let currentConversation = null;
let conversations = [];
let currentTab = 'all'; // 'all', 'buyers', 'riders'
let messagePollingInterval = null;
let searchTimeout = null;

// DOM Elements
const conversationsList = document.getElementById('conversationsList');
const chatMessages = document.getElementById('chatMessages');
const messageInput = document.getElementById('messageInput');
const sendBtn = document.getElementById('sendBtn');
const conversationSearch = document.getElementById('conversationSearch');
const chatContactName = document.getElementById('chatContactName');
const chatContactType = document.getElementById('chatContactType');
const chatAvatar = document.getElementById('chatAvatar');

// Avatar helpers ------------------------------------------------------------
// A contact is considered to have a real avatar only when the URL is set and
// is not pointing at the placeholder default avatar.
function hasContactAvatar(rawAvatar) {
    return Boolean(
        rawAvatar &&
        !rawAvatar.includes('default-avatar') &&
        rawAvatar !== '/static/images/default-avatar.png'
    );
}

// Normalize avatar URLs so they work whether they come back as Supabase URLs
// or as local /static or static/ paths.
function resolveAvatarSrc(rawAvatar) {
    if (!rawAvatar) return '';
    if (rawAvatar.startsWith('http://') || rawAvatar.startsWith('https://')) return rawAvatar;
    if (rawAvatar.startsWith('/static/')) return rawAvatar;
    if (rawAvatar.startsWith('static/')) return `/${rawAvatar}`;
    return `/static/${rawAvatar}`;
}

// Get the first letter of the contact's name for the initial fallback.
function getContactInitial(name) {
    return name && name.trim() ? name.trim().charAt(0).toUpperCase() : 'U';
}

// Build the avatar HTML used for the chat header, message bubbles, and
// conversation list. Falls back to a styled initial circle when there is no
// avatar, and uses onerror to fall back when the image URL is broken.
function buildAvatarHTML(rawAvatar, name, sizeClass) {
    const initial = getContactInitial(name);
    const safeName = escapeHtml(name || 'User');
    const sizeAttr = sizeClass ? ` ${sizeClass}` : '';

    if (!hasContactAvatar(rawAvatar)) {
        return `<div class="avatar-initial${sizeAttr}">${initial}</div>`;
    }

    const src = resolveAvatarSrc(rawAvatar);
    const fallback = `<div class=&quot;avatar-initial${sizeAttr}&quot;>${initial}</div>`;
    return `<img src="${src}" alt="${safeName}" onerror="this.outerHTML='${fallback}'">`;
}
// ---------------------------------------------------------------------------

// Wait for DOM to be fully loaded
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Seller Messages - Initializing...');
    console.log('📋 conversationsList element:', conversationsList);
    console.log('💬 chatMessages element:', chatMessages);
    
    initializeChat();
    setupEventListeners();
    loadConversations();
});

// Initialize chat system
function initializeChat() {
    setupTabListeners();
    setupSearchListeners();
    setupMessageListeners();
    
    // Start polling for new messages
    startMessagePolling();
}

// Setup event listeners
function setupEventListeners() {
    // Tab switching
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            switchTab(this.dataset.tab);
        });
    });
    
    // Event delegation for conversation items (prevents multiple handlers on refresh)
    if (conversationsList) {
        conversationsList.addEventListener('click', function(e) {
            const conversationItem = e.target.closest('.conversation-item');
            if (conversationItem) {
                const conversationId = conversationItem.dataset.conversationId;
                selectConversation(conversationId);
            }
        });
    }
}

// Setup tab listeners
function setupTabListeners() {
    const tabButtons = document.querySelectorAll('.tab-btn');
    tabButtons.forEach(btn => {
        btn.addEventListener('click', function() {
            // Remove active class from all tabs
            tabButtons.forEach(b => b.classList.remove('active'));
            // Add active class to clicked tab
            this.classList.add('active');
            
            currentTab = this.dataset.tab;
            filterConversations();
        });
    });
}

// Setup search listeners
function setupSearchListeners() {
    conversationSearch.addEventListener('input', function(e) {
        clearTimeout(searchTimeout);
        searchTimeout = setTimeout(() => {
            filterConversations();
        }, 300);
    });
}

// Setup message listeners
function setupMessageListeners() {
    if (sendBtn) {
        sendBtn.addEventListener('click', sendMessage);
    }
    
    if (messageInput) {
        messageInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        });
    }
}



// Switch between tabs
function switchTab(tab) {
    currentTab = tab;
    
    // Update tab UI
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    document.querySelector(`[data-tab="${tab}"]`).classList.add('active');
    
    // Filter conversations
    filterConversations();
}

// Load conversations from server
async function loadConversations() {
    console.log('📞 loadConversations() called');
    
    try {
        console.log('🌐 Fetching /api/chat/conversations...');
        const response = await fetch('/api/chat/conversations');
        const data = await response.json();
        
        console.log('📦 Response status:', response.status);
        console.log('📦 Response data:', data);
        
        if (response.ok) {
            conversations = data.conversations || [];
            console.log('=== LOADED SELLER CONVERSATIONS ===');
            console.log('Total conversations:', conversations.length);
            conversations.forEach((conv, index) => {
                console.log(`[${index}] ${conv.contact_type}: ${conv.contact_name} (ID: ${conv.contact_id})`);
                console.log(`    Avatar: ${conv.contact_avatar || 'NO AVATAR'}`);
            });
            
            filterConversations();
        } else {
            console.error('❌ Error loading conversations:', data.error);
            displayEmptyConversations();
        }
    } catch (error) {
        console.error('❌ Error loading conversations:', error);
        displayEmptyConversations();
    }
}

// Filter conversations based on current tab and search
function filterConversations() {
    let filteredConversations = [...conversations];
    
    // Filter by tab
    if (currentTab === 'buyers') {
        filteredConversations = filteredConversations.filter(conv => conv.contact_type === 'buyer');
    } else if (currentTab === 'riders') {
        filteredConversations = filteredConversations.filter(conv => conv.contact_type === 'rider');
    }
    
    // Filter by search term
    const searchTerm = conversationSearch.value.toLowerCase().trim();
    if (searchTerm) {
        filteredConversations = filteredConversations.filter(conv => 
            conv.contact_name.toLowerCase().includes(searchTerm) ||
            (conv.last_message && conv.last_message.toLowerCase().includes(searchTerm)) ||
            (conv.order_number && conv.order_number.toLowerCase().includes(searchTerm))
        );
    }
    
    // Sort by last message time (most recent first)
    filteredConversations.sort((a, b) => {
        const timeA = new Date(a.last_message_time || 0);
        const timeB = new Date(b.last_message_time || 0);
        return timeB - timeA;
    });
    
    displayConversations(filteredConversations);
}

// Display conversations in the list
function displayConversations(convs) {
    if (!conversationsList) return;
    
    if (!convs || convs.length === 0) {
        displayEmptyConversations();
        return;
    }
    
    // Check if this is first load (no existing conversations)
    const existingItems = conversationsList.querySelectorAll('.conversation-item');
    const isFirstLoad = existingItems.length === 0;
    
    if (isFirstLoad) {
        // First load - render all conversations
        const html = convs.map(conv => createConversationItem(conv)).join('');
        conversationsList.innerHTML = html;
        return;
    }
    
    // Smart update - only update changed conversations instead of reloading everything
    convs.forEach((conv, index) => {
        const existingItem = conversationsList.querySelector(`[data-conversation-id="${conv.conversation_id}"]`);
        
        if (existingItem) {
            // Update existing conversation item (only if data changed)
            const lastMessageEl = existingItem.querySelector('.conversation-message');
            const timeEl = existingItem.querySelector('.conversation-time');
            const unreadBadgeEl = existingItem.querySelector('.unread-badge');
            
            // Update last message if changed
            if (lastMessageEl) {
                const currentText = lastMessageEl.textContent.replace(/\d+$/, '').trim(); // Remove unread count
                const newText = conv.last_message || 'No messages yet';
                if (currentText !== newText) {
                    const unreadBadge = conv.unread_count > 0 ? 
                        `<span class="unread-badge">${conv.unread_count}</span>` : '';
                    lastMessageEl.innerHTML = `${newText} ${unreadBadge}`;
                }
            }
            
            // Update time if changed
            if (timeEl) {
                const newTime = formatTime(conv.last_message_time);
                if (timeEl.textContent !== newTime) {
                    timeEl.textContent = newTime;
                }
            }
            
            // Update unread badge
            if (conv.unread_count > 0) {
                if (!unreadBadgeEl) {
                    lastMessageEl.insertAdjacentHTML('beforeend', `<span class="unread-badge">${conv.unread_count}</span>`);
                } else if (unreadBadgeEl.textContent !== conv.unread_count.toString()) {
                    unreadBadgeEl.textContent = conv.unread_count;
                }
            } else if (unreadBadgeEl) {
                unreadBadgeEl.remove();
            }
            
            // Move to correct position if order changed
            const currentIndex = Array.from(conversationsList.children).indexOf(existingItem);
            if (currentIndex !== index) {
                if (index === 0) {
                    conversationsList.prepend(existingItem);
                } else {
                    const referenceNode = conversationsList.children[index];
                    conversationsList.insertBefore(existingItem, referenceNode);
                }
            }
        } else {
            // New conversation - add it
            const html = createConversationItem(conv);
            if (index === 0) {
                conversationsList.insertAdjacentHTML('afterbegin', html);
            } else {
                const referenceNode = conversationsList.children[index - 1];
                if (referenceNode) {
                    referenceNode.insertAdjacentHTML('afterend', html);
                } else {
                    conversationsList.insertAdjacentHTML('beforeend', html);
                }
            }
        }
    });
    
    // Remove conversations that no longer exist in the filtered list
    const currentIds = convs.map(c => c.conversation_id);
    existingItems.forEach(item => {
        const itemId = parseInt(item.dataset.conversationId);
        if (!currentIds.includes(itemId)) {
            item.remove();
        }
    });
}

// Create conversation item HTML
function createConversationItem(conv) {
    const time = formatTime(conv.last_message_time);
    const unreadBadge = conv.unread_count > 0 ? 
        `<span class="unread-badge">${conv.unread_count}</span>` : '';

    const avatarHTML = buildAvatarHTML(conv.contact_avatar, conv.contact_name);

    // Contact type badge
    const typeBadge = conv.contact_type === 'rider' ? 
        `<span class="contact-type-badge rider">Rider</span>` : '';
    
    // Delivery status for rider conversations
    const deliveryInfo = conv.contact_type === 'rider' && conv.delivery_status ? 
        `<div class="delivery-info">Order #${conv.order_number || 'N/A'} • ${conv.delivery_status}</div>` : '';
    
    return `
        <div class="conversation-item" data-conversation-id="${conv.conversation_id}" data-contact-type="${conv.contact_type}">
            <div class="conversation-avatar">
                ${avatarHTML}
            </div>
            <div class="conversation-info">
                <div class="conversation-header-row">
                    <span class="conversation-name">${conv.contact_name}</span>
                    <span class="conversation-time">${time}</span>
                </div>
                <div class="conversation-message">
                    ${conv.last_message || 'No messages yet'}
                    ${unreadBadge}
                </div>
                ${deliveryInfo}
            </div>
            ${typeBadge}
        </div>
    `;
}

// Display empty conversations state
function displayEmptyConversations() {
    if (!conversationsList) return;
    
    let emptyMessage = 'No conversations yet';
    let emptySubtitle = 'Start chatting with buyers or riders';
    
    if (currentTab === 'buyers') {
        emptyMessage = 'No buyer conversations';
        emptySubtitle = 'Buyers will appear here when they message you';
    } else if (currentTab === 'riders') {
        emptyMessage = 'No rider conversations';
        emptySubtitle = 'Riders will appear here for delivery coordination';
    }
    
    conversationsList.innerHTML = `
        <div class="empty-conversations">
            <i class="bi bi-chat-dots"></i>
            <p>${emptyMessage}</p>
            <p class="empty-subtitle">${emptySubtitle}</p>
        </div>
    `;
}

// Select a conversation
async function selectConversation(conversationId) {
    // Find conversation in our data
    currentConversation = conversations.find(c => c.conversation_id == conversationId);
    
    if (!currentConversation) {
        console.error('Conversation not found:', conversationId);
        return;
    }
    
    console.log('📋 Selected conversation:', currentConversation);
    console.log('🖼️ Contact avatar:', currentConversation.contact_avatar);
    
    // Update active state in UI
    document.querySelectorAll('.conversation-item').forEach(item => {
        item.classList.remove('active');
    });
    document.querySelector(`[data-conversation-id="${conversationId}"]`)?.classList.add('active');
    
    // Update chat header
    updateChatHeader(currentConversation);
    
    // Load messages
    await loadMessages(conversationId);
}

// Update chat header with contact info
function updateChatHeader(conv) {
    if (!chatContactName || !chatContactType) return;
    
    chatContactName.textContent = conv.contact_name;
    
    // Set contact type badge
    if (conv.contact_type === 'rider') {
        chatContactType.textContent = 'Rider • Delivery';
        chatContactType.className = 'chat-contact-type rider';
    } else {
        chatContactType.textContent = 'Buyer';
        chatContactType.className = 'chat-contact-type buyer';
    }
    
    // Update avatar with proper URL handling. We replace the inner HTML of the
    // chat-avatar container so we can render an initial circle when the buyer
    // has no profile picture (instead of falling back to the broken alt text).
    const chatAvatarContainer = document.querySelector('.chat-avatar');
    if (chatAvatarContainer) {
        chatAvatarContainer.innerHTML = buildAvatarHTML(
            conv.contact_avatar,
            conv.contact_name,
            'chat-avatar-initial'
        );
    }
}

// Load messages for a conversation
async function loadMessages(conversationId) {
    try {
        const response = await fetch(`/api/chat/messages/${conversationId}`);
        const data = await response.json();
        
        if (response.ok) {
            const messages = data.messages || [];
            displayMessages(messages);
        } else {
            console.error('Error loading messages:', data.error);
            displayEmptyMessages();
        }
    } catch (error) {
        console.error('Error loading messages:', error);
        displayEmptyMessages();
    }
}

// Display messages in chat area
function displayMessages(messages) {
    if (!chatMessages) return;
    
    if (!messages || messages.length === 0) {
        displayEmptyMessages();
        return;
    }
    
    // Check if we already have messages displayed
    const existingMessages = chatMessages.querySelectorAll('.message:not([id^="temp-"])[data-message-id]');
    
    console.log(`📊 displayMessages: ${messages.length} total, ${existingMessages.length} existing`);
    
    // If we have existing messages, only add new ones (smart refresh)
    if (existingMessages.length > 0) {
        // Get existing message IDs
        const existingIds = Array.from(existingMessages).map(el => parseInt(el.dataset.messageId));
        
        // Find messages that are NOT in the existing list
        const newMessages = messages.filter(msg => !existingIds.includes(msg.message_id));
        
        console.log('🔍 Existing IDs:', existingIds.slice(-5)); // Show last 5
        console.log('🔍 New messages:', newMessages.map(m => `${m.message_id}:${m.message_text.substring(0,10)}`));
        
        // Only append if there are actually new messages
        if (newMessages.length > 0) {
            console.log(`📨 Adding ${newMessages.length} new messages:`);
            newMessages.forEach(msg => {
                console.log(`  - ID ${msg.message_id} from ${msg.sender_type}: "${msg.message_text}"`);
                chatMessages.insertAdjacentHTML('beforeend', createMessageBubble(msg));
            });
            
            // Auto-scroll to bottom
            chatMessages.scrollTop = chatMessages.scrollHeight;
        } else {
            console.log(`⏸️ No new messages`);
        }
    } else {
        // First load - display all messages with date dividers
        console.log(`📨 First load - displaying ${messages.length} messages`);
        const groupedMessages = groupMessagesByDate(messages);
        
        let html = '';
        Object.entries(groupedMessages).forEach(([date, dayMessages]) => {
            html += `<div class="message-date-divider"><span>${date}</span></div>`;
            
            dayMessages.forEach(msg => {
                html += createMessageBubble(msg);
            });
        });
        
        chatMessages.innerHTML = html;
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }
}

// Display empty messages state
function displayEmptyMessages() {
    if (!chatMessages) return;
    
    chatMessages.innerHTML = `
        <div class="empty-chat">
            <i class="bi bi-chat-text"></i>
            <h3>No messages yet</h3>
            <p>Start the conversation with a friendly message</p>
        </div>
    `;
}

// Group messages by date
function groupMessagesByDate(messages) {
    const grouped = {};
    
    messages.forEach(msg => {
        const date = formatDate(msg.created_at);
        if (!grouped[date]) {
            grouped[date] = [];
        }
        grouped[date].push(msg);
    });
    
    return grouped;
}

// Create message bubble HTML
function createMessageBubble(msg) {
    const isSent = msg.sender_type === 'seller';
    const messageClass = isSent ? 'sent' : 'received';
    const time = formatMessageTime(msg.created_at); // Use 12-hour format with AM/PM
    
    // Avatar for received messages. Render an initial circle when the contact
    // has no avatar so the bubble doesn't show a broken image with the full name.
    let avatarHTML = '';
    if (!isSent && currentConversation) {
        const innerAvatar = buildAvatarHTML(
            currentConversation.contact_avatar,
            currentConversation.contact_name,
            'message-avatar-initial'
        );
        avatarHTML = `<div class="message-avatar">${innerAvatar}</div>`;
    }
    
    return `
        <div class="message ${messageClass}" data-message-id="${msg.message_id}">
            ${avatarHTML}
            <div class="message-content">
                <div class="message-bubble">${escapeHtml(msg.message_text)}</div>
                <span class="message-timestamp">${time}</span>
            </div>
        </div>
    `;
}

// Send message
async function sendMessage() {
    if (!messageInput || !currentConversation) return;
    
    const messageText = messageInput.value.trim();
    if (!messageText) return;
    
    // Clear input immediately
    messageInput.value = '';
    
    // Add temporary "sending" message with loading animation
    const tempMessageId = 'temp-' + Date.now();
    const tempMessageHTML = `
        <div class="message sent" id="${tempMessageId}">
            <div class="message-content">
                <div class="message-bubble">${escapeHtml(messageText)}</div>
                <span class="message-timestamp">
                    <div class="message-sending-indicator">
                        <span class="dot"></span>
                        <span class="dot"></span>
                        <span class="dot"></span>
                    </div>
                </span>
            </div>
        </div>
    `;
    
    if (chatMessages) {
        chatMessages.insertAdjacentHTML('beforeend', tempMessageHTML);
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }
    
    try {
        const response = await fetch('/api/chat/send', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                conversation_id: currentConversation.conversation_id,
                contact_id: currentConversation.contact_id,
                message_text: messageText
            })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            // Remove temporary message
            const tempMsg = document.getElementById(tempMessageId);
            if (tempMsg) tempMsg.remove();
            
            // Reload messages
            await loadMessages(currentConversation.conversation_id);
            
            // Reload conversations to update last message
            await loadConversations();
        } else {
            // Remove temporary message and show error
            const tempMsg = document.getElementById(tempMessageId);
            if (tempMsg) tempMsg.remove();
            
            console.error('Error sending message:', data.error);
            alert('Failed to send message. Please try again.');
            
            // Restore message text
            messageInput.value = messageText;
        }
    } catch (error) {
        // Remove temporary message and show error
        const tempMsg = document.getElementById(tempMessageId);
        if (tempMsg) tempMsg.remove();
        
        console.error('Error sending message:', error);
        alert('Failed to send message. Please try again.');
        
        // Restore message text
        messageInput.value = messageText;
    }
}

// Start polling for new messages
function startMessagePolling() {
    if (messagePollingInterval) {
        clearInterval(messagePollingInterval);
    }
    
    messagePollingInterval = setInterval(async () => {
        // Skip while tab is hidden so navigation in other tabs isn't slowed.
        if (document.hidden) return;

        // Reload conversations
        await loadConversations();
        
        // Reload current conversation messages
        if (currentConversation) {
            await loadMessages(currentConversation.conversation_id);
        }
    }, 5000); // Poll every 5 seconds
}

// Format time for display (relative time for conversation list)
function formatTime(dateString) {
    if (!dateString) return '';
    
    // Parse timestamp directly (format: YYYY-MM-DD HH:MM:SS)
    const date = new Date(dateString);
    const now = new Date();
    const diff = now - date;
    
    // Less than 1 minute
    if (diff < 60000) {
        return 'Just now';
    }
    
    // Less than 1 hour
    if (diff < 3600000) {
        const minutes = Math.floor(diff / 60000);
        return `${minutes}m ago`;
    }
    
    // Less than 24 hours
    if (diff < 86400000) {
        const hours = Math.floor(diff / 3600000);
        return `${hours}h ago`;
    }
    
    // Less than 7 days
    if (diff < 604800000) {
        const days = Math.floor(diff / 86400000);
        return `${days}d ago`;
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

// Format date for message grouping
function formatDate(dateString) {
    if (!dateString) return 'Today';
    
    const date = new Date(dateString);
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    
    // Reset time to compare dates
    const resetTime = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
    const resetDate = resetTime(date);
    const resetToday = resetTime(today);
    const resetYesterday = resetTime(yesterday);
    
    if (resetDate.getTime() === resetToday.getTime()) {
        return 'Today';
    } else if (resetDate.getTime() === resetYesterday.getTime()) {
        return 'Yesterday';
    } else {
        return date.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
    }
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Cleanup on page unload
window.addEventListener('beforeunload', function() {
    if (messagePollingInterval) {
        clearInterval(messagePollingInterval);
    }
});
