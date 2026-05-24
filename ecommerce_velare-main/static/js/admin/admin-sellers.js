// Admin Sellers Management JavaScript
// Version: 2.0 - ID Type Label Fix
console.log('🔄 Admin Sellers JS Loaded - Version 2.0');

let currentFilters = {
    status: 'all',
    search: ''
};

// Image Modal Setup
function setupImageModal() {
    const style = document.createElement('style');
    style.textContent = `
        #admin-image-modal-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100vw;
            height: 100vh;
            background: rgba(0, 0, 0, 0.6);
            z-index: 10000;
            opacity: 0;
            pointer-events: none;
            transition: opacity 0.3s ease;
            backdrop-filter: blur(8px);
            -webkit-backdrop-filter: blur(8px);
        }
        
        #admin-image-modal-overlay.show {
            opacity: 1;
            pointer-events: auto;
        }
        
        .admin-image-modal {
            display: none;
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%) scale(0.95);
            z-index: 10001;
            max-width: 80vw;
            max-height: 85vh;
            box-shadow: 0 12px 40px rgba(0, 0, 0, 0.25);
            border-radius: 4px;
            transition: transform 0.3s ease, opacity 0.3s ease;
            opacity: 0;
        }
        
        .admin-image-modal.show {
            display: block;
            opacity: 1;
            transform: translate(-50%, -50%) scale(1);
        }
        
        .admin-image-modal-content {
            width: 600px;
            height: 600px;
            max-width: 80vw;
            max-height: 85vh;
            display: block;
            border-radius: 4px;
            object-fit: contain;
            background: rgba(0, 0, 0, 0.1);
        }
        
        .admin-image-modal-close {
            position: absolute;
            top: -15px;
            right: -15px;
            color: #ffffff;
            background: rgba(0, 0, 0, 0.7);
            border-radius: 50%;
            width: 32px;
            height: 32px;
            line-height: 32px;
            text-align: center;
            font-size: 24px;
            font-weight: bold;
            cursor: pointer;
            transition: transform 0.2s ease, background 0.2s ease;
            border: none;
            padding: 0;
        }
        
        .admin-image-modal-close:hover {
            transform: scale(1.1);
            background: rgba(0, 0, 0, 0.9);
        }
    `;
    document.head.appendChild(style);
    
    // Create modal HTML
    const modalOverlay = document.createElement('div');
    modalOverlay.id = 'admin-image-modal-overlay';
    
    const modal = document.createElement('div');
    modal.id = 'admin-image-modal';
    modal.className = 'admin-image-modal';
    modal.innerHTML = `
        <button class="admin-image-modal-close">&times;</button>
        <img class="admin-image-modal-content" id="admin-modal-image-content">
    `;
    
    document.body.appendChild(modalOverlay);
    document.body.appendChild(modal);
    
    // Setup event listeners
    const closeBtn = modal.querySelector('.admin-image-modal-close');
    closeBtn.addEventListener('click', hideImageModal);
    modalOverlay.addEventListener('click', hideImageModal);
}

function showImageModal(src) {
    const modal = document.getElementById('admin-image-modal');
    const overlay = document.getElementById('admin-image-modal-overlay');
    const img = document.getElementById('admin-modal-image-content');
    
    if (modal && overlay && img) {
        img.src = src;
        modal.classList.add('show');
        overlay.classList.add('show');
    }
}

function hideImageModal() {
    const modal = document.getElementById('admin-image-modal');
    const overlay = document.getElementById('admin-image-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.remove('show');
        overlay.classList.remove('show');
    }
}

// Fetch sellers from backend
async function fetchSellers() {
    try {
        const params = new URLSearchParams({
            status: currentFilters.status,
            search: currentFilters.search
        });

        const response = await fetch(`/api/admin/sellers?${params}`);
        const data = await response.json();

        if (data.success) {
            displaySellers(data.sellers);
            updateCounts(data.counts);
        } else {
            console.error('Failed to fetch sellers:', data.message);
        }
    } catch (error) {
        console.error('Error fetching sellers:', error);
    }
}

// Display sellers in cards
function displaySellers(sellers) {
    const grid = document.getElementById('sellersGrid');
    
    if (!sellers || sellers.length === 0) {
        grid.innerHTML = '<div style="grid-column: 1/-1; text-align:center; padding:40px; color:#666;">No sellers found</div>';
        return;
    }

    grid.innerHTML = sellers.map(seller => createSellerCard(seller)).join('');
    setupActionButtons();
}

// Create seller card
function createSellerCard(seller) {
    // Debug logging
    console.log('=== Creating card for seller ===');
    console.log('Name:', seller.first_name, seller.last_name);
    console.log('ID Type:', seller.id_type, '(Type:', typeof seller.id_type, ')');
    console.log('ID Type is null?', seller.id_type === null);
    console.log('ID Type is undefined?', seller.id_type === undefined);
    console.log('ID Type is empty?', seller.id_type === '');
    console.log('ID File Path:', seller.id_file_path);
    console.log('Business Permit Path:', seller.business_permit_file_path);
    console.log('Shop Logo:', seller.shop_logo);
    console.log('Full seller object:', seller);
    
    const initials = `${seller.first_name?.[0] || '?'}${seller.last_name?.[0] || '?'}`.toUpperCase();
    const joinDate = new Date(seller.created_at).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
    
    const statusClass = (seller.status || 'pending').toLowerCase();
    const statusLabel = (seller.status || 'Pending').charAt(0).toUpperCase() + (seller.status || 'pending').slice(1);
    
    return `
        <div class="approval-card" data-seller-id="${seller.account_id}" data-user-id="${seller.user_id}" data-status="${seller.status || 'pending'}">
            <div class="card-body">
                <div class="product-image-section">
                    <div class="main-product-image clickable-image" ${seller.id_file_path ? `onclick="showImageModal('${seller.id_file_path}')"` : ''} style="${seller.id_file_path ? 'cursor: pointer;' : ''}">
                        ${seller.id_file_path ? 
                            `<img src="${seller.id_file_path}" alt="ID Document" onerror="console.error('Failed to load image:', this.src); this.parentElement.innerHTML='<div class=\\'id-placeholder\\'><i class=\\'bi bi-card-text\\'></i><p>Image Load Failed</p></div>';">` :
                            `<div class="id-placeholder"><i class="bi bi-card-text"></i><p>No ID Uploaded</p></div>`
                        }
                    </div>
                    <div style="display: block !important; visibility: visible !important; opacity: 1 !important; color: #000000 !important; font-weight: 600 !important; padding: 8px 0 !important; margin: 8px 0 0 0 !important; width: 200px !important; box-sizing: border-box !important; text-align: center !important; font-family: 'Montserrat', sans-serif !important; font-size: 0.8rem !important; text-transform: uppercase !important; letter-spacing: 0.5px !important;">
                        ${seller.id_type ? seller.id_type.replace(/_/g, ' ').toUpperCase() : 'VALID ID'}
                    </div>
                </div>
                
                <div class="product-details-section">
                    <div class="buyer-name-header">
                        ${seller.shop_logo ? 
                            `<div class="small-avatar" style="background: none; border: 2px solid rgba(211, 189, 155, 0.3); padding: 0; overflow: hidden;">
                                <img src="${seller.shop_logo.startsWith('http://') || seller.shop_logo.startsWith('https://') ? seller.shop_logo : (seller.shop_logo.startsWith('/') ? seller.shop_logo : '/static/' + seller.shop_logo)}" alt="Shop Logo" style="width: 100%; height: 100%; object-fit: cover;" onerror="console.error('Failed to load shop logo:', this.src); this.parentElement.innerHTML='<div style=\\'width:100%;height:100%;display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,#d3bd9b 0%,#c4a882 100%);color:#fff;font-family:Playfair Display,serif;font-size:1.1rem;font-weight:700;\\'>${initials}</div>';">
                            </div>` :
                            `<div class="small-avatar">${initials}</div>`
                        }
                        <h3 class="product-name">${seller.first_name} ${seller.last_name}</h3>
                        <span class="status-badge ${statusClass}">${statusLabel}</span>
                        ${seller.report_count && seller.report_count > 0 ? `
                            <span class="report-count-badge" style="background: ${seller.report_count >= 3 ? '#dc3545' : seller.report_count >= 2 ? '#ff6b6b' : '#ffa500'} !important; color: white !important; padding: 4px 10px !important; border-radius: 2px !important; border: 2px solid ${seller.report_count >= 3 ? '#b02a37' : seller.report_count >= 2 ? '#e85555' : '#e69500'} !important; font-size: 0.75rem !important; font-weight: 600 !important; margin-left: 8px !important;">
                                <i class="bi bi-flag-fill"></i> ${seller.report_count} Report${seller.report_count > 1 ? 's' : ''}
                            </span>
                        ` : ''}
                    </div>
                    
                    <div class="product-info-grid">
                        <div class="info-item">
                            <label>Shop Name:</label>
                            <span>${seller.shop_name || 'N/A'}</span>
                        </div>
                        <div class="info-item">
                            <label>Email:</label>
                            <span>${seller.email}</span>
                        </div>
                        <div class="info-item">
                            <label>Phone:</label>
                            <span>${seller.phone_number || 'N/A'}</span>
                        </div>
                        <div class="info-item">
                            <label>Address:</label>
                            <span>${seller.full_address || 'N/A'}</span>
                        </div>
                        <div class="info-item">
                            <label>Business Permit:</label>
                            <span>
                                ${seller.business_permit_file_path ? 
                                    `<a onclick="showImageModal('${seller.business_permit_file_path}')" style="color: #D3BD9B; text-decoration: underline; cursor: pointer;">View Document</a>` :
                                    'Not Uploaded'
                                }
                            </span>
                        </div>
                    </div>
                    
                    <div class="submission-info">
                        <i class="bi bi-calendar3"></i>
                        <span>Registered: ${joinDate}</span>
                    </div>
                </div>
            </div>
            
            <div class="card-actions">
                ${seller.status === 'pending' ? `
                    <button class="btn btn-approve" data-action="approve">
                        <i class="bi bi-check-circle"></i>
                        Approve
                    </button>
                    <button class="btn btn-reject" data-action="reject">
                        <i class="bi bi-x-circle"></i>
                        Reject
                    </button>
                ` : seller.status === 'active' ? `
                    <button class="btn btn-reject" data-action="suspend">
                        <i class="bi bi-pause-circle"></i>
                        Suspend
                    </button>
                    <button class="btn btn-reject" data-action="ban">
                        <i class="bi bi-slash-circle"></i>
                        Ban
                    </button>
                ` : seller.status === 'suspended' ? `
                    <button class="btn btn-approve" data-action="approve">
                        <i class="bi bi-check-circle"></i>
                        Activate
                    </button>
                    <button class="btn btn-reject" data-action="ban">
                        <i class="bi bi-slash-circle"></i>
                        Ban
                    </button>
                ` : `
                    <button class="btn btn-approve" data-action="approve">
                        <i class="bi bi-check-circle"></i>
                        Activate
                    </button>
                `}
            </div>
        </div>
    `;
}

// Update count badges based on current filter
function updateCounts(counts) {
    const statsContainer = document.querySelector('.approvals-stats');
    const currentStatus = currentFilters.status;
    
    let badgeHTML = '';
    let badgeClass = '';
    let badgeIcon = '';
    let badgeLabel = '';
    let badgeCount = 0;
    
    switch(currentStatus) {
        case 'all':
            badgeClass = 'total';
            badgeIcon = 'bi-shop';
            badgeLabel = 'Total Sellers';
            badgeCount = (counts.pending_count || 0) + (counts.active_count || 0) + 
                        (counts.rejected_count || 0) + (counts.suspended_count || 0) + 
                        (counts.banned_count || 0);
            break;
        case 'pending':
            badgeClass = 'pending';
            badgeIcon = 'bi-clock-history';
            badgeLabel = 'Pending';
            badgeCount = counts.pending_count || 0;
            break;
        case 'active':
            badgeClass = 'active';
            badgeIcon = 'bi-check-circle';
            badgeLabel = 'Active';
            badgeCount = counts.active_count || 0;
            break;
        case 'rejected':
            badgeClass = 'rejected';
            badgeIcon = 'bi-x-circle';
            badgeLabel = 'Rejected';
            badgeCount = counts.rejected_count || 0;
            break;
        case 'suspended':
            badgeClass = 'suspended';
            badgeIcon = 'bi-pause-circle';
            badgeLabel = 'Suspended';
            badgeCount = counts.suspended_count || 0;
            break;
        case 'banned':
            badgeClass = 'banned';
            badgeIcon = 'bi-slash-circle';
            badgeLabel = 'Banned';
            badgeCount = counts.banned_count || 0;
            break;
    }
    
    badgeHTML = `
        <span class="stat-badge ${badgeClass}">
            <i class="${badgeIcon}"></i>
            <span>${badgeCount}</span> ${badgeLabel}
        </span>
    `;
    
    statsContainer.innerHTML = badgeHTML;
}

// Setup action button handlers
function setupActionButtons() {
    document.querySelectorAll('.btn').forEach(btn => {
        btn.addEventListener('click', async function() {
            const action = this.dataset.action;
            const card = this.closest('.approval-card');
            const sellerId = card.dataset.sellerId;
            const userId = card.dataset.userId;
            const sellerName = card.querySelector('.product-name').textContent;
            
            // For suspend/ban actions, show duration modal first (no alert yet)
            if (action === 'suspend' || action === 'ban') {
                const suspendData = await showSuspendModal(action, sellerName, userId);
                if (!suspendData) {
                    return; // User cancelled
                }
                
                // Now show final confirmation modal with duration
                const confirmMsg = action === 'ban' 
                    ? `Are you sure you want to PERMANENTLY BAN ${sellerName}? This action cannot be undone.`
                    : `Are you sure you want to suspend ${sellerName} for ${suspendData.duration_value} ${suspendData.duration_unit}?`;
                
                const confirmed = await showConfirmationModal(confirmMsg, action);
                if (!confirmed) {
                    return;
                }
                
                // Send suspend/ban request with duration
                try {
                    const response = await fetch('/admin/suspend-user', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            reported_user_id: suspendData.user_id,
                            reported_user_type: 'seller',
                            action: action,
                            duration_value: suspendData.duration_value,
                            duration_unit: suspendData.duration_unit,
                            reason: suspendData.reason
                        })
                    });
                    
                    const data = await response.json();
                    
                    if (data.success) {
                        showNotification(data.message, 'success');
                        fetchSellers();
                    } else {
                        showNotification(data.message || `Failed to ${action} seller`, 'error');
                    }
                } catch (error) {
                    console.error('Error:', error);
                    showNotification(`An error occurred while trying to ${action} the seller`, 'error');
                }
                return;
            }
            
            // For other actions (approve, reject, activate), show simple confirmation
            const confirmed = await showActionConfirmModal(action, sellerName);
            if (!confirmed) {
                return;
            }
            
            try {
                const response = await fetch(`/api/admin/sellers/${sellerId}/${action}`, {
                    method: 'POST'
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showNotification(data.message || `Seller ${action}ed successfully`, 'success');
                    fetchSellers();
                } else {
                    showNotification(data.message || `Failed to ${action} seller`, 'error');
                }
            } catch (error) {
                console.error('Error:', error);
                showNotification(`An error occurred while trying to ${action} the seller`, 'error');
            }
        });
    });
}

// Show suspend/ban duration modal (NO ALERT YET)
async function showSuspendModal(action, userName, userId) {
    // Reuse existing modal structure
    const modal = document.getElementById('action-confirm-modal');
    const overlay = document.getElementById('action-confirm-modal-overlay');
    const title = document.getElementById('action-confirm-title');
    const message = document.getElementById('action-confirm-message');
    const confirmBtn = document.getElementById('confirm-action-btn');
    
    if (!modal || !overlay) {
        console.error('Modal not found');
        return null;
    }
    
    // Set modal title
    title.textContent = action === 'ban' ? 'Ban User Permanently' : 'Suspend User';
    
    // Build modal content with duration inputs
    let modalContent = `
        <div style="margin-bottom: 20px;">
            <label style="display: block; margin-bottom: 8px; font-weight: 600; color: #2c2236;">User:</label>
            <div style="padding: 10px; background: #f3f4f6; border-radius: 6px; color: #2c2236; font-weight: 500;">${userName}</div>
        </div>
    `;
    
    if (action === 'suspend') {
        modalContent += `
            <div style="margin-bottom: 20px;">
                <label style="display: block; margin-bottom: 8px; font-weight: 600; color: #2c2236;">Suspension Duration:</label>
                <div style="display: flex; gap: 12px;">
                    <input type="number" id="suspend-duration-value" min="1" max="52" value="2" style="width: 100px; padding: 8px; border: 1.5px solid #e0d7c6; border-radius: 6px; font-family: 'Montserrat', sans-serif;">
                    <select id="suspend-duration-unit" style="width: 150px; padding: 8px; border: 1.5px solid #e0d7c6; border-radius: 6px; font-family: 'Montserrat', sans-serif;">
                        <option value="weeks">Weeks</option>
                        <option value="months">Months</option>
                    </select>
                </div>
            </div>
        `;
    }
    
    modalContent += `
        <div style="margin-bottom: 20px;">
            <label style="display: block; margin-bottom: 8px; font-weight: 600; color: #2c2236;">Reason:</label>
            <textarea id="suspend-reason" rows="3" style="width: 100%; padding: 10px; border: 1.5px solid #e0d7c6; border-radius: 6px; font-family: 'Montserrat', sans-serif; resize: vertical;" placeholder="Enter reason for ${action}..." required></textarea>
        </div>
    `;
    
    message.innerHTML = modalContent;
    confirmBtn.textContent = 'Continue';
    
    // Show modal (NO ALERT)
    modal.classList.add('active');
    overlay.classList.add('show');
    
    // Wait for user to set duration and click continue
    return new Promise((resolve) => {
        const confirmHandler = () => {
            const reason = document.getElementById('suspend-reason').value;
            
            if (!reason.trim()) {
                alert('Please enter a reason for this action');
                return;
            }
            
            let durationValue = 2;
            let durationUnit = 'weeks';
            
            if (action === 'suspend') {
                durationValue = document.getElementById('suspend-duration-value').value;
                durationUnit = document.getElementById('suspend-duration-unit').value;
            }
            
            cleanup();
            resolve({
                user_id: userId,
                duration_value: durationValue,
                duration_unit: durationUnit,
                reason: reason
            });
        };
        
        const cancelHandler = () => {
            cleanup();
            resolve(null);
        };
        
        const cleanup = () => {
            modal.classList.remove('active');
            overlay.classList.remove('show');
            message.textContent = '';
            confirmBtn.removeEventListener('click', confirmHandler);
            document.getElementById('cancel-action-btn').removeEventListener('click', cancelHandler);
            overlay.removeEventListener('click', cancelHandler);
        };
        
        confirmBtn.addEventListener('click', confirmHandler);
        document.getElementById('cancel-action-btn').addEventListener('click', cancelHandler);
        overlay.addEventListener('click', cancelHandler);
    });
}

// Show action confirmation modal
async function showActionConfirmModal(action, userName) {
    const modal = document.getElementById('action-confirm-modal');
    const overlay = document.getElementById('action-confirm-modal-overlay');
    const title = document.getElementById('action-confirm-title');
    const message = document.getElementById('action-confirm-message');
    const confirmBtn = document.getElementById('confirm-action-btn');
    
    if (!modal || !overlay) {
        console.error('Action confirm modal not found');
        return false;
    }
    
    // Set modal content based on action
    let actionText = action.charAt(0).toUpperCase() + action.slice(1);
    title.textContent = `${actionText} User?`;
    message.textContent = `Are you sure you want to ${action} ${userName}?`;
    confirmBtn.textContent = actionText;
    
    // Show modal
    modal.classList.add('active');
    overlay.classList.add('show');
    
    // Wait for user confirmation
    return new Promise((resolve) => {
        const confirmHandler = () => {
            cleanup();
            resolve(true);
        };
        
        const cancelHandler = () => {
            cleanup();
            resolve(false);
        };
        
        const cleanup = () => {
            modal.classList.remove('active');
            overlay.classList.remove('show');
            confirmBtn.removeEventListener('click', confirmHandler);
            document.getElementById('cancel-action-btn').removeEventListener('click', cancelHandler);
            overlay.removeEventListener('click', cancelHandler);
        };
        
        confirmBtn.addEventListener('click', confirmHandler);
        document.getElementById('cancel-action-btn').addEventListener('click', cancelHandler);
        overlay.addEventListener('click', cancelHandler);
    });
}

// Show notification
function showNotification(message, type = 'info') {
    // Remove existing notifications
    const existingNotifications = document.querySelectorAll('.admin-notification');
    existingNotifications.forEach(notif => notif.remove());
    
    const notification = document.createElement('div');
    notification.className = 'admin-notification';
    
    const iconClass = type === 'success' ? 'bi-check-circle' : type === 'error' ? 'bi-x-circle' : 'bi-info-circle';
    const bgColor = type === 'success' ? '#ecfdf5' : type === 'error' ? '#fef2f2' : '#eff6ff';
    const textColor = type === 'success' ? '#059669' : type === 'error' ? '#dc2626' : '#2563eb';
    const borderColor = type === 'success' ? '#10b981' : type === 'error' ? '#f87171' : '#60a5fa';
    
    notification.innerHTML = `
        <i class="bi ${iconClass}"></i>
        <span>${message}</span>
    `;
    
    notification.style.cssText = `
        position: fixed;
        top: 100px;
        right: 30px;
        padding: 16px 24px;
        background: ${bgColor};
        color: ${textColor};
        border: 2px solid ${borderColor};
        border-radius: 8px;
        box-shadow: 0 4px 16px rgba(0,0,0,0.1);
        z-index: 10000;
        display: flex;
        align-items: center;
        gap: 12px;
        font-family: 'Montserrat', sans-serif;
        font-size: 0.95rem;
        font-weight: 600;
        opacity: 0;
        transform: translateX(400px);
        transition: all 0.3s ease;
    `;
    
    document.body.appendChild(notification);
    
    // Trigger animation
    setTimeout(() => {
        notification.style.opacity = '1';
        notification.style.transform = 'translateX(0)';
    }, 10);
    
    // Remove after 3 seconds
    setTimeout(() => {
        notification.style.opacity = '0';
        notification.style.transform = 'translateX(400px)';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// Show confirmation modal (like logout modal)
async function showConfirmationModal(message, action) {
    // Create modal if it doesn't exist
    let modal = document.getElementById('confirmation-modal');
    let overlay = document.getElementById('confirmation-modal-overlay');
    
    if (!modal) {
        const modalHTML = `
            <div id="confirmation-modal-overlay" style="position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0,0,0,0.18); z-index: 9998; display: none; backdrop-filter: blur(4px); -webkit-backdrop-filter: blur(4px);"></div>
            <div id="confirmation-modal" class="modal" style="display: none; position: fixed; z-index: 9999; left: 0; top: 0; width: 100vw; height: 100vh; align-items: center; justify-content: center;">
                <div class="modal-content" style="background: #fff; padding: 32px 28px 24px 28px; border-radius: 2px; box-shadow: 0 4px 24px rgba(0,0,0,0.13); min-width: 320px; max-width: 90vw; text-align: center;">
                    <div class="modal-title" id="confirmation-modal-title" style="font-size: 1.25rem; font-family: 'Playfair Display', serif; margin-bottom: 18px; color: #181818;"></div>
                    <div class="modal-actions" style="display: flex; gap: 18px; justify-content: center;">
                        <button id="confirm-action-modal-btn" class="modal-btn" style="border: none; border-radius: 2px; padding: 8px 24px; font-size: 1rem; cursor: pointer; background: #181818; color: #fff;">Confirm</button>
                        <button id="cancel-action-modal-btn" class="modal-btn" style="border: none; border-radius: 2px; padding: 8px 24px; font-size: 1rem; cursor: pointer; background: #e0d7c6; color: #181818;">Cancel</button>
                    </div>
                </div>
            </div>
        `;
        document.body.insertAdjacentHTML('beforeend', modalHTML);
        modal = document.getElementById('confirmation-modal');
        overlay = document.getElementById('confirmation-modal-overlay');
        
        // Add hover effects
        const confirmBtn = document.getElementById('confirm-action-modal-btn');
        const cancelBtn = document.getElementById('cancel-action-modal-btn');
        
        confirmBtn.addEventListener('mouseenter', () => { confirmBtn.style.background = '#D3BD9B'; confirmBtn.style.color = '#181818'; });
        confirmBtn.addEventListener('mouseleave', () => { confirmBtn.style.background = '#181818'; confirmBtn.style.color = '#fff'; });
        cancelBtn.addEventListener('mouseenter', () => { cancelBtn.style.background = '#D3BD9B'; cancelBtn.style.color = '#181818'; });
        cancelBtn.addEventListener('mouseleave', () => { cancelBtn.style.background = '#e0d7c6'; cancelBtn.style.color = '#181818'; });
    }
    
    // Set message
    document.getElementById('confirmation-modal-title').textContent = message;
    
    // Show modal
    modal.style.display = 'flex';
    overlay.style.display = 'block';
    
    // Wait for user response
    return new Promise((resolve) => {
        const confirmHandler = () => {
            cleanup();
            resolve(true);
        };
        
        const cancelHandler = () => {
            cleanup();
            resolve(false);
        };
        
        const cleanup = () => {
            modal.style.display = 'none';
            overlay.style.display = 'none';
            document.getElementById('confirm-action-modal-btn').removeEventListener('click', confirmHandler);
            document.getElementById('cancel-action-modal-btn').removeEventListener('click', cancelHandler);
            overlay.removeEventListener('click', cancelHandler);
        };
        
        document.getElementById('confirm-action-modal-btn').addEventListener('click', confirmHandler);
        document.getElementById('cancel-action-modal-btn').addEventListener('click', cancelHandler);
        overlay.addEventListener('click', cancelHandler);
    });
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
    // Setup image modal
    setupImageModal();
    
    // Fetch initial data
    fetchSellers();
    
    // Search functionality
    const sellerSearch = document.getElementById('sellerSearch');
    if (sellerSearch) {
        let searchTimeout;
        sellerSearch.addEventListener('input', function() {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => {
                currentFilters.search = this.value;
                fetchSellers();
            }, 500);
        });
    }

    // Status filter
    const statusFilter = document.getElementById('statusFilter');
    if (statusFilter) {
        statusFilter.addEventListener('change', function() {
            currentFilters.status = this.value;
            fetchSellers();
        });
    }
});
