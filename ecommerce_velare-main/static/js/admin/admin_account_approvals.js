// Admin Account Approvals JavaScript

let currentAccounts = [];
let currentFilters = {
    userType: 'all',
    status: 'pending',
    search: ''
};

// Fetch pending accounts
async function fetchPendingAccounts() {
    try {
        const params = new URLSearchParams({
            user_type: currentFilters.userType,
            status: currentFilters.status,
            search: currentFilters.search
        });

        const response = await fetch(`/api/admin/accounts/pending?${params}`);
        const data = await response.json();

        if (data.success) {
            currentAccounts = data.accounts;
            displayAccounts(currentAccounts);
            updatePendingCount(data.total_pending);
        } else {
            console.error('Failed to fetch accounts:', data.message);
        }
    } catch (error) {
        console.error('Error fetching accounts:', error);
    }
}

// Display accounts in grid
function displayAccounts(accounts) {
    const container = document.getElementById('approvalCardsContainer');
    
    if (!accounts || accounts.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class="bi bi-inbox" style="font-size: 4rem; color: #ccc;"></i>
                <h3>No Pending Accounts</h3>
                <p>All accounts have been reviewed</p>
            </div>
        `;
        return;
    }

    container.innerHTML = accounts.map(account => createAccountCard(account)).join('');
    
    // Add event listeners to action buttons
    document.querySelectorAll('.btn-approve').forEach(btn => {
        btn.addEventListener('click', (e) => handleApprove(e));
    });
    
    document.querySelectorAll('.btn-reject').forEach(btn => {
        btn.addEventListener('click', (e) => handleReject(e));
    });
}

// Create account card HTML
function createAccountCard(account) {
    // Set icon based on user type
    let userTypeIcon = 'bi-person';
    let userTypeLabel = 'Buyer';
    if (account.user_type === 'seller') {
        userTypeIcon = 'bi-shop';
        userTypeLabel = 'Seller';
    } else if (account.user_type === 'rider') {
        userTypeIcon = 'bi-bicycle';
        userTypeLabel = 'Rider';
    }
    
    const displayName = account.user_type === 'seller' && account.shop_name 
        ? account.shop_name 
        : `${account.first_name} ${account.last_name}`;
    
    const idImage = account.id_file_path || '/static/images/user.png';
    const submittedDate = new Date(account.created_at).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });

    return `
        <div class="approval-card" data-account-id="${account.account_id}" data-user-type="${account.user_type}">
            <div class="card-header">
                <div class="seller-info">
                    <i class="bi ${userTypeIcon}"></i>
                    <span class="seller-name">${displayName}</span>
                </div>
                <span class="status-badge pending">${userTypeLabel}</span>
            </div>
            
            <div class="card-body">
                <div class="product-image-section">
                    <div class="main-product-image">
                        <img src="${idImage}" alt="ID Document" style="object-fit: contain;">
                    </div>
                </div>
                
                <div class="product-details-section">
                    <h3 class="product-name">${account.first_name} ${account.last_name}</h3>
                    
                    <div class="product-info-grid">
                        <div class="info-item">
                            <label>Email:</label>
                            <span>${account.email}</span>
                        </div>
                        <div class="info-item">
                            <label>Phone:</label>
                            <span>${account.phone_number || 'N/A'}</span>
                        </div>
                        <div class="info-item">
                            <label>ID Type:</label>
                            <span>${formatIdType(account.id_type)}</span>
                        </div>
                        ${account.shop_name ? `
                        <div class="info-item">
                            <label>Shop Name:</label>
                            <span>${account.shop_name}</span>
                        </div>
                        ` : ''}
                    </div>
                    
                    <div class="product-description">
                        <label>Address:</label>
                        <p>${account.full_address || 'No address provided'}</p>
                        ${account.region ? `<p style="margin-top: 8px; font-size: 0.9em; color: #666;">
                            ${account.barangay}, ${account.city}, ${account.province}, ${account.region}
                        </p>` : ''}
                    </div>
                    
                    <div class="submission-info">
                        <i class="bi bi-calendar3"></i>
                        <span>Registered: ${submittedDate}</span>
                    </div>
                </div>
            </div>
            
            <div class="card-actions">
                <button class="btn btn-approve" data-action="approve">
                    <i class="bi bi-check-circle"></i>
                    Approve
                </button>
                <button class="btn btn-reject" data-action="reject">
                    <i class="bi bi-x-circle"></i>
                    Reject
                </button>
            </div>
        </div>
    `;
}

// Format ID type for display
function formatIdType(idType) {
    const types = {
        'passport': 'Passport',
        'driver_license': "Driver's License",
        'national_id': 'National ID',
        'sss': 'SSS ID',
        'umid': 'UMID',
        'other': 'Other'
    };
    return types[idType] || idType;
}

// Handle approve action
async function handleApprove(e) {
    const card = e.target.closest('.approval-card');
    const accountId = card.dataset.accountId;
    const userType = card.dataset.userType;
    
    if (!confirm(`Are you sure you want to approve this ${userType} account?`)) {
        return;
    }
    
    try {
        const response = await fetch(`/api/admin/accounts/${userType}/${accountId}/approve`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            showNotification('Account approved successfully!', 'success');
            fetchPendingAccounts(); // Refresh the list
        } else {
            showNotification(data.message || 'Failed to approve account', 'error');
        }
    } catch (error) {
        console.error('Error approving account:', error);
        showNotification('An error occurred', 'error');
    }
}

// Handle reject action
async function handleReject(e) {
    const card = e.target.closest('.approval-card');
    const accountId = card.dataset.accountId;
    const userType = card.dataset.userType;
    
    if (!confirm(`Are you sure you want to reject this ${userType} account?`)) {
        return;
    }
    
    try {
        const response = await fetch(`/api/admin/accounts/${userType}/${accountId}/reject`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            showNotification('Account rejected', 'error');
            fetchPendingAccounts(); // Refresh the list
        } else {
            showNotification(data.message || 'Failed to reject account', 'error');
        }
    } catch (error) {
        console.error('Error rejecting account:', error);
        showNotification('An error occurred', 'error');
    }
}

// Update pending count
function updatePendingCount(count) {
    const countElement = document.getElementById('pendingCount');
    if (countElement) {
        countElement.textContent = count;
    }
}

// Show notification
function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 25px;
        background: ${type === 'success' ? '#4CAF50' : type === 'error' ? '#f44336' : '#2196F3'};
        color: white;
        border-radius: 4px;
        box-shadow: 0 2px 5px rgba(0,0,0,0.2);
        z-index: 10000;
        animation: slideIn 0.3s ease-out;
    `;
    
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease-out';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(100%);
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
            transform: translateX(100%);
            opacity: 0;
        }
    }
    
    .empty-state {
        text-align: center;
        padding: 60px 20px;
        color: #666;
    }
    
    .empty-state h3 {
        margin: 20px 0 10px;
        font-size: 1.5rem;
    }
`;
document.head.appendChild(style);

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    // Fetch initial data
    fetchPendingAccounts();
    
    // Set up filter listeners
    const userTypeFilter = document.getElementById('userTypeFilter');
    const statusFilter = document.getElementById('statusFilter');
    const searchInput = document.getElementById('accountSearch');
    
    if (userTypeFilter) {
        userTypeFilter.addEventListener('change', (e) => {
            currentFilters.userType = e.target.value;
            fetchPendingAccounts();
        });
    }
    
    if (statusFilter) {
        statusFilter.addEventListener('change', (e) => {
            currentFilters.status = e.target.value;
            fetchPendingAccounts();
        });
    }
    
    if (searchInput) {
        let searchTimeout;
        searchInput.addEventListener('input', (e) => {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => {
                currentFilters.search = e.target.value;
                fetchPendingAccounts();
            }, 500); // Debounce search
        });
    }
});
