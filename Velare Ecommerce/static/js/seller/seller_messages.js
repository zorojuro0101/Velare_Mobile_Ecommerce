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

// Wait for DOM to be fully loaded
document.addEventListener('DOMContentLoaded', function() {
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
    try {
        const response = await fetch('/api/chat/conversations');
        const data = await response.json();
        
        if (response.ok) {
            conversations = data.conversations || [];
            console.log('=== LOADED SELLER CONVERSATIONS ===');
            console.log('Total conversations:', conversations.length);
            conversations.forEach((conv, index) => {
                console.log(`[${index}] ${conv.contact_type}: ${conv.contact_name} (ID: ${conv.contact_id})`);
            });
            
            filterConversations();
        } else {
            console.error('Error loading conversations:', data.error);
            displayEmptyConversations();
        }
    } catch (error) {
        console.error('Error loading conversations:', error);
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
    
    const html = convs.map(conv => createConversationItem(conv)).join('');
    conversationsList.innerHTML = html;
    
    // Note: Click handlers are set up once using event delegation in setupEventListeners()
}

// Create conversation item HTML
function createConversationItem(conv) {
    const time = formatTime(conv.last_message_time);
    const unreadBadge = conv.unread_count > 0 ? 
        `<span class="unread-badge">${conv.unread_count}</span>` : '';
    
    // Get first letter for avatar
    const initial = conv.contact_name ? conv.contact_name.charAt(0).toUpperCase() : 'U';
    
    // Check if avatar exists and is not default
    const hasAvatar = conv.contact_avatar && 
                     !conv.contact_avatar.includes('default-avatar') && 
                     conv.contact_avatar !== '/static/images/default-avatar.png';
    
    const avatarHTML = hasAvatar 
        ? `<img src="${conv.contact_avatar}" alt="${conv.contact_name}">`
        : `<div class="avatar-initial">${initial}</div>`;
    
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
    
    // Update avatar
    if (chatAvatar) {
        const hasAvatar = conv.contact_avatar && 
                         !conv.contact_avatar.includes('default-avatar') && 
                         conv.contact_avatar !== '/static/images/default-avatar.png';
        
        if (hasAvatar) {
            chatAvatar.src = conv.contact_avatar;
            chatAvatar.style.display = 'block';
        } else {
            // Use default avatar or initial
            chatAvatar.src = '/static/images/user.png';
        }
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
    
    // Group messages by date
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
    const time = formatTime(msg.created_at);
    
    // Avatar for received messages
    const avatarHTML = !isSent ? `
        <div class="message-avatar">
            <img src="/static/images/user.png" alt="${currentConversation?.contact_name || 'User'}">
        </div>
    ` : '';
    
    return `
        <div class="message ${messageClass}">
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
            // Clear input
            messageInput.value = '';
            
            // Reload messages
            await loadMessages(currentConversation.conversation_id);
            
            // Reload conversations to update last message
            await loadConversations();
        } else {
            console.error('Error sending message:', data.error);
            alert('Failed to send message. Please try again.');
        }
    } catch (error) {
        console.error('Error sending message:', error);
        alert('Failed to send message. Please try again.');
    }
}

// Start polling for new messages
function startMessagePolling() {
    if (messagePollingInterval) {
        clearInterval(messagePollingInterval);
    }
    
    messagePollingInterval = setInterval(async () => {
        // Reload conversations
        await loadConversations();
        
        // Reload current conversation messages
        if (currentConversation) {
            await loadMessages(currentConversation.conversation_id);
        }
    }, 5000); // Poll every 5 seconds
}

// Format time for display
function formatTime(dateString) {
    if (!dateString) return '';
    
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
