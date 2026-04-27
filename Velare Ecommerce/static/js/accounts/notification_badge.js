// Notification Badge - Shared across all myAccount pages
// This script fetches and displays the unread notification count

document.addEventListener('DOMContentLoaded', () => {
    const isNotificationPage = window.location.pathname.includes('myAccount_notification');
    
    if (isNotificationPage) {
        // On notification page, hide badge and mark as viewed
        const badge = document.getElementById('notificationBadge') || document.getElementById('notification-badge');
        if (badge) {
            badge.style.display = 'none';
        }
        
        // Store current timestamp as "last viewed time"
        localStorage.setItem('lastViewedNotifTime', Date.now().toString());
    } else {
        // On other pages, check for notifications
        updateNotificationBadgeFromAPI();
        
        // Update badge every 5 seconds (more frequent for real-time updates)
        setInterval(updateNotificationBadgeFromAPI, 5000);
    }
    
    // Listen for notification updates from other tabs/pages
    window.addEventListener('storage', (e) => {
        if (e.key === 'notificationUpdate') {
            // Another page marked notifications as read, update badge immediately
            updateNotificationBadgeFromAPI();
        }
    });
    
    // Add click handler to Notifications tab
    const notificationsTab = document.getElementById('notificationsTab');
    if (notificationsTab) {
        notificationsTab.addEventListener('click', () => {
            // Hide badge immediately when clicking
            const badge = document.getElementById('notificationBadge') || document.getElementById('notification-badge');
            if (badge) {
                badge.style.display = 'none';
            }
        });
    }
});

async function updateNotificationBadgeFromAPI() {
    try {
        const response = await fetch('/api/notifications/count', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        const data = await response.json();
        
        if (data.success) {
            const badge = document.getElementById('notificationBadge') || document.getElementById('notification-badge');
            if (badge) {
                const currentCount = data.count;
                
                // Show badge if there are notifications
                if (currentCount > 0) {
                    badge.textContent = currentCount;
                    badge.style.display = 'flex';
                } else {
                    badge.style.display = 'none';
                }
            }
        }
    } catch (error) {
        console.error('Error fetching notification count:', error);
    }
}
