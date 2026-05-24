// Seller Select Vouchers JavaScript

// Notification function (same as admin)
function showNotification(message, type = 'success') {
    const existingNotifications = document.querySelectorAll('.notification');
    existingNotifications.forEach(notif => {
        notif.style.animation = 'slideOut 0.2s ease';
        setTimeout(() => {
            notif.remove();
        }, 200);
    });
    
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

    if (!document.getElementById('notification-styles')) {
        const style = document.createElement('style');
        style.id = 'notification-styles';
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
    }

    document.body.appendChild(notification);

    setTimeout(() => {
        notification.style.animation = 'slideOut 0.2s ease';
        setTimeout(() => {
            notification.remove();
        }, 200);
    }, 3000);
}

document.addEventListener('DOMContentLoaded', function() {
    // Select Voucher Modal Elements
    const selectModal = document.getElementById('select-voucher-modal');
    const selectModalOverlay = document.getElementById('select-voucher-modal-overlay');
    const confirmSelectBtn = document.getElementById('confirm-select-voucher');
    const cancelSelectBtn = document.getElementById('cancel-select-voucher');
    const selectVoucherNameSpan = document.getElementById('select-voucher-name');
    
    // Remove Voucher Modal Elements
    const removeModal = document.getElementById('remove-voucher-modal');
    const removeModalOverlay = document.getElementById('remove-voucher-modal-overlay');
    const confirmRemoveBtn = document.getElementById('confirm-remove-voucher');
    const cancelRemoveBtn = document.getElementById('cancel-remove-voucher');
    const removeVoucherNameSpan = document.getElementById('remove-voucher-name');
    
    let currentVoucherId = null;

    // Show/Hide Select Modal
    function showSelectModal() {
        if (selectModal) selectModal.style.display = 'flex';
        if (selectModalOverlay) selectModalOverlay.classList.add('show');
    }

    function hideSelectModal() {
        if (selectModal) selectModal.style.display = 'none';
        if (selectModalOverlay) selectModalOverlay.classList.remove('show');
    }

    // Show/Hide Remove Modal
    function showRemoveModal() {
        if (removeModal) removeModal.style.display = 'flex';
        if (removeModalOverlay) removeModalOverlay.classList.add('show');
    }

    function hideRemoveModal() {
        if (removeModal) removeModal.style.display = 'none';
        if (removeModalOverlay) removeModalOverlay.classList.remove('show');
    }

    // Handle voucher selection
    const selectButtons = document.querySelectorAll('.select-voucher-btn');
    selectButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            e.preventDefault();
            currentVoucherId = this.dataset.voucherId;
            const voucherCode = this.dataset.voucherCode;
            if (selectVoucherNameSpan) {
                selectVoucherNameSpan.textContent = voucherCode;
            }
            showSelectModal();
        });
    });

    // Cancel select
    if (cancelSelectBtn) {
        cancelSelectBtn.addEventListener('click', function() {
            hideSelectModal();
            currentVoucherId = null;
        });
    }

    // Close modal on outside click
    if (selectModal) {
        selectModal.addEventListener('click', function(e) {
            if (e.target === selectModal) {
                hideSelectModal();
                currentVoucherId = null;
            }
        });
    }
    
    if (selectModalOverlay) {
        selectModalOverlay.addEventListener('click', function() {
            hideSelectModal();
            currentVoucherId = null;
        });
    }

    // Confirm select
    if (confirmSelectBtn) {
        confirmSelectBtn.addEventListener('click', async function() {
            if (!currentVoucherId) return;

            const voucherIdToSelect = currentVoucherId;
            hideSelectModal();
            currentVoucherId = null;

            try {
                const response = await fetch('/seller/vouchers/select', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ voucher_id: voucherIdToSelect })
                });

                const result = await response.json();

                if (result.success) {
                    showNotification(result.message, 'success');
                    setTimeout(() => {
                        window.location.reload();
                    }, 1000);
                } else {
                    showNotification('Error: ' + result.message, 'error');
                }
            } catch (error) {
                console.error('Error selecting voucher:', error);
                showNotification('An error occurred while selecting the voucher', 'error');
            }
        });
    }

    // Handle voucher removal
    const removeButtons = document.querySelectorAll('.remove-voucher-btn');
    removeButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            e.preventDefault();
            currentVoucherId = this.dataset.voucherId;
            const voucherCode = this.dataset.voucherCode;
            if (removeVoucherNameSpan) {
                removeVoucherNameSpan.textContent = voucherCode;
            }
            showRemoveModal();
        });
    });

    // Cancel remove
    if (cancelRemoveBtn) {
        cancelRemoveBtn.addEventListener('click', function() {
            hideRemoveModal();
            currentVoucherId = null;
        });
    }

    // Close modal on outside click
    if (removeModal) {
        removeModal.addEventListener('click', function(e) {
            if (e.target === removeModal) {
                hideRemoveModal();
                currentVoucherId = null;
            }
        });
    }
    
    if (removeModalOverlay) {
        removeModalOverlay.addEventListener('click', function() {
            hideRemoveModal();
            currentVoucherId = null;
        });
    }

    // Confirm remove
    if (confirmRemoveBtn) {
        confirmRemoveBtn.addEventListener('click', async function() {
            if (!currentVoucherId) return;

            const voucherIdToRemove = currentVoucherId;
            hideRemoveModal();
            currentVoucherId = null;

            try {
                const response = await fetch('/seller/vouchers/remove', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ voucher_id: voucherIdToRemove })
                });

                const result = await response.json();

                if (result.success) {
                    showNotification(result.message, 'success');
                    setTimeout(() => {
                        window.location.reload();
                    }, 1000);
                } else {
                    showNotification('Error: ' + result.message, 'error');
                }
            } catch (error) {
                console.error('Error removing voucher:', error);
                showNotification('An error occurred while removing the voucher', 'error');
            }
        });
    }
});
