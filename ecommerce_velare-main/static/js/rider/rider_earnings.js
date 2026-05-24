// Rider Earnings JavaScript

document.addEventListener('DOMContentLoaded', function() {
    initializeEarnings();
    setupEventListeners();
});

// Initialize earnings page
function initializeEarnings() {
    loadEarningsData();
    loadAvailableBalance();
    loadWithdrawalHistory();
}

// Setup event listeners
function setupEventListeners() {
    // Date range inputs
    const startDate = document.getElementById('startDate');
    const endDate = document.getElementById('endDate');
    
    if (startDate) {
        startDate.addEventListener('change', handleDateRangeChange);
    }
    if (endDate) {
        endDate.addEventListener('change', handleDateRangeChange);
    }

    // Refresh button
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', refreshEarnings);
    }

    // Withdrawal button
    const withdrawBtn = document.getElementById('withdrawBtn');
    if (withdrawBtn) {
        withdrawBtn.addEventListener('click', handleWithdrawClick);
    }

    // Withdrawal modal buttons
    const withdrawalForm = document.getElementById('withdrawalForm');
    const closeModalBtn = document.getElementById('closeWithdrawalModal');
    const cancelWithdrawalBtn = document.getElementById('cancelWithdrawalBtn');
    const withdrawalOverlay = document.getElementById('withdrawal-modal-overlay');
    
    if (withdrawalForm) {
        withdrawalForm.addEventListener('submit', handleWithdrawalSubmit);
    }
    if (closeModalBtn) {
        closeModalBtn.addEventListener('click', closeWithdrawalModal);
    }
    if (cancelWithdrawalBtn) {
        cancelWithdrawalBtn.addEventListener('click', closeWithdrawalModal);
    }
    if (withdrawalOverlay) {
        withdrawalOverlay.addEventListener('click', closeWithdrawalModal);
    }

    // Amount input validation
    const amountInput = document.getElementById('withdrawalAmount');
    if (amountInput) {
        amountInput.addEventListener('input', validateWithdrawalAmount);
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

// Load earnings data
function loadEarningsData(startDate = null, endDate = null) {
    console.log('=== Loading earnings with date range:', startDate, endDate);
    
    // Build query parameters
    let url = '/rider/earnings/api/earnings-data';
    if (startDate && endDate) {
        url += `?startDate=${startDate}&endDate=${endDate}`;
    }
    
    // Fetch data from server
    fetch(url)
        .then(response => {
            console.log('Response status:', response.status);
            return response.json();
        })
        .then(data => {
            console.log('Earnings data received:', data);
            
            if (data.success) {
                console.log('Number of earnings:', data.earnings.length);
                console.log('Total earnings:', data.totalEarnings);
                displayEarnings(data.earnings);
                updateTotalEarnings(data.earnings, data.totalEarnings);
            } else {
                console.error('Error loading earnings:', data.error);
                console.error('Error details:', data.details);
                alert('Error loading earnings: ' + data.error + '\n\nCheck Flask console for details.');
                displayEarnings([]);
                updateTotalEarnings([], 0);
            }
        })
        .catch(error => {
            console.error('Error fetching earnings data:', error);
            console.error('Error type:', error.name);
            console.error('Error message:', error.message);
            alert('Failed to load earnings.\n\nError: ' + error.message + '\n\nMake sure Flask server is running on http://127.0.0.1:5000');
            displayEarnings([]);
            updateTotalEarnings([], 0);
        });
}

// Filter earnings by date
function filterEarningsByDate(earnings, filter) {
    const today = new Date('2025-10-02'); // Using the current date from context
    
    switch(filter) {
        case 'today':
            return earnings.filter(e => {
                const deliveryDate = new Date(e.buyer.deliveryDate);
                return deliveryDate.toDateString() === today.toDateString();
            });
        
        case 'week':
            const weekAgo = new Date(today);
            weekAgo.setDate(today.getDate() - 7);
            return earnings.filter(e => {
                const deliveryDate = new Date(e.buyer.deliveryDate);
                return deliveryDate >= weekAgo && deliveryDate <= today;
            });
        
        case 'month':
            const monthAgo = new Date(today);
            monthAgo.setMonth(today.getMonth() - 1);
            return earnings.filter(e => {
                const deliveryDate = new Date(e.buyer.deliveryDate);
                return deliveryDate >= monthAgo && deliveryDate <= today;
            });
        
        case 'all':
        default:
            return earnings;
    }
}

// Display earnings in table
function displayEarnings(earnings) {
    const tableBody = document.getElementById('earningsTableBody');
    const emptyState = document.getElementById('emptyState');
    const table = document.querySelector('.earnings-table');
    
    if (!tableBody || !emptyState || !table) return;
    
    // Always show table headers
    table.style.display = 'table';
    
    if (earnings.length === 0) {
        // Clear table body and show empty state
        tableBody.innerHTML = '';
        emptyState.classList.add('show');
    } else {
        // Show table with data and hide empty state
        emptyState.classList.remove('show');
        tableBody.innerHTML = earnings.map(earning => createEarningRow(earning)).join('');
    }
}

// Create earning row HTML
function createEarningRow(earning) {
    return `
        <tr>
            <td>
                <span class="order-id">${earning.orderId}</span>
            </td>
            <td>
                <div class="buyer-info">
                    <div class="info-row">
                        <span class="info-label">Name:</span>
                        <span class="info-value">${earning.buyer.name}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Address:</span>
                        <span class="info-value">${earning.buyer.address}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Date:</span>
                        <span class="info-value">${formatDate(earning.buyer.deliveryDate)}</span>
                    </div>
                </div>
            </td>
            <td>
                <div class="seller-info">
                    <div class="info-row">
                        <span class="info-label">Seller:</span>
                        <span class="info-value">${earning.seller.name}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Store:</span>
                        <span class="info-value">${earning.seller.storeName}</span>
                    </div>
                </div>
            </td>
            <td>
                <span class="product-name">${earning.productName}</span>
            </td>
            <td>
                <div class="amount-cell">
                    <span class="amount-plus">+</span>
                    <span class="amount-value">₱${earning.amount.toFixed(2)}</span>
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

// Update total earnings
function updateTotalEarnings(earnings, totalEarnings = null) {
    const totalEarningsElement = document.getElementById('totalEarnings');
    
    if (!totalEarningsElement) return;
    
    // Use provided totalEarnings or calculate from earnings array
    const total = totalEarnings !== null ? totalEarnings : earnings.reduce((sum, earning) => sum + earning.amount, 0);
    totalEarningsElement.textContent = `₱${total.toFixed(2)}`;
}

// Handle date range change
function handleDateRangeChange() {
    const startDate = document.getElementById('startDate')?.value;
    const endDate = document.getElementById('endDate')?.value;
    
    if (startDate && endDate) {
        console.log('Date range changed:', startDate, 'to', endDate);
        loadEarningsData(startDate, endDate);
    }
}

// Refresh earnings
function refreshEarnings() {
    console.log('Refreshing earnings...');
    const startDate = document.getElementById('startDate')?.value;
    const endDate = document.getElementById('endDate')?.value;
    loadEarningsData(startDate, endDate);
    
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
    
    // Handle specific sub-navigation for items without href
    switch(tab) {
        case 'list-pickup':
            window.location.href = '/rider/pickup';
            break;
        case 'active-delivery':
            window.location.href = '/rider/active-delivery';
            break;
        default:
            console.log('Unknown sub-tab:', tab);
    }
}

// Handle logout
function handleLogout() {
    // Logout is now handled by logout-modal.js
}

// Load available balance
function loadAvailableBalance() {
    fetch('/rider/earnings/api/available-balance')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                const balanceElement = document.getElementById('availableBalance');
                if (balanceElement) {
                    balanceElement.textContent = `₱${data.availableBalance.toFixed(2)}`;
                }
                
                // Store pending status for withdrawal button
                window.riderBalanceData = {
                    availableBalance: data.availableBalance,
                    hasPending: data.hasPending,
                    pendingAmount: data.pendingAmount
                };
            }
        })
        .catch(error => {
            console.error('Error loading available balance:', error);
        });
}

// Load withdrawal history
function loadWithdrawalHistory() {
    fetch('/rider/earnings/api/withdrawal-history')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                displayWithdrawalHistory(data.withdrawals);
            }
        })
        .catch(error => {
            console.error('Error loading withdrawal history:', error);
        });
}

// Display withdrawal history
function displayWithdrawalHistory(withdrawals) {
    const tableBody = document.getElementById('withdrawalHistoryBody');
    const emptyState = document.getElementById('emptyWithdrawalState');
    const table = document.querySelector('.withdrawal-table');
    
    if (!tableBody || !emptyState || !table) return;
    
    table.style.display = 'table';
    
    if (withdrawals.length === 0) {
        tableBody.innerHTML = '';
        emptyState.classList.add('show');
    } else {
        emptyState.classList.remove('show');
        tableBody.innerHTML = withdrawals.map(withdrawal => `
            <tr>
                <td>${formatDate(withdrawal.requestedAt)}</td>
                <td>₱${withdrawal.amount.toFixed(2)}</td>
                <td>
                    <span class="status-badge status-${withdrawal.status.toLowerCase()}">
                        ${withdrawal.status.charAt(0).toUpperCase() + withdrawal.status.slice(1)}
                    </span>
                </td>
                <td>${withdrawal.processedAt ? formatDate(withdrawal.processedAt) : '-'}</td>
            </tr>
        `).join('');
    }
}

// Handle withdraw button click
function handleWithdrawClick() {
    // Check if there's a pending withdrawal
    if (window.riderBalanceData && window.riderBalanceData.hasPending) {
        showWithdrawConfirmModal(
            'Pending Withdrawal',
            'You already have a pending withdrawal request.\n\nPending Amount: ₱' + window.riderBalanceData.pendingAmount.toFixed(2) + '\n\nPlease wait for it to be processed before submitting a new request.',
            null
        );
        return;
    }
    
    // Get current available balance
    const balanceElement = document.getElementById('availableBalance');
    const balanceText = balanceElement ? balanceElement.textContent : '₱0.00';
    const balance = parseFloat(balanceText.replace('₱', '').replace(',', ''));
    
    // Check if balance is valid
    if (balance <= 0) {
        showWithdrawConfirmModal(
            'Insufficient Balance',
            'Your current available balance: ' + balanceText,
            null
        );
        return;
    }
    
    // Check minimum withdrawal amount
    if (balance < 100) {
        showWithdrawConfirmModal(
            'Minimum Amount Required',
            'Minimum withdrawal amount is ₱100.00\n\nYour current available balance: ' + balanceText,
            null
        );
        return;
    }
    
    // Update modal balance display
    const modalBalance = document.getElementById('modalAvailableBalance');
    if (modalBalance) {
        modalBalance.textContent = balanceText;
    }
    
    // Set max attribute on amount input
    const amountInput = document.getElementById('withdrawalAmount');
    if (amountInput) {
        amountInput.setAttribute('max', balance);
        amountInput.value = ''; // Clear previous value
    }
    
    // Reset form
    const form = document.getElementById('withdrawalForm');
    if (form) {
        form.reset();
    }
    
    openWithdrawalModal();
}

// Open withdrawal modal
function openWithdrawalModal() {
    const modal = document.getElementById('withdrawal-modal');
    const overlay = document.getElementById('withdrawal-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.add('show');
        overlay.classList.add('show');
        document.body.style.overflow = 'hidden'; // Prevent background scroll
    }
}

// Close withdrawal modal
function closeWithdrawalModal() {
    const modal = document.getElementById('withdrawal-modal');
    const overlay = document.getElementById('withdrawal-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.remove('show');
        overlay.classList.remove('show');
        document.body.style.overflow = ''; // Restore scroll
    }
    
    // Reset form
    const form = document.getElementById('withdrawalForm');
    if (form) {
        form.reset();
    }
}

// Validate withdrawal amount
function validateWithdrawalAmount(e) {
    const input = e.target;
    const value = parseFloat(input.value);
    const max = parseFloat(input.getAttribute('max'));
    const min = parseFloat(input.getAttribute('min'));
    
    // Remove any existing error message
    let errorMsg = input.parentElement.querySelector('.error-message');
    if (errorMsg) {
        errorMsg.remove();
    }
    
    // Validate
    if (value < min) {
        showInputError(input, `Minimum withdrawal is ₱${min.toFixed(2)}`);
    } else if (value > max) {
        showInputError(input, `Maximum withdrawal is ₱${max.toFixed(2)}`);
        input.value = max;
    }
}

// Show input error
function showInputError(input, message) {
    let errorMsg = input.parentElement.querySelector('.error-message');
    if (!errorMsg) {
        errorMsg = document.createElement('small');
        errorMsg.className = 'error-message';
        input.parentElement.appendChild(errorMsg);
    }
    errorMsg.textContent = message;
}

// Handle withdrawal form submit
function handleWithdrawalSubmit(e) {
    e.preventDefault();
    
    const form = e.target;
    const formData = new FormData(form);
    
    const amount = parseFloat(formData.get('amount'));
    const method = formData.get('method');
    const notes = formData.get('notes');
    
    // Get available balance
    const balanceElement = document.getElementById('availableBalance');
    const balanceText = balanceElement ? balanceElement.textContent : '₱0.00';
    const availableBalance = parseFloat(balanceText.replace('₱', '').replace(',', ''));
    
    // Final validation
    if (isNaN(amount) || amount <= 0) {
        showWithdrawConfirmModal('Invalid Amount', 'Please enter a valid amount', null);
        return;
    }
    
    if (amount < 100) {
        showWithdrawConfirmModal('Minimum Amount Required', 'Minimum withdrawal amount is ₱100.00', null);
        return;
    }
    
    if (amount > availableBalance) {
        showWithdrawConfirmModal(
            'Insufficient Balance',
            `Requested: ₱${amount.toFixed(2)}\nAvailable: ₱${availableBalance.toFixed(2)}`,
            null
        );
        return;
    }
    
    // Check if withdrawal would result in negative balance
    if (availableBalance - amount < 0) {
        showWithdrawConfirmModal(
            'Invalid Withdrawal',
            'This withdrawal would result in a negative balance.\n\nPlease check your available balance.',
            null
        );
        return;
    }
    
    // Disable submit button
    const submitBtn = form.querySelector('button[type="submit"]');
    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="bi bi-hourglass-split"></i> Processing...';
    }
    
    // Send withdrawal request
    fetch('/rider/earnings/api/withdraw', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ 
            amount: amount,
            method: method,
            notes: notes
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showNotification('Withdrawal request submitted successfully! Amount: ₱' + amount.toFixed(2), 'success');
            closeWithdrawalModal();
            // Reload data
            loadAvailableBalance();
            loadWithdrawalHistory();
        } else {
            showNotification(data.error, 'error');
        }
    })
    .catch(error => {
        console.error('Error submitting withdrawal:', error);
        showNotification('Failed to submit withdrawal request', 'error');
    })
    .finally(() => {
        // Re-enable submit button
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<i class="bi bi-check-circle"></i> Submit Request';
        }
    });
}

// Notification function
function showNotification(message, type = 'success') {
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
        border: 1.5px solid ${type === 'success' ? '#10b981' : type === 'error' ? '#f87171' : '#60a5fa'};
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

// Show withdrawal confirmation modal (logout style)
function showWithdrawConfirmModal(title, message, onConfirm) {
    const modal = document.getElementById('withdraw-confirm-modal');
    const overlay = document.getElementById('withdraw-confirm-modal-overlay');
    const titleElement = document.getElementById('withdrawConfirmTitle');
    const messageElement = document.getElementById('withdrawConfirmMessage');
    const confirmBtn = document.getElementById('confirm-withdraw');
    const cancelBtn = document.getElementById('cancel-withdraw');
    
    if (!modal || !overlay) return;
    
    // Set title and message
    if (titleElement) titleElement.textContent = title;
    if (messageElement) messageElement.textContent = message;
    
    // Show/hide confirm button based on whether there's a callback
    if (confirmBtn) {
        if (onConfirm) {
            confirmBtn.style.display = 'inline-block';
            // Remove old listeners
            const newConfirmBtn = confirmBtn.cloneNode(true);
            confirmBtn.parentNode.replaceChild(newConfirmBtn, confirmBtn);
            // Add new listener
            newConfirmBtn.addEventListener('click', () => {
                closeWithdrawConfirmModal();
                onConfirm();
            });
        } else {
            confirmBtn.style.display = 'none';
        }
    }
    
    // Cancel button closes modal
    if (cancelBtn) {
        const newCancelBtn = cancelBtn.cloneNode(true);
        cancelBtn.parentNode.replaceChild(newCancelBtn, cancelBtn);
        newCancelBtn.addEventListener('click', closeWithdrawConfirmModal);
        // If no confirm button, change text to "OK"
        if (!onConfirm) {
            newCancelBtn.textContent = 'OK';
        } else {
            newCancelBtn.textContent = 'Cancel';
        }
    }
    
    // Show modal
    modal.classList.add('active');
    overlay.classList.add('show');
    document.body.style.overflow = 'hidden';
}

// Close withdrawal confirmation modal
function closeWithdrawConfirmModal() {
    const modal = document.getElementById('withdraw-confirm-modal');
    const overlay = document.getElementById('withdraw-confirm-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.remove('active');
        overlay.classList.remove('show');
        document.body.style.overflow = '';
    }
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes spin {
        from { transform: rotate(0deg); }
        to { transform: rotate(360deg); }
    }
    
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
