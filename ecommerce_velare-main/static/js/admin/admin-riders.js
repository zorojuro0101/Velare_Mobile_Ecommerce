// Admin Riders Management JavaScript

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

// Fetch riders from backend
async function fetchRiders() {
    try {
        const params = new URLSearchParams({
            status: currentFilters.status,
            search: currentFilters.search
        });

        const response = await fetch(`/api/admin/riders?${params}`);
        const data = await response.json();

        if (data.success) {
            displayRiders(data.riders);
            updateCounts(data.counts);
        } else {
            console.error('Failed to fetch riders:', data.message);
        }
    } catch (error) {
        console.error('Error fetching riders:', error);
    }
}

// Display riders in cards
function displayRiders(riders) {
    const grid = document.getElementById('ridersGrid');
    
    if (!riders || riders.length === 0) {
        grid.innerHTML = '<div style="grid-column: 1/-1; text-align:center; padding:40px; color:#666;">No riders found</div>';
        return;
    }

    grid.innerHTML = riders.map(rider => createRiderCard(rider)).join('');
    setupActionButtons();
}

// Create rider card
function createRiderCard(rider) {
    // Debug logging
    console.log('Creating card for rider:', rider.first_name, rider.last_name);
    console.log('ORCR Path:', rider.orcr_file_path);
    console.log('Driver License Path:', rider.driver_license_file_path);
    console.log('Profile Image:', rider.profile_image);
    
    const initials = `${rider.first_name?.[0] || '?'}${rider.last_name?.[0] || '?'}`.toUpperCase();
    const joinDate = new Date(rider.created_at).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
    
    const statusClass = (rider.status || 'pending').toLowerCase();
    const statusLabel = (rider.status || 'Pending').charAt(0).toUpperCase() + (rider.status || 'pending').slice(1);
    
    return `
        <div class="approval-card" data-rider-id="${rider.account_id}" data-status="${rider.status || 'pending'}">
            <div class="card-body">
                <div class="product-image-section">
                    <div class="main-product-image clickable-image" ${rider.orcr_file_path ? `onclick="showImageModal('${rider.orcr_file_path}')"` : ''} style="${rider.orcr_file_path ? 'cursor: pointer;' : ''}">
                        ${rider.orcr_file_path ? 
                            `<img src="${rider.orcr_file_path}" alt="ORCR Document" onerror="console.error('Failed to load image:', this.src); this.parentElement.innerHTML='<div class=\\'id-placeholder\\'><i class=\\'bi bi-card-text\\'></i><p>Image Load Failed</p></div>';">` :
                            `<div class="id-placeholder"><i class="bi bi-card-text"></i><p>No ORCR Uploaded</p></div>`
                        }
                    </div>
                    <div style="display: block !important; visibility: visible !important; opacity: 1 !important; color: #000000 !important; font-weight: 600 !important; padding: 8px 0 !important; margin: 8px 0 0 0 !important; width: 200px !important; box-sizing: border-box !important; text-align: center !important; font-family: 'Montserrat', sans-serif !important; font-size: 0.8rem !important; text-transform: uppercase !important; letter-spacing: 0.5px !important;">
                        ORCR
                    </div>
                </div>
                
                <div class="product-details-section">
                    <div class="buyer-name-header">
                        ${rider.profile_image ? 
                            `<div class="small-avatar" style="background: none; border: 2px solid rgba(211, 189, 155, 0.3); padding: 0; overflow: hidden;">
                                <img src="${rider.profile_image.startsWith('http://') || rider.profile_image.startsWith('https://') ? rider.profile_image : (rider.profile_image.startsWith('/') ? rider.profile_image : '/static/' + rider.profile_image)}" alt="Profile" style="width: 100%; height: 100%; object-fit: cover;" onerror="console.error('Failed to load profile:', this.src); this.parentElement.innerHTML='<div style=\\'width:100%;height:100%;display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,#d3bd9b 0%,#c4a882 100%);color:#fff;font-family:Playfair Display,serif;font-size:1.1rem;font-weight:700;\\'>${initials}</div>';">
                            </div>` :
                            `<div class="small-avatar">${initials}</div>`
                        }
                        <h3 class="product-name">${rider.first_name} ${rider.last_name}</h3>
                        <span class="status-badge ${statusClass}">${statusLabel}</span>
                        ${rider.report_count && rider.report_count > 0 ? `
                            <span class="report-count-badge" style="background: ${rider.report_count >= 3 ? '#dc3545' : rider.report_count >= 2 ? '#ff6b6b' : '#ffa500'} !important; color: white !important; padding: 4px 10px !important; border-radius: 2px !important; border: 2px solid ${rider.report_count >= 3 ? '#b02a37' : rider.report_count >= 2 ? '#e85555' : '#e69500'} !important; font-size: 0.75rem !important; font-weight: 600 !important; margin-left: 8px !important;">
                                <i class="bi bi-flag-fill"></i> ${rider.report_count} Report${rider.report_count > 1 ? 's' : ''}
                            </span>
                        ` : ''}
                    </div>
                    
                    <div class="product-info-grid">
                        <div class="info-item">
                            <label>Email:</label>
                            <span>${rider.email}</span>
                        </div>
                        <div class="info-item">
                            <label>Phone:</label>
                            <span>${rider.phone_number || 'N/A'}</span>
                        </div>
                        <div class="info-item">
                            <label>Vehicle Type:</label>
                            <span>${rider.vehicle_type || 'N/A'}</span>
                        </div>
                        <div class="info-item">
                            <label>Plate Number:</label>
                            <span>${rider.plate_number || 'N/A'}</span>
                        </div>
                        <div class="info-item">
                            <label>Address:</label>
                            <span>${rider.full_address || 'N/A'}</span>
                        </div>
                        <div class="info-item">
                            <label>Driver License:</label>
                            <span>
                                ${rider.driver_license_file_path ? 
                                    `<a onclick="showImageModal('${rider.driver_license_file_path}')" style="color: #D3BD9B; text-decoration: underline; cursor: pointer;">View Document</a>` :
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
                ${rider.status === 'pending' ? `
                    <button class="btn btn-approve" data-action="approve">
                        <i class="bi bi-check-circle"></i>
                        Approve
                    </button>
                    <button class="btn btn-reject" data-action="reject">
                        <i class="bi bi-x-circle"></i>
                        Reject
                    </button>
                ` : rider.status === 'active' ? `
                    <button class="btn btn-reject" data-action="suspend">
                        <i class="bi bi-pause-circle"></i>
                        Suspend
                    </button>
                    <button class="btn btn-reject" data-action="ban">
                        <i class="bi bi-slash-circle"></i>
                        Ban
                    </button>
                ` : rider.status === 'suspended' ? `
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
            badgeIcon = 'bi-bicycle';
            badgeLabel = 'Total Riders';
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
            const riderId = card.dataset.riderId;
            const riderName = card.querySelector('.product-name').textContent;
            
            // Show confirmation modal
            const confirmed = await showActionConfirmModal(action, riderName);
            if (!confirmed) {
                return;
            }
            
            try {
                const response = await fetch(`/api/admin/riders/${riderId}/${action}`, {
                    method: 'POST'
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showNotification(data.message || `Rider ${action}ed successfully`, 'success');
                    fetchRiders();
                } else {
                    showNotification(data.message || `Failed to ${action} rider`, 'error');
                }
            } catch (error) {
                console.error('Error:', error);
                showNotification(`An error occurred while trying to ${action} the rider`, 'error');
            }
        });
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

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
    // Setup image modal
    setupImageModal();
    
    // Fetch initial data
    fetchRiders();
    
    // Search functionality
    const riderSearch = document.getElementById('riderSearch');
    if (riderSearch) {
        let searchTimeout;
        riderSearch.addEventListener('input', function() {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => {
                currentFilters.search = this.value;
                fetchRiders();
            }, 500);
        });
    }

    // Status filter
    const statusFilter = document.getElementById('statusFilter');
    if (statusFilter) {
        statusFilter.addEventListener('change', function() {
            currentFilters.status = this.value;
            fetchRiders();
        });
    }
});
