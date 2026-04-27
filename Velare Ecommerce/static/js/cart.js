// Helper function to attach quantity button listeners
function attachQuantityListeners(container) {
    // Handle quantity increase
    container.querySelectorAll('.qty-increase').forEach(btn => {
        btn.addEventListener('click', function() {
            const cartId = this.dataset.cartId;
            const maxStock = parseInt(this.dataset.max);
            const row = this.closest('.cart-item-row');
            const input = row.querySelector('.qty-input');
            let currentQty = parseInt(input.value);
            
            // Check if out of stock
            if (maxStock <= 0) {
                showNotification('This product is out of stock', 'error');
                return;
            }
            
            if (currentQty >= maxStock) {
                showNotification(`Only ${maxStock} items available in stock`, 'error');
                return;
            }
            
            const newQty = currentQty + 1;
            
            // Update quantity in database
            fetch('/update_cart_quantity', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    cart_id: cartId,
                    quantity: newQty
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    input.value = newQty;
                    updateItemPrice(row);
                    updateCartTotals();
                } else {
                    showNotification(data.message || 'Failed to update quantity', 'error');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                showNotification('An error occurred while updating quantity', 'error');
            });
        });
    });
    
    // Handle quantity decrease
    container.querySelectorAll('.qty-decrease').forEach(btn => {
        btn.addEventListener('click', function() {
            const cartId = this.dataset.cartId;
            const row = this.closest('.cart-item-row');
            const input = row.querySelector('.qty-input');
            let currentQty = parseInt(input.value);
            
            if (currentQty <= 1) {
                showNotification('Quantity cannot be less than 1', 'error');
                return;
            }
            
            const newQty = currentQty - 1;
            
            // Update quantity in database
            fetch('/update_cart_quantity', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    cart_id: cartId,
                    quantity: newQty
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    input.value = newQty;
                    updateItemPrice(row);
                    updateCartTotals();
                } else {
                    showNotification(data.message || 'Failed to update quantity', 'error');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                showNotification('An error occurred while updating quantity', 'error');
            });
        });
    });
}

// Cart functionality with database operations
document.addEventListener('DOMContentLoaded', function() {
    
    // Calculate and update cart totals
    function updateCartTotals() {
        let totalItems = 0;
        let totalPrice = 0;
        
        document.querySelectorAll('.cart-item-row').forEach(row => {
            const checkbox = row.querySelector('.cart-item-checkbox');
            if (checkbox && checkbox.checked) {
                const quantity = parseInt(row.querySelector('.qty-input').value);
                const price = parseFloat(row.dataset.price);
                totalItems += quantity;
                totalPrice += price * quantity;
            }
        });
        
        document.getElementById('cartTotalItems').textContent = totalItems;
        document.getElementById('cartTotalPrice').textContent = totalPrice.toFixed(2);
    }
    
    // Update individual item price display
    function updateItemPrice(row) {
        const quantity = parseInt(row.querySelector('.qty-input').value);
        const price = parseFloat(row.dataset.price);
        const priceElement = row.querySelector('.cart-item-price');
        priceElement.textContent = '₱' + (price * quantity).toFixed(2);
    }
    
    // Show notification (same style as favorite page)
    function showNotification(message, type = 'success') {
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
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => {
                notification.remove();
            }, 300);
        }, 3000);
    }
    
    // Attach quantity button listeners to document
    attachQuantityListeners(document);
    
    // Handle delete button
    document.querySelectorAll('.delete-btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            const cartId = this.dataset.cartId;
            const row = this.closest('.cart-item-row');
            
            // Check if confirmation already exists
            const existingConfirm = document.querySelector('.remove-confirm-popup');
            if (existingConfirm) {
                existingConfirm.remove();
            }
            
            // Create confirmation popup
            const confirmPopup = document.createElement('div');
            confirmPopup.className = 'remove-confirm-popup';
            confirmPopup.innerHTML = `
                <div class="confirm-text">Remove from cart?</div>
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
                // Get the shop group before removing the row
                const shopGroup = row.closest('.shop-group');
                const sellerId = row.dataset.sellerId;
                
                // Remove from database
                fetch('/remove_from_cart', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        cart_id: cartId
                    })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        row.remove();
                        updateCartTotals();
                        showNotification('Item removed from cart');
                        
                        // Update cart badge
                        if (typeof window.updateCartBadge === 'function') {
                            window.updateCartBadge();
                        }
                        
                        // Check if the shop group is now empty
                        if (shopGroup) {
                            const remainingItems = shopGroup.querySelectorAll('.cart-item-row');
                            if (remainingItems.length === 0) {
                                // Remove the entire shop group if no items left
                                shopGroup.remove();
                            }
                        }
                        
                        // Check if cart is completely empty
                        if (document.querySelectorAll('.cart-item-row').length === 0) {
                            location.reload();
                        }
                    } else {
                        showNotification(data.message || 'Failed to remove item', 'error');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    showNotification('An error occurred while removing item', 'error');
                });
                
                confirmPopup.remove();
            });
            
            // Handle No button
            confirmPopup.querySelector('.confirm-no').addEventListener('click', function() {
                confirmPopup.remove();
            });
            
            // Close on outside click
            setTimeout(() => {
                document.addEventListener('click', function closePopup(e) {
                    if (!confirmPopup.contains(e.target) && e.target !== btn) {
                        confirmPopup.remove();
                        document.removeEventListener('click', closePopup);
                    }
                });
            }, 100);
        });
    });
    
    // Handle add to favorites from cart
    document.querySelectorAll('.add-to-favorites-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const productId = this.dataset.productId;
            const starIcon = this.querySelector('i');
            
            // Add to favorites
            fetch('/add_to_favorites', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    product_id: productId
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.classList.add('active');
                    starIcon.classList.remove('bi-star');
                    starIcon.classList.add('bi-star-fill');
                    showNotification('Added to favorites');
                } else if (data.message === 'Already in favorites') {
                    this.classList.add('active');
                    starIcon.classList.remove('bi-star');
                    starIcon.classList.add('bi-star-fill');
                    showNotification('Already in favorites', 'error');
                } else {
                    showNotification(data.message || 'Failed to add to favorites', 'error');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                showNotification('An error occurred', 'error');
            });
        });
    });
    
    // Handle shop checkbox - check/uncheck all items in that shop
    document.querySelectorAll('.shop-checkbox').forEach(shopCheckbox => {
        shopCheckbox.addEventListener('change', function() {
            const sellerId = this.dataset.sellerId;
            const isChecked = this.checked;
            
            // Check/uncheck all items from this shop
            document.querySelectorAll(`.cart-item-checkbox[data-seller-id="${sellerId}"]`).forEach(itemCheckbox => {
                itemCheckbox.checked = isChecked;
            });
            
            updateCartTotals();
        });
    });
    
    // Handle individual item checkbox changes
    document.querySelectorAll('.cart-item-checkbox').forEach(checkbox => {
        checkbox.addEventListener('change', function() {
            const sellerId = this.dataset.sellerId;
            
            // Check if all items from this shop are checked
            const shopItems = document.querySelectorAll(`.cart-item-checkbox[data-seller-id="${sellerId}"]`);
            const allChecked = Array.from(shopItems).every(item => item.checked);
            
            // Update shop checkbox
            const shopCheckbox = document.querySelector(`.shop-checkbox[data-seller-id="${sellerId}"]`);
            if (shopCheckbox) {
                shopCheckbox.checked = allChecked;
            }
            
            updateCartTotals();
        });
    });
    
    // Handle checkout button
    const checkoutBtn = document.getElementById('checkoutBtn');
    if (checkoutBtn) {
        checkoutBtn.addEventListener('click', function() {
            // Get all checked cart IDs
            const cartIds = [];
            const outOfStockItems = [];
            
            document.querySelectorAll('.cart-item-checkbox:checked').forEach(checkbox => {
                const row = checkbox.closest('.cart-item-row');
                const cartId = row.dataset.cartId;
                const productId = row.dataset.productId;
                const productName = row.querySelector('.cart-item-name')?.textContent || 'Product';
                const quantityInput = row.querySelector('.qty-input');
                const stock = quantityInput ? parseInt(quantityInput.dataset.max) : 0;
                const quantity = quantityInput ? parseInt(quantityInput.value) : 1;
                const color = row.dataset.color || '';
                const size = row.dataset.size || '';
                
                // Check if item is out of stock or insufficient stock
                if (stock <= 0) {
                    outOfStockItems.push({
                        productName: productName,
                        color: color,
                        size: size,
                        reason: 'out_of_stock'
                    });
                } else if (quantity > stock) {
                    outOfStockItems.push({
                        productName: productName,
                        color: color,
                        size: size,
                        available: stock,
                        requested: quantity,
                        reason: 'insufficient'
                    });
                } else {
                    cartIds.push(cartId);
                }
            });
            
            if (cartIds.length === 0 && outOfStockItems.length === 0) {
                showNotification('Please select at least one item to checkout', 'error');
                return;
            }
            
            // If there are out of stock items, show error and don't proceed
            if (outOfStockItems.length > 0) {
                let errorMsg = 'Cannot checkout - the following items have stock issues:\n\n';
                outOfStockItems.forEach(item => {
                    if (item.reason === 'out_of_stock') {
                        errorMsg += `• ${item.productName}${item.color ? ' (' + item.color : ''}${item.size ? ', ' + item.size : ''}${item.color || item.size ? ')' : ''} - Out of stock\n`;
                    } else {
                        errorMsg += `• ${item.productName}${item.color ? ' (' + item.color : ''}${item.size ? ', ' + item.size : ''}${item.color || item.size ? ')' : ''} - Only ${item.available} available, but ${item.requested} requested\n`;
                    }
                });
                showNotification(errorMsg, 'error');
                return;
            }
            
            // Redirect to checkout page with cart IDs as query parameter
            window.location.href = `/checkout?cart_ids=${cartIds.join(',')}`;
        });
    }
    
    // Initialize totals
    updateCartTotals();
    
    // Periodic stock status check (every 5 seconds)
    setInterval(function() {
        checkCartStockStatus();
    }, 5000);
});

// Function to check if cart items have stock status changes
function checkCartStockStatus() {
    const cartItems = [];
    
    // Collect all cart items with their current stock info
    document.querySelectorAll('.cart-item-row').forEach(row => {
        const cartId = row.dataset.cartId;
        const productId = row.dataset.productId;
        const stockStatusDiv = row.querySelector('.cart-item-stock-status');
        const variantId = stockStatusDiv ? stockStatusDiv.dataset.variantId : null;
        const currentStock = stockStatusDiv ? parseInt(stockStatusDiv.dataset.stock) : null;
        const productNameEl = row.querySelector('.cart-item-name');
        const productName = productNameEl ? productNameEl.textContent : null;
        
        if (variantId && currentStock !== null) {
            cartItems.push({
                cart_id: cartId,
                variant_id: variantId,
                current_stock: currentStock,
                product_id: productId,
                product_name: productName
            });
        }
    });
    
    if (cartItems.length === 0) {
        console.log('[STOCK_CHECK] No cart items to check');
        return;
    }
    
    console.log('[STOCK_CHECK] Checking stock for', cartItems.length, 'items:', cartItems);
    
    // Check stock status changes
    fetch('/check_cart_stock_status', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            cart_items: cartItems
        })
    })
    .then(response => response.json())
    .then(data => {
        console.log('[STOCK_CHECK] Response:', data);
        
        if (data.success && data.changes && data.changes.length > 0) {
            console.log('[STOCK_CHECK] Found', data.changes.length, 'stock changes');
            
            // Process each stock status change
            data.changes.forEach(change => {
                console.log('[STOCK_CHECK] Processing change:', change);
                
                const row = document.querySelector(`.cart-item-row[data-cart-id="${change.cart_id}"]`);
                if (!row) {
                    console.log('[STOCK_CHECK] Row not found for cart_id:', change.cart_id);
                    return;
                }
                
                const stockStatusDiv = row.querySelector('.cart-item-stock-status');
                const qtyIncreaseBtn = row.querySelector('.qty-increase');
                
                // Update the data attributes
                stockStatusDiv.dataset.stock = change.new_stock;
                if (qtyIncreaseBtn) {
                    qtyIncreaseBtn.dataset.max = change.new_stock;
                }
                
                // Update the badge display
                const badgeSpan = stockStatusDiv.querySelector('.stock-badge');
                let newBadgeHTML = '';
                
                if (change.new_stock <= 0) {
                    newBadgeHTML = '<span class="stock-badge stock-out">Out of Stock</span>';
                } else if (change.new_stock <= 5) {
                    newBadgeHTML = '<span class="stock-badge stock-low">Low on Stock</span>';
                }
                
                if (newBadgeHTML) {
                    stockStatusDiv.innerHTML = newBadgeHTML;
                } else if (badgeSpan) {
                    badgeSpan.remove();
                }
                
                // Update quantity section - replace with badge if out of stock
                const qtySection = row.querySelector('.cart-item-quantity');
                if (change.new_stock <= 0) {
                    // Replace quantity controls with out of stock badge
                    qtySection.innerHTML = '<span class="stock-badge stock-out" style="display: inline-block; width: 100%; text-align: center;">Out of Stock</span>';
                } else if (change.new_stock > 0 && qtySection.querySelector('.stock-badge')) {
                    // If stock is back to normal, restore quantity controls
                    const cartId = row.dataset.cartId;
                    const currentQty = row.querySelector('.qty-input')?.value || 1;
                    qtySection.innerHTML = `
                        <button class="qty-btn qty-decrease" data-cart-id="${cartId}" title="Decrease">-</button>
                        <input type="text" class="qty-input" value="${currentQty}" data-cart-id="${cartId}" data-max="${change.new_stock}" readonly />
                        <button class="qty-btn qty-increase" data-cart-id="${cartId}" data-max="${change.new_stock}" title="Increase">+</button>
                    `;
                    // Re-attach event listeners to the new buttons
                    attachQuantityListeners(qtySection);
                }
                
                // Show notification about the change
                if (change.old_status === 'normal' && change.new_status === 'low_on_stock') {
                    showNotification('A product in your cart is now Low on Stock', 'warning');
                } else if (change.new_status === 'out_of_stock') {
                    showNotification('A product in your cart is now Out of Stock', 'error');
                }
            });
        } else {
            console.log('[STOCK_CHECK] No changes detected');
        }
    })
    .catch(error => {
        console.error('[STOCK_CHECK] Error checking stock status:', error);
    });
}
