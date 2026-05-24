// Rider Dashboard JavaScript

document.addEventListener('DOMContentLoaded', function() {
    initializeDashboard();
    setupEventListeners();
});

// Initialize dashboard
function initializeDashboard() {
    loadRiderProfile();
    loadDashboardData();
    updateStatusText();
    loadPendingPickupData();
    loadEarningsData();
}

// Load rider profile data into sidebar
function loadRiderProfile() {
    // Get rider data from the page (passed from backend)
    const riderNameElement = document.getElementById('sidebarProfileName');
    const riderImageElement = document.getElementById('sidebarProfileImg');
    
    // The data is already rendered in the HTML template by Jinja2
    // This function can be used for any additional client-side processing if needed
    console.log('Rider profile loaded from template');
}

// Setup event listeners
function setupEventListeners() {
    // Online/Offline status toggle - SIMPLIFIED VERSION
    const statusToggle = document.getElementById('onlineStatus');
    const statusText = document.getElementById('statusText');
    
    console.log('=== SETTING UP STATUS TOGGLE ===');
    console.log('Status toggle:', statusToggle);
    console.log('Status text:', statusText);
    
    if (statusToggle && statusText) {
        statusToggle.addEventListener('change', function() {
            console.log('CHANGE EVENT FIRED! Checked:', this.checked);
            
            if (this.checked) {
                statusText.textContent = 'Online';
                statusText.style.color = '#000000';
                statusText.style.fontWeight = '700';
                console.log('Set to ONLINE');
            } else {
                statusText.textContent = 'Offline';
                statusText.style.color = '#cccccc';
                statusText.style.fontWeight = '400';
                console.log('Set to OFFLINE');
            }
        });
        
        console.log('✓ Event listener added');
    } else {
        console.error('❌ Elements not found!');
    }

    // Refresh button for active deliveries
    const refreshBtn = document.querySelector('.refresh-btn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', refreshDeliveries);
    }

    // Refresh button for pending pickup
    const refreshPendingPickupBtn = document.getElementById('refreshPendingPickupBtn');
    if (refreshPendingPickupBtn) {
        refreshPendingPickupBtn.addEventListener('click', refreshPendingPickup);
    }

    // Refresh button for earnings
    const refreshEarningsBtn = document.getElementById('refreshEarningsBtn');
    if (refreshEarningsBtn) {
        refreshEarningsBtn.addEventListener('click', refreshEarnings);
    }

    // Sidebar profile click
    const sidebarProfile = document.getElementById('sidebarProfile');
    console.log('Sidebar profile element:', sidebarProfile);
    if (sidebarProfile) {
        sidebarProfile.addEventListener('click', function(e) {
            console.log('PROFILE CLICKED!!!');
            handleProfileClick(e);
        });
        console.log('Profile click listener added');
        
        // Also add to profile name specifically
        const profileName = document.getElementById('sidebarProfileName');
        if (profileName) {
            profileName.addEventListener('click', function(e) {
                console.log('PROFILE NAME CLICKED!!!');
                handleProfileClick(e);
            });
        }
    } else {
        console.error('Sidebar profile element not found!');
    }

    // Delivery Management toggle
    const deliveryManagementToggle = document.getElementById('deliveryManagementToggle');
    if (deliveryManagementToggle) {
        deliveryManagementToggle.addEventListener('click', toggleDeliverySubmenu);
    }

    // Navigation items (excluding delivery management and logout since logout is handled by logout-modal.js)
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


// Update status text
function updateStatusText() {
    const statusToggle = document.getElementById('onlineStatus');
    const statusText = document.getElementById('statusText');
    
    if (statusToggle && statusText) {
        if (statusToggle.checked) {
            statusText.textContent = 'Online';
            statusText.classList.add('online');
        } else {
            statusText.textContent = 'Offline';
            statusText.classList.remove('online');
        }
    }
}

// Load dashboard data
function loadDashboardData() {
    // Fetch summary statistics from server
    fetch('/rider/dashboard/api/summary')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                const summary = data.summary;
                const statsData = {
                    activeDeliveries: summary.activeDeliveries,
                    completedDeliveries: summary.completedDeliveries,
                    pending: summary.pendingPickups,
                    earnings: summary.todayEarnings
                };
                updateStats(statsData);
            } else {
                console.error('Error loading summary:', data.error);
            }
        })
        .catch(error => {
            console.error('Error fetching dashboard summary:', error);
        });
    
    loadActiveDeliveries();
    loadRecentActivity();
}

// Update statistics cards
function updateStats(data) {
    // Update Active Deliveries count
    const activeDeliveriesElement = document.getElementById('activeDeliveriesCount');
    if (activeDeliveriesElement) {
        activeDeliveriesElement.textContent = data.activeDeliveries;
    }
    
    // Update Completed count
    const completedElement = document.getElementById('completedDeliveriesCount');
    if (completedElement) {
        completedElement.textContent = data.completedDeliveries;
    }
    
    // Update other stats if they exist
    const statNumbers = document.querySelectorAll('.stat-number');
    if (statNumbers.length >= 4) {
        statNumbers[2].textContent = data.pending;
        statNumbers[3].textContent = `₱${data.earnings.toFixed(2)}`;
    }
}

// Load active deliveries (summary from active delivery page)
function loadActiveDeliveries() {
    const deliveriesList = document.getElementById('deliveriesList');
    
    // Fetch from server
    fetch('/rider/dashboard/api/active-deliveries')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                displayActiveDeliveries(data.deliveries);
            } else {
                console.error('Error loading active deliveries:', data.error);
                displayActiveDeliveries([]);
            }
        })
        .catch(error => {
            console.error('Error fetching active deliveries:', error);
            displayActiveDeliveries([]);
        });
}

// Display active deliveries
function displayActiveDeliveries(deliveries) {
    const deliveriesList = document.getElementById('deliveriesList');
    
    if (!deliveriesList) return;
    
    if (deliveries.length === 0) {
        deliveriesList.innerHTML = `
            <div class="empty-state">
                <p>No active deliveries at the moment</p>
                <p class="empty-subtitle">Turn on your status to receive delivery requests</p>
            </div>
        `;
    } else {
        // Render deliveries as table
        deliveriesList.innerHTML = `
            <table class="dashboard-table">
                <thead>
                    <tr>
                        <th>ORDER ID</th>
                        <th>STORE NAME</th>
                        <th>BUYER INFORMATION</th>
                        <th>AMOUNT TO BE COLLECTED</th>
                    </tr>
                </thead>
                <tbody>
                    ${deliveries.map(item => `
                        <tr>
                            <td><span class="order-id-cell">${item.orderId}</span></td>
                            <td>${item.item.storeName}</td>
                            <td>
                                <div class="info-group">
                                    <div class="info-line"><span class="info-label">Name:</span> ${item.buyer.name}</div>
                                    <div class="info-line"><span class="info-label">Address:</span> ${item.buyer.address}</div>
                                </div>
                            </td>
                            <td class="text-center"><span class="amount-collected">₱${item.amount.toFixed(2)}</span></td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
    }
}

// Create delivery card HTML
function createDeliveryCard(delivery) {
    return `
        <div class="delivery-card" data-id="${delivery.id}">
            <div class="delivery-header">
                <span class="order-number">#${delivery.orderNumber}</span>
                <span class="delivery-status ${delivery.status}">${delivery.status}</span>
            </div>
            <div class="delivery-info">
                <p><strong>Customer:</strong> ${delivery.customerName}</p>
                <p><strong>Address:</strong> ${delivery.address}</p>
                <p><strong>Distance:</strong> ${delivery.distance} km</p>
                <p><strong>Payment:</strong> ₱${delivery.amount.toFixed(2)}</p>
            </div>
            <div class="delivery-actions">
                <button class="btn-accept" onclick="acceptDelivery('${delivery.id}')">Accept</button>
                <button class="btn-view" onclick="viewDeliveryDetails('${delivery.id}')">View Details</button>
            </div>
        </div>
    `;
}

// Load recent activity
function loadRecentActivity() {
    const activityList = document.getElementById('activityList');
    
    // Check if element exists first
    if (!activityList) {
        console.log('Activity list element not found, skipping...');
        return;
    }
    
    // TODO: Fetch from server
    const activities = [];
    
    if (activities.length === 0) {
        activityList.innerHTML = `
            <div class="empty-state">
                <p>No recent activity</p>
            </div>
        `;
    } else {
        // Render activities
        activityList.innerHTML = activities.map(activity => createActivityItem(activity)).join('');
    }
}

// Create activity item HTML
function createActivityItem(activity) {
    return `
        <div class="activity-item">
            <div class="activity-icon">${activity.icon}</div>
            <div class="activity-content">
                <p class="activity-text">${activity.text}</p>
                <span class="activity-time">${activity.time}</span>
            </div>
        </div>
    `;
}

// Refresh deliveries
function refreshDeliveries() {
    console.log('Refreshing deliveries...');
    loadActiveDeliveries();
    // TODO: Fetch latest deliveries from server
}

// Handle profile click
function handleProfileClick(e) {
    console.log('Profile clicked - navigating to profile page');
    console.log('Event:', e);
    if (e) {
        e.preventDefault();
        e.stopPropagation();
    }
    console.log('Redirecting to: /rider/profile');
    setTimeout(() => {
        window.location.href = '/rider/profile';
    }, 100);
}

// Toggle delivery submenu with animation
function toggleDeliverySubmenu(e) {
    e.preventDefault();
    
    // Automatically navigate to List for Pickup page
    window.location.href = '/rider/pickup';
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
    
    // Remove active class from all items and subitems
    document.querySelectorAll('.nav-item:not(#deliveryManagementToggle)').forEach(item => {
        item.classList.remove('active');
    });
    document.querySelectorAll('.nav-subitem').forEach(item => {
        item.classList.remove('active');
    });
    
    // Add active class to clicked item
    e.currentTarget.classList.add('active');
    
    // Handle specific navigation for items without href
    switch(tab) {
        case 'dashboard':
            loadDashboardView();
            break;
        case 'earnings':
            // This should not be reached since earnings has href
            window.location.href = '/rider/earnings';
            break;
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
    
    // Handle specific sub-navigation for items without href
    switch(tab) {
        case 'list-pickup':
            // This should not be reached since pickup has href
            window.location.href = '/rider/pickup';
            break;
        case 'active-delivery':
            // This should not be reached since active-delivery has href
            window.location.href = '/rider/active-delivery';
            break;
        default:
            console.log('Unknown sub-tab:', tab);
    }
}

// Accept delivery
function acceptDelivery(deliveryId) {
    console.log('Accepting delivery:', deliveryId);
    // TODO: Send accept request to server
    loadActiveDeliveries();
}

// View delivery details
function viewDeliveryDetails(deliveryId) {
    console.log('Viewing delivery details:', deliveryId);
    // TODO: Open delivery details modal or page
}

// Show notification
function showNotification(message, type = 'info') {
    // Simple console notification for now
    // TODO: Implement proper notification UI
    console.log(`[${type.toUpperCase()}] ${message}`);
}

// View loading functions
function loadDashboardView() {
    console.log('Loading Dashboard view...');
    // TODO: Load dashboard content
}

function loadEarningsView() {
    console.log('Loading Earnings view...');
    // TODO: Load earnings content
}

function loadListForPickupView() {
    console.log('Loading List for Pickup view...');
    // TODO: Load pickup list content
}

function loadActiveDeliveryView() {
    console.log('Loading Active Delivery view...');
    // TODO: Load active delivery list content
}

function handleLogout() {
    // Logout is now handled by logout-modal.js
}

// Load pending pickup data (summary from pickup page)
function loadPendingPickupData() {
    // Fetch from server
    fetch('/rider/dashboard/api/pending-pickups')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                displayPendingPickup(data.pickups);
            } else {
                console.error('Error loading pending pickups:', data.error);
                displayPendingPickup([]);
            }
        })
        .catch(error => {
            console.error('Error fetching pending pickups:', error);
            displayPendingPickup([]);
        });
}

// Display pending pickup
function displayPendingPickup(data) {
    const container = document.getElementById('pendingPickupList');
    if (!container) return;
    
    console.log('📊 Displaying pending pickup data:', data);
    
    if (data.length === 0) {
        container.innerHTML = '<div class="empty-state"><p>No pending pickups</p></div>';
        return;
    }
    
    // Log each item's deliveryId
    data.forEach((item, index) => {
        console.log(`📦 Item ${index}: deliveryId = ${item.deliveryId} (type: ${typeof item.deliveryId})`);
    });
    
    container.innerHTML = `
        <table class="dashboard-table">
            <thead>
                <tr>
                    <th>ORDER ID</th>
                    <th>SELLER INFORMATION</th>
                    <th>PICKUP ADDRESS</th>
                    <th>BUYER</th>
                    <th>ACTIONS</th>
                </tr>
            </thead>
            <tbody>
                ${data.map(item => {
                    console.log(`🔨 Creating button for deliveryId: ${item.deliveryId}`);
                    return `
                    <tr data-delivery-id="${item.deliveryId}">
                        <td>
                            <span class="order-id">${item.orderId}</span>
                        </td>
                        <td>
                            <div class="seller-info">
                                <div class="info-row">
                                    <span class="info-label">Store:</span>
                                    <span class="info-value">${item.seller.storeName}</span>
                                </div>
                                <div class="info-row">
                                    <span class="info-label">Phone:</span>
                                    <span class="info-value">${item.seller.phone || 'N/A'}</span>
                                </div>
                            </div>
                        </td>
                        <td>
                            <span class="delivery-address">${item.seller.storeAddress}</span>
                        </td>
                        <td>
                            <span class="buyer-name">${item.buyer.name}</span>
                        </td>
                        <td>
                            <div class="action-buttons">
                                <button class="btn-accept" data-delivery-id="${item.deliveryId}">
                                    <i class="bi bi-check-circle"></i>
                                    <span>Accept</span>
                                </button>
                                <button class="btn-reject" data-delivery-id="${item.deliveryId}">
                                    <i class="bi bi-x-circle"></i>
                                    <span>Reject</span>
                                </button>
                            </div>
                        </td>
                    </tr>
                `;
                }).join('')}
            </tbody>
        </table>
    `;
    
    // Add event listeners to buttons (like rider_pickup.js)
    const acceptButtons = container.querySelectorAll('.btn-accept');
    const rejectButtons = container.querySelectorAll('.btn-reject');
    
    console.log(`✅ Found ${acceptButtons.length} accept buttons`);
    
    acceptButtons.forEach((button, idx) => {
        const deliveryId = button.getAttribute('data-delivery-id');
        console.log(`  Button ${idx}: data-delivery-id = ${deliveryId}`);
        button.addEventListener('click', function() {
            handleAcceptClick(deliveryId);
        });
    });
    
    rejectButtons.forEach(button => {
        const deliveryId = button.getAttribute('data-delivery-id');
        button.addEventListener('click', function() {
            handleRejectClick(deliveryId);
        });
    });
}

// Handle accept button click (like rider_pickup.js)
function handleAcceptClick(deliveryId) {
    console.log('🔍 Accept button clicked, delivery_id:', deliveryId);
    pendingDeliveryId = deliveryId;
    console.log('✅ Stored pendingDeliveryId:', pendingDeliveryId);
    showAcceptDeliveryModal();
}

// Handle reject button click
function handleRejectClick(deliveryId) {
    console.log('🔍 Reject button clicked, delivery_id:', deliveryId);
    // TODO: Implement reject functionality
    showNotification('Delivery rejected', 'info');
}

// Refresh pending pickup
function refreshPendingPickup() {
    console.log('Refreshing pending pickup...');
    loadPendingPickupData();
    
    // Add visual feedback
    const refreshBtn = document.getElementById('refreshPendingPickupBtn');
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

// Load earnings data (summary from earnings page)
function loadEarningsData() {
    // Fetch from server
    fetch('/rider/dashboard/api/earnings-summary')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                displayEarnings(data.earnings);
            } else {
                console.error('Error loading earnings:', data.error);
                displayEarnings([]);
            }
        })
        .catch(error => {
            console.error('Error fetching earnings:', error);
            displayEarnings([]);
        });
}

// Display earnings
function displayEarnings(data) {
    const container = document.getElementById('earningsList');
    if (!container) return;
    
    if (data.length === 0) {
        container.innerHTML = '<div class="empty-state"><p>No earnings data available</p></div>';
        return;
    }
    
    container.innerHTML = `
        <table class="dashboard-table">
            <thead>
                <tr>
                    <th>ORDER ID</th>
                    <th>BUYER INFORMATION</th>
                    <th>SELLER INFORMATION</th>
                    <th>PRODUCT NAME</th>
                    <th>AMOUNT</th>
                </tr>
            </thead>
            <tbody>
                ${data.map(item => `
                    <tr>
                        <td><span class="order-id-cell">${item.orderId}</span></td>
                        <td>
                            <div class="info-group">
                                <div class="info-line"><span class="info-label">Name:</span> ${item.buyer.name}</div>
                                <div class="info-line"><span class="info-label">Address:</span> ${item.buyer.address}</div>
                            </div>
                        </td>
                        <td>
                            <div class="info-group">
                                <div class="info-line"><span class="info-label">Seller:</span> ${item.seller.name}</div>
                                <div class="info-line"><span class="info-label">Store:</span> ${item.seller.storeName}</div>
                            </div>
                        </td>
                        <td>${item.productName}</td>
                        <td><span class="amount-cell">+ ₱${item.amount.toFixed(2)}</span></td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

// Refresh earnings
function refreshEarnings() {
    console.log('Refreshing earnings...');
    loadEarningsData();
    
    // Add visual feedback
    const refreshBtn = document.getElementById('refreshEarningsBtn');
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

// Add CSS animation for refresh button
const style = document.createElement('style');
style.textContent = `
    @keyframes spin {
        from { transform: rotate(0deg); }
        to { transform: rotate(360deg); }
    }
`;
document.head.appendChild(style);

// Auto-refresh deliveries every 30 seconds when online
setInterval(() => {
    const statusToggle = document.getElementById('onlineStatus');
    if (statusToggle && statusToggle.checked) {
        loadActiveDeliveries();
    }
}, 30000);


// Accept delivery from dashboard - Show confirmation modal first
let pendingDeliveryId = null;

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
}

function confirmAcceptDelivery() {
    console.log('📤 confirmAcceptDelivery called, pendingDeliveryId:', pendingDeliveryId);
    
    if (!pendingDeliveryId) {
        console.error('❌ No pendingDeliveryId!');
        return;
    }
    
    hideAcceptDeliveryModal();
    
    console.log('📨 Sending request with delivery_id:', pendingDeliveryId);
    
    fetch('/rider/pickup/api/accept-delivery', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ delivery_id: pendingDeliveryId })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showNotification('Delivery accepted successfully!', 'success');
            // Refresh dashboard data
            loadPendingPickupData();
            loadActiveDeliveriesData();
            loadStats();
        } else {
            showNotification(data.error || 'Failed to accept delivery', 'error');
        }
    })
    .catch(error => {
        console.error('Error accepting delivery:', error);
        showNotification('Failed to accept delivery', 'error');
    });
}

// Setup modal event listeners
document.addEventListener('DOMContentLoaded', function() {
    const confirmBtn = document.getElementById('confirm-accept-delivery');
    const cancelBtn = document.getElementById('cancel-accept-delivery');
    const overlay = document.getElementById('accept-delivery-modal-overlay');
    
    if (confirmBtn) {
        confirmBtn.addEventListener('click', confirmAcceptDelivery);
    }
    
    if (cancelBtn) {
        cancelBtn.addEventListener('click', hideAcceptDeliveryModal);
    }
    
    if (overlay) {
        overlay.addEventListener('click', hideAcceptDeliveryModal);
    }
});

// Reject delivery from dashboard
function rejectDelivery(deliveryId) {
    fetch('/rider/pickup/api/reject-delivery', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ 
            delivery_id: deliveryId
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showNotification('Delivery rejected', 'info');
            // Refresh dashboard data
            loadPendingPickupData();
            loadStats();
        } else {
            showNotification(data.error || 'Failed to reject delivery', 'error');
        }
    })
    .catch(error => {
        console.error('Error rejecting delivery:', error);
        showNotification('Failed to reject delivery', 'error');
    });
}

// Show notification (same as pickup page)
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

