document.addEventListener('DOMContentLoaded', () => {
    const hamburgerBtn = document.getElementById('hamburgerBtn');
    const sideMenu = document.querySelector('.side-menu');
    const overlay = document.querySelector('.side-menu-overlay');
    const myAccountTab = document.getElementById('myAccountTab');
    const myAccountSubTabs = document.getElementById('myAccountSubTabs');
    const mainTabs = document.querySelectorAll('.main-tab');
    const notificationsTab = document.getElementById('notificationsTab');
    const markAllReadBtn = document.getElementById('markAllReadBtn');

    // Sidebar (hamburger menu) functionality
    if (hamburgerBtn && sideMenu && overlay) {
        hamburgerBtn.addEventListener('click', () => {
            const isOpen = sideMenu.classList.toggle('open');
            overlay.classList.toggle('show', isOpen);
            hamburgerBtn.classList.toggle('open', isOpen);
        });

        overlay.addEventListener('click', () => {
            sideMenu.classList.remove('open');
            overlay.classList.remove('show');
            hamburgerBtn.classList.remove('open');
        });
    }

    // Set the active tab on page load
    if (notificationsTab) {
        mainTabs.forEach(tab => {
            if (tab !== myAccountTab) { // Don't deactivate My Account if a sub-tab is active
                tab.classList.remove('active');
            }
        });
        notificationsTab.classList.add('active');
    }

    const openSubTabs = () => {
        if (!myAccountSubTabs) return;
        myAccountSubTabs.style.display = 'flex';
        requestAnimationFrame(() => {
            myAccountSubTabs.classList.add('open');
            myAccountSubTabs.classList.remove('closing');
        });
        if (myAccountTab) {
            myAccountTab.classList.add('active');
        }
    };

    const closeSubTabs = () => {
        if (!myAccountSubTabs) return;
        myAccountSubTabs.classList.remove('open');
        myAccountSubTabs.classList.add('closing');
        myAccountSubTabs.addEventListener('transitionend', () => {
            myAccountSubTabs.classList.remove('closing');
            myAccountSubTabs.style.display = 'none';
        }, { once: true });
    };

    // Initialize sub-tabs as closed
    if (myAccountSubTabs) {
        myAccountSubTabs.style.display = 'none';
        myAccountSubTabs.classList.remove('open', 'closing');
    }

    // Since 'My Account' is a link, we don't need a click handler to toggle.
    // The profile page script will handle opening the sub-tabs.
    // However, for other main tabs, we ensure sub-tabs are closed.
    mainTabs.forEach(tab => {
        if (tab !== myAccountTab) {
            tab.addEventListener('click', () => {
                if (myAccountSubTabs && myAccountSubTabs.classList.contains('open')) {
                    closeSubTabs();
                    if (myAccountTab) {
                        myAccountTab.classList.remove('active');
                    }
                }
            });
        }
    });

    // Update notification badge on page load
    updateNotificationBadge();

    // Auto-mark all notifications as read when page loads
    autoMarkAllAsReadOnPageLoad();

    // Notification functionality (without click-to-read)
    initializeNotificationHandlers();
    
    // REMOVED: Auto-refresh every 5 seconds (too expensive)
    // Use notification_badge.js polling instead which is more efficient
});

// Auto-mark all notifications as read when page loads
async function autoMarkAllAsReadOnPageLoad() {
    const unreadNotifications = document.querySelectorAll('.notification-item.unread');
    
    // Only mark as read if there are unread notifications
    if (unreadNotifications.length > 0) {
        try {
            const response = await fetch('/api/notifications/mark-all-read', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            const data = await response.json();
            
            if (data.success) {
                // Update all unread notifications in UI
                unreadNotifications.forEach(item => {
                    item.classList.remove('unread');
                    item.classList.add('read');
                    
                    // Remove mark as read buttons
                    const markReadBtn = item.querySelector('.mark-read-btn');
                    if (markReadBtn) {
                        markReadBtn.remove();
                    }
                });
                
                // Update notification badge
                updateNotificationBadge();
                
                // Signal other pages to update their badge
                localStorage.setItem('notificationUpdate', Date.now().toString());
                
                // Hide the mark all button
                const markAllBtn = document.getElementById('markAllReadBtn');
                if (markAllBtn) {
                    markAllBtn.style.display = 'none';
                }
                
                console.log('All notifications auto-marked as read on page load');
            }
        } catch (error) {
            console.error('Error auto-marking notifications as read:', error);
        }
    }
}

// Update notification badge count
function updateNotificationBadge() {
    const unreadNotifications = document.querySelectorAll('.notification-item.unread');
    const badge = document.getElementById('notificationBadge');
    
    if (badge) {
        const count = unreadNotifications.length;
        if (count > 0) {
            badge.textContent = count;
            badge.style.display = 'flex';
        } else {
            badge.style.display = 'none';
        }
    }
}

function initializeNotificationHandlers() {
    // Mark individual notification as read
    const markReadButtons = document.querySelectorAll('.mark-read-btn');
    markReadButtons.forEach(btn => {
        btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const notificationId = btn.getAttribute('data-notification-id');
            await markNotificationAsRead(notificationId);
        });
    });

    // Add click-to-read functionality for notification items
    const notificationItems = document.querySelectorAll('.notification-item');
    notificationItems.forEach(item => {
        item.addEventListener('click', async (e) => {
            // Don't trigger if clicking on delete button
            if (e.target.closest('.delete-btn')) {
                return;
            }
            
            const notificationId = item.getAttribute('data-notification-id');
            const deliveryStatus = item.getAttribute('data-delivery-status');
            const orderId = item.getAttribute('data-order-id');
            const notificationType = item.getAttribute('data-notification-type');
            
            // Mark as read if unread
            if (notificationId && item.classList.contains('unread')) {
                await markNotificationAsRead(notificationId);
            }
            
            // Redirect to purchases page with correct tab if it's an order/delivery notification
            if ((notificationType === 'order' || notificationType === 'delivery') && orderId) {
                let targetTab = 'all'; // default
                
                // Get notification title and message for better routing
                const notificationTitle = item.querySelector('.notification-title')?.textContent.toLowerCase() || '';
                const notificationMessage = item.querySelector('.notification-message')?.textContent.toLowerCase() || '';
                
                // Check notification content first (more reliable than current status)
                if (notificationTitle.includes('shipped') || notificationMessage.includes('shipped') || 
                    notificationTitle.includes('on its way') || notificationMessage.includes('on its way')) {
                    // "Order Shipped" notifications should go to In Transit
                    targetTab = 'in-transit';
                } else if (notificationTitle.includes('delivered') || notificationMessage.includes('delivered')) {
                    // "Order Delivered" notifications should go to Delivered
                    targetTab = 'delivered';
                } else if (notificationTitle.includes('cancelled') || notificationMessage.includes('cancelled')) {
                    // "Order Cancelled" notifications should go to Cancelled
                    targetTab = 'cancelled';
                } else if (notificationTitle.includes('placed') || notificationMessage.includes('placed') ||
                           notificationTitle.includes('confirmed') || notificationMessage.includes('confirmed')) {
                    // "Order Placed/Confirmed" notifications should go to Pending
                    targetTab = 'pending-shipment';
                } else {
                    // Fallback to delivery status if notification content doesn't match
                    if (deliveryStatus === 'pending' || deliveryStatus === 'preparing') {
                        targetTab = 'pending-shipment';
                    } else if (deliveryStatus === 'in_transit' || deliveryStatus === 'assigned') {
                        targetTab = 'in-transit';
                    } else if (deliveryStatus === 'delivered') {
                        targetTab = 'delivered';
                    } else if (deliveryStatus === 'cancelled') {
                        targetTab = 'cancelled';
                    }
                }
                
                // Save the target tab to localStorage
                localStorage.setItem('activePurchaseTab', targetTab);
                
                // Redirect to purchases page
                window.location.href = '/myAccount_purchases';
            }
        });
    });

    // Delete notification
    const deleteButtons = document.querySelectorAll('.delete-btn');
    deleteButtons.forEach(btn => {
        btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const notificationId = btn.getAttribute('data-notification-id');
            
            // Check if confirmation already exists
            const existingConfirm = document.querySelector('.remove-confirm-popup');
            if (existingConfirm) {
                existingConfirm.remove();
            }
            
            // Create confirmation popup
            const confirmPopup = document.createElement('div');
            confirmPopup.className = 'remove-confirm-popup';
            confirmPopup.innerHTML = `
                <div class="confirm-text">Delete this notification?</div>
                <div class="confirm-buttons">
                    <button class="confirm-yes">Yes</button>
                    <button class="confirm-no">No</button>
                </div>
            `;
            
            // Position it next to the button (left side)
            const buttonRect = btn.getBoundingClientRect();
            confirmPopup.style.position = 'fixed';
            confirmPopup.style.top = `${buttonRect.top}px`;
            confirmPopup.style.right = `${window.innerWidth - buttonRect.left + 10}px`;
            
            document.body.appendChild(confirmPopup);
            
            // Handle Yes button
            confirmPopup.querySelector('.confirm-yes').addEventListener('click', function() {
                deleteNotification(notificationId);
                confirmPopup.remove();
            });
            
            // Handle No button
            confirmPopup.querySelector('.confirm-no').addEventListener('click', function() {
                confirmPopup.remove();
            });
            
            // Close on outside click
            setTimeout(() => {
                document.addEventListener('click', function closePopup(e) {
                    if (!confirmPopup.contains(e.target) && e.target !== btn) {
                        confirmPopup.remove();
                        document.removeEventListener('click', closePopup);
                    }
                });
            }, 100);
        });
    });

    // Mark all as read
    const markAllReadBtn = document.getElementById('markAllReadBtn');
    if (markAllReadBtn) {
        markAllReadBtn.addEventListener('click', async () => {
            await markAllNotificationsAsRead();
        });
    }
}

async function markNotificationAsRead(notificationId) {
    try {
        const response = await fetch(`/api/notifications/mark-read/${notificationId}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        const data = await response.json();
        
        if (data.success) {
            // Update UI
            const notificationItem = document.querySelector(`[data-notification-id="${notificationId}"]`);
            if (notificationItem) {
                notificationItem.classList.remove('unread');
                notificationItem.classList.add('read');
                
                // Remove the mark as read button
                const markReadBtn = notificationItem.querySelector('.mark-read-btn');
                if (markReadBtn) {
                    markReadBtn.remove();
                }
            }
            
            // Update notification badge
            updateNotificationBadge();
            
            // Signal other pages to update their badge
            localStorage.setItem('notificationUpdate', Date.now().toString());
            
            // Check if there are any unread notifications left
            const unreadCount = document.querySelectorAll('.notification-item.unread').length;
            if (unreadCount === 0) {
                const markAllBtn = document.getElementById('markAllReadBtn');
                if (markAllBtn) {
                    markAllBtn.style.display = 'none';
                }
            }
        } else {
            console.error('Failed to mark notification as read:', data.message);
        }
    } catch (error) {
        console.error('Error marking notification as read:', error);
    }
}

async function deleteNotification(notificationId) {
    try {
        const response = await fetch(`/api/notifications/delete/${notificationId}`, {
            method: 'DELETE',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        const data = await response.json();
        
        if (data.success) {
            // Show success notification
            showNotification('Notification deleted!', 'success');
            
            // Remove notification from UI with animation
            const notificationItem = document.querySelector(`[data-notification-id="${notificationId}"]`);
            if (notificationItem) {
                notificationItem.style.opacity = '0';
                notificationItem.style.transform = 'translateX(20px)';
                notificationItem.style.transition = 'all 0.3s ease';
                
                setTimeout(() => {
                    notificationItem.remove();
                    
                    // Update notification badge
                    updateNotificationBadge();
                    
                    // Signal other pages to update their badge
                    localStorage.setItem('notificationUpdate', Date.now().toString());
                    
                    // Check if there are any notifications left
                    const remainingNotifications = document.querySelectorAll('.notification-item');
                    if (remainingNotifications.length === 0) {
                        const notificationsContent = document.querySelector('.notifications-content');
                        notificationsContent.innerHTML = `
                            <div class="no-notifications">
                                <i class="bi bi-bell-slash" style="font-size: 3em; color: #ccc; margin-bottom: 10px;"></i>
                                <p>No notifications yet</p>
                            </div>
                        `;
                        
                        // Hide mark all button
                        const markAllBtn = document.getElementById('markAllReadBtn');
                        if (markAllBtn) {
                            markAllBtn.style.display = 'none';
                        }
                    }
                }, 300);
            }
        } else {
            console.error('Failed to delete notification:', data.message);
            showNotification('Failed to delete notification. Please try again.', 'error');
        }
    } catch (error) {
        console.error('Error deleting notification:', error);
        showNotification('Connection error. Please try again.', 'error');
    }
}

async function markAllNotificationsAsRead() {
    try {
        const response = await fetch('/api/notifications/mark-all-read', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        const data = await response.json();
        
        if (data.success) {
            // Show success notification
            showNotification('All notifications marked as read!', 'success');
            
            // Update all unread notifications in UI
            const unreadNotifications = document.querySelectorAll('.notification-item.unread');
            unreadNotifications.forEach(item => {
                item.classList.remove('unread');
                item.classList.add('read');
                
                // Remove mark as read buttons
                const markReadBtn = item.querySelector('.mark-read-btn');
                if (markReadBtn) {
                    markReadBtn.remove();
                }
            });
            
            // Update notification badge
            updateNotificationBadge();
            
            // Signal other pages to update their badge
            localStorage.setItem('notificationUpdate', Date.now().toString());
            
            // Hide the mark all button
            const markAllBtn = document.getElementById('markAllReadBtn');
            if (markAllBtn) {
                markAllBtn.style.display = 'none';
            }
        } else {
            console.error('Failed to mark all notifications as read:', data.message);
            showNotification('Failed to mark all as read. Please try again.', 'error');
        }
    } catch (error) {
        console.error('Error marking all notifications as read:', error);
        showNotification('Connection error. Please try again.', 'error');
    }
}

// Show notification function (side popup)
function showNotification(message, type = 'info') {
    // Remove any existing notifications first
    const existingNotifications = document.querySelectorAll('.side-notification');
    existingNotifications.forEach(notif => {
        notif.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notif.remove();
        }, 300);
    });
    
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `side-notification notification-${type}`;
    notification.innerHTML = `
        <i class="bi bi-${type === 'success' ? 'check-circle' : type === 'error' ? 'x-circle' : 'info-circle'}"></i>
        <span>${message}</span>
    `;
    
    notification.style.cssText = `
        position: fixed;
        top: 60px;
        right: 30px;
        padding: 16px 24px;
        background: ${type === 'success' ? '#ecfdf5' : type === 'error' ? '#fef2f2' : '#eff6ff'};
        color: ${type === 'success' ? '#059669' : type === 'error' ? '#dc2626' : '#2563eb'};
        border: 2px solid ${type === 'success' ? '#10b981' : type === 'error' ? '#f87171' : '#60a5fa'};
        border-radius: 8px;
        box-shadow: 0 4px 16px rgba(0,0,0,0.1);
        z-index: 10000;
        display: flex;
        align-items: center;
        gap: 12px;
        font-family: 'Goudy Bookletter 1911', 'Goudy Old Style', serif;
        font-size: 0.95rem;
        font-weight: 600;
        animation: slideIn 0.3s ease;
    `;

    // Add animation keyframes
    if (!document.getElementById('notification-styles')) {
        const style = document.createElement('style');
        style.id = 'notification-styles';
        style.textContent = `
            @keyframes slideIn {
                from {
                    transform: translateX(400px);
                    opacity: 0;
                }
                to {
                    transform: translateX(0);
                    opacity: 1;
                }
            }
            @keyframes slideOut {
                from {
                    transform: translateX(0);
                    opacity: 1;
                }
                to {
                    transform: translateX(400px);
                    opacity: 0;
                }
            }
        `;
        document.head.appendChild(style);
    }

    document.body.appendChild(notification);

    // Remove after 3 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 3000);
}

