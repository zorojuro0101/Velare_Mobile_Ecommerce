// Chat Widget Functionality
document.addEventListener('DOMContentLoaded', function() {
    const chatButton = document.getElementById('chat-button');
    const chatWindow = document.getElementById('chat-window');
    const closeBtn = document.getElementById('close-chat');
    const searchInput = document.querySelector('.chat-search-input');
    const chatContacts = document.querySelectorAll('.chat-contact');
    
    console.log('Chat contacts found:', chatContacts.length);

    let isOpen = false;

    // Toggle chat window
    function toggleChat() {
        isOpen = !isOpen;
        if (isOpen) {
            chatWindow.classList.remove('chat-window-hidden');
            chatWindow.classList.add('chat-window-visible');
            chatButton.classList.add('chat-opened');
        } else {
            chatWindow.classList.remove('chat-window-visible');
            chatWindow.classList.add('chat-window-hidden');
            chatButton.classList.remove('chat-opened');
        }
    }

    // Close chat window
    function closeChat() {
        isOpen = false;
        chatWindow.classList.remove('chat-window-visible');
        chatWindow.classList.add('chat-window-hidden');
        chatButton.classList.remove('chat-opened');
    }

    // Event listeners
    if (chatButton) {
        chatButton.addEventListener('click', toggleChat);
    }
    
    if (closeBtn) {
        closeBtn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            closeChat();
            console.log('Close button clicked');
        });
    }

    // Search functionality
    searchInput.addEventListener('input', function() {
        const searchTerm = this.value.toLowerCase();
        chatContacts.forEach(contact => {
            const contactName = contact.querySelector('.contact-name').textContent.toLowerCase();
            const contactMessage = contact.querySelector('.contact-message').textContent.toLowerCase();
            
            if (contactName.includes(searchTerm) || contactMessage.includes(searchTerm)) {
                contact.style.display = 'flex';
            } else {
                contact.style.display = 'none';
            }
        });
    });


    // Contact click functionality
    chatContacts.forEach((contact, index) => {
        contact.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('Contact clicked:', index);
            
            // Remove active class from all contacts
            chatContacts.forEach(c => c.classList.remove('active'));
            // Add active class to clicked contact
            this.classList.add('active');
            
            // Show conversation view
            showConversation(this);
        });
        
        // Make sure contact is clickable
        contact.style.cursor = 'pointer';
        contact.style.userSelect = 'none';
    });

    // Show conversation function
    function showConversation(contactElement) {
        const chatWelcome = document.querySelector('.chat-welcome');
        const chatConversation = document.querySelector('.chat-conversation');
        
        // Hide welcome message
        chatWelcome.classList.add('hidden');
        
        // Show conversation
        chatConversation.classList.add('active');
        
        // Update conversation header with contact info
        const contactName = contactElement.querySelector('.contact-name').textContent;
        const contactAvatar = contactElement.querySelector('.contact-avatar img').src;
        
        const conversationName = document.querySelector('.conversation-name');
        const conversationAvatar = document.querySelector('.conversation-avatar img');
        
        conversationName.textContent = contactName;
        conversationAvatar.src = contactAvatar;
    }

    // Close chat when clicking outside
    document.addEventListener('click', function(event) {
        const chatWidget = document.getElementById('chat-widget');
        if (!chatWidget.contains(event.target) && isOpen) {
            closeChat();
        }
    });

    // Prevent chat window from closing when clicking inside it
    if (chatWindow) {
        chatWindow.addEventListener('click', function(event) {
            event.stopPropagation();
        });
    }

    // Add some smooth animations and interactions
    chatButton.addEventListener('mouseenter', function() {
        this.style.transform = 'translateY(-2px)';
    });

    chatButton.addEventListener('mouseleave', function() {
        this.style.transform = 'translateY(0)';
    });

    // Message sending functionality
    const messageInput = document.querySelector('.message-input');
    const sendButton = document.querySelector('.send-button');
    const conversationMessages = document.querySelector('.conversation-messages');

    function sendMessage() {
        if (!messageInput) return;
        const messageText = messageInput.value.trim();
        if (messageText === '') return;

        // Create message element
        const messageDiv = document.createElement('div');
        messageDiv.className = 'message sent';
        
        const now = new Date();
        const timeString = now.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        
        messageDiv.innerHTML = `
            <div class="message-content">
                <p>${messageText}</p>
            </div>
            <div class="message-time">${timeString}</div>
        `;

        // Add message to conversation
        conversationMessages.appendChild(messageDiv);
        
        // Clear input
        messageInput.value = '';
        
        // Scroll to bottom
        conversationMessages.scrollTop = conversationMessages.scrollHeight;

        // Simulate a response after 2 seconds
        setTimeout(() => {
            const responseDiv = document.createElement('div');
            responseDiv.className = 'message received';
            responseDiv.innerHTML = `
                <div class="message-content">
                    <p>Thank you for your message! Our team will assist you shortly.</p>
                </div>
                <div class="message-time">${new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</div>
            `;
            conversationMessages.appendChild(responseDiv);
            conversationMessages.scrollTop = conversationMessages.scrollHeight;
        }, 2000);
    }

    if (sendButton) {
        sendButton.addEventListener('click', sendMessage);
    }
    
    if (messageInput) {
        messageInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                sendMessage();
            }
        });
    }

    // Add active state for contacts
    const style = document.createElement('style');
    style.textContent = `
        .chat-contact.active {
            background: #f8f9fa !important;
            border-left: 3px solid #bf9f4a;
        }
        
        .chat-contact.active .contact-name {
            color: #bf9f4a;
            font-weight: 700;
        }
    `;
    document.head.appendChild(style);

    // Handle image link clicks to store hero image
    const imageLinks = document.querySelectorAll('.image-link[data-hero-image]');
    imageLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            const heroImage = this.getAttribute('data-hero-image');
            if (heroImage) {
                sessionStorage.setItem('browseHeroImage', heroImage);
            }
        });
    });
});
