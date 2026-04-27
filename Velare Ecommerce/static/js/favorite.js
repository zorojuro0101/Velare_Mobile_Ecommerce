// Unfavorite button functionality
document.addEventListener('DOMContentLoaded', function() {
    // Handle add to cart buttons
    const addToCartButtons = document.querySelectorAll('.add-to-cart-btn');
    addToCartButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            e.preventDefault();
            const productId = this.dataset.productId;
            
            // Add to cart
            fetch('/add_to_cart', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    product_id: productId,
                    quantity: 1
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showNotification(data.message || 'Added to cart successfully!', 'success');
                } else {
                    showNotification(data.message || 'Failed to add to cart', 'error');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                showNotification('Connection error. Please try again.', 'error');
            });
        });
    });
    
    // Handle unfavorite buttons
    const unfavoriteButtons = document.querySelectorAll('.favorite-action-btn.favorite');
    unfavoriteButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            e.preventDefault();
            const favoriteId = this.dataset.favoriteId;
            
            // Check if confirmation already exists
            const existingConfirm = document.querySelector('.remove-confirm-popup');
            if (existingConfirm) {
                existingConfirm.remove();
            }
            
            // Create confirmation popup
            const confirmPopup = document.createElement('div');
            confirmPopup.className = 'remove-confirm-popup';
            confirmPopup.innerHTML = `
                <div class="confirm-text">Remove from favorites?</div>
                <div class="confirm-buttons">
                    <button class="confirm-yes">Yes</button>
                    <button class="confirm-no">No</button>
                </div>
            `;
            
            // Position it next to the button
            const buttonRect = this.getBoundingClientRect();
            confirmPopup.style.position = 'fixed';
            confirmPopup.style.top = `${buttonRect.top}px`;
            confirmPopup.style.left = `${buttonRect.right + 10}px`;
            
            document.body.appendChild(confirmPopup);
            
            // Handle Yes button
            confirmPopup.querySelector('.confirm-yes').addEventListener('click', function() {
                removeFavorite(favoriteId, button);
                confirmPopup.remove();
            });
            
            // Handle No button
            confirmPopup.querySelector('.confirm-no').addEventListener('click', function() {
                confirmPopup.remove();
            });
            
            // Close on outside click
            setTimeout(() => {
                document.addEventListener('click', function closePopup(e) {
                    if (!confirmPopup.contains(e.target) && e.target !== button) {
                        confirmPopup.remove();
                        document.removeEventListener('click', closePopup);
                    }
                });
            }, 100);
        });
    });
});

// Function to remove favorite
function removeFavorite(favoriteId, buttonElement) {
    fetch('/remove_from_favorites', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            favorite_id: favoriteId
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Show success notification first
            showNotification('Removed from favorites!', 'success');
            
            // Find and remove the entire favorite-item-row
            const itemRow = buttonElement.closest('.favorite-item-row');
            if (itemRow) {
                // Get the shop group before removing the row
                const shopGroup = itemRow.closest('.shop-group');
                
                // Add fade out animation
                itemRow.style.transition = 'opacity 0.3s ease';
                itemRow.style.opacity = '0';
                
                // Remove from DOM after animation
                setTimeout(() => {
                    itemRow.remove();
                    
                    // Check if the shop group is now empty
                    if (shopGroup) {
                        const remainingItems = shopGroup.querySelectorAll('.favorite-item-row');
                        if (remainingItems.length === 0) {
                            // Remove the entire shop group if no items left
                            shopGroup.remove();
                        }
                    }
                    
                    // Check if there are any favorites left
                    const remainingItems = document.querySelectorAll('.favorite-item-row');
                    if (remainingItems.length === 0) {
                        // Wait a bit before reloading to show notification
                        setTimeout(() => {
                            location.reload();
                        }, 800);
                    }
                }, 300);
            }
        } else {
            showNotification(data.message || 'Failed to remove from favorites', 'error');
        }
    })
    .catch(error => {
        console.error('Error:', error);
        showNotification('Connection error. Please try again.', 'error');
    });
}

// Show notification function
function showNotification(message, type = 'info') {
    // Remove any existing notifications first
    const existingNotifications = document.querySelectorAll('.notification');
    existingNotifications.forEach(notif => {
        notif.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notif.remove();
        }, 300);
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
        top: 60px;
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
        font-family: 'Goudy Bookletter 1911', 'Goudy Old Style', serif;
        font-size: 0.95rem;
        font-weight: 600;
        animation: slideIn 0.3s ease;
    `;

    // Add animation keyframes
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
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 3000);
}
