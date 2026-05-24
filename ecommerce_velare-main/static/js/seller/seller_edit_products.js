// seller_edit_products.js
// Handles edit product functionality

document.addEventListener('DOMContentLoaded', function() {
    const editProductForm = document.getElementById('editProductForm');
    const cancelBtn = document.getElementById('cancelEditProduct');
    const productImagesInput = document.getElementById('editProductImages');
    const productImagePreview = document.getElementById('editProductImagePreview');
    const productImageImg = document.getElementById('editProductImageImg');
    const uploadPlaceholder = document.getElementById('editUploadPlaceholder');
    const uploadOverlay = document.getElementById('editUploadOverlay');
    const productImagesGrid = document.getElementById('editProductImagesGrid');
    
    // Get product ID from URL
    const urlParams = new URLSearchParams(window.location.search);
    const productId = urlParams.get('id');
    
    // Load product data if ID is present
    if (productId) {
        loadProductData(productId);
    } else {
        showNotification('No product ID provided', 'error');
    }

    // Click on image container to trigger file input
    if (productImagePreview) {
        productImagePreview.addEventListener('click', function() {
            productImagesInput.click();
        });
    }

    // Handle image selection
    if (productImagesInput) {
        productImagesInput.addEventListener('change', function(e) {
            const files = Array.from(e.target.files);
            
            if (files.length > 0) {
                // Validate file type
                const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
                const invalidFiles = files.filter(file => !allowedTypes.includes(file.type));
                
                if (invalidFiles.length > 0) {
                    alert('Only JPG, PNG, and GIF files are allowed.');
                    productImagesInput.value = '';
                    return;
                }
                
                // Validate file size (5MB max per file)
                const maxSize = 5 * 1024 * 1024;
                const oversizedFiles = files.filter(file => file.size > maxSize);
                
                if (oversizedFiles.length > 0) {
                    alert('Each file size must not exceed 5MB.');
                    productImagesInput.value = '';
                    return;
                }
                
                // Limit to 5 images
                const limitedFiles = files.slice(0, 5);
                
                // Show first image as main preview
                const firstFile = limitedFiles[0];
                const reader = new FileReader();
                reader.onload = function(e) {
                    productImageImg.src = e.target.result;
                    productImageImg.style.display = 'block';
                    uploadPlaceholder.style.display = 'none';
                    productImagePreview.classList.add('has-image');
                };
                reader.readAsDataURL(firstFile);
                
                // Show all images in grid
                if (limitedFiles.length > 1) {
                    productImagesGrid.style.display = 'flex';
                    productImagesGrid.innerHTML = '';
                    
                    limitedFiles.slice(1).forEach(file => {
                        const reader = new FileReader();
                        reader.onload = function(e) {
                            const img = document.createElement('img');
                            img.src = e.target.result;
                            img.alt = 'Product Image';
                            productImagesGrid.appendChild(img);
                        };
                        reader.readAsDataURL(file);
                    });
                } else {
                    productImagesGrid.style.display = 'none';
                }
            } else {
                // Reset to default state
                productImageImg.style.display = 'none';
                uploadPlaceholder.style.display = 'flex';
                productImagePreview.classList.remove('has-image');
                productImagesGrid.style.display = 'none';
            }
        });
    }

    // Load product data from API
    async function loadProductData(productId) {
        try {
            const response = await fetch(`/api/products/${productId}`);
            const result = await response.json();
            
            if (!response.ok) {
                throw new Error(result.message || 'Failed to load product');
            }
            
            const product = result.product;
            
            // Populate form fields
            document.getElementById('editProductName').value = product.product_name || '';
            document.getElementById('editProductCategory').value = product.category || '';
            document.getElementById('editProductPrice').value = product.price || '';
            document.getElementById('editProductStock').value = product.stock_quantity || '';
            document.getElementById('editProductDescription').value = product.description || '';
            
            // Set SDG checkboxes
            if (product.materials) {
                if (product.materials.includes('Handmade')) {
                    document.getElementById('editProductHandmade').checked = true;
                }
                if (product.materials.includes('Biodegradable')) {
                    document.getElementById('editProductBiodegradable').checked = true;
                }
            }
            
            // Display product images
            if (product.images && product.images.length > 0) {
                const firstImage = product.images[0];
                
                // Handle both Supabase URLs and local paths
                if (firstImage.startsWith('http://') || firstImage.startsWith('https://')) {
                    productImageImg.src = firstImage;
                } else if (firstImage.startsWith('static/')) {
                    productImageImg.src = '/' + firstImage;
                } else {
                    productImageImg.src = '/static/' + firstImage;
                }
                
                productImageImg.style.display = 'block';
                uploadPlaceholder.style.display = 'none';
                productImagePreview.classList.add('has-image');
                
                // Show additional images in grid
                if (product.images.length > 1) {
                    productImagesGrid.style.display = 'flex';
                    productImagesGrid.innerHTML = '';
                    
                    product.images.slice(1).forEach(imageUrl => {
                        const img = document.createElement('img');
                        
                        // Handle both Supabase URLs and local paths
                        if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
                            img.src = imageUrl;
                        } else if (imageUrl.startsWith('static/')) {
                            img.src = '/' + imageUrl;
                        } else {
                            img.src = '/static/' + imageUrl;
                        }
                        
                        img.alt = 'Product Image';
                        productImagesGrid.appendChild(img);
                    });
                }
            }
            
        } catch (error) {
            console.error('Error loading product:', error);
            showNotification(error.message || 'Failed to load product data', 'error');
        }
    }

    // Form submission
    if (editProductForm) {
        editProductForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const submitBtn = this.querySelector('.btn-primary');
            const originalBtnText = submitBtn.textContent;
            
            try {
                // Get form data
                const formData = new FormData();
                
                // Add form fields with correct names for backend
                formData.append('productName', document.getElementById('editProductName').value);
                formData.append('productCategory', document.getElementById('editProductCategory').value);
                formData.append('productPrice', document.getElementById('editProductPrice').value);
                formData.append('productStock', document.getElementById('editProductStock').value);
                formData.append('productDescription', document.getElementById('editProductDescription').value);
                
                // Add SDG checkboxes
                if (document.getElementById('editProductHandmade').checked) {
                    formData.append('productHandmade', 'handmade');
                }
                if (document.getElementById('editProductBiodegradable').checked) {
                    formData.append('productBiodegradable', 'biodegradable');
                }
                
                // Add images if new ones were selected
                if (productImagesInput.files && productImagesInput.files.length > 0) {
                    Array.from(productImagesInput.files).forEach(file => {
                        formData.append('productImages', file);
                    });
                }
                
                // Validation
                const productName = document.getElementById('editProductName').value.trim();
                const productCategory = document.getElementById('editProductCategory').value;
                const productPrice = document.getElementById('editProductPrice').value;
                const productStock = document.getElementById('editProductStock').value;
                
                if (!productName) {
                    throw new Error('Please enter a product name');
                }
                
                if (!productCategory) {
                    throw new Error('Please select a category');
                }
                
                if (!productPrice || parseFloat(productPrice) <= 0) {
                    throw new Error('Please enter a valid price');
                }
                
                if (!productStock || parseInt(productStock) < 0) {
                    throw new Error('Please enter a valid stock quantity');
                }
                
                // Show loading state
                submitBtn.disabled = true;
                submitBtn.innerHTML = '<span style="display: inline-block; animation: spin 1s linear infinite;">⟳</span> Updating...';
                submitBtn.style.opacity = '0.7';
                
                // Send update request
                const response = await fetch(`/api/products/${productId}`, {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (!response.ok) {
                    throw new Error(result.message || 'Failed to update product');
                }
                
                console.log('Product updated successfully');
                showNotification('Product updated successfully!', 'success');
                
                // Redirect back to product list after delay
                setTimeout(() => {
                    window.location.href = '/seller/product-management?tab=products';
                }, 1500);
                
            } catch (error) {
                console.error('Error updating product:', error);
                showNotification(error.message || 'Failed to update product', 'error');
                
                // Reset button state
                submitBtn.disabled = false;
                submitBtn.textContent = originalBtnText;
                submitBtn.style.opacity = '1';
            }
        });
    }
    
    // Notification helper function
    function showNotification(message, type = 'info') {
        const existingNotif = document.querySelector('.custom-notification');
        if (existingNotif) {
            existingNotif.remove();
        }

        const notification = document.createElement('div');
        notification.className = 'custom-notification';
        
        const styles = {
            success: { 
                bg: 'linear-gradient(135deg, #f8f6f2 0%, #e8e5dc 100%)', 
                border: '#D3BD9B', 
                text: '#2c2236', 
                icon: '✓',
                accent: 'linear-gradient(180deg, #D3BD9B 0%, #c4a882 100%)'
            },
            error: { 
                bg: 'linear-gradient(135deg, #fff5f5 0%, #ffe8e8 100%)', 
                border: '#D3BD9B', 
                text: '#2c2236', 
                icon: '⚠',
                accent: 'linear-gradient(180deg, #c4a882 0%, #D3BD9B 100%)'
            },
            info: { 
                bg: 'linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)', 
                border: '#D3BD9B', 
                text: '#2c2236', 
                icon: 'ℹ',
                accent: 'linear-gradient(180deg, #D3BD9B 0%, #bfa14a 100%)'
            }
        };
        
        const style = styles[type] || styles.info;
        
        notification.style.cssText = `
            position: fixed;
            top: 50px;
            right: 20px;
            background: ${style.bg};
            border: 2px solid ${style.border};
            color: ${style.text};
            padding: 12px 20px;
            border-radius: 0px;
            font-family: 'Goudy Bookletter 1911', 'Goudy Old Style', serif;
            font-size: 0.9rem;
            font-weight: 700;
            display: inline-flex;
            align-items: center;
            gap: 10px;
            box-shadow: 0 8px 32px rgba(44, 34, 54, 0.15);
            z-index: 10000;
            animation: slideInRight 0.4s cubic-bezier(0.4, 0, 0.2, 1), fadeOut 0.4s ease 2.6s;
            max-width: 400px;
            white-space: nowrap;
            overflow: hidden;
        `;
        
        notification.innerHTML = `
            <div style="position: absolute; left: 0; top: 0; bottom: 0; width: 4px; background: ${style.accent};"></div>
            <span style="font-size: 1.3rem; color: #D3BD9B; margin-left: 8px;">${style.icon}</span>
            <span style="flex: 1;">${message}</span>
        `;
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, 3000);
    }
    
    // Add notification animations
    const style = document.createElement('style');
    style.textContent = `
        @keyframes slideInRight {
            from {
                opacity: 0;
                transform: translateX(100px);
            }
            to {
                opacity: 1;
                transform: translateX(0);
            }
        }
        @keyframes fadeOut {
            from { opacity: 1; }
            to { opacity: 0; }
        }
        @keyframes spin {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }
    `;
    document.head.appendChild(style);

    // Cancel button
    if (cancelBtn) {
        cancelBtn.addEventListener('click', function() {
            if (confirm('Are you sure you want to cancel? Any unsaved changes will be lost.')) {
                window.history.back();
            }
        });
    }

    // Price formatting on blur
    const priceInput = document.getElementById('editProductPrice');
    if (priceInput) {
        priceInput.addEventListener('blur', function() {
            const value = parseFloat(this.value.replace(/,/g, ''));
            if (!isNaN(value)) {
                this.value = value.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
            }
        });
        
        // Remove commas before form submission
        priceInput.addEventListener('focus', function() {
            this.value = this.value.replace(/,/g, '');
        });
    }

    // Stock validation
    const stockInput = document.getElementById('editProductStock');
    if (stockInput) {
        stockInput.addEventListener('input', function() {
            let value = parseInt(this.value);
            if (isNaN(value) || value < 0) {
                this.value = 0;
            } else {
                this.value = value;
            }
        });
    }
});