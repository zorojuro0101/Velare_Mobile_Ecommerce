// Seller Dashboard Notifications JavaScript
// Handles real-time message notifications on the dashboard

let notificationInterval = null;

// DOM Elements
const notificationDot = document.getElementById('message-notification-dot');

// Initialize notifications when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    console.log('=== DASHBOARD NOTIFICATIONS INITIALIZING ===');
    console.log('Notification dot element:', notificationDot);
    
    // Check if we're on a seller page
    if (notificationDot) {
        console.log('Notification dot found, initializing system...');
        initializeNotifications();
    } else {
        console.log('Notification dot not found - not on a seller page or element missing');
    }
});

// Initialize notification system
function initializeNotifications() {
    console.log('=== INITIALIZING NOTIFICATION SYSTEM ===');
    
    // Check for unread messages immediately
    checkUnreadMessages();
    
    // Then check every 30 seconds
    startNotificationPolling();
}

// Check for unread messages from server
async function checkUnreadMessages() {
    console.log('=== CHECKING UNREAD MESSAGES ===');
    
    try {
        const response = await fetch('/api/chat/unread-count');
        const data = await response.json();
        
        console.log('API Response:', data);
        
        if (response.ok) {
            const unreadCount = data.unread_count || 0;
            console.log('Unread count:', unreadCount);
            updateNotificationDot(unreadCount);
        } else {
            console.error('Error checking unread messages:', data.error);
            hideNotificationDot();
        }
    } catch (error) {
        console.error('Error checking unread messages:', error);
        hideNotificationDot();
    }
}

// Update notification dot visibility based on unread count
function updateNotificationDot(unreadCount) {
    console.log('=== UPDATING NOTIFICATION DOT ===');
    console.log('Unread count:', unreadCount);
    console.log('Notification dot element:', notificationDot);
    
    if (!notificationDot) {
        console.error('Notification dot element not found!');
        return;
    }
    
    if (unreadCount > 0) {
        console.log('Showing notification dot');
        showNotificationDot();
        
        // Update title to show unread count
        updatePageTitle(unreadCount);
    } else {
        console.log('Hiding notification dot');
        hideNotificationDot();
        
        // Reset title to normal
        resetPageTitle();
    }
}

// Show notification dot
function showNotificationDot() {
    if (!notificationDot) return;
    console.log('Setting display: block');
    notificationDot.style.setProperty('display', 'block', 'important');
}

// Hide notification dot
function hideNotificationDot() {
    if (!notificationDot) return;
    console.log('Setting display: none');
    notificationDot.style.display = 'none';
}

// Update page title to show unread count
function updatePageTitle(unreadCount) {
    const originalTitle = document.title.replace(/^\(\d+\)\s*/, '');
    document.title = `(${unreadCount}) ${originalTitle}`;
}

// Reset page title to normal
function resetPageTitle() {
    document.title = document.title.replace(/^\(\d+\)\s*/, '');
}

// Start polling for new notifications
function startNotificationPolling() {
    if (notificationInterval) {
        clearInterval(notificationInterval);
    }
    
    console.log('Starting notification polling (every 30 seconds)');
    notificationInterval = setInterval(() => {
        console.log('Polling for new messages...');
        checkUnreadMessages();
    }, 30000); // Check every 30 seconds
}

// Stop polling for new notifications
function stopNotificationPolling() {
    if (notificationInterval) {
        clearInterval(notificationInterval);
        notificationInterval = null;
    }
}

// Cleanup on page unload
window.addEventListener('beforeunload', function() {
    stopNotificationPolling();
});

// Also check when page becomes visible again (user switches back to tab)
document.addEventListener('visibilitychange', function() {
    if (!document.hidden) {
        console.log('Page became visible, checking messages...');
        checkUnreadMessages();
    }
});

// Check when window gets focus (user clicks back to window)
window.addEventListener('focus', function() {
    console.log('Window got focus, checking messages...');
    checkUnreadMessages();
});

// Test function - call this from browser console to test
window.testNotificationDot = function() {
    console.log('=== TESTING NOTIFICATION DOT ===');
    if (notificationDot) {
        console.log('Test: Showing notification dot');
        notificationDot.style.display = 'block';
        notificationDot.classList.add('test-visible');
        updatePageTitle(5);
    } else {
        console.error('Test: Notification dot element not found!');
    }
};

// Test function to hide dot
window.hideTestNotificationDot = function() {
    console.log('=== HIDING TEST NOTIFICATION DOT ===');
    if (notificationDot) {
        notificationDot.style.display = 'none';
        notificationDot.classList.remove('test-visible');
        resetPageTitle();
    }
};
