// Rider Active Delivery JavaScript

document.addEventListener('DOMContentLoaded', function() {
    initializeActiveDelivery();
    setupEventListeners();
});

// Initialize active delivery page
function initializeActiveDelivery() {
    loadActiveDeliveryData();

    // Fix header text in case of cache issues
    const orderNumberHeader = document.querySelector('.delivery-table th:first-child');
    if (orderNumberHeader && orderNumberHeader.textContent.includes('Order ID')) {
        orderNumberHeader.textContent = 'Order Number';
    }
}

// Setup event listeners
function setupEventListeners() {
    // Refresh button
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', refreshActiveDelivery);
    }

    // Pickup package modal buttons
    const confirmPickupBtn = document.getElementById('confirm-pickup-package');
    const cancelPickupBtn = document.getElementById('cancel-pickup-package');
    const pickupModalOverlay = document.getElementById('pickup-package-modal-overlay');
    
    if (confirmPickupBtn) {
        confirmPickupBtn.addEventListener('click', confirmPickupPackage);
    }
    
    if (cancelPickupBtn) {
        cancelPickupBtn.addEventListener('click', hidePickupPackageModal);
    }
    
    if (pickupModalOverlay) {
        pickupModalOverlay.addEventListener('click', hidePickupPackageModal);
    }

    // Complete delivery modal buttons
    const confirmCompleteBtn = document.getElementById('confirm-complete-delivery');
    const cancelCompleteBtn = document.getElementById('cancel-complete-delivery');
    const completeModalOverlay = document.getElementById('complete-delivery-modal-overlay');
    
    if (confirmCompleteBtn) {
        confirmCompleteBtn.addEventListener('click', confirmCompleteDelivery);
    }
    
    if (cancelCompleteBtn) {
        cancelCompleteBtn.addEventListener('click', hideCompleteDeliveryModal);
    }
    
    if (completeModalOverlay) {
        completeModalOverlay.addEventListener('click', hideCompleteDeliveryModal);
    }

    // Delivery Management toggle
    const deliveryManagementToggle = document.getElementById('deliveryManagementToggle');
    if (deliveryManagementToggle) {
        deliveryManagementToggle.addEventListener('click', toggleDeliverySubmenu);
    }

    // Navigation items (excluding logout since it's handled separately)
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

// Load active delivery data
function loadActiveDeliveryData() {
    // Fetch data from server
    fetch('/rider/active-delivery/api/active-deliveries')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                displayActiveDeliveryData(data.deliveries);
            } else {
                console.error('Error loading active delivery data:', data.error);
                showNotification(data.error || 'Failed to load active deliveries', 'error');
                displayActiveDeliveryData([]);
            }
        })
        .catch(error => {
            console.error('Error fetching active delivery data:', error);
            showNotification('Failed to load active deliveries', 'error');
            displayActiveDeliveryData([]);
        });
}

// Display active delivery data in table
function displayActiveDeliveryData(deliveryData) {
    const tableBody = document.getElementById('deliveryTableBody');
    const emptyState = document.getElementById('emptyState');
    const table = document.querySelector('.delivery-table');
    
    if (!tableBody || !emptyState || !table) return;
    
    console.log('📦 Active Deliveries Data:', deliveryData);
    console.log('📊 Total deliveries:', deliveryData.length);
    
    if (deliveryData.length === 0) {
        // Show empty state but keep table visible
        tableBody.innerHTML = '';
        emptyState.classList.add('show');
    } else {
        // Show table with data
        emptyState.classList.remove('show');
        
        tableBody.innerHTML = deliveryData.map((item, index) => {
            console.log(`🚚 Delivery ${index + 1}:`, item.order_number, 'Status:', item.status);
            return createDeliveryRow(item, index);
        }).join('');
        
        // Add event listeners to pickup buttons
        const pickupButtons = document.querySelectorAll('.btn-pickup');
        pickupButtons.forEach(button => {
            button.addEventListener('click', handlePickupClick);
        });
        
        // Add event listeners to delivered buttons
        const deliveredButtons = document.querySelectorAll('.btn-delivered:not(.disabled)');
        deliveredButtons.forEach(button => {
            button.addEventListener('click', handleItemDelivered);
        });
    }
}

// Create delivery row HTML
function createDeliveryRow(item, index) {
    // Determine button based on status
    let actionButton = '';
    if (item.status === 'assigned') {
        actionButton = `
            <button class="btn-pickup" data-delivery-id="${item.delivery_id}">
                <i class="bi bi-box-seam"></i> Mark as Picked Up
            </button>
        `;
    } else if (item.status === 'picked_up' || item.status === 'in_transit') {
        actionButton = `
            <button class="btn-delivered" data-delivery-id="${item.delivery_id}">
                <i class="bi bi-check-circle"></i> Item Delivered
            </button>
        `;
    } else if (item.status === 'delivered') {
        actionButton = `
            <button class="btn-delivered disabled" disabled>
                <i class="bi bi-clock-history"></i> Awaiting Confirmation
            </button>
        `;
    }
    
    return `
        <tr data-delivery-id="${item.delivery_id}">
            <td>
                <span class="order-id">${item.order_number}</span>
            </td>
            <td>
                <span class="store-name">${item.seller_shop_name}</span>
            </td>
            <td>
                <div class="buyer-info">
                    <div class="info-row">
                        <span class="info-label">Name:</span>
                        <span class="info-value">${item.buyer_name}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Address:</span>
                        <span class="info-value">${item.delivery_address}</span>
                    </div>
                </div>
            </td>
            <td class="text-center">
                <span class="amount-collected">₱${parseFloat(item.total_amount).toFixed(2)}</span>
            </td>
            <td class="text-center">
                ${actionButton}
            </td>
        </tr>
    `;
}

// Refresh active delivery list
function refreshActiveDelivery() {
    loadActiveDeliveryData();
    
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

// Toggle delivery submenu
function toggleDeliverySubmenu(e) {
    e.preventDefault();
    
    // Automatically navigate to List for Pickup page
    window.location.href = '/rider/pickup';
}

// Handle sub-navigation
function handleSubNavigation(e) {
    const tab = e.currentTarget.getAttribute('data-tab');
    const href = e.currentTarget.getAttribute('href');
    
    // Handle specific navigation
    if (href && href !== '#') {
        // Allow normal navigation for links with valid href
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
    
    // Handle specific sub-navigation for items without href
    switch(tab) {
        case 'list-pickup':
            window.location.href = '/rider/pickup';
            break;
        case 'active-delivery':
            // Already on Active Delivery page
            break;
        default:
            // Unknown sub-tab
            break;
    }
}

// Handle navigation
function handleNavigation(e) {
    const tab = e.currentTarget.getAttribute('data-tab');
    const href = e.currentTarget.getAttribute('href');
    
    // Handle specific navigation
    if (href && href !== '#') {
        // Allow normal navigation for links with valid href
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
            // Unknown tab
            break;
    }
}

// Handle logout
function handleLogout() {
    // Logout is now handled by logout-modal.js
}

// Handle pickup button click
// Store pending action info for modals
let pendingPickupDeliveryId = null;
let pendingPickupButton = null;
let pendingCompleteDeliveryId = null;
let pendingCompleteButton = null;

function handlePickupClick(e) {
    const button = e.currentTarget;
    const deliveryId = button.getAttribute('data-delivery-id');
    
    // Store for confirmation
    pendingPickupDeliveryId = deliveryId;
    pendingPickupButton = button;
    
    // Show confirmation modal
    showPickupPackageModal();
}

function showPickupPackageModal() {
    const modal = document.getElementById('pickup-package-modal');
    const overlay = document.getElementById('pickup-package-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.add('active');
        overlay.classList.add('show');
    }
}

function hidePickupPackageModal() {
    const modal = document.getElementById('pickup-package-modal');
    const overlay = document.getElementById('pickup-package-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.remove('active');
        overlay.classList.remove('show');
    }
    pendingPickupDeliveryId = null;
    pendingPickupButton = null;
}

function confirmPickupPackage() {
    if (!pendingPickupDeliveryId || !pendingPickupButton) return;
    
    const deliveryId = pendingPickupDeliveryId;
    const button = pendingPickupButton;
    
    hidePickupPackageModal();
    
    // INSTANT UI UPDATE - Update button immediately for instant feedback
    button.className = 'btn-delivered';
    button.disabled = true;
    button.innerHTML = '<i class="bi bi-hourglass-split"></i> Processing...';
    
    // Show immediate notification
    showNotification('Marking as picked up...', 'info');
    
    // Send to server in background
    fetch('/rider/active-delivery/api/pickup-item', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ delivery_id: deliveryId })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Update to final state
            button.className = 'btn-delivered';
            button.disabled = false;
            button.innerHTML = '<i class="bi bi-check-circle"></i> Item Delivered';
            
            // Re-attach event listener for the new button
            button.removeEventListener('click', handlePickupClick);
            button.addEventListener('click', handleItemDelivered);
            
            showNotification('Item marked as picked up!', 'success');
        } else {
            // Revert on error
            button.className = 'btn-pickup';
            button.disabled = false;
            button.innerHTML = '<i class="bi bi-box-seam"></i> Mark as Picked Up';
            showNotification(data.error || 'Failed to mark as picked up', 'error');
        }
    })
    .catch(error => {
        console.error('Error marking as picked up:', error);
        // Revert on error
        button.className = 'btn-pickup';
        button.disabled = false;
        button.innerHTML = '<i class="bi bi-box-seam"></i> Mark as Picked Up';
        showNotification('Failed to mark as picked up', 'error');
    });
}

// Handle item delivered
function handleItemDelivered(e) {
    const button = e.currentTarget;
    const deliveryId = button.getAttribute('data-delivery-id');
    
    // Store for confirmation
    pendingCompleteDeliveryId = deliveryId;
    pendingCompleteButton = button;
    
    // Show confirmation modal
    showCompleteDeliveryModal();
}

function showCompleteDeliveryModal() {
    const modal = document.getElementById('complete-delivery-modal');
    const overlay = document.getElementById('complete-delivery-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.add('active');
        overlay.classList.add('show');
    }
}

function hideCompleteDeliveryModal() {
    const modal = document.getElementById('complete-delivery-modal');
    const overlay = document.getElementById('complete-delivery-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.remove('active');
        overlay.classList.remove('show');
    }
    pendingCompleteDeliveryId = null;
    pendingCompleteButton = null;
}

function confirmCompleteDelivery() {
    if (!pendingCompleteDeliveryId || !pendingCompleteButton) return;
    
    const deliveryId = pendingCompleteDeliveryId;
    const button = pendingCompleteButton;
    
    hideCompleteDeliveryModal();
    
    // INSTANT UI UPDATE - Update immediately for instant feedback
    button.disabled = true;
    button.classList.add('disabled');
    button.innerHTML = '<i class="bi bi-hourglass-split"></i> Processing...';
    
    // Show immediate notification
    showNotification('Marking as delivered...', 'info');
    
    // Send request to server in background
    fetch('/rider/active-delivery/api/mark-delivered', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ delivery_id: deliveryId })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Update to final state
            button.innerHTML = '<i class="bi bi-clock-history"></i> Awaiting Confirmation';
            showNotification('Waiting for buyer confirmation', 'success');
        } else {
            // Revert on error
            button.disabled = false;
            button.classList.remove('disabled');
            button.innerHTML = '<i class="bi bi-check-circle"></i> Item Delivered';
            showNotification(data.error || 'Failed to mark as delivered', 'error');
        }
    })
    .catch(error => {
        console.error('Error marking as delivered:', error);
        // Revert on error
        button.disabled = false;
        button.classList.remove('disabled');
        button.innerHTML = '<i class="bi bi-check-circle"></i> Item Delivered';
        showNotification('Failed to mark as delivered', 'error');
    });
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
    
    // Faster timeout for quicker feedback
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 2000);
}
