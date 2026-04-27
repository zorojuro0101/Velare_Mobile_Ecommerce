// Admin Vouchers Management JavaScript

// Notification function
function showNotification(message, type = 'success') {
    // Remove any existing notifications first
    const existingNotifications = document.querySelectorAll('.notification');
    existingNotifications.forEach(notif => {
        notif.style.animation = 'slideOut 0.2s ease';
        setTimeout(() => {
            notif.remove();
        }, 200);
    });
    
    // Create notification element
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

    // Add animation keyframes if not already added
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

    // Remove after 3 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.2s ease';
        setTimeout(() => {
            notification.remove();
        }, 200);
    }, 3000);
}

document.addEventListener('DOMContentLoaded', function() {
    const createVoucherBtn = document.getElementById('createVoucherBtn');
    const createVoucherModal = document.getElementById('createVoucherModal');
    const closeModalBtn = document.getElementById('closeModalBtn');
    const cancelBtn = document.getElementById('cancelBtn');
    const createVoucherForm = document.getElementById('createVoucherForm');

    // Open modal
    if (createVoucherBtn) {
        createVoucherBtn.addEventListener('click', function() {
            createVoucherModal.style.display = 'flex';
            // Set minimum date to today
            const today = new Date().toISOString().split('T')[0];
            document.getElementById('startDate').setAttribute('min', today);
            document.getElementById('endDate').setAttribute('min', today);
        });
    }

    // Close modal
    function closeModal() {
        createVoucherModal.style.display = 'none';
        createVoucherForm.reset();
    }

    if (closeModalBtn) {
        closeModalBtn.addEventListener('click', closeModal);
    }

    if (cancelBtn) {
        cancelBtn.addEventListener('click', closeModal);
    }

    // Close modal when clicking outside
    createVoucherModal.addEventListener('click', function(e) {
        if (e.target === createVoucherModal) {
            closeModal();
        }
    });

    // Handle form submission
    if (createVoucherForm) {
        createVoucherForm.addEventListener('submit', async function(e) {
            e.preventDefault();

            const formData = {
                voucher_type: document.getElementById('voucherType').value,
                voucher_percent: document.getElementById('voucherPercent').value,
                start_date: document.getElementById('startDate').value,
                end_date: document.getElementById('endDate').value
            };

            // Validate dates
            const startDate = new Date(formData.start_date);
            const endDate = new Date(formData.end_date);
            if (endDate < startDate) {
                showNotification('End date must be after start date', 'error');
                return;
            }

            try {
                const response = await fetch('/admin/vouchers/create', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(formData)
                });

                const result = await response.json();

                if (result.success) {
                    showNotification('Voucher created successfully!', 'success');
                    setTimeout(() => {
                        window.location.reload();
                    }, 1000);
                } else {
                    showNotification('Error: ' + result.message, 'error');
                }
            } catch (error) {
                console.error('Error creating voucher:', error);
                showNotification('An error occurred while creating the voucher', 'error');
            }
        });
    }

    // Handle delete voucher with modal (same pattern as logout modal)
    const deleteModal = document.getElementById('delete-voucher-modal');
    const deleteModalOverlay = document.getElementById('delete-voucher-modal-overlay');
    const confirmDeleteBtn = document.getElementById('confirm-delete-voucher');
    const cancelDeleteBtn = document.getElementById('cancel-delete-voucher');
    const deleteVoucherCodeSpan = document.getElementById('delete-voucher-code');
    
    let currentDeleteVoucherId = null;

    function showDeleteModal() {
        if (deleteModal) deleteModal.style.display = 'flex';
        if (deleteModalOverlay) deleteModalOverlay.classList.add('show');
    }

    function hideDeleteModal() {
        if (deleteModal) deleteModal.style.display = 'none';
        if (deleteModalOverlay) deleteModalOverlay.classList.remove('show');
    }

    // Delete button click handlers
    const deleteButtons = document.querySelectorAll('.delete-voucher-btn');
    deleteButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            e.preventDefault();
            currentDeleteVoucherId = this.dataset.voucherId;
            const voucherCode = this.dataset.voucherCode;
            if (deleteVoucherCodeSpan) {
                deleteVoucherCodeSpan.textContent = voucherCode;
            }
            showDeleteModal();
        });
    });

    // Cancel delete
    if (cancelDeleteBtn) {
        cancelDeleteBtn.addEventListener('click', function() {
            hideDeleteModal();
        });
    }

    // Close modal on outside click
    if (deleteModal) {
        deleteModal.addEventListener('click', function(e) {
            if (e.target === deleteModal) hideDeleteModal();
        });
    }
    
    if (deleteModalOverlay) {
        deleteModalOverlay.addEventListener('click', hideDeleteModal);
    }

    // Confirm delete
    if (confirmDeleteBtn) {
        confirmDeleteBtn.addEventListener('click', async function() {
            if (!currentDeleteVoucherId) {
                console.error('No voucher ID set');
                showNotification('Error: No voucher selected', 'error');
                return;
            }

            const voucherIdToDelete = currentDeleteVoucherId;
            hideDeleteModal();
            currentDeleteVoucherId = null; // Reset after getting the value

            try {
                const response = await fetch(`/admin/vouchers/delete/${voucherIdToDelete}`, {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    credentials: 'same-origin'
                });

                // Check if response is ok
                if (!response.ok) {
                    console.error('Response not ok:', response.status, response.statusText);
                    const text = await response.text();
                    console.error('Response body:', text);
                    showNotification(`Error: ${response.status} - ${response.statusText}`, 'error');
                    return;
                }

                const result = await response.json();

                if (result.success) {
                    showNotification('Voucher deleted successfully!', 'success');
                    setTimeout(() => {
                        window.location.reload();
                    }, 1000);
                } else {
                    showNotification('Error: ' + result.message, 'error');
                }
            } catch (error) {
                console.error('Error deleting voucher:', error);
                showNotification('An error occurred while deleting the voucher', 'error');
            }
        });
    }
});
