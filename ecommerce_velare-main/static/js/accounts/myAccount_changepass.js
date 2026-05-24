document.addEventListener('DOMContentLoaded', function() {
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

    const mainTabs = document.querySelectorAll('.main-tab');
    const myAccountTab = document.getElementById('myAccountTab');
    const myAccountSubTabs = document.getElementById('myAccountSubTabs');
    const newPasswordInput = document.getElementById('new-password');
    const requirementItems = document.querySelectorAll('.password-guidelines-list li');
    const passwordForm = document.querySelector('.password-form');
    const passwordToggles = document.querySelectorAll('.password-toggle');

    // Open My Account by default
    if (myAccountTab && myAccountSubTabs) {
        myAccountTab.classList.add('active');
        myAccountSubTabs.classList.add('open');
        myAccountSubTabs.style.display = 'flex';
    }

    mainTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            // Remove active from all main tabs
            mainTabs.forEach(t => t.classList.remove('active'));

            // Handle sub-tabs visibility
            if (myAccountSubTabs) {
                if (tab !== myAccountTab) {
                    // Hide sub-tabs immediately
                    myAccountSubTabs.classList.remove('open');
                    myAccountSubTabs.style.display = 'none';
                } else {
                    // Show sub-tabs immediately
                    myAccountSubTabs.style.display = 'flex';
                    myAccountSubTabs.classList.add('open');
                }
            }

            // Set active tab
            tab.classList.add('active');
        });
    });

    const requirementChecks = {
        length: password => password.length >= 6,
        uppercase: password => /[A-Z]/.test(password),
        lowercase: password => /[a-z]/.test(password),
        number: password => /\d/.test(password)
    };

    let hasAttemptedSubmit = false;

    function updateRequirementStates(password, highlightUnmet = false) {
        requirementItems.forEach(item => {
            const requirement = item.dataset.requirement;
            if (requirement && requirementChecks[requirement]) {
                const isMet = requirementChecks[requirement](password);
                item.classList.toggle('met', isMet);
                if (isMet) {
                    item.classList.remove('unmet');
                } else if (highlightUnmet) {
                    // Remove and re-add class to restart animation
                    item.classList.remove('unmet');
                    // Force reflow to restart animation
                    void item.offsetWidth;
                    item.classList.add('unmet');
                } else {
                    item.classList.remove('unmet');
                }
            }
        });
    }

    if (newPasswordInput) {
        newPasswordInput.addEventListener('input', event => {
            const value = event.target.value;
            updateRequirementStates(value, hasAttemptedSubmit);
        });

        // Initialize state on load in case of pre-filled values
        updateRequirementStates(newPasswordInput.value || '');
    }

    if (passwordForm) {
        passwordForm.addEventListener('submit', async event => {
            event.preventDefault();
            
            if (!newPasswordInput) {
                return;
            }

            hasAttemptedSubmit = true;
            updateRequirementStates(newPasswordInput.value, true);

            const hasUnmetRequirements = Array.from(requirementItems).some(item => !item.classList.contains('met'));
            if (hasUnmetRequirements) {
                newPasswordInput.focus();
                return;
            }

            // Get form values
            const currentPassword = document.getElementById('current-password').value;
            const newPassword = document.getElementById('new-password').value;
            const confirmPassword = document.getElementById('confirm-password').value;

            // Client-side validation
            if (!currentPassword || !newPassword || !confirmPassword) {
                showNotification('Please fill in all fields', 'error');
                return;
            }

            if (newPassword !== confirmPassword) {
                showNotification('New passwords do not match', 'error');
                return;
            }

            // Disable submit button to prevent double submission
            const submitBtn = passwordForm.querySelector('.save-btn');
            const originalText = submitBtn.textContent;
            submitBtn.disabled = true;
            submitBtn.textContent = 'Updating...';

            try {
                // Send password change request
                const response = await fetch('/myAccount_changepass/update', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        current_password: currentPassword,
                        new_password: newPassword,
                        confirm_password: confirmPassword
                    })
                });

                const data = await response.json();

                if (data.success) {
                    showNotification(data.message, 'success');
                    // Clear form
                    passwordForm.reset();
                    hasAttemptedSubmit = false;
                    updateRequirementStates('', false);
                } else {
                    showNotification(data.message || 'Failed to update password', 'error');
                }
            } catch (error) {
                console.error('Error:', error);
                showNotification('An error occurred. Please try again.', 'error');
            } finally {
                // Re-enable submit button
                submitBtn.disabled = false;
                submitBtn.textContent = originalText;
            }
        });
    }

    // Password toggle functionality
    passwordToggles.forEach(toggle => {
        const targetId = toggle.dataset.target;
        const targetInput = document.getElementById(targetId);

        if (!targetInput) {
            return;
        }

        const icon = toggle.querySelector('i');

        const syncState = () => {
            const isVisible = targetInput.type === 'text';
            if (icon) {
                icon.className = isVisible ? 'bi bi-eye' : 'bi bi-eye-slash';
            }
            toggle.setAttribute('aria-pressed', isVisible ? 'true' : 'false');
        };

        toggle.addEventListener('click', () => {
            const isPassword = targetInput.type === 'password';
            targetInput.type = isPassword ? 'text' : 'password';
            syncState();
        });

        syncState();
    });
});

