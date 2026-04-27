// Notification Bell Handler
document.addEventListener('DOMContentLoaded', function() {
    const notificationBell = document.getElementById('notification-bell');
    const notificationBadge = document.getElementById('notification-badge');
    const notificationList = document.getElementById('notification-list');
    const notificationWrapper = document.querySelector('.notification-icon-wrapper');
    const notificationDropdown = document.querySelector('.notification-dropdown');
    
    if (!notificationBell || !notificationList) return;
    
    // Toggle dropdown on click
    notificationWrapper.addEventListener('click', function(e) {
        e.stopPropagation();
        notificationDropdown.classList.toggle('show');
    });
    
    // Close dropdown when clicking outside
    document.addEventListener('click', function(e) {
        if (!notificationWrapper.contains(e.target)) {
            notificationDropdown.classList.remove('show');
        }
    });
    
    // Fetch notifications on page load
    fetchNotifications();
    
    // Refresh notifications every 30 seconds
    setInterval(fetchNotifications, 30000);
    
    async function fetchNotifications() {
        try {
            const response = await fetch('/api/notifications');
            const data = await response.json();
            
            if (data.success) {
                updateNotificationBadge(data.unread_count);
                renderNotifications(data.notifications);
            }
        } catch (error) {
            console.error('Error fetching notifications:', error);
        }
    }
    
    function updateNotificationBadge(count) {
        if (count > 0) {
            notificationBadge.textContent = count > 99 ? '99+' : count;
            notificationBadge.style.display = 'flex';
        } else {
            notificationBadge.style.display = 'none';
        }
    }
    
    function renderNotifications(notifications) {
        if (!notifications || notifications.length === 0) {
            notificationList.innerHTML = '<div class="notification-empty">No notifications</div>';
            return;
        }
        
        notificationList.innerHTML = '';
        
        notifications.forEach(notif => {
            const item = document.createElement('a');
            item.className = 'notification-item' + (notif.is_read ? '' : ' unread');
            item.href = getNotificationLink(notif);
            
            const typeBadge = document.createElement('div');
            typeBadge.className = `notification-type-badge notification-type-${notif.notification_type}`;
            typeBadge.textContent = formatType(notif.notification_type);
            
            const title = document.createElement('div');
            title.className = 'notification-title';
            title.textContent = notif.title;
            
            const message = document.createElement('div');
            message.className = 'notification-message';
            message.textContent = notif.message;
            
            const time = document.createElement('div');
            time.className = 'notification-time';
            time.textContent = formatTime(notif.created_at);
            
            item.appendChild(typeBadge);
            item.appendChild(title);
            item.appendChild(message);
            item.appendChild(time);
            
            // Mark as read when clicked
            item.addEventListener('click', async function(e) {
                e.preventDefault();
                const href = this.getAttribute('href');
                
                if (!notif.is_read) {
                    await markAsRead(notif.notification_id);
                }
                
                // If it's a purchases link with tab parameter, save to localStorage
                if (href.includes('/myAccount_purchases?tab=')) {
                    const tabMatch = href.match(/tab=([^&]+)/);
                    if (tabMatch) {
                        const tabValue = tabMatch[1];
                        console.log('Saving tab to localStorage:', tabValue);
                        localStorage.setItem('activePurchaseTab', tabValue);
                    }
                }
                
                // Navigate to the link
                window.location.href = href;
            });
            
            notificationList.appendChild(item);
        });
    }
    
    function getNotificationLink(notif) {
        // Map notification types to pages with specific tabs
        if (notif.notification_type === 'order' || notif.notification_type === 'delivery') {
            // Check title and message for order status keywords
            const title = (notif.title || '').toLowerCase();
            const message = (notif.message || '').toLowerCase();
            
            console.log('Notification:', {
                title: notif.title,
                message: notif.message,
                type: notif.notification_type,
                titleLower: title,
                messageLower: message
            });
            
            // Check for "Order Shipped" or "shipped" in title/message → In Transit tab
            if (title.includes('shipped') || message.includes('on the way') || message.includes('in transit')) {
                console.log('→ Redirecting to In Transit tab');
                return '/myAccount_purchases?tab=in-transit';
            } 
            // Check for "Order Delivered" or "delivered" in title/message → Delivered tab
            else if (title.includes('delivered') || message.includes('delivered')) {
                console.log('→ Redirecting to Delivered tab');
                return '/myAccount_purchases?tab=delivered';
            } 
            // Check for pending/preparing → Pending Shipment tab
            else if (message.includes('pending') || message.includes('preparing')) {
                console.log('→ Redirecting to Pending Shipment tab');
                return '/myAccount_purchases?tab=pending-shipment';
            } 
            // Check for cancelled → Cancelled tab
            else if (message.includes('cancelled')) {
                console.log('→ Redirecting to Cancelled tab');
                return '/myAccount_purchases?tab=cancelled';
            }
            console.log('→ Redirecting to default purchases page');
            return '/myAccount_purchases';
        }
        
        const typeMap = {
            'product': '/browse_product',
            'message': '/myAccount_notification',
            'system': '/myAccount_notification'
        };
        
        return typeMap[notif.notification_type] || '/myAccount_notification';
    }
    
    function formatType(type) {
        const typeNames = {
            'order': 'Order',
            'delivery': 'Delivery',
            'product': 'Product',
            'message': 'Message',
            'system': 'System'
        };
        return typeNames[type] || type;
    }
    
    function formatTime(timestamp) {
        const date = new Date(timestamp);
        const now = new Date();
        const diff = Math.floor((now - date) / 1000); // seconds
        
        if (diff < 60) return 'Just now';
        if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
        if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
        if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
        
        return date.toLocaleDateString();
    }
    
    async function markAsRead(notificationId) {
        try {
            await fetch(`/api/notifications/${notificationId}/read`, {
                method: 'POST'
            });
            fetchNotifications(); // Refresh
        } catch (error) {
            console.error('Error marking notification as read:', error);
        }
    }
});
