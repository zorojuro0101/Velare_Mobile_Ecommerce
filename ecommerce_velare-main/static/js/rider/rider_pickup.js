// Rider Pickup JavaScript

document.addEventListener('DOMContentLoaded', function() {
    initializePickup();
    setupEventListeners();
});

// Initialize pickup page
function initializePickup() {
    loadPickupData();

    // Fix header text in case of cache issues
    const orderNumberHeader = document.querySelector('.pickup-table th:first-child');
    if (orderNumberHeader && orderNumberHeader.textContent.includes('Order ID')) {
        orderNumberHeader.textContent = 'Order Number';
    }
}

// Setup event listeners
function setupEventListeners() {
    // Refresh button
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', refreshPickup);
    }

    // Accept delivery modal buttons
    const confirmAcceptBtn = document.getElementById('confirm-accept-delivery');
    const cancelAcceptBtn = document.getElementById('cancel-accept-delivery');
    const acceptModalOverlay = document.getElementById('accept-delivery-modal-overlay');
    
    if (confirmAcceptBtn) {
        confirmAcceptBtn.addEventListener('click', confirmAcceptDelivery);
    }
    
    if (cancelAcceptBtn) {
        cancelAcceptBtn.addEventListener('click', hideAcceptDeliveryModal);
    }
    
    if (acceptModalOverlay) {
        acceptModalOverlay.addEventListener('click', hideAcceptDeliveryModal);
    }

    // Delivery Management toggle
    const deliveryManagementToggle = document.getElementById('deliveryManagementToggle');
    if (deliveryManagementToggle) {
        deliveryManagementToggle.addEventListener('click', toggleDeliverySubmenu);
    }

    // Navigation items (excluding logout since it's handled by logout-modal.js)
    const navItems = document.querySelectorAll('.nav-item:not(#deliveryManagementToggle):not(#logout-link)');
    navItems.forEach(item => {
        item.addEventListener('click', handleNavigation);
    });

    // Navigation subitems
    const navSubitems = document.querySelectorAll('.nav-subitem');
    navSubitems.forEach(item => {
        item.addEventListener('click', handleSubNavigation);
    });
}

// Load pickup data
function loadPickupData() {
    // Fetch data from server
    fetch('/rider/pickup/api/pending-deliveries')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                displayPickupData(data.deliveries);
            } else {
                console.error('Error loading pickup data:', data.error);
                showNotification(data.error || 'Failed to load pickup data', 'error');
                displayPickupData([]);
            }
        })
        .catch(error => {
            console.error('Error fetching pickup data:', error);
            showNotification('Failed to load pickup data', 'error');
            displayPickupData([]);
        });
}

// Display pickup data in table
function displayPickupData(pickupData) {
    const tableBody = document.getElementById('pickupTableBody');
    const emptyState = document.getElementById('emptyState');
    const table = document.querySelector('.pickup-table');
    
    console.log('📊 Displaying pickup data:', pickupData);
    
    if (!tableBody || !emptyState || !table) return;
    
    if (pickupData.length === 0) {
        // Show empty state but keep table visible
        tableBody.innerHTML = '';
        emptyState.classList.add('show');
    } else {
        // Show table with data
        emptyState.classList.remove('show');
        
        tableBody.innerHTML = pickupData.map((item, index) => {
            console.log(`📦 Creating row for delivery_id: ${item.delivery_id}`);
            return createPickupRow(item, index);
        }).join('');
        
        // Add event listeners to accept buttons
        const acceptButtons = document.querySelectorAll('.btn-accept');
        console.log(`✅ Found ${acceptButtons.length} accept buttons`);
        acceptButtons.forEach((button, idx) => {
            const deliveryId = button.getAttribute('data-delivery-id');
            console.log(`  Button ${idx}: data-delivery-id = ${deliveryId}`);
            button.addEventListener('click', handleAcceptClick);
        });
        
        // Add event listeners to reject buttons
        const rejectButtons = document.querySelectorAll('.btn-reject');
        rejectButtons.forEach(button => {
            button.addEventListener('click', handleRejectClick);
        });
    }
}

// Create pickup row HTML
function createPickupRow(item, index) {
    return `
        <tr data-delivery-id="${item.delivery_id}">
            <td>
                <span class="order-id">${item.order_number}</span>
            </td>
            <td>
                <div class="seller-info">
                    <div class="info-row">
                        <span class="info-label">Store:</span>
                        <span class="info-value">${item.seller_shop_name}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Phone:</span>
                        <span class="info-value">${item.seller_phone || 'N/A'}</span>
                    </div>
                </div>
            </td>
            <td>
                <span class="delivery-address">${item.pickup_address}</span>
            </td>
            <td>
                <span class="buyer-name">${item.buyer_name}</span>
            </td>
            <td>
                <div class="action-buttons">
                    <button class="btn-accept" data-delivery-id="${item.delivery_id}">
                        <i class="bi bi-check-circle"></i>
                        <span>Accept</span>
                    </button>
                    <button class="btn-reject" data-delivery-id="${item.delivery_id}">
                        <i class="bi bi-x-circle"></i>
                        <span>Reject</span>
                    </button>
                </div>
            </td>
        </tr>
    `;
}

// Format date
function formatDate(dateString) {
    const date = new Date(dateString);
    const options = { year: 'numeric', month: 'short', day: 'numeric' };
    return date.toLocaleDateString('en-US', options);
}

// Handle accept button click
// Store pending delivery info for modal
let pendingDeliveryId = null;
let pendingAcceptButton = null;

function handleAcceptClick(e) {
    const button = e.currentTarget;
    const deliveryId = button.getAttribute('data-delivery-id');
    
    console.log('🔍 Accept button clicked, delivery_id:', deliveryId);
    
    // Store for confirmation
    pendingDeliveryId = deliveryId;
    pendingAcceptButton = button;
    
    console.log('✅ Stored pendingDeliveryId:', pendingDeliveryId);
    
    // Show confirmation modal
    showAcceptDeliveryModal();
}

function showAcceptDeliveryModal() {
    const modal = document.getElementById('accept-delivery-modal');
    const overlay = document.getElementById('accept-delivery-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.add('active');
        overlay.classList.add('show');
    }
}

function hideAcceptDeliveryModal() {
    const modal = document.getElementById('accept-delivery-modal');
    const overlay = document.getElementById('accept-delivery-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.remove('active');
        overlay.classList.remove('show');
    }
    pendingDeliveryId = null;
    pendingAcceptButton = null;
}

function confirmAcceptDelivery() {
    if (!pendingDeliveryId || !pendingAcceptButton) {
        console.error('❌ No pending delivery ID or button');
        return;
    }
    
    const deliveryId = pendingDeliveryId;
    const button = pendingAcceptButton;
    
    console.log('📤 Sending accept request for delivery_id:', deliveryId);
    
    hideAcceptDeliveryModal();
    
    // Disable button to prevent double clicks
    button.disabled = true;
    
    // Send to server
    fetch('/rider/pickup/api/accept-delivery', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ delivery_id: deliveryId })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Remove the row from the table
            const row = button.closest('tr');
            if (row) {
                row.style.opacity = '0';
                row.style.transition = 'opacity 0.3s ease';
                setTimeout(() => {
                    row.remove();
                    
                    // Check if table is empty
                    const tableBody = document.getElementById('pickupTableBody');
                    if (tableBody && tableBody.children.length === 0) {
                        const emptyState = document.getElementById('emptyState');
                        if (emptyState) emptyState.classList.add('show');
                    }
                }, 300);
            }
            
            showNotification('Delivery accepted successfully!', 'success');
        } else {
            button.disabled = false;
            showNotification(data.error || 'Failed to accept delivery', 'error');
        }
    })
    .catch(error => {
        console.error('Error accepting delivery:', error);
        button.disabled = false;
        showNotification('Failed to accept delivery', 'error');
    });
}

// Handle reject button click
function handleRejectClick(e) {
    const button = e.currentTarget;
    const deliveryId = button.getAttribute('data-delivery-id');
    
    // Send to server
    fetch('/rider/pickup/api/reject-delivery', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ delivery_id: deliveryId })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Remove the row from the table
            const row = button.closest('tr');
            if (row) {
                row.style.opacity = '0';
                row.style.transition = 'opacity 0.3s ease';
                setTimeout(() => {
                    row.remove();
                    
                    // Check if table is empty
                    const tableBody = document.getElementById('pickupTableBody');
                    if (tableBody && tableBody.children.length === 0) {
                        const emptyState = document.getElementById('emptyState');
                        if (emptyState) emptyState.classList.add('show');
                    }
                }, 300);
            }
            
            showNotification('Delivery rejected', 'info');
        } else {
            showNotification(data.error || 'Failed to reject delivery', 'error');
        }
    })
    .catch(error => {
        console.error('Error rejecting delivery:', error);
        showNotification('Failed to reject delivery', 'error');
    });
}

// Refresh pickup list
function refreshPickup() {
    console.log('Refreshing pickup list...');
    loadPickupData();
    
    // Add visual feedback
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        const icon = refreshBtn.querySelector('i');
        if (icon) {
            icon.style.animation = 'spin 0.5s linear';
            setTimeout(() => {
                icon.style.animation = '';
            }, 500);
        }
    }
}

// Toggle delivery submenu with animation
function toggleDeliverySubmenu(e) {
    e.preventDefault();
    
    // Already on List for Pickup page, just keep submenu open
    // Do nothing since we're already here
}

// Handle navigation
function handleNavigation(e) {
    const tab = e.currentTarget.getAttribute('data-tab');
    const href = e.currentTarget.getAttribute('href');
    
    console.log('Navigating to:', tab, 'href:', href);
    
    // Handle specific navigation
    if (href && href !== '#') {
        // Allow normal navigation for links with valid href
        console.log('Following href:', href);
        window.location.href = href;
        return;
    }
    
    // Prevent default for other cases
    e.preventDefault();
    
    // Handle specific navigation for items without href
    switch(tab) {
        case 'logout':
            handleLogout();
            break;
        default:
            console.log('Unknown tab:', tab);
    }
}

// Handle sub-navigation
function handleSubNavigation(e) {
    const tab = e.currentTarget.getAttribute('data-tab');
    const href = e.currentTarget.getAttribute('href');
    
    console.log('Navigating to sub-tab:', tab, 'href:', href);
    
    // Handle specific navigation
    if (href && href !== '#') {
        // Allow normal navigation for links with valid href
        console.log('Following href:', href);
        window.location.href = href;
        return;
    }
    
    // Prevent default for other cases
    e.preventDefault();
    
    // Remove active class from all subitems
    document.querySelectorAll('.nav-subitem').forEach(item => {
        item.classList.remove('active');
    });
    
    // Add active class to clicked subitem
    e.currentTarget.classList.add('active');
    
    // Handle specific sub-navigation
    switch(tab) {
        case 'list-pickup':
            console.log('Already on List for Pickup page');
            break;
        case 'active-delivery':
            console.log('Loading Active Delivery view...');
            // TODO: Navigate to active delivery page
            break;
        default:
            console.log('Unknown sub-tab:', tab);
    }
}

// Handle logout
function handleLogout() {
    // Logout is now handled by logout-modal.js
}

// Show notification
function showNotification(message, type = 'info') {
    // Remove any existing notifications first
    const existingNotifications = document.querySelectorAll('.notification');
    existingNotifications.forEach(notif => {
        notif.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notif.remove();
        }, 300);
    });
    
    // Create new notification
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <i class="bi bi-${type === 'success' ? 'check-circle' : type === 'error' ? 'x-circle' : 'info-circle'}"></i>
        <span>${message}</span>
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 3000);
}
