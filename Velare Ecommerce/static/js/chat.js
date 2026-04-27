// Chat Widget Functionality
(function() {
    'use strict';

    // State management
    let currentConversationId = null;
    let currentContactId = null;
    let currentContactType = null;
    let currentContactName = null; // Store current contact/shop name
    let conversations = [];
    let messagePollingInterval = null;
    let searchTimeout = null; // For debouncing search
    let currentSearchQuery = ''; // Store current search query

    // DOM Elements
    const chatWidget = document.getElementById('chat-widget');
    const chatButton = document.getElementById('chat-button');
    const chatWindow = document.getElementById('chat-window');
    const closeChat = document.getElementById('close-chat');
    const chatContacts = document.querySelector('.chat-contacts');
    const chatRightPanel = document.querySelector('.chat-right-panel');
    const chatWelcome = document.querySelector('.chat-welcome');

    // Check if user is logged in
    function isUserLoggedIn() {
        // Check if user is logged in by looking for session data
        return document.body.dataset.isLoggedIn === 'true';
    }

    // Initialize chat
    function initChat() {
        if (!chatButton || !chatWindow) {
            console.error('Chat elements not found');
            return;
        }

        // Toggle chat window
        chatButton.addEventListener('click', async function(e) {
            e.stopPropagation();
            
            // Check if user is logged in
            if (!isUserLoggedIn()) {
                openChatWindow();
                showLoginRequired();
                return;
            }
            
            // Check if we're on a product page and should auto-open with seller
            const chatWithShopBtn = document.getElementById('chat-with-shop-btn');
            if (chatWithShopBtn) {
                const sellerId = parseInt(chatWithShopBtn.dataset.sellerId);
                const shopName = chatWithShopBtn.dataset.shopName;
                
                if (sellerId && shopName) {
                    // Open chat window and start conversation with this seller
                    openChatWindow();
                    // Wait for conversations to load before opening seller chat
                    await loadConversations();
                    await openNewSellerChat(sellerId, shopName);
                    return;
                }
            }
            
            // Otherwise, just toggle normally
            toggleChatWindow();
        });

        // Close chat
        if (closeChat) {
            closeChat.addEventListener('click', function(e) {
                e.stopPropagation();
                closeChatWindow();
            });
        }

        // Close chat when clicking outside
        document.addEventListener('click', function(e) {
            if (chatWindow.classList.contains('chat-window-visible') && 
                !chatWidget.contains(e.target)) {
                closeChatWindow();
            }
        });

        // Prevent chat window clicks from closing it
        chatWindow.addEventListener('click', function(e) {
            e.stopPropagation();
        });

        // Event delegation for conversation clicks (prevents multiple handlers on refresh)
        if (chatContacts) {
            chatContacts.addEventListener('click', function(e) {
                const contactElement = e.target.closest('.chat-contact');
                if (contactElement) {
                    // Check if this is a search result (new seller chat)
                    if (contactElement.dataset.sellerId) {
                        const sellerId = parseInt(contactElement.dataset.sellerId);
                        const shopName = contactElement.dataset.shopName;
                        console.log('Opening chat with seller:', sellerId, shopName);
                        openNewSellerChat(sellerId, shopName);
                    } 
                    // Otherwise it's an existing conversation
                    else {
                        const conversationId = contactElement.dataset.conversationId || null;
                        const contactId = contactElement.dataset.contactId;
                        const contactType = contactElement.dataset.contactType;
                        openConversation(conversationId, contactId, contactType);
                    }
                }
            });
        }

        // Load conversations when chat is opened
        loadConversations();
        
        // Add handler for "Chat with Shop" button on product pages
        const chatWithShopBtn = document.getElementById('chat-with-shop-btn');
        if (chatWithShopBtn) {
            chatWithShopBtn.addEventListener('click', async function(e) {
                e.stopPropagation();
                const sellerId = parseInt(this.dataset.sellerId);
                const shopName = this.dataset.shopName;
                
                if (sellerId && shopName) {
                    openChatWindow();
                    // Wait for conversations to load before opening seller chat
                    await loadConversations();
                    await openNewSellerChat(sellerId, shopName);
                }
            });
            
            // Add hover effect
            chatWithShopBtn.addEventListener('mouseenter', function() {
                this.style.background = 'black';
                this.style.color = 'white';
                this.style.transform = 'translateY(-2px)';
                this.style.boxShadow = '0 4px 8px rgba(0, 0, 0, 0.2)';
            });
            
            chatWithShopBtn.addEventListener('mouseleave', function() {
                this.style.background = 'white';
                this.style.color = 'black';
                this.style.transform = 'translateY(0)';
                this.style.boxShadow = 'none';
            });
        }
    }

    function toggleChatWindow() {
        const isVisible = chatWindow.classList.contains('chat-window-visible');
        
        if (isVisible) {
            closeChatWindow();
        } else {
            openChatWindow();
        }
    }

    // Show login required message for guest users
    function showLoginRequired() {
        if (!chatRightPanel || !chatContacts) return;
        
        // Hide welcome message
        if (chatWelcome) {
            chatWelcome.classList.add('hidden');
        }
        
        // Show login required in left panel
        chatContacts.innerHTML = `
            <div style="display: flex; flex-direction: column; align-items: center; justify-content: flex-start; height: 100%; padding: 60px 20px 40px 20px; text-align: center;">
                <div style="width: 80px; height: 80px; border-radius: 50%; background: #f5f5f5; display: flex; align-items: center; justify-content: center; margin-bottom: 20px;">
                    <svg width="40" height="40" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z" fill="#999"/>
                    </svg>
                </div>
                <h3 style="margin: 0 0 8px 0; font-size: 18px; font-weight: 600; color: #181818; font-family: 'Cinzel', serif; letter-spacing: 1px;">Login Required</h3>
                <p style="margin: 0 0 24px 0; font-size: 14px; color: #666; font-family: 'Goudy Bookletter 1911', serif;">Please log in to use the chat feature</p>
                <a href="/login" style="padding: 12px 32px; background: #181818; color: white; text-decoration: none; border-radius: 2px; font-size: 14px; font-weight: 500; font-family: 'Goudy Bookletter 1911', serif; transition: background 0.2s;" onmouseover="this.style.background='#bf9f4a'" onmouseout="this.style.background='#181818'">Login Now</a>
            </div>
        `;
        
        // Show welcome message in right panel
        chatRightPanel.innerHTML = `
            <div class="chat-welcome" style="display: flex;">
                <div class="welcome-icon">
                    <svg width="80" height="60" viewBox="0 0 100 75" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <rect x="10" y="15" width="80" height="50" rx="8" fill="#e0d7c6" stroke="#bf9f4a" stroke-width="2"/>
                        <rect x="15" y="20" width="70" height="30" rx="4" fill="#fafafa"/>
                        <rect x="20" y="25" width="25" height="3" rx="1.5" fill="#bf9f4a"/>
                        <rect x="20" y="30" width="35" height="3" rx="1.5" fill="#bf9f4a"/>
                        <rect x="20" y="35" width="20" height="3" rx="1.5" fill="#bf9f4a"/>
                        <circle cx="65" cy="35" r="8" fill="#181818"/>
                        <circle cx="65" cy="35" r="3" fill="white"/>
                        <circle cx="67" cy="33" r="1" fill="#181818"/>
                        <circle cx="69" cy="35" r="1" fill="#181818"/>
                        <circle cx="67" cy="37" r="1" fill="#181818"/>
                    </svg>
                </div>
                <h4>WELCOME TO VELARE CHAT</h4>
                <p>Search and connect with sellers to start chatting</p>
            </div>
        `;
        chatRightPanel.classList.remove('hidden');
    }

    function openChatWindow() {
        chatWindow.classList.remove('chat-window-hidden');
        chatWindow.classList.add('chat-window-visible');
        chatButton.classList.add('chat-opened');
        
        // Only load conversations if user is logged in
        if (isUserLoggedIn()) {
            loadConversations();
        }
        
        // Setup search after window opens
        setTimeout(() => {
            const searchInput = document.querySelector('.chat-search-input');
            console.log('Search input found:', searchInput); // Debug
            
            if (searchInput) {
                // Clear any existing value
                searchInput.value = '';
                
                // Remove any existing listeners
                searchInput.removeEventListener('input', handleSearch);
                searchInput.removeEventListener('keyup', handleSearch);
                
                // Add new listeners
                searchInput.addEventListener('input', handleSearch);
                searchInput.addEventListener('keyup', handleSearch);
                
                console.log('Search listeners attached!'); // Debug
                
                // Test if it works
                searchInput.addEventListener('focus', function() {
                    console.log('Search input focused!');
                });
            } else {
                console.error('Search input NOT found!');
            }
        }, 200);
        
        // Start polling for new messages
        if (!messagePollingInterval) {
            messagePollingInterval = setInterval(pollForNewMessages, 5000); // Poll every 5 seconds
        }
    }
    
    // Handle search input with debouncing
    function handleSearch(e) {
        const query = e.target.value;
        currentSearchQuery = query; // Store the query
        
        console.log('handleSearch triggered! Value:', query); // Debug
        
        // Clear previous timeout
        if (searchTimeout) {
            clearTimeout(searchTimeout);
        }
        
        // Debounce search - wait 300ms after user stops typing
        searchTimeout = setTimeout(() => {
            filterConversations(query);
        }, 300);
    }

    function closeChatWindow() {
        chatWindow.classList.remove('chat-window-visible');
        chatWindow.classList.add('chat-window-hidden');
        chatButton.classList.remove('chat-opened');
        
        // Stop polling
        if (messagePollingInterval) {
            clearInterval(messagePollingInterval);
            messagePollingInterval = null;
        }
    }

    // Load all conversations
    async function loadConversations() {
        try {
            const response = await fetch('/api/chat/conversations');
            const data = await response.json();

            if (response.ok) {
                conversations = data.conversations || [];
                console.log('=== LOADED CONVERSATIONS ===');
                console.log('Total:', conversations.length);
                console.log('Raw data:', conversations);
                
                // Show each conversation's contact_name
                conversations.forEach((conv, index) => {
                    console.log(`[${index}] contact_name: "${conv.contact_name}" (type: ${typeof conv.contact_name})`);
                });
                
                console.log('Full JSON:', JSON.stringify(conversations, null, 2));
                renderConversations(true); // Force update on initial load
            } else {
                console.error('Error loading conversations:', data.error);
            }
        } catch (error) {
            console.error('Error loading conversations:', error);
        }
    }

    // Render conversation list
    function renderConversations(forceUpdate = false) {
        if (!chatContacts) return;

        // Filter out delivered conversations older than 20 seconds
        const filteredConversations = conversations.filter(conv => {
            if (conv.delivery_status === 'delivered' && conv.last_message_time) {
                const lastMessageDate = new Date(conv.last_message_time);
                const now = new Date();
                const diffSeconds = (now - lastMessageDate) / 1000;
                return diffSeconds <= 20; // Keep only if 20 seconds or less
            }
            return true; // Keep non-delivered conversations
        });

        // Check if we need to update (compare with existing DOM)
        const existingContacts = chatContacts.querySelectorAll('.chat-contact');
        
        // Only do full re-render if forced or if count changed significantly
        if (!forceUpdate && existingContacts.length === filteredConversations.length) {
            // Update only changed elements (time, message, unread badge)
            filteredConversations.forEach((conv, index) => {
                const existingContact = existingContacts[index];
                if (existingContact && existingContact.dataset.conversationId == conv.conversation_id) {
                    // Update time
                    const timeElement = existingContact.querySelector('.contact-time');
                    if (timeElement) {
                        const time = formatTime(conv.last_message_time);
                        const unreadBadge = conv.unread_count > 0 ? 
                            `<span class="unread-badge" style="background: #bf9f4a; color: white; padding: 2px 6px; border-radius: 10px; font-size: 11px; margin-left: 4px;">${conv.unread_count}</span>` : '';
                        timeElement.innerHTML = time + unreadBadge;
                    }
                    
                    // Update last message
                    const messageElement = existingContact.querySelector('.contact-message');
                    if (messageElement && messageElement.textContent !== conv.last_message) {
                        messageElement.textContent = conv.last_message || 'No messages yet';
                    }
                }
            });
            return; // Skip full re-render
        }

        // Full re-render only when necessary
        let html = '';

        if (filteredConversations.length === 0) {
            html = `
                <div style="padding: 40px 20px; text-align: center; color: #999;">
                    <svg width="48" height="48" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="opacity: 0.5; margin-bottom: 16px;">
                        <path d="M20 2H4C2.9 2 2 2.9 2 4V22L6 18H20C21.1 18 22 17.1 22 16V4C22 2.9 21.1 2 20 2ZM20 16H5.17L4 17.17V4H20V16Z" fill="currentColor"/>
                    </svg>
                    <p style="margin: 0; font-size: 14px; font-family: 'Goudy Bookletter 1911', serif;">No conversations yet</p>
                    <p style="margin: 8px 0 0 0; font-size: 12px; color: #bbb;">Start chatting with sellers from product pages</p>
                </div>
            `;
        } else {
            filteredConversations.forEach(conv => {
                // Fix avatar path - add /static/ prefix if it's a file path
                let avatar = conv.contact_avatar;
                if (avatar && !avatar.startsWith('data:') && !avatar.startsWith('http')) {
                    avatar = avatar.startsWith('/') ? avatar : '/' + avatar;
                    if (!avatar.startsWith('/static/')) {
                        avatar = '/static' + avatar;
                    }
                }
                avatar = avatar || generateDefaultAvatar(conv.contact_name);
                const time = formatTime(conv.last_message_time);
                const unreadBadge = conv.unread_count > 0 ? 
                    `<span class="unread-badge" style="background: #bf9f4a; color: white; padding: 2px 6px; border-radius: 10px; font-size: 11px; margin-left: 4px;">${conv.unread_count}</span>` : '';
                
                const riderLabel = conv.contact_type === 'rider' ? 
                    `<span style="font-size: 11px; color: #999; font-weight: 500;">Rider</span>` : '';
                
                html += `
                    <div class="chat-contact" data-conversation-id="${conv.conversation_id}" 
                         data-contact-id="${conv.contact_id}" data-contact-type="${conv.contact_type}">
                        <div class="contact-avatar">
                            <img src="${avatar}" alt="${conv.contact_name}">
                        </div>
                        <div class="contact-info">
                            <div class="contact-name">
                                ${escapeHtml(conv.contact_name)}
                                ${riderLabel}
                            </div>
                            <div class="contact-message">${escapeHtml(conv.last_message || 'No messages yet')}</div>
                        </div>
                        <div class="contact-time">${time}${unreadBadge}</div>
                    </div>
                `;
            });
        }

        chatContacts.innerHTML = html;

        // Note: Click handlers are set up once using event delegation in initialization
    }

    // Search ALL sellers (not just conversations)
    async function filterConversations(searchQuery) {
        if (!chatContacts) return;

        const query = searchQuery.trim();
        
        console.log('Searching for:', query); // Debug log
        
        if (!query) {
            // If search is empty, show all conversations
            renderConversations(true); // Force update when clearing search
            return;
        }

        // Search ALL sellers from database
        try {
            const response = await fetch(`/api/chat/search-sellers?q=${encodeURIComponent(query)}`);
            const data = await response.json();
            
            if (response.ok) {
                const sellers = data.sellers || [];
                console.log('Found sellers:', sellers.length); // Debug log
                renderSearchResults(sellers, query);
            } else {
                console.error('Error searching sellers:', data.error);
                renderNoResults(query);
            }
        } catch (error) {
            console.error('Error searching sellers:', error);
            renderNoResults(query);
        }
    }
    
    // Render search results (all sellers matching query)
    function renderSearchResults(sellers, query) {
        if (!chatContacts) return;

        let html = '';

        if (sellers.length === 0) {
            renderNoResults(query);
            return;
        }

        // Show search results - all sellers matching query
        sellers.forEach(seller => {
            // Fix avatar path - add /static/ prefix if it's a file path
            let avatar = seller.shop_logo;
            if (avatar && !avatar.startsWith('data:') && !avatar.startsWith('http')) {
                avatar = avatar.startsWith('/') ? avatar : '/' + avatar;
                if (!avatar.startsWith('/static/')) {
                    avatar = '/static' + avatar;
                }
            }
            avatar = avatar || generateDefaultAvatar(seller.shop_name);
            const description = seller.shop_description ? 
                (seller.shop_description.substring(0, 50) + '...') : 
                'Click to start chatting';
            
            html += `
                <div class="chat-contact" data-seller-id="${seller.seller_id}" data-shop-name="${escapeHtml(seller.shop_name)}">
                    <div class="contact-avatar">
                        <img src="${avatar}" alt="${seller.shop_name}">
                    </div>
                    <div class="contact-info">
                        <div class="contact-name">${escapeHtml(seller.shop_name)}</div>
                        <div class="contact-message" style="color: #999;">${escapeHtml(description)}</div>
                    </div>
                    <div class="contact-time" style="color: #bf9f4a; font-size: 11px;">Start Chat →</div>
                </div>
            `;
        });

        chatContacts.innerHTML = html;

        // Note: Click handlers are set up once using event delegation in initialization
    }
    
    // Render no results message
    function renderNoResults(query) {
        if (!chatContacts) return;
        
        const html = `
            <div style="padding: 40px 20px; text-align: center; color: #999;">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="opacity: 0.5; margin-bottom: 16px;">
                    <path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z" fill="currentColor"/>
                </svg>
                <p style="margin: 0; font-size: 14px; font-family: 'Goudy Bookletter 1911', serif;">No sellers found for "${escapeHtml(query)}"</p>
                <p style="margin: 8px 0 0 0; font-size: 12px; color: #bbb;">Try a different search term</p>
                <button onclick="document.querySelector('.chat-search-input').value=''; document.querySelector('.chat-search-input').dispatchEvent(new Event('input'));" style="margin-top: 16px; padding: 8px 16px; background: #bf9f4a; color: white; border: none; border-radius: 4px; cursor: pointer; font-family: 'Goudy Bookletter 1911', serif;">Show My Conversations</button>
            </div>
        `;
        
        chatContacts.innerHTML = html;
    }
    
    // Open seller chat - check if conversation exists first
    async function openNewSellerChat(sellerId, shopName) {
        // First, check if we already have a conversation with this seller
        const existingConv = conversations.find(c => 
            c.contact_id == sellerId && c.contact_type === 'seller'
        );
        
        if (existingConv) {
            // Conversation exists - open it with messages
            console.log('Found existing conversation:', existingConv.conversation_id);
            await openConversation(existingConv.conversation_id, sellerId, 'seller');
        } else {
            // No existing conversation - create new empty chat
            console.log('No existing conversation, creating new chat UI');
            currentConversationId = null;  // Important: null means no conversation created yet
            currentContactId = sellerId;
            currentContactType = 'seller';
            currentContactName = shopName; // Store shop name for later use
            
            // Hide welcome message
            if (chatWelcome) {
                chatWelcome.classList.add('hidden');
            }
            
            // Render empty chat window with seller info
            renderNewSellerChatUI(sellerId, shopName);
        }
    }
    
    // Render new seller chat UI (no messages yet)
    function renderNewSellerChatUI(sellerId, shopName) {
        if (!chatRightPanel) return;
        
        const contactAvatar = generateDefaultAvatar(shopName);
        
        const html = `
            <div class="chat-conversation active">
                <div class="conversation-header">
                    <div class="conversation-contact">
                        <div class="conversation-avatar">
                            <img src="${contactAvatar}" alt="${shopName}">
                        </div>
                        <div>
                            <div class="conversation-name">${escapeHtml(shopName)}</div>
                        </div>
                    </div>
                </div>
                <div class="conversation-messages" id="conversationMessages">
                    <div style="padding: 40px 20px; text-align: center; color: #999;">
                        <p style="margin: 0; font-size: 14px;">Start a conversation with ${escapeHtml(shopName)}</p>
                        <p style="margin: 8px 0 0 0; font-size: 12px; color: #bbb;">Send a message to begin chatting</p>
                    </div>
                </div>
                <div class="conversation-input">
                    <input type="text" class="message-input" placeholder="Type your first message..." id="messageInput">
                    <button class="send-button" id="sendButton">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" fill="currentColor"/>
                        </svg>
                    </button>
                </div>
            </div>
        `;
        
        chatRightPanel.innerHTML = html;
        chatRightPanel.classList.remove('hidden');
        
        // Add send message handler
        const messageInput = document.getElementById('messageInput');
        const sendButton = document.getElementById('sendButton');

        if (sendButton) {
            sendButton.addEventListener('click', sendMessage);
        }

        if (messageInput) {
            messageInput.addEventListener('keypress', function(e) {
                if (e.key === 'Enter') {
                    sendMessage();
                }
            });
            messageInput.focus();
        }
    }

    // Open a conversation
    async function openConversation(conversationId, contactId, contactType) {
        currentConversationId = conversationId;
        currentContactId = contactId;
        currentContactType = contactType;

        // Hide welcome message
        if (chatWelcome) {
            chatWelcome.classList.add('hidden');
        }
        
        // Show right panel
        if (chatRightPanel) {
            chatRightPanel.classList.remove('hidden');
        }

        // Load messages
        if (conversationId) {
            await loadMessages(conversationId, contactType);
        } else {
            // New conversation - show empty state
            renderConversationUI(contactId, contactType, []);
        }
    }

    // Load messages for a conversation
    async function loadMessages(conversationId, contactType) {
        try {
            const response = await fetch(`/api/chat/messages/${conversationId}?contact_type=${contactType}`);
            const data = await response.json();

            if (response.ok) {
                const messages = data.messages || [];
                renderConversationUI(currentContactId, contactType, messages);
            } else {
                console.error('Error loading messages:', data.error);
            }
        } catch (error) {
            console.error('Error loading messages:', error);
        }
    }

    // Render conversation UI
    function renderConversationUI(contactId, contactType, messages) {
        if (!chatRightPanel) return;

        // Get contact info
        let contactName = currentContactName || 'Chat'; // Use stored name first
        let contactAvatar = '';

        if (contactType === 'support') {
            contactName = 'Velare Support';
            contactAvatar = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'%3E%3Ccircle cx='16' cy='16' r='16' fill='%23bf9f4a'/%3E%3Ctext x='16' y='20' text-anchor='middle' fill='white' font-size='12' font-weight='bold'%3EV%3C/text%3E%3C/svg%3E";
        } else {
            const conv = conversations.find(c => c.contact_id == contactId && c.contact_type === contactType);
            if (conv) {
                contactName = conv.contact_name;
                // Fix avatar path - add /static/ prefix if it's a file path
                let avatar = conv.contact_avatar;
                console.log('Original avatar path:', avatar);
                if (avatar && !avatar.startsWith('data:') && !avatar.startsWith('http')) {
                    avatar = avatar.startsWith('/') ? avatar : '/' + avatar;
                    if (!avatar.startsWith('/static/')) {
                        avatar = '/static' + avatar;
                    }
                }
                contactAvatar = avatar || generateDefaultAvatar(contactName);
                console.log('Final avatar path:', contactAvatar);
            } else if (currentContactName) {
                // Use stored contact name if conversation not found yet (new conversation)
                contactName = currentContactName;
                contactAvatar = generateDefaultAvatar(contactName);
            }
        }
        
        // Ensure contactAvatar has a value
        if (!contactAvatar) {
            contactAvatar = generateDefaultAvatar(contactName);
        }

        // Build conversation HTML
        const riderLabel = contactType === 'rider' ? 
            `<div style="font-size: 12px; color: #999; margin-top: 2px;">Rider</div>` : '';
        
        // Check if THIS SPECIFIC delivery is completed (use conversation_id, not contact_id)
        const conv = conversations.find(c => c.conversation_id == currentConversationId);
        const isDelivered = conv && conv.delivery_status === 'delivered';
        
        console.log('=== Delivery Status Check ===');
        console.log('Conversation ID:', currentConversationId);
        console.log('Found conversation:', conv);
        console.log('Delivery status:', conv?.delivery_status);
        console.log('Is delivered:', isDelivered);
        
        // Chat ended message
        const chatEndedMessage = isDelivered ? `
            <div style="text-align: center; padding: 20px; margin: 20px 0;">
                <div style="background: #f0f0f0; padding: 15px; border-radius: 8px; display: inline-block;">
                    <i class="bi bi-check-circle" style="color: #4CAF50; font-size: 24px; margin-bottom: 8px; display: block;"></i>
                    <p style="color: #666; font-weight: 600; margin: 0;">Order Delivered</p>
                    <p style="color: #999; font-size: 13px; margin: 5px 0 0 0;">This conversation has ended</p>
                </div>
            </div>
        ` : '';
        
        const inputDisabled = isDelivered ? 'disabled' : '';
        const inputPlaceholder = isDelivered ? 'Chat has ended' : 'Type a message...';
        
        let html = `
            <div class="chat-conversation active">
                <div class="conversation-header">
                    <div class="conversation-contact">
                        <div class="conversation-avatar">
                            <img src="${contactAvatar}" alt="${contactName}">
                        </div>
                        <div>
                            <div class="conversation-name">${escapeHtml(contactName)}</div>
                            ${riderLabel}
                        </div>
                    </div>
                </div>
                <div class="conversation-messages" id="conversationMessages">
                    ${renderMessages(messages)}
                    ${chatEndedMessage}
                </div>
                <div class="conversation-input">
                    <input type="text" class="message-input" placeholder="${inputPlaceholder}" id="messageInput" ${inputDisabled}>
                    <button class="send-button" id="sendButton" ${inputDisabled}>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M2.01 21L23 12L2.01 3L2 10L17 12L2 14L2.01 21Z" fill="currentColor"/>
                        </svg>
                    </button>
                </div>
            </div>
        `;

        chatRightPanel.innerHTML = html;

        // Scroll to bottom
        const messagesContainer = document.getElementById('conversationMessages');
        if (messagesContainer) {
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
        }

        // Add send message handler
        const messageInput = document.getElementById('messageInput');
        const sendButton = document.getElementById('sendButton');

        if (sendButton) {
            sendButton.addEventListener('click', sendMessage);
        }

        if (messageInput) {
            messageInput.addEventListener('keypress', function(e) {
                if (e.key === 'Enter') {
                    sendMessage();
                }
            });
            messageInput.focus();
        }
    }

    // Render messages
    function renderMessages(messages) {
        if (!messages || messages.length === 0) {
            return '<div style="text-align: center; color: #999; padding: 20px;">No messages yet. Start the conversation!</div>';
        }

        return messages.map(msg => {
            // Check if the message was sent by the current user
            // For buyers: their messages have sender_type = 'buyer'
            // For sellers: their messages have sender_type = 'seller'
            const isSent = (msg.sender_type === 'buyer');  // Buyer's perspective
            const messageClass = isSent ? 'sent' : 'received';
            const time = formatTime(msg.created_at);

            return `
                <div class="message ${messageClass}">
                    <div class="message-content">
                        <p>${escapeHtml(msg.message_text)}</p>
                    </div>
                    <div class="message-time">${time}</div>
                </div>
            `;
        }).join('');
    }

    // Send message
    async function sendMessage() {
        const messageInput = document.getElementById('messageInput');
        const sendButton = document.getElementById('sendButton');
        const messagesContainer = document.getElementById('conversationMessages');
        
        if (!messageInput || !sendButton) return;

        const messageText = messageInput.value.trim();
        if (!messageText) return;

        // Clear input immediately
        messageInput.value = '';

        // Disable button
        sendButton.disabled = true;
        sendButton.classList.add('sending');
        
        // Add message to UI immediately with "Sending..." status
        const tempMessageId = 'temp-' + Date.now();
        const userType = 'buyer'; // or get from session
        
        // Add temporary message to conversation
        if (messagesContainer) {
            const messageHTML = `
                <div class="message sent" id="${tempMessageId}">
                    <div class="message-content">
                        <p>${escapeHtml(messageText)}</p>
                    </div>
                    <div class="message-time" style="color: #999; font-size: 11px; font-style: italic;">
                        Sending...
                    </div>
                </div>
            `;
            
            // Check if there's a "no messages" placeholder
            const noMessagesPlaceholder = messagesContainer.querySelector('[style*="padding: 40px"]');
            if (noMessagesPlaceholder) {
                messagesContainer.innerHTML = messageHTML;
            } else {
                messagesContainer.insertAdjacentHTML('beforeend', messageHTML);
            }
            
            // Scroll to bottom
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
        }

        try {
            const response = await fetch('/api/chat/send', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    conversation_id: currentConversationId,
                    contact_id: currentContactId,
                    message_text: messageText,
                    contact_type: currentContactType
                })
            });

            const data = await response.json();

            if (response.ok) {
                // Update conversation ID if it was a new conversation
                if (data.conversation_id && !currentConversationId) {
                    currentConversationId = data.conversation_id;
                }

                // Remove temporary message
                const tempMessage = document.getElementById(tempMessageId);
                if (tempMessage) {
                    tempMessage.remove();
                }

                // Reload messages to show the actual sent message
                if (currentConversationId) {
                    await loadMessages(currentConversationId, currentContactType);
                }

                // Reload conversations list
                await loadConversations();
            } else {
                console.error('Error sending message:', data.error);
                
                // Update temporary message to show error
                const tempMessage = document.getElementById(tempMessageId);
                if (tempMessage) {
                    const timeElement = tempMessage.querySelector('.message-time');
                    if (timeElement) {
                        timeElement.innerHTML = '<span style="color: #dc3545;">Failed to send. Click to retry.</span>';
                        timeElement.style.cursor = 'pointer';
                        timeElement.onclick = () => {
                            messageInput.value = messageText;
                            tempMessage.remove();
                        };
                    }
                }
                
                alert('Failed to send message: ' + (data.error || 'Please try again.'));
            }
        } catch (error) {
            console.error('Error sending message:', error);
            
            // Update temporary message to show error
            const tempMessage = document.getElementById(tempMessageId);
            if (tempMessage) {
                const timeElement = tempMessage.querySelector('.message-time');
                if (timeElement) {
                    timeElement.innerHTML = '<span style="color: #dc3545;">Failed to send. Click to retry.</span>';
                    timeElement.style.cursor = 'pointer';
                    timeElement.onclick = () => {
                        messageInput.value = messageText;
                        tempMessage.remove();
                    };
                }
            }
            
            alert('Failed to send message. Please check your connection and try again.');
        } finally {
            // Re-enable button
            sendButton.disabled = false;
            sendButton.classList.remove('sending');
        }
    }

    // Poll for new messages
    async function pollForNewMessages() {
        if (currentConversationId && currentContactType) {
            try {
                const response = await fetch(`/api/chat/messages/${currentConversationId}?contact_type=${currentContactType}`);
                const data = await response.json();

                if (response.ok) {
                    const messages = data.messages || [];
                    const messagesContainer = document.getElementById('conversationMessages');
                    if (messagesContainer) {
                        const currentScrollHeight = messagesContainer.scrollHeight;
                        const currentScrollTop = messagesContainer.scrollTop;
                        const isScrolledToBottom = currentScrollTop + messagesContainer.clientHeight >= currentScrollHeight - 50;

                        messagesContainer.innerHTML = renderMessages(messages);

                        // Auto-scroll if user was at bottom
                        if (isScrolledToBottom) {
                            messagesContainer.scrollTop = messagesContainer.scrollHeight;
                        }
                    }
                }
            } catch (error) {
                console.error('Error polling messages:', error);
            }
        }

        // Only refresh conversations list if NOT actively searching
        if (!currentSearchQuery || currentSearchQuery.trim() === '') {
            await loadConversations();
        }
    }

    // Utility functions
    function formatTime(timestamp) {
        if (!timestamp) return '';

        const date = new Date(timestamp);
        const now = new Date();
        const diff = now - date;

        // Less than 1 minute
        if (diff < 60000) {
            return 'Now';
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

        // Format as date
        return date.toLocaleDateString();
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    function generateDefaultAvatar(name) {
        const initial = name.charAt(0).toUpperCase();
        
        // Use gradient background matching My Purchases design
        return `data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'%3E%3Cdefs%3E%3ClinearGradient id='grad' x1='0%25' y1='0%25' x2='100%25' y2='100%25'%3E%3Cstop offset='0%25' style='stop-color:rgba(211,189,155,0.35);stop-opacity:1' /%3E%3Cstop offset='100%25' style='stop-color:rgba(105,91,68,0.35);stop-opacity:1' /%3E%3C/linearGradient%3E%3C/defs%3E%3Crect width='40' height='40' rx='20' fill='url(%23grad)'/%3E%3Ctext x='20' y='26' text-anchor='middle' fill='%238b7355' font-size='16' font-weight='600' font-family='Playfair Display, serif'%3E${initial}%3C/text%3E%3C/svg%3E`;
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initChat);
    } else {
        initChat();
    }

    // Expose function to start conversation from product pages
    window.startChatWithSeller = async function(sellerId) {
        try {
            const response = await fetch('/api/chat/start-conversation', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ seller_id: sellerId })
            });

            const data = await response.json();

            if (response.ok) {
                // Open chat window
                openChatWindow();
                
                // Open the conversation
                await openConversation(data.conversation_id, sellerId, 'seller');
            } else {
                console.error('Error starting conversation:', data.error);
                alert('Failed to start conversation. Please try again.');
            }
        } catch (error) {
            console.error('Error starting conversation:', error);
            alert('Failed to start conversation. Please try again.');
        }
    };

    // Auto-refresh conversations every 5 seconds (to update the 20-second filter)
    setInterval(() => {
        // Only refresh if chat window is open and not searching
        const chatWindow = document.getElementById('chat-window');
        if (chatWindow && chatWindow.classList.contains('chat-window-visible')) {
            if (!currentSearchQuery || currentSearchQuery.trim() === '') {
                loadConversations();
            }
        }
    }, 5000);

})();
