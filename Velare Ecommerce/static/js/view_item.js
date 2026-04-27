// Color and Size selection functionality

function initializeViewItem() {
    const colorButtons = document.querySelectorAll('.color-option');
    const selectedColorInput = document.getElementById('selected-color');
    const sizeDropdown = document.getElementById('size-dropdown');
    const colorsList = document.querySelector('.other-colors-list');
    const variantsData = document.getElementById('variants-data');
    
    // ===== Quantity controls =====
    const quantityInput = document.getElementById('quantity-input');
    const quantityMinus = document.querySelector('.quantity-minus');
    const quantityPlus = document.querySelector('.quantity-plus');
    
    if (quantityMinus && quantityInput) {
        quantityMinus.addEventListener('click', function() {
            const currentValue = parseInt(quantityInput.value) || 1;
            const minValue = parseInt(quantityInput.min) || 1;
            if (currentValue > minValue) {
                quantityInput.value = currentValue - 1;
            }
        });
    }
    
    if (quantityPlus && quantityInput) {
        quantityPlus.addEventListener('click', function() {
            const currentValue = parseInt(quantityInput.value) || 1;
            const maxValue = parseInt(quantityInput.max) || 999;
            if (currentValue < maxValue) {
                quantityInput.value = currentValue + 1;
            }
        });
    }
    
    // Validate quantity input
    if (quantityInput) {
        quantityInput.addEventListener('input', function() {
            const minValue = parseInt(this.min) || 1;
            const maxValue = parseInt(this.max) || 999;
            let value = parseInt(this.value) || minValue;
            
            if (value < minValue) value = minValue;
            if (value > maxValue) value = maxValue;
            
            this.value = value;
        });
    }
    
    // Store all variants data from hidden container
    const variants = [];
    if (variantsData) {
        const spans = variantsData.querySelectorAll('span[data-variant-id]');
        spans.forEach(span => {
            variants.push({
                variantId: span.dataset.variantId,
                size: span.dataset.size,
                color: span.dataset.color,
                hex: span.dataset.hex,
                stock: parseInt(span.dataset.stock)
            });
        });
    }
    
    // Store color-specific images (passed from backend)
    const colorImages = window.colorImagesData || {};
    
    // Populate size dropdown with unique sizes
    function populateSizeDropdown() {
        if (!sizeDropdown) return;
        
        // Get unique sizes with total stock
        const sizeMap = new Map();
        variants.forEach(v => {
            if (!sizeMap.has(v.size)) {
                sizeMap.set(v.size, 0);
            }
            sizeMap.set(v.size, sizeMap.get(v.size) + v.stock);
        });
        
        // Add size options
        sizeMap.forEach((totalStock, size) => {
            const option = document.createElement('option');
            option.value = size;
            option.dataset.size = size;
            option.textContent = `${size} (${totalStock} in stock)`;
            sizeDropdown.appendChild(option);
        });
    }
    
    // Initialize size dropdown
    populateSizeDropdown();
    
    // Initialize colors on page load (show all colors, none disabled)
    updateAvailableColors(null);
    
    // Function to update available colors based on selected size
    function updateAvailableColors(selectedSize) {
        if (!colorsList) return;
        
        // Remember currently selected color
        const currentSelectedColor = selectedColorInput.value;
        
        // Get all unique colors
        const allColors = new Map();
        variants.forEach(v => {
            if (!allColors.has(v.color)) {
                allColors.set(v.color, v.hex);
            }
        });
        
        // Get colors available for selected size
        const availableColors = new Set();
        if (selectedSize) {
            variants.forEach(v => {
                if (v.size === selectedSize) {
                    availableColors.add(v.color);
                }
            });
        }
        
        // Clear current colors
        colorsList.innerHTML = '';
        
        // Add all colors, but disable those not available for selected size
        allColors.forEach((hex, colorName) => {
            const isAvailable = !selectedSize || availableColors.has(colorName);
            addColorButton(colorName, hex, !isAvailable);
        });
        
        // Restore selected color highlight if it was previously selected
        if (currentSelectedColor) {
            const colorButtons = document.querySelectorAll('.color-option');
            colorButtons.forEach(btn => {
                if (btn.dataset.color === currentSelectedColor) {
                    btn.classList.add('selected');
                }
            });
        }
    }
    
    // Function to add color button
    function addColorButton(colorName, hexCode, isDisabled = false) {
        const button = document.createElement('button');
        button.className = 'color-option';
        button.dataset.color = colorName;
        
        if (isDisabled) {
            button.disabled = true;
            button.classList.add('disabled');
            button.style.opacity = '0.4';
            button.style.cursor = 'not-allowed';
        }
        
        const swatch = document.createElement('span');
        swatch.className = 'color-swatch-half';
        swatch.dataset.colorName = colorName;
        if (hexCode) {
            swatch.style.backgroundColor = hexCode;
        }
        
        const name = document.createElement('span');
        name.className = 'color-name';
        name.textContent = colorName;
        
        button.appendChild(swatch);
        button.appendChild(name);
        colorsList.appendChild(button);
    }
    
    // Function to update product images based on selected color
    function updateProductImages(colorName) {
        const imageList = document.querySelector('.product-image-list');
        if (!imageList) return;
        
        // Get images for this color
        const images = colorImages[colorName];
        
        console.log('=== UPDATE PRODUCT IMAGES ===');
        console.log('Color:', colorName);
        console.log('Images:', images);
        console.log('colorImages object:', colorImages);
        
        if (images && images.length > 0) {
            // Clear current images
            imageList.innerHTML = '';
            
            // Add new images
            images.forEach(imageUrl => {
                console.log('Processing image URL:', imageUrl);
                const img = document.createElement('img');
                // Handle different URL formats
                if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
                    // Full URL (Supabase Storage)
                    img.src = imageUrl;
                    console.log('Using full URL:', imageUrl);
                } else if (imageUrl.startsWith('static/')) {
                    // Local path with static/ prefix
                    img.src = `/${imageUrl}`;
                    console.log('Using local path with prefix:', `/${imageUrl}`);
                } else {
                    // Relative path
                    img.src = `/static/${imageUrl}`;
                    console.log('Using relative path:', `/static/${imageUrl}`);
                }
                img.alt = colorName;
                img.className = 'product-main-image';
                imageList.appendChild(img);
            });
        } else {
            console.log('No images found for color:', colorName);
        }
    }
    
    // Use event delegation for color buttons to avoid duplicate listeners
    if (colorsList) {
        colorsList.addEventListener('click', function(e) {
            const button = e.target.closest('.color-option');
            if (!button) return;
            
            e.preventDefault();
            
            // Don't allow clicking disabled buttons
            if (button.disabled) return;
            
            const buttons = document.querySelectorAll('.color-option');
            
            // Check if already selected - if yes, unselect it
            if (button.classList.contains('selected')) {
                button.classList.remove('selected');
                selectedColorInput.value = '';
                // Reset size dropdown to show all sizes
                updateSizeDropdown(null);
                // Reset to default images (first color or all images)
                const firstColor = Object.keys(colorImages)[0];
                if (firstColor) {
                    updateProductImages(firstColor);
                }
            } else {
                // Remove selected class from all buttons
                buttons.forEach(btn => btn.classList.remove('selected'));
                
                // Add selected class to clicked button
                button.classList.add('selected');
                
                // Store selected color
                const selectedColor = button.dataset.color;
                selectedColorInput.value = selectedColor;
                
                // Update product images for selected color
                updateProductImages(selectedColor);
                
                // Update size dropdown to show only matching variants
                updateSizeDropdown(selectedColor);
            }
        });
    }
    
    // Function to update size dropdown based on selected color
    function updateSizeDropdown(selectedColor) {
        if (!sizeDropdown) return;
        
        // Remember currently selected size
        const currentSelectedSize = sizeDropdown.value;
        
        // Get all unique sizes
        const allSizes = new Map();
        variants.forEach(v => {
            if (!allSizes.has(v.size)) {
                allSizes.set(v.size, 0);
            }
            allSizes.set(v.size, allSizes.get(v.size) + v.stock);
        });
        
        // Get sizes available for selected color
        const availableSizes = new Map();
        if (selectedColor) {
            variants.forEach(v => {
                if (v.color === selectedColor) {
                    if (!availableSizes.has(v.size)) {
                        availableSizes.set(v.size, 0);
                    }
                    availableSizes.set(v.size, availableSizes.get(v.size) + v.stock);
                }
            });
        }
        
        // Clear and repopulate size dropdown
        sizeDropdown.innerHTML = '<option value="">Select Size</option>';
        
        // Add all sizes, but disable those not available for selected color
        allSizes.forEach((totalStock, size) => {
            const option = document.createElement('option');
            option.value = size;
            option.dataset.size = size;
            
            if (selectedColor) {
                // If color is selected, check if size is available for that color
                if (availableSizes.has(size)) {
                    const stock = availableSizes.get(size);
                    if (stock === 0) {
                        option.textContent = `${size} (0) out of stock`;
                        option.disabled = true;
                    } else {
                        option.textContent = `${size} (${stock} in stock)`;
                    }
                } else {
                    option.textContent = `${size} (Not available)`;
                    option.disabled = true;
                }
            } else {
                // No color selected, show total stock
                if (totalStock === 0) {
                    option.textContent = `${size} (0) out of stock`;
                    option.disabled = true;
                } else {
                    option.textContent = `${size} (${totalStock} in stock)`;
                }
            }
            
            sizeDropdown.appendChild(option);
        });
        
        // Restore previously selected size if it's still available
        if (currentSelectedSize) {
            const stillAvailable = Array.from(sizeDropdown.options).some(opt => 
                opt.value === currentSelectedSize && !opt.disabled
            );
            if (stillAvailable) {
                sizeDropdown.value = currentSelectedSize;
            }
        }
    }
    
    // Listen to size dropdown changes
    if (sizeDropdown) {
        sizeDropdown.addEventListener('change', function() {
            const selectedSize = this.value;
            
            // Don't clear color selection, just update available colors
            // Update available colors (will disable unavailable ones)
            updateAvailableColors(selectedSize);
            
            // If currently selected color is not available for this size, clear it
            const selectedColor = selectedColorInput.value;
            if (selectedColor && selectedSize) {
                const isColorAvailable = variants.some(v => 
                    v.size === selectedSize && v.color === selectedColor
                );
                
                if (!isColorAvailable) {
                    selectedColorInput.value = '';
                    document.querySelectorAll('.color-option').forEach(btn => {
                        btn.classList.remove('selected');
                    });
                }
            }
        });
    }
    
    // Helper function to get variant_id based on size and color
    window.getVariantId = function(size, color) {
        const variant = variants.find(v => v.size === size && v.color === color);
        return variant ? variant.variantId : null;
    };
    
    // Helper function to get variant stock
    window.getVariantStock = function(size, color) {
        const variant = variants.find(v => v.size === size && v.color === color);
        return variant ? variant.stock : 0;
    };
    
    // Function to update quantity input max based on selected variant
    function updateQuantityMax() {
        if (!quantityInput) return;
        
        const selectedSize = sizeDropdown ? sizeDropdown.value : null;
        const selectedColor = selectedColorInput ? selectedColorInput.value : null;
        
        if (selectedSize && selectedColor) {
            // Get stock for specific variant
            const variantStock = window.getVariantStock(selectedSize, selectedColor);
            quantityInput.max = variantStock;
            
            // If current quantity exceeds new max, adjust it
            const currentQty = parseInt(quantityInput.value) || 1;
            if (currentQty > variantStock) {
                quantityInput.value = Math.max(1, variantStock);
            }
        }
    }
    
    // Update quantity max when size or color changes
    if (sizeDropdown) {
        sizeDropdown.addEventListener('change', updateQuantityMax);
    }
    
    if (colorsList) {
        colorsList.addEventListener('click', function(e) {
            const button = e.target.closest('.color-option');
            if (button) {
                // Wait a bit for the color selection to complete
                setTimeout(updateQuantityMax, 100);
            }
        });
    }

    // ===== Favorite button functionality =====
    const favoriteBtn = document.getElementById('favorite-btn');
    
    console.log('[VIEW_ITEM] Initializing favorite button. Already attached?', favoriteBtn?.dataset.listenerAttached);
    
    if (favoriteBtn && !favoriteBtn.dataset.listenerAttached) {
        favoriteBtn.dataset.listenerAttached = 'true';
        console.log('[VIEW_ITEM] Attaching favorite button listener');
        favoriteBtn.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('[VIEW_ITEM] Favorite button clicked');
            const productId = this.dataset.productId;
            const isActive = this.classList.contains('active');
            
            if (isActive) {
                // Remove from favorites
                fetch('/remove_from_favorites_by_product', {
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
                        // Remove active class
                        this.classList.remove('active');
                        
                        // Change icon to outline star
                        const icon = this.querySelector('.favorite-icon');
                        icon.classList.remove('bi-star-fill');
                        icon.classList.add('bi-star');
                        
                        // Update label
                        this.dataset.label = 'Add to Favorites';
                        
                        // Show notification in red
                        showNotification('Removed from favorites!', 'error');
                    } else {
                        showNotification(data.message || 'Failed to remove from favorites', 'error');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    showNotification('Connection error. Please try again.', 'error');
                });
            } else {
                // Add to favorites - check if color and size are selected first
                const sizeDropdown = document.getElementById('size-dropdown');
                const selectedSize = sizeDropdown ? sizeDropdown.value : null;
                const colorButtons = document.querySelectorAll('.color-option');
                const selectedColor = selectedColorInput.value;
                
                // Check if color selection is required
                if (colorButtons.length > 0 && !selectedColor) {
                    showNotification('Please select a color', 'error');
                    return;
                }
                
                // Check if size selection is required
                if (sizeDropdown && !selectedSize) {
                    showNotification('Please select a size', 'error');
                    return;
                }
                
                // Add to favorites - get variant_id like cart does
                const variantId = window.getVariantId ? window.getVariantId(selectedSize, selectedColor) : null;
                
                const requestBody = {
                    product_id: productId
                };
                
                if (variantId) {
                    requestBody.variant_id = variantId;
                }
                
                fetch('/add_to_favorites', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(requestBody)
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        // Add active class
                        this.classList.add('active');
                        
                        // Change icon to filled star
                        const icon = this.querySelector('.favorite-icon');
                        icon.classList.remove('bi-star');
                        icon.classList.add('bi-star-fill');
                        
                        // Update label
                        this.dataset.label = 'Remove from Favorites';
                        
                        // Show success notification
                        showNotification('Added to favorites!', 'success');
                    } else {
                        showNotification(data.message || 'Failed to add to favorites', 'error');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    showNotification('Connection error. Please try again.', 'error');
                });
            }
        });
    }

    // ===== Buy Now button functionality =====
    const buyBtn = document.querySelector('.buy-btn');
    let buyNowProcessing = false;
    
    console.log('[VIEW_ITEM] Initializing buy now button. Already attached?', buyBtn?.dataset.listenerAttached);
    
    if (buyBtn && !buyBtn.dataset.listenerAttached) {
        buyBtn.dataset.listenerAttached = 'true';
        console.log('[VIEW_ITEM] Attaching buy now button listener');
        buyBtn.addEventListener('click', function() {
            console.log('[VIEW_ITEM] Buy now button clicked. Processing:', buyNowProcessing);
            // Prevent double-clicking
            if (buyNowProcessing) {
                console.log('[VIEW_ITEM] Buy now already processing, ignoring click');
                return;
            }
            buyNowProcessing = true;
            const productId = document.getElementById('favorite-btn')?.dataset.productId;
            const sizeDropdown = document.getElementById('size-dropdown');
            const selectedSize = sizeDropdown ? sizeDropdown.value : null;
            const colorButtons = document.querySelectorAll('.color-option');
            const selectedColor = document.getElementById('selected-color').value;
            
            if (!productId) {
                buyNowProcessing = false;
                showNotification('Product information not found', 'error');
                return;
            }
            
            // Check if color selection is required
            if (colorButtons.length > 0 && !selectedColor) {
                buyNowProcessing = false;
                showNotification('Please select a color', 'error');
                return;
            }
            
            // Check if size selection is required
            if (sizeDropdown && !selectedSize) {
                buyNowProcessing = false;
                showNotification('Please select a size', 'error');
                return;
            }
            
            // Get quantity from input
            const quantityInput = document.getElementById('quantity-input');
            const quantity = quantityInput ? parseInt(quantityInput.value) || 1 : 1;
            
            // Get variant_id and stock based on size and color
            const variantId = window.getVariantId ? window.getVariantId(selectedSize, selectedColor) : null;
            const variantStock = window.getVariantStock ? window.getVariantStock(selectedSize, selectedColor) : 999;
            
            // Check if quantity exceeds variant stock
            if (quantity > variantStock) {
                buyNowProcessing = false;
                showNotification(`Only ${variantStock} items available for this variant`, 'error');
                return;
            }
            
            // Additional check: if variant stock is 0
            if (variantStock === 0) {
                buyNowProcessing = false;
                showNotification('This variant is out of stock', 'error');
                return;
            }
            
            // Use buy_now_cart endpoint (doesn't increase quantity if already in cart)
            const requestBody = {
                product_id: productId,
                quantity: quantity
            };
            
            if (variantId) {
                requestBody.variant_id = variantId;
            }
            
            if (selectedColor) {
                requestBody.color = selectedColor;
            }
            
            console.log('[VIEW_ITEM] Buy now - sending request to /buy_now_cart:', JSON.stringify(requestBody));
            
            fetch('/buy_now_cart', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(requestBody)
            })
            .then(response => response.json())
            .then(data => {
                if (data.success && data.cart_id) {
                    // Redirect to checkout with the cart_id
                    window.location.href = `/checkout?cart_ids=${data.cart_id}`;
                } else {
                    buyNowProcessing = false;
                    showNotification(data.message || 'Failed to process order', 'error');
                }
            })
            .catch(error => {
                buyNowProcessing = false;
                console.error('Error:', error);
                showNotification('Connection error. Please try again.', 'error');
            });
        });
    }

    // ===== Add to Cart button functionality with animation =====
    const addToCartBtn = document.querySelector('.add-to-cart-btn');
    let addToCartProcessing = false;
    
    console.log('[VIEW_ITEM] Initializing add to cart button. Already attached?', addToCartBtn?.dataset.listenerAttached);
    
    if (addToCartBtn && !addToCartBtn.dataset.listenerAttached) {
        addToCartBtn.dataset.listenerAttached = 'true';
        console.log('[VIEW_ITEM] Attaching add to cart button listener');
        addToCartBtn.addEventListener('click', function() {
            console.log('[VIEW_ITEM] Add to cart button clicked. Processing:', addToCartProcessing);
            // Prevent double-clicking
            if (addToCartProcessing) {
                console.log('[VIEW_ITEM] Add to cart already processing, ignoring click');
                return;
            }
            addToCartProcessing = true;
            const productId = document.getElementById('favorite-btn')?.dataset.productId;
            const sizeDropdown = document.getElementById('size-dropdown');
            const selectedSize = sizeDropdown ? sizeDropdown.value : null;
            const colorButtons = document.querySelectorAll('.color-option');
            const selectedColor = document.getElementById('selected-color').value;
            
            if (!productId) {
                addToCartProcessing = false;
                showNotification('Product information not found', 'error');
                return;
            }
            
            // Check if color selection is required
            if (colorButtons.length > 0 && !selectedColor) {
                addToCartProcessing = false;
                showNotification('Please select a color', 'error');
                return;
            }
            
            // Check if size selection is required
            if (sizeDropdown && !selectedSize) {
                addToCartProcessing = false;
                showNotification('Please select a size', 'error');
                return;
            }
            
            // Get quantity from input
            const quantityInput = document.getElementById('quantity-input');
            const quantity = quantityInput ? parseInt(quantityInput.value) || 1 : 1;
            
            // Get variant_id and stock based on size and color
            const variantId = window.getVariantId ? window.getVariantId(selectedSize, selectedColor) : null;
            const variantStock = window.getVariantStock ? window.getVariantStock(selectedSize, selectedColor) : 999;
            
            // Check if quantity exceeds variant stock
            if (quantity > variantStock) {
                addToCartProcessing = false;
                showNotification(`Only ${variantStock} items available for this variant`, 'error');
                return;
            }
            
            // Additional check: if variant stock is 0
            if (variantStock === 0) {
                addToCartProcessing = false;
                showNotification('This variant is out of stock', 'error');
                return;
            }
            
            // Trigger flying animation before API call
            createFlyingCartAnimation(this);
            
            // Add to cart via API
            const requestBody = {
                product_id: productId,
                quantity: quantity
            };
            
            if (variantId) {
                requestBody.variant_id = variantId;
            }
            
            if (selectedColor) {
                requestBody.color = selectedColor;
            }
            
            console.log('[VIEW_ITEM] Add to cart - sending request to /add_to_cart:', JSON.stringify(requestBody));
            
            fetch('/add_to_cart', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(requestBody)
            })
            .then(response => response.json())
            .then(data => {
                addToCartProcessing = false;
                if (data.success) {
                    showNotification(data.message || 'Product added to cart!', 'success');
                    // Update cart badge
                    if (typeof window.updateCartBadge === 'function') {
                        window.updateCartBadge();
                    }
                } else {
                    showNotification(data.message || 'Failed to add to cart', 'error');
                }
            })
            .catch(error => {
                addToCartProcessing = false;
                console.error('Error:', error);
                showNotification('Connection error. Please try again.', 'error');
            });
        });
    }
}

// Create flying cart animation
function createFlyingCartAnimation(button) {
    // Get the product image and cart icon
    const productImage = document.querySelector('.product-main-image');
    const cartIcon = document.querySelector('.cart-icon-wrapper');
    
    if (!productImage || !cartIcon || !button) return;
    
    // Get positions - start from button, not image
    const buttonRect = button.getBoundingClientRect();
    const cartRect = cartIcon.getBoundingClientRect();
    
    // Create flying element (clone of product image)
    const flyingImg = document.createElement('img');
    flyingImg.src = productImage.src;
    flyingImg.style.cssText = `
        position: fixed;
        width: 60px;
        height: 60px;
        object-fit: cover;
        border-radius: 8px;
        z-index: 9999;
        pointer-events: none;
        box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        left: ${buttonRect.left + buttonRect.width / 2 - 30}px;
        top: ${buttonRect.top + buttonRect.height / 2 - 30}px;
        transition: all 0.8s cubic-bezier(0.4, 0.0, 0.2, 1);
        opacity: 1;
    `;
    
    document.body.appendChild(flyingImg);
    
    // Trigger animation after a small delay to ensure styles are applied
    setTimeout(() => {
        flyingImg.style.left = `${cartRect.left + cartRect.width / 2 - 10}px`;
        flyingImg.style.top = `${cartRect.top + cartRect.height / 2 - 10}px`;
        flyingImg.style.width = '20px';
        flyingImg.style.height = '20px';
        flyingImg.style.opacity = '0';
        flyingImg.style.transform = 'scale(0.2) rotate(360deg)';
    }, 10);
    
    // Remove flying element after animation
    setTimeout(() => {
        flyingImg.remove();
    }, 800);
}

// Show notification function
function showNotification(message, type = 'info') {
    // Remove any existing notifications first
    const existingNotifications = document.querySelectorAll('.notification');
    existingNotifications.forEach(notif => {
        notif.style.animation = 'slideOut 0.2s ease';
        setTimeout(() => {
            notif.remove();
        }, 150);
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
        animation: slideIn 0.2s ease;
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

    // Remove after 1.5 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.15s ease';
        setTimeout(() => {
            notification.remove();
        }, 150);
    }, 1500);
}

// Initialize on DOMContentLoaded
document.addEventListener('DOMContentLoaded', function() {
    if (!window.viewItemInitialized) {
        window.viewItemInitialized = true;
        initializeViewItem();
    }
});
