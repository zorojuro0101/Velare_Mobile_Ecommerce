// Admin Rider Payouts JavaScript

document.addEventListener('DOMContentLoaded', function() {
    loadWithdrawalRequests();
    loadCommissionDeductions();
    setupDateRangeFilter();
});

// Setup date range filter
function setupDateRangeFilter() {
    const startDateInput = document.getElementById('startDate');
    const endDateInput = document.getElementById('endDate');
    
    // Set current values from URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    const startDate = urlParams.get('startDate');
    const endDate = urlParams.get('endDate');
    
    if (startDateInput && startDate) {
        startDateInput.value = startDate;
    }
    if (endDateInput && endDate) {
        endDateInput.value = endDate;
    }
    
    // Auto-reload when date changes
    if (startDateInput) {
        startDateInput.addEventListener('change', function() {
            applyDateFilter();
        });
    }
    
    if (endDateInput) {
        endDateInput.addEventListener('change', function() {
            applyDateFilter();
        });
    }
}

function applyDateFilter() {
    const startDate = document.getElementById('startDate')?.value;
    const endDate = document.getElementById('endDate')?.value;
    
    if (startDate && endDate) {
        window.location.href = `/admin/rider-payouts?startDate=${startDate}&endDate=${endDate}`;
    }
}

// Load pending withdrawal requests
function loadWithdrawalRequests() {
    fetch('/admin/rider-payouts/api/withdrawal-requests')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                displayWithdrawalRequests(data.requests);
            }
        })
        .catch(error => {
            console.error('Error loading withdrawal requests:', error);
        });
}

// Display withdrawal requests
function displayWithdrawalRequests(requests) {
    const tbody = document.getElementById('withdrawalRequestsBody');
    const emptyState = document.getElementById('emptyWithdrawalRequests');
    
    if (!tbody || !emptyState) return;
    
    if (requests.length === 0) {
        tbody.style.display = 'none';
        emptyState.style.display = 'flex';
    } else {
        tbody.style.display = '';
        emptyState.style.display = 'none';
        
        tbody.innerHTML = requests.map(req => `
            <tr data-withdrawal-id="${req.withdrawalId}">
                <td>
                    <div class="rider-info">
                        <div class="rider-name">${req.riderName}</div>
                        <div class="rider-email">${req.riderEmail}</div>
                    </div>
                </td>
                <td><strong>₱${req.amount.toFixed(2)}</strong></td>
                <td>${req.method}</td>
                <td>${formatDate(req.requestedAt)}</td>
                <td>${req.notes || '-'}</td>
                <td>
                    <div class="action-buttons">
                        <button class="approve-btn" onclick="approveWithdrawal(${req.withdrawalId})">
                            <i class="bi bi-check-circle"></i> Approve
                        </button>
                        <button class="reject-btn" onclick="rejectWithdrawal(${req.withdrawalId})">
                            <i class="bi bi-x-circle"></i> Reject
                        </button>
                    </div>
                </td>
            </tr>
        `).join('');
    }
}

// Approve withdrawal
function approveWithdrawal(withdrawalId) {
    fetch('/admin/rider-payouts/api/approve-withdrawal', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ withdrawalId: withdrawalId })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showNotification('Withdrawal approved successfully!', 'success');
            loadWithdrawalRequests(); // Reload the list
        } else {
            showNotification('Error: ' + data.error, 'error');
        }
    })
    .catch(error => {
        console.error('Error approving withdrawal:', error);
        showNotification('Failed to approve withdrawal', 'error');
    });
}

// Reject withdrawal
function rejectWithdrawal(withdrawalId) {
    fetch('/admin/rider-payouts/api/reject-withdrawal', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ 
            withdrawalId: withdrawalId,
            reason: ''
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showNotification('Withdrawal rejected', 'info');
            loadWithdrawalRequests(); // Reload the list
        } else {
            showNotification('Error: ' + data.error, 'error');
        }
    })
    .catch(error => {
        console.error('Error rejecting withdrawal:', error);
        showNotification('Failed to reject withdrawal', 'error');
    });
}

// Load commission deductions
function loadCommissionDeductions() {
    fetch('/admin/rider-payouts/api/commission-deductions')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                displayCommissionDeductions(data.deductions, data.totalDeducted);
            }
        })
        .catch(error => {
            console.error('Error loading commission deductions:', error);
        });
}

// Display commission deductions
function displayCommissionDeductions(deductions, totalDeducted) {
    const tbody = document.getElementById('commissionDeductionsBody');
    const emptyState = document.getElementById('emptyCommissionDeductions');
    const totalElement = document.getElementById('totalDeducted');
    
    if (!tbody || !emptyState) return;
    
    // Update total
    if (totalElement) {
        totalElement.textContent = `₱${totalDeducted.toFixed(2)}`;
    }
    
    if (deductions.length === 0) {
        tbody.style.display = 'none';
        emptyState.style.display = 'flex';
    } else {
        tbody.style.display = '';
        emptyState.style.display = 'none';
        
        tbody.innerHTML = deductions.map(ded => `
            <tr>
                <td>${ded.orderNumber}</td>
                <td>${ded.riderName}</td>
                <td>${ded.buyerName}</td>
                <td><strong>₱${ded.amount.toFixed(2)}</strong></td>
                <td>₱${ded.commission.toFixed(2)}</td>
                <td>${formatDate(ded.deliveredAt)}</td>
            </tr>
        `).join('');
    }
}

// Format date
function formatDate(dateString) {
    const date = new Date(dateString);
    const options = { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' };
    return date.toLocaleDateString('en-US', options);
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
    
    notification.style.cssText = `
        position: fixed;
        top: 100px;
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
        font-family: 'Montserrat', sans-serif;
        font-size: 0.95rem;
        font-weight: 600;
        animation: slideIn 0.3s ease;
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 3000);
}

// Add CSS animations
const style = document.createElement('style');
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
