document.addEventListener('DOMContentLoaded', function() {
    // Notification function (same design as register page)
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

    // Image Preview Modal Logic
    const imageModal = document.getElementById('image-preview-modal');
    const imageModalOverlay = document.getElementById('image-preview-modal-overlay');
    const modalImageContent = document.getElementById('modal-image-content');
    const closeModalBtn = document.querySelector('.image-modal-close');

    function showImageModal(src) {
        if (modalImageContent && imageModal && imageModalOverlay) {
            modalImageContent.src = src;
            imageModal.classList.add('show');
            imageModalOverlay.classList.add('show');
        }
    }

    function hideImageModal() {
        if (imageModal && imageModalOverlay) {
            imageModal.classList.remove('show');
            imageModalOverlay.classList.remove('show');
            
            // Clear carousel data
            currentCarouselImages = [];
            currentCarouselIndex = 0;
            
            // Remove carousel controls
            const carouselControls = imageModal.querySelectorAll('.modal-carousel-nav, .modal-carousel-indicator');
            carouselControls.forEach(el => el.remove());
            
            // Clear image src to prevent showing old images
            if (modalImageContent) {
                modalImageContent.src = '';
            }
        }
    }
    
    // Carousel modal for multiple images
    let currentCarouselImages = [];
    let currentCarouselIndex = 0;
    
    function showImageCarouselModal(imageUrls, startIndex = 0) {
        if (!modalImageContent || !imageModal || !imageModalOverlay) return;
        
        console.log('🖼️ Opening carousel with', imageUrls.length, 'images');
        
        currentCarouselImages = imageUrls;
        currentCarouselIndex = startIndex;
        
        // Remove existing controls first (before showing modal)
        const existingControls = imageModal.querySelectorAll('.modal-carousel-nav, .modal-carousel-indicator');
        existingControls.forEach(el => el.remove());
        
        // Show first image
        modalImageContent.src = imageUrls[startIndex];
        imageModal.classList.add('show');
        imageModalOverlay.classList.add('show');
        
        // Add carousel controls if multiple images
        if (imageUrls.length > 1) {
            console.log('✅ Adding carousel controls (prev/next/indicator)');
            
            // Add navigation buttons
            const prevBtn = document.createElement('button');
            prevBtn.className = 'modal-carousel-nav modal-prev-btn';
            prevBtn.innerHTML = '<i class="bi bi-chevron-left"></i>';
            prevBtn.onclick = () => navigateCarousel(-1);
            
            const nextBtn = document.createElement('button');
            nextBtn.className = 'modal-carousel-nav modal-next-btn';
            nextBtn.innerHTML = '<i class="bi bi-chevron-right"></i>';
            nextBtn.onclick = () => navigateCarousel(1);
            
            // Add indicator
            const indicator = document.createElement('div');
            indicator.className = 'modal-carousel-indicator';
            indicator.textContent = `${startIndex + 1} / ${imageUrls.length}`;
            
            imageModal.appendChild(prevBtn);
            imageModal.appendChild(nextBtn);
            imageModal.appendChild(indicator);
            
            console.log('✅ Controls appended to modal');
        } else {
            console.log('ℹ️ Only 1 image, no controls needed');
        }
    }
    
    function navigateCarousel(direction) {
        if (currentCarouselImages.length === 0) return;
        
        currentCarouselIndex = (currentCarouselIndex + direction + currentCarouselImages.length) % currentCarouselImages.length;
        modalImageContent.src = currentCarouselImages[currentCarouselIndex];
        
        // Update indicator
        const indicator = imageModal.querySelector('.modal-carousel-indicator');
        if (indicator) {
            indicator.textContent = `${currentCarouselIndex + 1} / ${currentCarouselImages.length}`;
        }
    }
    
    function toggleVariantDetails(productId) {
        const variantRow = document.querySelector(`.variant-details-row[data-product-id="${productId}"]`);
        const toggleBtn = document.querySelector(`.view-variants-btn[data-product-id="${productId}"]`);
        
        if (variantRow && toggleBtn) {
            const isVisible = variantRow.style.display !== 'none';
            
            if (isVisible) {
                // Collapse
                variantRow.style.display = 'none';
                toggleBtn.innerHTML = '<i class="bi bi-chevron-down"></i>';
                toggleBtn.classList.remove('expanded');
            } else {
                // Expand
                variantRow.style.display = 'table-row';
                toggleBtn.innerHTML = '<i class="bi bi-chevron-up"></i>';
                toggleBtn.classList.add('expanded');
            }
        }
    }

    if (closeModalBtn) {
        closeModalBtn.addEventListener('click', hideImageModal);
    }
    if (imageModalOverlay) {
        imageModalOverlay.addEventListener('click', hideImageModal);
    }

    // Main tab/sub-tab logic with animation
    const mainTabs = document.querySelectorAll('.main-tab');
    const productManagementTab = document.getElementById('productManagementTab');
    const productManagementSubTabs = document.getElementById('productManagementSubTabs');
    const ordersTab = document.getElementById('ordersTab');
    const productSoldTab = document.getElementById('productSoldTab');
    const productListTab = document.getElementById('productListTab');
    const addProductTab = document.getElementById('addProductTab');
    const accountCardContainer = document.getElementById('accountCardContainer');

    // Open Product Management by default
    if (productManagementTab && productManagementSubTabs) {
        productManagementTab.classList.add('active');
        productManagementSubTabs.classList.add('open');
        productManagementSubTabs.style.display = 'flex';
    }

    mainTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            // Remove active from all main tabs
            mainTabs.forEach(t => t.classList.remove('active'));

            // Animate sub-tabs closing if not Product Management
            if (productManagementSubTabs && tab !== productManagementTab && productManagementSubTabs.classList.contains('open')) {
                productManagementSubTabs.classList.remove('open');
                productManagementSubTabs.classList.add('closing');
                setTimeout(() => {
                    productManagementSubTabs.classList.remove('closing');
                    productManagementSubTabs.style.display = 'none';
                }, 280);
            } else if (productManagementSubTabs && tab === productManagementTab) {
                productManagementSubTabs.style.display = 'flex';
                setTimeout(() => {
                    productManagementSubTabs.classList.add('open');
                }, 10);
            } else if (productManagementSubTabs) {
                productManagementSubTabs.classList.remove('open', 'closing');
                productManagementSubTabs.style.display = 'none';
            }

            // If Product Management, show sub-tabs
            if (tab === productManagementTab) {
                tab.classList.add('active');
                productManagementSubTabs.style.display = 'flex';
                setTimeout(() => {
                    productManagementSubTabs.classList.add('open');
                }, 10);
            } else {
                tab.classList.add('active');
            }
        });
    });

    // Check URL parameters for tab navigation
    const urlParams = new URLSearchParams(window.location.search);
    const activeTab = urlParams.get('tab');
    
    if (activeTab === 'orders') {
        document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
        ordersTab.classList.add('active');
        loadOrdersContent();
    } else if (activeTab === 'product-sold') {
        document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
        productSoldTab.classList.add('active');
        loadProductSoldContent();
    } else if (activeTab === 'products') {
        document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
        productListTab.classList.add('active');
        loadProductListContent();
    } else {
        // Default to Orders tab if no URL parameter
        document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
        ordersTab.classList.add('active');
        loadOrdersContent();
    }

    // Sub-tab content switching
    function loadOrdersContent() {
        if (!accountCardContainer) return;
        // Table HTML (minimal tbody, rows are inserted by JS)
        const ordersHTML = `
            <div class="product-management-main-content">
                <h2 class="product-management-title">Orders Management</h2>
                <hr class="product-management-divider">
                <div class="product-management-content">
                    <div class="product-list-controls">
                        <div class="search-filter-section">
                            <div class="search-box">
                                <i class="bi bi-search"></i>
                                <input type="text" placeholder="Search orders..." id="orderSearch">
                            </div>
                            <div class="filter-dropdown">
                                <select id="orderStatusFilter">
                                    <option value="">All Status</option>
                                    <option value="pending">Pending</option>
                                    <option value="in_transit">In Transit</option>
                                    <option value="delivered">Delivered</option>
                                    <option value="cancelled">Cancelled</option>
                                </select>
                            </div>
                            <div class="filter-dropdown date-range-filter">
                                <input type="date" id="orderDateFrom" placeholder="From Date">
                                <span style="margin: 0 8px;">to</span>
                                <input type="date" id="orderDateTo" placeholder="To Date">
                            </div>
                        </div>
                    </div>
                    <div class="product-list-table">
                        <table class="products-table">
                            <thead>
                                <tr>
                                    <th>Order #</th>
                                    <th>Product Image</th>
                                    <th>Product Name</th>
                                    <th>Customer</th>
                                    <th>Date</th>
                                    <th>Amount</th>
                                    <th>Status</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody id="orderTableBody">
                                <tr><td colspan="8" style="text-align:center;padding:32px;">Loading orders...</td></tr>
                            </tbody>
                        </table>
                                        </div>
                                        </div>
                                        </div>
        `;
        accountCardContainer.innerHTML = ordersHTML;
        fetchAndDisplayOrders();
        attachOrdersEventListeners();
        
        // Make fetchAndDisplayOrders globally accessible for modal functions
        window.refreshOrders = fetchAndDisplayOrders;
    }

    // Fetch seller's orders from backend & render
    async function fetchAndDisplayOrders() {
        const orderTableBody = document.getElementById('orderTableBody');
        if (!orderTableBody) return;
        try {
            const response = await fetch('/api/orders/seller');
            const res = await response.json();
            orderTableBody.innerHTML = '';
            if (!res.success || !res.orders || res.orders.length === 0) {
                orderTableBody.innerHTML = `<tr><td colspan="8" style="text-align:center;padding:32px;">No orders found.</td></tr>`;
                return;
            }
            res.orders.forEach(order => {
                const item = order.items[0] || {};
                // Check if image is a Supabase URL or local path
                let productImage = '/static/images/image.png';
                if (item.image) {
                    if (item.image.startsWith('http://') || item.image.startsWith('https://')) {
                        productImage = item.image; // Supabase URL
                    } else {
                        productImage = `/${item.image}`; // Local path
                    }
                }
                
                // Create product display with dropdown for multiple items
                let productDisplay = '';
                if (order.items.length > 1) {
                    // Multiple products - show dropdown with full details
                    const firstItemVariant = item.variant_color || item.variant_size 
                        ? `<span class="item-variant">${item.variant_color || ''}${item.variant_color && item.variant_size ? ' • ' : ''}${item.variant_size || ''}</span>`
                        : '';
                    const firstItemQty = `<span class="item-qty-inline">Qty: ${item.quantity}</span>`;
                    
                    productDisplay = `
                        <div class="product-dropdown-container">
                            <div class="product-main-item">
                                <span class="product-name">${item.product_name}</span>
                                ${firstItemVariant}
                                ${firstItemQty}
                                <button class="product-dropdown-toggle" data-order-id="${order.order_id}">
                                    <i class="bi bi-chevron-down"></i>
                                    <span class="item-count">+${order.items.length - 1} more</span>
                                </button>
                            </div>
                            <div class="product-dropdown-list" id="dropdown-${order.order_id}" style="display: none;">
                                ${order.items.slice(1).map(it => {
                                    // Check if image is Supabase URL or local path
                                    let itemImage = '/static/images/image.png';
                                    if (it.image) {
                                        if (it.image.startsWith('http://') || it.image.startsWith('https://')) {
                                            itemImage = it.image; // Supabase URL
                                        } else {
                                            itemImage = `/${it.image}`; // Local path
                                        }
                                    }
                                    const itemVariant = `${it.variant_color || ''}${it.variant_color && it.variant_size ? ' • ' : ''}${it.variant_size || ''}`;
                                    return `
                                        <div class="dropdown-item-detailed">
                                            <div class="item-image">
                                                <img src="${itemImage}" alt="${it.product_name}">
                                            </div>
                                            <div class="item-details">
                                                <div class="item-name">${it.product_name}</div>
                                                <div class="item-variant">${itemVariant}</div>
                                            </div>
                                            <div class="item-qty">Qty: ${it.quantity}</div>
                                        </div>
                                    `;
                                }).join('')}
                            </div>
                        </div>
                    `;
                } else {
                    // Single product with variant info and quantity
                    const singleVariant = item.variant_color || item.variant_size 
                        ? `<div class="item-variant-inline">${item.variant_color || ''}${item.variant_color && item.variant_size ? ' • ' : ''}${item.variant_size || ''}</div>`
                        : '';
                    const singleQty = `<div class="item-qty-inline">Qty: ${item.quantity}</div>`;
                    productDisplay = `
                        <div class="product-single">
                            <span class="product-name">${item.product_name || ''}</span>
                            ${singleVariant}
                            ${singleQty}
                        </div>
                    `;
                }
                // Status badge class
                let statusClass = '';
                if (order.order_status === 'pending') statusClass = 'status-pending';
                else if (order.order_status === 'in_transit') statusClass = 'status-shipped';
                else if (order.order_status === 'delivered') statusClass = 'status-delivered';
                else if (order.order_status === 'cancelled') statusClass = 'status-cancelled';
                else statusClass = '';
                // Row HTML
                // Determine button text and action based on delivery status
                let buttonHtml = '';
                const deliveryStatus = order.delivery_status;
                
                if (order.order_status === 'pending') {
                    if (!deliveryStatus || deliveryStatus === 'none' || deliveryStatus === null) {
                        // Step 1: Preparing Package
                        buttonHtml = `<button class="action-btn preparing-btn" data-order-id="${order.order_id}" data-action="preparing">
                            <i class="bi bi-box-seam"></i>Preparing Package
                        </button>`;
                    } else if (deliveryStatus === 'preparing') {
                        // Step 2: Ready for Pickup
                        buttonHtml = `<button class="action-btn pickup-btn" data-order-id="${order.order_id}" data-action="ready">
                            <i class="bi bi-box-arrow-up"></i>Ready for Pickup
                        </button>`;
                    } else if (deliveryStatus === 'pending') {
                        // Step 3: Waiting for rider - keep as button (disabled)
                        buttonHtml = `<button class="action-btn status-btn" disabled>
                            <i class="bi bi-clock-history"></i>For Pickup
                        </button>`;
                    } else if (deliveryStatus === 'assigned') {
                        // Step 4: Rider assigned (accepted but not picked up yet)
                        buttonHtml = `<button class="action-btn status-btn" disabled>
                            <i class="bi bi-person-check"></i>Rider Assigned
                        </button>`;
                    } else if (deliveryStatus === 'in_transit') {
                        // Step 5: Rider picked up the item and is delivering
                        buttonHtml = `<button class="action-btn status-btn" disabled>
                            <i class="bi bi-truck"></i>In Transit
                        </button>`;
                    }
                } else if (order.order_status === 'in_transit') {
                    buttonHtml = `<button class="action-btn status-btn" disabled>
                        <i class="bi bi-truck"></i>In Transit
                    </button>`;
                } else if (order.order_status === 'delivered') {
                    buttonHtml = `<button class="action-btn status-btn" disabled>
                        <i class="bi bi-check-circle"></i>Delivered
                    </button>`;
                } else if (order.order_status === 'cancelled') {
                    buttonHtml = `<button class="action-btn status-btn" disabled>
                        <i class="bi bi-x-circle"></i>Cancelled
                    </button>`;
                }
                
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${order.order_number}</td>
                    <td><div class="product-image-cell"><img src="${productImage}" alt="Product"></div></td>
                    <td><div class="product-name-cell">${productDisplay}</div></td>
                    <td>${order.buyer_name || ''}</td>
                    <td>${order.created_at ? new Date(order.created_at).toLocaleDateString() : ''}</td>
                    <td>₱${parseFloat(order.subtotal).toLocaleString('en-PH', {minimumFractionDigits:2})}</td>
                    <td><span class="status-badge ${statusClass}">${capitalize(order.order_status)}</span></td>
                    <td>
                        <div class="action-buttons">
                            ${buttonHtml}
                        </div>
                    </td>
                `;
                orderTableBody.appendChild(row);
                
                // Add dropdown toggle event listener for multiple products
                if (order.items.length > 1) {
                    const toggleBtn = row.querySelector('.product-dropdown-toggle');
                    if (toggleBtn) {
                        toggleBtn.addEventListener('click', function(e) {
                            e.stopPropagation();
                            const dropdown = document.getElementById(`dropdown-${order.order_id}`);
                            const icon = this.querySelector('i');
                            if (dropdown.style.display === 'none') {
                                dropdown.style.display = 'block';
                                icon.classList.remove('bi-chevron-down');
                                icon.classList.add('bi-chevron-up');
                            } else {
                                dropdown.style.display = 'none';
                                icon.classList.remove('bi-chevron-up');
                                icon.classList.add('bi-chevron-down');
                            }
                        });
                    }
                }
            });
            
            // Add event listeners to preparing buttons
            document.querySelectorAll('.preparing-btn').forEach(btn => {
                btn.addEventListener('click', function() {
                    const orderId = this.getAttribute('data-order-id');
                    console.log('Preparing button clicked, orderId:', orderId);
                    showPreparingModal(orderId);
                });
            });
            
            // Add event listeners to pickup buttons
            document.querySelectorAll('.pickup-btn').forEach(btn => {
                btn.addEventListener('click', function() {
                    const orderId = this.getAttribute('data-order-id');
                    console.log('Pickup button clicked, orderId:', orderId);
                    showPickupModal(orderId);
                });
            });
        } catch (error) {
            orderTableBody.innerHTML = `<tr><td colspan="8" style="text-align:center;color:#d32f2f;padding:28px;">Failed to load orders.</td></tr>`;
        }
    }
    
    // Show notification function
    function showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = 'notification';
        
        // Icon based on type
        let icon = 'info-circle';
        if (type === 'success') icon = 'check-circle';
        else if (type === 'error') icon = 'x-circle';
        
        // Colors based on type
        let bgColor = '#eff6ff';
        let textColor = '#1e40af';
        let borderColor = '#3b82f6';
        
        if (type === 'success') {
            bgColor = '#ecfdf5';
            textColor = '#059669';
            borderColor = '#10b981';
        } else if (type === 'error') {
            bgColor = '#fef2f2';
            textColor = '#dc2626';
            borderColor = '#f87171';
        }
        
        notification.innerHTML = `<i class="bi bi-${icon}"></i><span>${message}</span>`;
        notification.style.cssText = `
            position: fixed; top: 100px; right: 30px; padding: 16px 24px;
            background: ${bgColor};
            color: ${textColor};
            border: 2px solid ${borderColor};
            border-radius: 8px; box-shadow: 0 4px 16px rgba(0,0,0,0.1);
            z-index: 10000; display: flex; align-items: center; gap: 12px;
            font-family: 'Montserrat', sans-serif; font-size: 0.95rem; font-weight: 600;
            animation: slideIn 0.3s ease;
        `;
        document.body.appendChild(notification);
        setTimeout(() => notification.remove(), 2000);
    }
    
    // Utility: capitalize
    function capitalize(str) {
        if (!str) return '';
        return str.charAt(0).toUpperCase() + str.slice(1).replace('_', ' ');
    }

    async function loadProductListContent() {
        if (!accountCardContainer) return;
        
        const productListHTML = `
            <div class="product-management-main-content">
                <h2 class="product-management-title">Product List</h2>
                <hr class="product-management-divider">
                
                <div class="product-management-content">
                    <div class="product-list-controls">
                        <div class="search-filter-section">
                            <div class="search-box">
                                <i class="bi bi-search"></i>
                                <input type="text" placeholder="Search products..." id="productSearch">
                            </div>
                            <div class="filter-dropdown">
                                <select id="categoryFilter">
                                    <option value="">All Categories</option>
                                    <option value="dresses">Dresses</option>
                                    <option value="skirts">Skirts</option>
                                    <option value="tops">Tops</option>
                                    <option value="blouses">Blouses</option>
                                    <option value="Active Wear">Activewear</option>
                                    <option value="Yoga Pants">Yoga Pants</option>
                                    <option value="lingerie">Lingerie</option>
                                    <option value="sleepwear">Sleepwear</option>
                                    <option value="jackets">Jackets</option>
                                    <option value="coats">Coats</option>
                                    <option value="shoes">Shoes</option>
                                    <option value="accessories">Accessories</option>
                                </select>
                            </div>
                            <div class="status-filter-buttons">
                                <button class="status-filter-btn active" id="filterActive" data-status="active">
                                    <i class="bi bi-check-circle"></i> Active
                                </button>
                                <button class="status-filter-btn" id="filterArchived" data-status="archived">
                                    <i class="bi bi-archive"></i> Archived
                                </button>
                            </div>
                        </div>
                        <button class="add-product-btn" id="addNewProductBtn">
                            <i class="bi bi-plus-circle"></i>
                            Add New Product
                        </button>
                    </div>

                    <div class="product-list-table">
                        <table class="products-table">
                            <thead>
                                <tr>
                                    <th>Product Image</th>
                                    <th>Product Name</th>
                                    <th>Category</th>
                                    <th>Price</th>
                                    <th>Status</th>
                                    <th>Variants</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody id="productTableBody">
                                <tr>
                                    <td colspan="6" style="text-align: center; padding: 40px;">
                                        <i class="bi bi-hourglass-split" style="font-size: 2em; color: #D3BD9B;"></i>
                                        <p style="margin-top: 10px; color: #666;">Loading products...</p>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        `;
        
        accountCardContainer.innerHTML = productListHTML;
        
        // Fetch products from API
        await fetchAndDisplayProducts();
        
        // Re-attach event listeners for the new content
        attachProductListEventListeners();
    }

    async function fetchAndDisplayProducts() {
        try {
            // Use proper cache headers instead of cache-busting timestamp
            const response = await fetch('/api/products/list', {
                method: 'GET',
                cache: 'no-store',
                headers: {
                    'Cache-Control': 'no-cache',
                    'Pragma': 'no-cache'
                }
            });
            const result = await response.json();
            
            console.log('📦 Fetched products from API:', result.products?.length || 0);
            if (result.products && result.products.length > 0) {
                console.log('Stock quantities:', result.products.map(p => ({
                    id: p.product_id,
                    name: p.product_name,
                    stock: p.stock_quantity
                })));
                
                // Log the first product in detail
                console.log('First product details:', result.products[0]);
            }
            
            if (!response.ok) {
                throw new Error(result.message || 'Failed to fetch products');
            }
            
            const productTableBody = document.getElementById('productTableBody');
            if (!productTableBody) return;
            
            // Clear loading message
            productTableBody.innerHTML = '';
            
            if (!result.products || result.products.length === 0) {
                productTableBody.innerHTML = `
                    <tr>
                        <td colspan="6" style="text-align: center; padding: 40px;">
                            <i class="bi bi-inbox" style="font-size: 2em; color: #D3BD9B;"></i>
                            <p style="margin-top: 10px; color: #666;">No products yet. Add your first product!</p>
                        </td>
                    </tr>
                `;
                return;
            }
            
            // Get current status filter (default to active)
            let currentStatusFilter = 'active';
            const activeBtn = document.getElementById('filterActive');
            const archivedBtn = document.getElementById('filterArchived');
            if (archivedBtn && archivedBtn.classList.contains('active')) {
                currentStatusFilter = 'archived';
            }
            
            // Filter products based on status
            const filteredProducts = result.products.filter(product => {
                if (currentStatusFilter === 'active') {
                    return product.is_active === 1 || product.is_active === true;
                } else {
                    return product.is_active === 0 || product.is_active === false;
                }
            });
            
            // Display products
            filteredProducts.forEach(product => {
                // Check if image is a Supabase URL or local path
                let imageUrl = '/static/images/user.png';
                if (product.primary_image) {
                    if (product.primary_image.startsWith('http://') || product.primary_image.startsWith('https://')) {
                        imageUrl = product.primary_image; // Supabase URL
                    } else {
                        imageUrl = `/${product.primary_image}`; // Local path
                    }
                }
                
                // Get unique colors from variants
                const uniqueColors = [];
                const colorMap = new Map();
                if (product.variants && product.variants.length > 0) {
                    product.variants.forEach(variant => {
                        if (variant.hex_code && !colorMap.has(variant.hex_code)) {
                            colorMap.set(variant.hex_code, {
                                hex: variant.hex_code,
                                name: variant.color_name || variant.color
                            });
                            uniqueColors.push(colorMap.get(variant.hex_code));
                        }
                    });
                }
                
                // Generate color swatches HTML
                const maxVisibleColors = 5;
                let colorSwatchesHTML = '';
                if (uniqueColors.length > 0) {
                    const visibleColors = uniqueColors.slice(0, maxVisibleColors);
                    colorSwatchesHTML = visibleColors.map(color => 
                        `<span class="color-swatch" style="background-color: ${color.hex};" title="${color.name}"></span>`
                    ).join('');
                    
                    if (uniqueColors.length > maxVisibleColors) {
                        colorSwatchesHTML += `<span class="color-more">+${uniqueColors.length - maxVisibleColors}</span>`;
                    }
                    
                    colorSwatchesHTML += `<button class="view-variants-btn" data-product-id="${product.product_id}" title="View all variants">
                        <i class="bi bi-chevron-down"></i>
                    </button>`;
                } else {
                    colorSwatchesHTML = '<span style="color: #999;">No variants</span>';
                }
                
                const row = document.createElement('tr');
                row.className = 'product-row';
                row.dataset.productId = product.product_id;
                row.innerHTML = `
                    <td>
                        <div class="product-image-cell">
                            <img src="${imageUrl}" alt="${product.product_name}" class="clickable-image" data-product-id="${product.product_id}" title="Click to view product">
                        </div>
                    </td>
                    <td>
                        <div class="product-name-cell">
                            <span class="product-name">${product.product_name}</span>
                        </div>
                    </td>
                    <td>${product.category}</td>
                    <td>₱${parseFloat(product.price).toLocaleString('en-PH', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                    <td>
                        <span class="status-badge ${product.is_active ? 'status-active' : 'status-archived'}">
                            <i class="bi ${product.is_active ? 'bi-check-circle' : 'bi-archive'}"></i>
                            ${product.is_active ? 'Active' : 'Archived'}
                        </span>
                    </td>
                    <td>
                        <div class="variants-cell">
                            ${colorSwatchesHTML}
                        </div>
                    </td>
                    <td>
                        <div class="action-buttons">
                            <button id="add-variant-btn-${product.product_id}" class="action-btn add-variant-btn" title="Add Variant" data-product-id="${product.product_id}">
                                <i class="bi bi-plus-circle"></i>
                            </button>
                            <button class="action-btn edit-btn" title="Edit" data-product-id="${product.product_id}">
                                <i class="bi bi-pencil"></i>
                            </button>
                            <button class="action-btn archive-btn" title="${product.is_active ? (product.has_ongoing_orders ? 'Cannot archive yet - product has ongoing orders. Complete them first.' : 'Archive') : 'Unarchive'}" data-product-id="${product.product_id}" data-is-active="${product.is_active}" data-has-ongoing-orders="${product.has_ongoing_orders ? 'true' : 'false'}">
                                <i class="bi ${product.is_active ? 'bi-archive' : 'bi-arrow-counterclockwise'}"></i>
                            </button>
                            <button class="action-btn delete-btn" title="${product.has_orders ? 'Cannot delete - product has existing orders. Archive it instead.' : 'Delete'}" data-product-id="${product.product_id}" ${product.has_orders ? 'disabled' : ''}>
                                <i class="bi bi-trash"></i>
                            </button>
                        </div>
                    </td>
                `;
                productTableBody.appendChild(row);
                
                // Create expandable row for variant details (hidden by default)
                if (product.variants && product.variants.length > 0) {
                    const variantRow = document.createElement('tr');
                    variantRow.className = 'variant-details-row';
                    variantRow.dataset.productId = product.product_id;
                    variantRow.style.display = 'none';
                    
                    // Build variant details table
                    let variantTableHTML = `
                        <table class="variant-details-table">
                            <thead>
                                <tr>
                                    <th>Image</th>
                                    <th>Color</th>
                                    <th>Size</th>
                                    <th>Stock</th>
                                </tr>
                            </thead>
                            <tbody>
                    `;
                    
                    product.variants.forEach(variant => {
                        // Get all images for this variant
                        let variantImagesHTML = '';
                        let imagesToDisplay = variant.images || [];
                        
                        // If this variant has no images, find images from same-color variant
                        if ((!imagesToDisplay || imagesToDisplay.length === 0) && variant.hex_code) {
                            const sameColorVariant = product.variants.find(v => 
                                v.hex_code === variant.hex_code && v.images && v.images.length > 0
                            );
                            if (sameColorVariant) {
                                imagesToDisplay = sameColorVariant.images;
                            }
                        }
                        
                        if (imagesToDisplay && imagesToDisplay.length > 0) {
                            // Show all images with count badge
                            const firstImage = imagesToDisplay[0];
                            // Check if image is Supabase URL or local path
                            let firstImageUrl = '/static/images/user.png';
                            if (firstImage.url) {
                                if (firstImage.url.startsWith('http://') || firstImage.url.startsWith('https://')) {
                                    firstImageUrl = firstImage.url; // Supabase URL
                                } else {
                                    firstImageUrl = `/${firstImage.url}`; // Local path
                                }
                            }
                            variantImagesHTML = `
                                <div class="variant-images-preview">
                                    <img src="${firstImageUrl}" alt="${variant.color_name || variant.color}" 
                                         class="variant-image-thumb clickable-variant-image" 
                                         data-variant-id="${variant.variant_id}"
                                         data-product-id="${product.product_id}"
                                         title="Click to view all ${imagesToDisplay.length} images">
                                    ${imagesToDisplay.length > 1 ? `<span class="image-count-badge">+${imagesToDisplay.length - 1}</span>` : ''}
                                </div>
                            `;
                        } else {
                            // Fallback to single image_url
                            const variantImageUrl = variant.image_url || imageUrl;
                            // Check if image is Supabase URL or local path
                            let displayImageUrl = '/static/images/user.png';
                            if (variantImageUrl) {
                                if (variantImageUrl.startsWith('http://') || variantImageUrl.startsWith('https://')) {
                                    displayImageUrl = variantImageUrl; // Supabase URL
                                } else {
                                    displayImageUrl = `/${variantImageUrl}`; // Local path
                                }
                            }
                            variantImagesHTML = `
                                <img src="${displayImageUrl}" alt="${variant.color_name || variant.color}" 
                                     class="variant-image-thumb clickable-variant-image"
                                     data-variant-id="${variant.variant_id}"
                                     data-product-id="${product.product_id}"
                                     title="Click to view">
                            `;
                        }
                        
                        variantTableHTML += `
                            <tr>
                                <td>${variantImagesHTML}</td>
                                <td>
                                    <div class="variant-color-info">
                                        <span class="color-swatch" style="background-color: ${variant.hex_code};"></span>
                                        <span>${variant.color_name || variant.color}</span>
                                    </div>
                                </td>
                                <td>${variant.size}</td>
                                <td>
                                    ${variant.stock_quantity === 0 ? 
                                        '<span class="out-of-stock-text">Out of Stock</span>' : 
                                        variant.stock_quantity
                                    }
                                </td>
                            </tr>
                        `;
                    });
                    
                    variantTableHTML += `
                            </tbody>
                        </table>
                    `;
                    
                    variantRow.innerHTML = `
                        <td colspan="6">
                            <div class="variant-details-container">
                                ${variantTableHTML}
                            </div>
                        </td>
                    `;
                    
                    productTableBody.appendChild(variantRow);
                }
            });

            // Add event listeners for the new clickable images
            document.querySelectorAll('.clickable-image').forEach(img => {
                img.addEventListener('click', function(event) {
                    event.preventDefault();
                    event.stopPropagation();
                    
                    const productId = parseInt(this.dataset.productId);
                    const product = result.products.find(p => p.product_id === productId);
                    
                    if (product && product.variants && product.variants.length > 0) {
                        // Collect all images from all variants
                        const allImages = [];
                        product.variants.forEach(variant => {
                            if (variant.images && variant.images.length > 0) {
                                variant.images.forEach(img => {
                                    allImages.push(img.url);
                                });
                            }
                        });
                        
                        // Remove duplicates and show carousel
                        const uniqueImages = [...new Set(allImages)];
                        if (uniqueImages.length > 0) {
                            // Handle both Supabase URLs and local paths
                            const formattedImages = uniqueImages.map(url => {
                                if (url.startsWith('http://') || url.startsWith('https://')) {
                                    return url; // Supabase URL - use as-is
                                } else {
                                    return '/' + url; // Local path - add slash
                                }
                            });
                            showImageCarouselModal(formattedImages, 0);
                        } else {
                            showImageModal(this.src);
                        }
                    } else {
                        showImageModal(this.src);
                    }
                });
            });
            
            // Add event listeners for variant-specific images
            document.querySelectorAll('.clickable-variant-image').forEach(img => {
                img.addEventListener('click', function(event) {
                    event.preventDefault();
                    event.stopPropagation();
                    
                    const productId = parseInt(this.dataset.productId);
                    const variantId = parseInt(this.dataset.variantId);
                    const product = result.products.find(p => p.product_id === productId);
                    
                    if (product && product.variants) {
                        const variant = product.variants.find(v => v.variant_id === variantId);
                        
                        let imagesToShow = variant && variant.images ? variant.images : [];
                        
                        // If this variant has no images, find images from same-color variant
                        if ((!imagesToShow || imagesToShow.length === 0) && variant && variant.hex_code) {
                            const sameColorVariant = product.variants.find(v => 
                                v.hex_code === variant.hex_code && v.images && v.images.length > 0
                            );
                            if (sameColorVariant) {
                                imagesToShow = sameColorVariant.images;
                            }
                        }
                        
                        if (imagesToShow && imagesToShow.length > 0) {
                            // Show all images for this variant (or same-color variant)
                            const variantImages = imagesToShow.map(img => {
                                // Check if image is Supabase URL or local path
                                if (img.url.startsWith('http://') || img.url.startsWith('https://')) {
                                    return img.url; // Supabase URL
                                } else {
                                    return '/' + img.url; // Local path
                                }
                            });
                            if (variantImages.length > 1) {
                                showImageCarouselModal(variantImages, 0);
                            } else {
                                showImageModal(variantImages[0]);
                            }
                        } else {
                            showImageModal(this.src);
                        }
                    } else {
                        showImageModal(this.src);
                    }
                });
            });
            
            // Add event listeners for view variants buttons
            document.querySelectorAll('.view-variants-btn').forEach(btn => {
                btn.addEventListener('click', function(event) {
                    event.preventDefault();
                    event.stopPropagation();
                    toggleVariantDetails(this.dataset.productId);
                });
            });
            
            // Add event listeners for add variant buttons
            document.querySelectorAll('.add-variant-btn').forEach(btn => {
                btn.addEventListener('click', function(event) {
                    event.preventDefault();
                    event.stopPropagation();
                    const productId = this.dataset.productId;
                    console.log('Add Variant button clicked for product ID:', productId);
                    openAddVariantModal(productId);
                });
            });
            
            // Add event listeners for edit buttons
            document.querySelectorAll('.edit-btn').forEach(btn => {
                btn.addEventListener('click', function(event) {
                    event.preventDefault();
                    event.stopPropagation();
                    const productId = this.dataset.productId;
                    console.log('Edit button clicked for product ID:', productId);
                    openEditProductModal(productId);
                });
            });
            
            // Add event listeners for archive buttons
            document.querySelectorAll('.archive-btn').forEach(btn => {
                btn.addEventListener('click', function(event) {
                    event.preventDefault();
                    event.stopPropagation();
                    const productId = this.dataset.productId;
                    const isActiveRaw = this.dataset.isActive;
                    const isActive = isActiveRaw === 'true' || isActiveRaw === '1' || isActiveRaw === 1 || isActiveRaw === true;
                    const hasOngoingOrders = this.dataset.hasOngoingOrders === 'true';
                    const row = this.closest('tr');
                    const productName = row.querySelector('.product-name').textContent;

                    console.log('Archive button clicked:', { productId, isActiveRaw, isActive, hasOngoingOrders });

                    // If the seller is trying to ARCHIVE a product that still has
                    // ongoing orders, show a clear notification and skip the modal
                    // entirely. The backend will block the request anyway, but
                    // intercepting here means the seller sees the reason instantly.
                    if (isActive && hasOngoingOrders) {
                        showNotification(
                            `Cannot archive "${productName}" yet. It has ongoing orders that need to be completed or cancelled first.`,
                            'error'
                        );
                        return;
                    }

                    // Show archive/unarchive modal
                    showArchiveModal(productId, productName, isActive);
                });
            });
            
            // Add event listeners for delete buttons
            document.querySelectorAll('.delete-btn').forEach(btn => {
                btn.addEventListener('click', function(event) {
                    event.preventDefault();
                    event.stopPropagation();
                    if (this.disabled) return;
                    const productId = this.dataset.productId;
                    const row = this.closest('tr');
                    const productName = row.querySelector('.product-name').textContent;
                    
                    // Show delete confirmation modal
                    showDeleteProductModal(productId, productName);
                });
            });
            
        } catch (error) {
            console.error('Error fetching products:', error);
            const productTableBody = document.getElementById('productTableBody');
            if (productTableBody) {
                productTableBody.innerHTML = `
                    <tr>
                        <td colspan="8" style="text-align: center; padding: 40px; color: #d32f2f;">
                            <i class="bi bi-exclamation-triangle" style="font-size: 2em;"></i>
                            <p style="margin-top: 10px;">Failed to load products. Please try again.</p>
                        </td>
                    </tr>
                `;
            }
        }
    }

    function loadProductSoldContent() {
        if (!accountCardContainer) return;
        
        const productSoldHTML = `
            <div class="product-management-main-content">
                <h2 class="product-management-title">Product Sold</h2>
                <hr class="product-management-divider">
                
                <div class="product-management-content">
                    <div class="product-list-controls">
                        <div class="search-filter-section">
                            <div class="search-box">
                                <i class="bi bi-search"></i>
                                <input type="text" placeholder="Search sold products..." id="productSoldSearch">
                            </div>
                            <div class="filter-dropdown date-range-filter">
                                <input type="date" id="productSoldDateFrom" placeholder="From Date">
                                <span style="margin: 0 8px;">to</span>
                                <input type="date" id="productSoldDateTo" placeholder="To Date">
                            </div>
                        </div>
                    </div>

                    <div class="product-list-table">
                        <table class="products-table">
                            <thead>
                                <tr>
                                    <th>Number</th>
                                    <th>Products</th>
                                    <th>Order Receive Date</th>
                                    <th>Buyer</th>
                                    <th>Order Total</th>
                                    <th>Commission (5%)</th>
                                </tr>
                            </thead>
                            <tbody id="productSoldTableBody">
                                <tr>
                                    <td colspan="6" style="text-align: center; padding: 40px;">
                                        <div class="loading-spinner">Loading sold products...</div>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        `;
        
        accountCardContainer.innerHTML = productSoldHTML;
        
        // Fetch and display sold products
        fetchAndDisplaySoldProducts();
        
        // Re-attach event listeners for the new content
        attachProductSoldEventListeners();
    }
    
    function fetchAndDisplaySoldProducts() {
        fetch('/api/products/sold')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    displaySoldProducts(data.sold_orders);
                } else {
                    console.error('Error loading sold products:', data.message);
                    showEmptySoldProducts();
                }
            })
            .catch(error => {
                console.error('Error fetching sold products:', error);
                showEmptySoldProducts();
            });
    }
    
    function displaySoldProducts(soldOrders) {
        const tbody = document.getElementById('productSoldTableBody');
        if (!tbody) return;
        
        if (soldOrders.length === 0) {
            showEmptySoldProducts();
            return;
        }
        
        tbody.innerHTML = soldOrders.map((order, index) => {
            const receivedDate = new Date(order.order_received_date).toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            });
            
            const orderTotal = parseFloat(order.order_total);
            const commission = parseFloat(order.commission_amount);
            
            // Build products list HTML
            const productsHTML = order.items.map(item => {
                const variant = [];
                if (item.variant_color) variant.push(item.variant_color);
                if (item.variant_size) variant.push(item.variant_size);
                const variantText = variant.length > 0 ? ` (${variant.join(', ')})` : '';
                
                return `
                    <div class="product-item-compact">
                        <span class="product-name">${item.product_name}</span>
                        ${variantText ? `<span class="product-variant">${variantText}</span>` : ''}
                        <span class="product-qty">× ${item.quantity}</span>
                    </div>
                `;
            }).join('');
            
            return `
                <tr>
                    <td>#${String(index + 1).padStart(3, '0')}</td>
                    <td>
                        <div class="products-list">
                            ${productsHTML}
                        </div>
                    </td>
                    <td>${receivedDate}</td>
                    <td>${order.buyer_name}</td>
                    <td class="price-positive">+₱${orderTotal.toFixed(2)}</td>
                    <td class="commission-negative">-₱${commission.toFixed(2)}</td>
                </tr>
            `;
        }).join('');
    }
    
    function showEmptySoldProducts() {
        const tbody = document.getElementById('productSoldTableBody');
        if (!tbody) return;
        
        tbody.innerHTML = `
            <tr>
                <td colspan="6" style="text-align: center; padding: 40px; color: #666;">
                    <i class="bi bi-inbox" style="font-size: 48px; display: block; margin-bottom: 16px;"></i>
                    <p>No sold products yet</p>
                </td>
            </tr>
        `;
    }

    function attachProductSoldEventListeners() {
        // Search functionality
        const productSoldSearch = document.getElementById('productSoldSearch');
        if (productSoldSearch) {
            productSoldSearch.addEventListener('input', function() {
                filterSoldProducts();
            });
        }

        // Date range filter functionality
        const productSoldDateFrom = document.getElementById('productSoldDateFrom');
        const productSoldDateTo = document.getElementById('productSoldDateTo');
        
        if (productSoldDateFrom) {
            productSoldDateFrom.addEventListener('change', function() {
                filterSoldProducts();
            });
        }
        
        if (productSoldDateTo) {
            productSoldDateTo.addEventListener('change', function() {
                filterSoldProducts();
            });
        }
    }
    
    function filterSoldProducts() {
        const searchTerm = document.getElementById('productSoldSearch')?.value.toLowerCase() || '';
        const dateFrom = document.getElementById('productSoldDateFrom')?.value || '';
        const dateTo = document.getElementById('productSoldDateTo')?.value || '';
        const rows = document.querySelectorAll('#productSoldTableBody tr');
        
        rows.forEach(row => {
            const productName = row.cells[1]?.textContent.toLowerCase() || '';
            const buyer = row.cells[3]?.textContent.toLowerCase() || '';
            const dateText = row.cells[2]?.textContent || '';
            
            // Check search match
            const searchMatch = !searchTerm || 
                productName.includes(searchTerm) || 
                buyer.includes(searchTerm);
            
            // Check date range filter
            let dateMatch = true;
            if ((dateFrom || dateTo) && dateText) {
                const rowDate = new Date(dateText);
                
                if (dateFrom && dateTo) {
                    // Both dates specified - check if within range
                    const fromDate = new Date(dateFrom);
                    const toDate = new Date(dateTo);
                    toDate.setHours(23, 59, 59, 999); // Include the entire end date
                    dateMatch = rowDate >= fromDate && rowDate <= toDate;
                } else if (dateFrom) {
                    // Only from date - show products on or after this date
                    const fromDate = new Date(dateFrom);
                    dateMatch = rowDate >= fromDate;
                } else if (dateTo) {
                    // Only to date - show products on or before this date
                    const toDate = new Date(dateTo);
                    toDate.setHours(23, 59, 59, 999);
                    dateMatch = rowDate <= toDate;
                }
            }
            
            // Show/hide row
            row.style.display = (searchMatch && dateMatch) ? '' : 'none';
        });
    }

    function filterOrders() {
        const searchTerm = document.getElementById('orderSearch')?.value.toLowerCase() || '';
        const statusFilter = document.getElementById('orderStatusFilter')?.value.toLowerCase() || '';
        const dateFrom = document.getElementById('orderDateFrom')?.value || '';
        const dateTo = document.getElementById('orderDateTo')?.value || '';
        const rows = document.querySelectorAll('#orderTableBody tr');
        
        rows.forEach(row => {
            // Skip if it's a loading/empty row
            if (row.cells.length < 7) return;
            
            const orderNumber = row.cells[0]?.textContent.toLowerCase() || '';
            const productNames = row.cells[2]?.textContent.toLowerCase() || '';
            const buyer = row.cells[3]?.textContent.toLowerCase() || '';
            const dateText = row.cells[4]?.textContent || '';
            const statusBadge = row.cells[6]?.querySelector('.status-badge');
            const statusText = statusBadge?.textContent.toLowerCase().trim() || '';
            
            // Check search match
            const searchMatch = !searchTerm || 
                orderNumber.includes(searchTerm) || 
                buyer.includes(searchTerm) ||
                productNames.includes(searchTerm);
            
            // Check status filter - exact match with status column
            let statusMatch = true;
            if (statusFilter) {
                statusMatch = statusText === statusFilter;
            }
            
            // Check date range filter
            let dateMatch = true;
            if ((dateFrom || dateTo) && dateText) {
                const rowDate = new Date(dateText);
                
                if (dateFrom && dateTo) {
                    // Both dates specified - check if within range
                    const fromDate = new Date(dateFrom);
                    const toDate = new Date(dateTo);
                    toDate.setHours(23, 59, 59, 999); // Include the entire end date
                    dateMatch = rowDate >= fromDate && rowDate <= toDate;
                } else if (dateFrom) {
                    // Only from date - show orders on or after this date
                    const fromDate = new Date(dateFrom);
                    dateMatch = rowDate >= fromDate;
                } else if (dateTo) {
                    // Only to date - show orders on or before this date
                    const toDate = new Date(dateTo);
                    toDate.setHours(23, 59, 59, 999);
                    dateMatch = rowDate <= toDate;
                }
            }
            
            // Show/hide row
            row.style.display = (searchMatch && statusMatch && dateMatch) ? '' : 'none';
        });
    }

    function attachOrdersEventListeners() {
        // Search functionality
        const orderSearch = document.getElementById('orderSearch');
        if (orderSearch) {
            orderSearch.addEventListener('input', function() {
                filterOrders();
            });
        }

        // Filter functionality
        const orderStatusFilter = document.getElementById('orderStatusFilter');
        const orderDateFrom = document.getElementById('orderDateFrom');
        const orderDateTo = document.getElementById('orderDateTo');
        
        if (orderStatusFilter) {
            orderStatusFilter.addEventListener('change', function() {
                filterOrders();
            });
        }
        
        if (orderDateFrom) {
            orderDateFrom.addEventListener('change', function() {
                filterOrders();
            });
        }
        
        if (orderDateTo) {
            orderDateTo.addEventListener('change', function() {
                filterOrders();
            });
        }

        // Action buttons
        document.querySelectorAll('.action-btn').forEach(btn => {
            btn.addEventListener('click', async function() {
                if (this.classList.contains('pickup-btn') && !this.disabled) {
                    const orderId = this.getAttribute('data-order-id');
                    const pickupBtn = this;
                    const originalHTML = pickupBtn.innerHTML;
                    const row = pickupBtn.closest('tr');
                    const statusBadge = row.querySelector('.status-badge');
                    
                    try {
                        // Show loading state
                        pickupBtn.disabled = true;
                        pickupBtn.style.opacity = '0.7';
                        pickupBtn.innerHTML = '<i class="bi bi-hourglass-split"></i> Processing...';
                        
                        // Simulate API call (replace with actual backend call)
                        await new Promise(resolve => setTimeout(resolve, 1000));
                        
                        // TODO: Replace with actual API call
                        // const response = await fetch(`/api/orders/${orderId}/ready-for-pickup`, {
                        //     method: 'POST',
                        //     headers: {
                        //         'Content-Type': 'application/json',
                        //     }
                        // });
                        
                        // if (!response.ok) {
                        //     const errorData = await response.json();
                        //     throw new Error(errorData.message || 'Failed to update order status');
                        // }
                        
                        console.log('Order ready for pickup:', orderId);
                        
                        // Update status badge to "For Pick Up"
                        statusBadge.className = 'status-badge status-for-pickup';
                        statusBadge.textContent = 'For Pick Up';
                        
                        // Update button to show it's ready
                        pickupBtn.innerHTML = '<i class="bi bi-box-seam"></i> For Pick Up';
                        pickupBtn.style.opacity = '1';
                        pickupBtn.style.background = 'rgba(59, 130, 246, 0.1)';
                        pickupBtn.style.color = '#3b82f6';
                        pickupBtn.disabled = false;
                        pickupBtn.classList.add('for-pickup');
                        pickupBtn.title = 'Click when rider picks up';
                        
                        // Show success notification
                        showNotification(`Order #${orderId} is ready for pick up!`, 'success');
                        
                        // Simulate rider picking up after 5 seconds (mock data)
                        setTimeout(async () => {
                            try {
                                pickupBtn.disabled = true;
                                pickupBtn.style.opacity = '0.7';
                                pickupBtn.innerHTML = '<i class="bi bi-hourglass-split"></i> Confirming...';
                                
                                // Simulate rider pickup confirmation
                                await new Promise(resolve => setTimeout(resolve, 1000));
                                
                                // TODO: Replace with actual API call
                                // const pickupResponse = await fetch(`/api/orders/${orderId}/confirm-pickup`, {
                                //     method: 'POST',
                                //     headers: {
                                //         'Content-Type': 'application/json',
                                //     }
                                // });
                                
                                console.log('Order picked up by rider:', orderId);
                                
                                // Update status badge to "Picked Up"
                                statusBadge.className = 'status-badge status-picked-up';
                                statusBadge.textContent = 'Picked Up';
                                
                                // Update button to final state
                                pickupBtn.innerHTML = '<i class="bi bi-check-circle"></i> Picked Up';
                                pickupBtn.style.opacity = '0.6';
                                pickupBtn.style.background = 'rgba(34, 197, 94, 0.1)';
                                pickupBtn.style.color = '#22c55e';
                                pickupBtn.classList.remove('for-pickup');
                                pickupBtn.classList.add('picked-up');
                                pickupBtn.title = 'Order has been picked up';
                                
                                // Show final notification
                                showNotification(`Order #${orderId} has been picked up by rider!`, 'success');
                                
                            } catch (error) {
                                console.error('Pickup confirmation error:', error);
                            }
                        }, 5000); // Mock: 5 seconds delay for rider pickup
                        
                    } catch (error) {
                        // Re-enable button on error
                        pickupBtn.disabled = false;
                        pickupBtn.style.opacity = '1';
                        pickupBtn.innerHTML = originalHTML;
                        
                        // Show error notification
                        showNotification(error.message || 'Failed to update order status. Please try again.', 'error');
                        
                        // Log error for debugging
                        console.error('Order status update error:', error);
                    }
                }
            });
        });
    }

    function loadAddProductContent() {
        if (!accountCardContainer) return;
        
        const addProductHTML = `
            <div class="product-management-main-content">
                <h2 class="product-management-title">Add New Product</h2>
                <hr class="product-management-divider">
                
                <form id="addProductForm">
                    <div class="profile-content-row-inner">
                        <div class="add-product-form">
                            <!-- Basic Information Section -->
                            <div class="form-group">
                                <label for="productName">Product Name</label>
                                <input type="text" id="productName" name="productName" placeholder="Enter product name" required>
                            </div>
                            
                            <div class="form-group">
                                <label for="productCategory">Category</label>
                                <select id="productCategory" name="productCategory" required>
                                    <option value="">Select Category</option>
                                    <option value="dresses">Dresses</option>
                                    <option value="skirts">Skirts</option>
                                    <option value="tops">Tops</option>
                                    <option value="blouses">Blouses</option>
                                    <option value="activewear">Activewear</option>
                                    <option value="yoga-pants">Yoga Pants</option>
                                    <option value="lingerie">Lingerie</option>
                                    <option value="sleepwear">Sleepwear</option>
                                    <option value="jackets">Jackets</option>
                                    <option value="coats">Coats</option>
                                    <option value="shoes">Shoes</option>
                                    <option value="accessories">Accessories</option>
                                </select>
                            </div>
                            
                            <div class="form-group">
                                <label for="productPrice">Price (₱)</label>
                                <input type="number" id="productPrice" name="productPrice" placeholder="0.00" step="0.01" min="0" required>
                            </div>
                            
                            <!-- Product Details Section -->
                            <div class="form-group full-width">
                                <label for="productDescription">Product Description</label>
                                <textarea id="productDescription" name="productDescription" class="profile-textarea" placeholder="Describe your product in detail..." rows="4"></textarea>
                            </div>
                            
                            <div class="form-group full-width">
                                <label for="productMaterials">Materials Used</label>
                                <textarea id="productMaterials" name="productMaterials" class="profile-textarea" placeholder="e.g., Cotton, Recycled Plastic, Organic Fabric..." rows="3"></textarea>
                            </div>
                            
                            <div class="form-group full-width">
                                <label title="Sustainable Development Goals">SDG</label>
                                <div class="checkbox-group">
                                    <label class="checkbox-label">
                                        <input type="checkbox" id="productHandmade" name="productHandmade" value="handmade">
                                        <span>Handmade</span>
                                    </label>
                                    <label class="checkbox-label">
                                        <input type="checkbox" id="productBiodegradable" name="productBiodegradable" value="biodegradable">
                                        <span>Biodegradable</span>
                                    </label>
                                </div>
                            </div>
                            
                            <input type="hidden" id="productColorsData" name="productColorsData" value="[]">
                            <input type="hidden" id="productSizesData" name="productSizesData" value="[]">
                            <input type="hidden" id="productStock" name="productStock" value="0">
                        </div>
                        
                        <div class="profile-vertical-divider"></div>
                        
                        <div class="profile-image-section">
                            <h3 class="variants-preview-title">Product Variants</h3>
                            
                            <div class="form-group color-picker-group">
                                <label for="productColor">Select Color</label>
                                <div class="color-input-wrapper">
                                    <input type="color" id="productColor" name="productColor" value="#000000">
                                    <span id="productColorName" class="color-name-display">Black</span>
                                    <input type="hidden" id="productColorNameHidden" name="productColorName" value="Black">
                                </div>
                            </div>
                            
                            <div class="form-group">
                                <label>Size</label>
                                <select id="sizeSelect" class="variant-size-selector">
                                    <option value="" disabled selected>Select Size</option>
                                </select>
                            </div>
                            
                            <div class="form-group">
                                <label>Quantity</label>
                                <input type="number" id="sizeQuantity" class="variant-quantity" placeholder="Quantity" min="1" step="1" value="1">
                            </div>
                            
                            <div class="form-group upload-image-group">
                                <label>Upload Images</label>
                                <div class="add-variant-images-gallery">
                                    <div class="add-variant-images-container" id="addVariantImagesContainer">
                                        <button type="button" class="add-variant-image-placeholder" id="addVariantImageBtn">
                                            <i class="bi bi-plus"></i>
                                            <span>Add Images</span>
                                        </button>
                                    </div>
                                    <input type="file" id="variantImage" accept="image/*" multiple style="display: none;">
                                </div>
                                <p class="image-upload-hint"><i class="bi bi-info-circle"></i> Drag images to reorder. First image will be the primary display image.</p>
                            </div>
                            
                            <div class="form-group full-width">
                                <button type="button" id="addVariantBtn" class="add-size-btn-full">Add Variant</button>
                            </div>
                        </div>
                    </div>
                    
                    <!-- Added Variants Display - Spans both columns -->
                    <div class="variants-display-fullwidth">
                        <label>Added Variants</label>
                        <div id="selectedVariantsContainer" class="selected-variants-display-horizontal">
                            <p class="no-variants-message">No variants added yet</p>
                        </div>
                    </div>
                    
                    <!-- Form Actions - Centered across both columns -->
                    <div class="form-actions-fullwidth-center">
                        <button type="submit" class="btn btn-primary">Add Product</button>
                        <button type="button" class="btn btn-secondary" id="cancelAddProduct">Cancel</button>
                    </div>
                </form>
            </div>
        `;
        
        accountCardContainer.innerHTML = addProductHTML;
        
        // Attach event listeners for the add product form
        attachAddProductEventListeners();
    }

    function attachProductListEventListeners() {
        // Add New Product button
        const addNewProductBtn = document.getElementById('addNewProductBtn');
        if (addNewProductBtn) {
            addNewProductBtn.addEventListener('click', function() {
                // Switch to Add Product tab
                document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
                addProductTab.classList.add('active');
                loadAddProductContent();
            });
        }

        // Filter and search functionality
        const categoryFilter = document.getElementById('categoryFilter');
        const productSearch = document.getElementById('productSearch');
        
        function filterProducts() {
            const categoryValue = categoryFilter ? categoryFilter.value.toLowerCase() : '';
            const searchValue = productSearch ? productSearch.value.toLowerCase() : '';
            const productRows = document.querySelectorAll('.product-row');
            
            productRows.forEach(row => {
                const productName = row.querySelector('.product-name')?.textContent.toLowerCase() || '';
                const category = row.querySelector('td:nth-child(3)')?.textContent.toLowerCase() || '';
                
                const matchesCategory = !categoryValue || category === categoryValue;
                const matchesSearch = !searchValue || productName.includes(searchValue);
                
                if (matchesCategory && matchesSearch) {
                    row.style.display = '';
                    // Also hide the variant details row if it exists
                    const variantRow = document.querySelector(`.variant-details-row[data-product-id="${row.dataset.productId}"]`);
                    if (variantRow && variantRow.style.display !== 'none') {
                        // Keep it visible if it was already expanded
                    }
                } else {
                    row.style.display = 'none';
                    // Also hide the variant details row
                    const variantRow = document.querySelector(`.variant-details-row[data-product-id="${row.dataset.productId}"]`);
                    if (variantRow) {
                        variantRow.style.display = 'none';
                    }
                }
            });
            
            // Check if any products are visible
            const visibleRows = Array.from(productRows).filter(row => row.style.display !== 'none');
            const productTableBody = document.getElementById('productTableBody');
            
            if (visibleRows.length === 0 && productTableBody) {
                // Show "no results" message
                const existingNoResults = productTableBody.querySelector('.no-results-row');
                if (!existingNoResults) {
                    const noResultsRow = document.createElement('tr');
                    noResultsRow.className = 'no-results-row';
                    noResultsRow.innerHTML = `
                        <td colspan="6" style="text-align: center; padding: 40px;">
                            <i class="bi bi-search" style="font-size: 2em; color: #D3BD9B;"></i>
                            <p style="margin-top: 10px; color: #666;">No products found matching your filters.</p>
                        </td>
                    `;
                    productTableBody.appendChild(noResultsRow);
                }
            } else {
                // Remove "no results" message if it exists
                const noResultsRow = productTableBody?.querySelector('.no-results-row');
                if (noResultsRow) {
                    noResultsRow.remove();
                }
            }
        }
        
        if (categoryFilter) {
            categoryFilter.addEventListener('change', filterProducts);
        }
        
        if (productSearch) {
            productSearch.addEventListener('input', filterProducts);
        }
        
        // Status filter buttons
        const filterActiveBtn = document.getElementById('filterActive');
        const filterArchivedBtn = document.getElementById('filterArchived');
        
        if (filterActiveBtn) {
            filterActiveBtn.addEventListener('click', async function() {
                document.querySelectorAll('.status-filter-btn').forEach(btn => btn.classList.remove('active'));
                filterActiveBtn.classList.add('active');
                await fetchAndDisplayProducts();
            });
        }
        
        if (filterArchivedBtn) {
            filterArchivedBtn.addEventListener('click', async function() {
                document.querySelectorAll('.status-filter-btn').forEach(btn => btn.classList.remove('active'));
                filterArchivedBtn.classList.add('active');
                await fetchAndDisplayProducts();
            });
        }

        // Note: Action button event listeners (edit, delete) are now attached 
        // directly in fetchAndDisplayProducts() after products are rendered
    }

    function attachAddProductEventListeners() {
        console.log('Attaching add product event listeners...');
        const addProductForm = document.getElementById('addProductForm');
        const cancelBtn = document.getElementById('cancelAddProduct');
        const productImagesInput = document.getElementById('productImages');
        const productImagePreview = document.getElementById('productImagePreview');
        const productImageImg = document.getElementById('productImageImg');
        const uploadPlaceholder = document.getElementById('uploadPlaceholder');
        const uploadOverlay = document.getElementById('uploadOverlay');
        const productImagesGrid = document.getElementById('productImagesGrid');
        const productColorInput = document.getElementById('productColor');
        const productColorNameDisplay = document.getElementById('productColorName');
        const productColorNameHidden = document.getElementById('productColorNameHidden');
        const selectedVariantsContainer = document.getElementById('selectedVariantsContainer');
        const productColorsData = document.getElementById('productColorsData');
        const productSizesData = document.getElementById('productSizesData');
        let selectedVariants = [];
        
        console.log('Form element found:', !!addProductForm);
        console.log('Selected variants container found:', !!selectedVariantsContainer);
        
        // Helper function to get color name from API
        async function getColorNameFromAPI(hexColor) {
            try {
                const cleanHex = hexColor.replace('#', '');
                const response = await fetch(`https://www.thecolorapi.com/id?hex=${cleanHex}`);
                const data = await response.json();
                return data.name.value;
            } catch (error) {
                console.error('Color API error:', error);
                return 'Custom Color';
            }
        }
        
        // Color picker event listener
        if (productColorInput && productColorNameDisplay) {
            // Set initial color name using API
            getColorNameFromAPI(productColorInput.value).then(colorName => {
                productColorNameDisplay.textContent = colorName;
                productColorNameHidden.value = colorName;
            });
            
            // Update color name as user picks color
            productColorInput.addEventListener('input', async function() {
                const colorName = await getColorNameFromAPI(this.value);
                productColorNameDisplay.textContent = colorName;
                productColorNameHidden.value = colorName;
            });
            
            // Update color name when done selecting
            productColorInput.addEventListener('change', async function() {
                const colorName = await getColorNameFromAPI(this.value);
                productColorNameDisplay.textContent = colorName;
                productColorNameHidden.value = colorName;
            });
            
            // Show uploaded images when color picker is clicked
            productColorInput.addEventListener('click', function() {
                if (variantImageFiles && variantImageFiles.length > 0) {
                    const imageUrls = variantImageFiles.map(img => img.preview);
                    showImageCarouselModal(imageUrls, 0);
                }
            });
            
            // Close color picker when clicking outside
            document.addEventListener('click', function(event) {
                // Check if click is outside the color picker
                if (!productColorInput.contains(event.target) && event.target !== productColorInput) {
                    productColorInput.blur();
                }
            });
        }

        // Variant management (Color + Size combination)
        const productCategorySelect = document.getElementById('productCategory');
        const sizeSelect = document.getElementById('sizeSelect');
        const sizeQuantity = document.getElementById('sizeQuantity');
        const addVariantBtn = document.getElementById('addVariantBtn');
        const variantImageInput = document.getElementById('variantImage');
        const addVariantImageBtn = document.getElementById('addVariantImageBtn');
        const addVariantImagesContainer = document.getElementById('addVariantImagesContainer');
        let variantImageFiles = []; // Changed to array for multiple images
        
        // Prevent decimal input in quantity field
        if (sizeQuantity) {
            sizeQuantity.addEventListener('keypress', function(e) {
                // Prevent decimal point (.) and minus sign (-)
                if (e.key === '.' || e.key === '-' || e.key === 'e' || e.key === 'E') {
                    e.preventDefault();
                }
            });
            
            // Also prevent pasting decimal values
            sizeQuantity.addEventListener('paste', function(e) {
                e.preventDefault();
                const pastedText = (e.clipboardData || window.clipboardData).getData('text');
                const numericValue = parseInt(pastedText);
                if (!isNaN(numericValue) && numericValue > 0) {
                    this.value = numericValue;
                }
            });
        }
        
        // Handle add image button click
        if (addVariantImageBtn && variantImageInput) {
            addVariantImageBtn.addEventListener('click', function() {
                variantImageInput.click();
            });
        }
        
        // Handle variant image selection (multiple images)
        if (variantImageInput) {
            variantImageInput.addEventListener('change', function(e) {
                if (e.target.files && e.target.files.length > 0) {
                    const files = Array.from(e.target.files);
                    console.log(`📸 Selected ${files.length} files for variant images`);
                    
                    let loadedCount = 0;
                    files.forEach((file, fileIndex) => {
                        const reader = new FileReader();
                        reader.onload = function(event) {
                            variantImageFiles.push({
                                file: file,
                                preview: event.target.result
                            });
                            loadedCount++;
                            console.log(`  ✅ Image ${loadedCount}/${files.length} loaded: ${file.name}`);
                            updateAddVariantImagesDisplay();
                        };
                        reader.onerror = function() {
                            console.error(`  ❌ Error loading image: ${file.name}`);
                        };
                        reader.readAsDataURL(file);
                    });
                    
                    console.log(`📸 Total variant images in array: ${variantImageFiles.length}`);
                    showNotification(`${files.length} image(s) added`, 'success');
                    this.value = ''; // Reset input
                }
            });
        }
        
        // Function to update the images display in Add Variant section
        function updateAddVariantImagesDisplay() {
            if (!addVariantImagesContainer) return;
            
            addVariantImagesContainer.innerHTML = variantImageFiles.map((img, index) => `
                <div class="variant-image-item-add" draggable="true" data-index="${index}">
                    <img src="${img.preview}" alt="Variant image" class="add-variant-image-preview">
                    <button type="button" class="remove-add-variant-image-btn" data-index="${index}">
                        <i class="bi bi-x"></i>
                    </button>
                    ${index === 0 ? '<span class="primary-badge">Primary</span>' : ''}
                </div>
            `).join('') + `
                <button type="button" class="add-variant-image-placeholder" id="addVariantImageBtn">
                    <i class="bi bi-plus"></i>
                    <span>Add More</span>
                </button>
            `;
            
            // Re-attach event listeners
            const newAddBtn = addVariantImagesContainer.querySelector('#addVariantImageBtn');
            if (newAddBtn) {
                newAddBtn.addEventListener('click', function() {
                    variantImageInput.click();
                });
            }
            
            // Attach remove button listeners
            addVariantImagesContainer.querySelectorAll('.remove-add-variant-image-btn').forEach(btn => {
                btn.addEventListener('click', function() {
                    const index = parseInt(this.dataset.index);
                    variantImageFiles.splice(index, 1);
                    updateAddVariantImagesDisplay();
                    showNotification('Image removed', 'info');
                });
            });
            
            // Add drag-and-drop functionality
            const imageItems = addVariantImagesContainer.querySelectorAll('.variant-image-item-add');
            let draggedIndex = null;
            
            imageItems.forEach((item, index) => {
                item.addEventListener('dragstart', function(e) {
                    draggedIndex = index;
                    this.style.opacity = '0.5';
                });
                
                item.addEventListener('dragend', function(e) {
                    this.style.opacity = '1';
                });
                
                item.addEventListener('dragover', function(e) {
                    e.preventDefault();
                    this.style.borderColor = '#D3BD9B';
                });
                
                item.addEventListener('dragleave', function(e) {
                    this.style.borderColor = '';
                });
                
                item.addEventListener('drop', function(e) {
                    e.preventDefault();
                    this.style.borderColor = '';
                    
                    const dropIndex = index;
                    if (draggedIndex !== null && draggedIndex !== dropIndex) {
                        // Reorder array
                        const [draggedItem] = variantImageFiles.splice(draggedIndex, 1);
                        variantImageFiles.splice(dropIndex, 0, draggedItem);
                        
                        updateAddVariantImagesDisplay();
                        showNotification('Images reordered. First image is now primary.', 'success');
                    }
                });
            });
        }

        // Update size options when category changes
        if (productCategorySelect) {
            productCategorySelect.addEventListener('change', function() {
                const category = this.value;
                const sizes = SizeConfig.getSizesForCategory(category);
                
                sizeSelect.innerHTML = '<option value="" disabled selected>Select a size</option>';
                sizes.forEach(size => {
                    const option = document.createElement('option');
                    option.value = size;
                    option.textContent = size;
                    sizeSelect.appendChild(option);
                });
                
                // Reset selected variants when category changes
                selectedVariants = [];
                updateVariantsDisplay();
            });
            
            // Initialize sizes on load
            const initialCategory = productCategorySelect.value;
            if (initialCategory) {
                const sizes = SizeConfig.getSizesForCategory(initialCategory);
                sizeSelect.innerHTML = '<option value="" disabled selected>Select a size</option>';
                sizes.forEach(size => {
                    const option = document.createElement('option');
                    option.value = size;
                    option.textContent = size;
                    sizeSelect.appendChild(option);
                });
            }
        }

        // Add variant button click (Color + Size + Quantity + Image)
        if (addVariantBtn) {
            addVariantBtn.addEventListener('click', function() {
                const colorHex = productColorInput.value;
                const colorName = productColorNameDisplay.textContent;
                const size = sizeSelect.value;
                const quantity = parseInt(sizeQuantity.value) || 1;
                
                if (!size) {
                    showNotification('Please select a size', 'error');
                    return;
                }
                
                if (quantity <= 0) {
                    showNotification('Quantity must be greater than 0', 'error');
                    return;
                }
                
                // Check if this color-size combination already exists
                const existingVariant = selectedVariants.find(v => 
                    v.colorHex.toLowerCase() === colorHex.toLowerCase() && v.size === size
                );
                if (existingVariant) {
                    showNotification(`${colorName} - ${size} already added`, 'error');
                    return;
                }
                
                // Check if this color already has images
                const colorHasImages = selectedVariants.some(v => 
                    v.colorHex.toLowerCase() === colorHex.toLowerCase() && v.images && v.images.length > 0
                );
                
                // If this is a new color and no images provided, require images
                const isNewColor = !selectedVariants.some(v => 
                    v.colorHex.toLowerCase() === colorHex.toLowerCase()
                );
                
                if (isNewColor && variantImageFiles.length === 0) {
                    showNotification('Please upload at least one image for this color variant', 'error');
                    return;
                }
                
                // Add variant with images
                // For new color: attach current images
                // For same color: find images from another variant of same color, or use current if available
                let variantImages = null;
                if (isNewColor && variantImageFiles.length > 0) {
                    // New color: use current images
                    variantImages = [...variantImageFiles];
                } else if (!isNewColor) {
                    // Same color: try to find images from existing variant of same color
                    const sameColorVariant = selectedVariants.find(v => 
                        v.colorHex.toLowerCase() === colorHex.toLowerCase() && v.images && v.images.length > 0
                    );
                    if (sameColorVariant) {
                        // Reuse images from same color variant (use reference - will be deduplicated during submit)
                        variantImages = sameColorVariant.images;
                    } else if (variantImageFiles.length > 0) {
                        // Or use current images if available
                        variantImages = [...variantImageFiles];
                    }
                }
                
                const variant = { 
                    colorHex, 
                    colorName, 
                    size, 
                    quantity,
                    images: variantImages
                };
                
                console.log(`📦 Adding variant: ${colorName} - ${size}`);
                console.log(`   Images attached: ${variantImages ? variantImages.length : 0}`);
                console.log(`   Variant data:`, variant);
                
                selectedVariants.push(variant);
                updateVariantsDisplay();
                
                // Disable left form fields after first variant is added
                if (selectedVariants.length === 1) {
                    const productNameInput = document.getElementById('productName');
                    const productCategoryInput = document.getElementById('productCategory');
                    const productPriceInput = document.getElementById('productPrice');
                    const productDescriptionInput = document.getElementById('productDescription');
                    const productMaterialsInput = document.getElementById('productMaterials');
                    const productHandmadeInput = document.getElementById('productHandmade');
                    const productBiodegradableInput = document.getElementById('productBiodegradable');
                    
                    if (productNameInput) productNameInput.disabled = true;
                    if (productCategoryInput) productCategoryInput.disabled = true;
                    if (productPriceInput) productPriceInput.disabled = true;
                    if (productDescriptionInput) productDescriptionInput.disabled = true;
                    if (productMaterialsInput) productMaterialsInput.disabled = true;
                    if (productHandmadeInput) productHandmadeInput.disabled = true;
                    if (productBiodegradableInput) productBiodegradableInput.disabled = true;
                }
                
                // Reset inputs
                sizeSelect.value = '';
                sizeQuantity.value = '1';
                
                // Only reset images if this is a new color
                // If same color, keep images for other size variants of same color
                if (isNewColor) {
                    variantImageFiles = [];
                    variantImageInput.value = '';
                    
                    // Reset images display
                    if (addVariantImagesContainer) {
                        addVariantImagesContainer.innerHTML = `
                            <button type="button" class="add-variant-image-placeholder" id="addVariantImageBtn">
                                <i class="bi bi-plus"></i>
                                <span>Add Images</span>
                            </button>
                        `;
                        
                        // Re-attach event listener
                        const newAddBtn = addVariantImagesContainer.querySelector('#addVariantImageBtn');
                        if (newAddBtn) {
                            newAddBtn.addEventListener('click', function() {
                                variantImageInput.click();
                            });
                        }
                    }
                }
                // If same color, keep the images for next size variant
                
                showNotification(`${colorName} - ${size} added successfully`, 'success');
            });
        }

        function updateVariantsDisplay() {
            selectedVariantsContainer.innerHTML = '';
            
            // Send complete variant data (color-size pairs) instead of separate arrays
            // This prevents creating unwanted Cartesian product combinations
            const variantsData = selectedVariants.map(variant => ({
                colorHex: variant.colorHex,
                colorName: variant.colorName,
                size: variant.size,
                quantity: variant.quantity
            }));
            
            productColorsData.value = JSON.stringify(variantsData);
            productSizesData.value = '[]'; // Not used anymore, but keep for compatibility
            
            // Calculate and update total stock
            const totalStock = selectedVariants.reduce((sum, item) => sum + parseInt(item.quantity || 0), 0);
            const productStockInput = document.getElementById('productStock');
            if (productStockInput) {
                productStockInput.value = totalStock;
            }
            
            if (selectedVariants.length === 0) {
                selectedVariantsContainer.innerHTML = '<p class="no-variants-message">No variants added yet. Add variants from the form to see them here.</p>';
                return;
            }
            
            selectedVariants.forEach((variant, index) => {
                const variantTag = document.createElement('div');
                variantTag.className = 'size-tag';
                
                // Find images for this color (from any variant with the same color)
                let imagesPreview = '';
                let variantImages = variant.images;
                
                // If this variant doesn't have images, find another variant with the same color that has images
                if (!variantImages || variantImages.length === 0) {
                    const sameColorVariant = selectedVariants.find(v => 
                        v.colorHex.toLowerCase() === variant.colorHex.toLowerCase() && v.images && v.images.length > 0
                    );
                    if (sameColorVariant) {
                        variantImages = sameColorVariant.images;
                    }
                }
                
                // Create images preview (show first image with count badge)
                if (variantImages && variantImages.length > 0) {
                    const firstImage = variantImages[0];
                    const imageUrl = firstImage.file ? URL.createObjectURL(firstImage.file) : firstImage.preview;
                    
                    imagesPreview = `
                        <div class="variant-image-wrapper">
                            <img src="${imageUrl}" class="variant-image-preview clickable-variant-image" data-variant-index="${index}" data-image-index="0" alt="${variant.colorName}" title="Click to view all images">
                            ${variantImages.length > 1 ? `<span class="variant-image-count">+${variantImages.length - 1}</span>` : ''}
                        </div>
                    `;
                }
                
                variantTag.innerHTML = `
                    ${imagesPreview}
                    <div class="color-preview" style="background-color: ${variant.colorHex};"></div>
                    <span class="size-info">${variant.colorName} - ${variant.size} <span class="size-qty">(${variant.quantity} pcs)</span></span>
                    <button type="button" class="remove-size-btn" data-index="${index}">
                        <i class="bi bi-x"></i>
                    </button>
                `;
                selectedVariantsContainer.appendChild(variantTag);
            });
            
            // Add click listeners to variant images - open modal with carousel
            document.querySelectorAll('.clickable-variant-image').forEach(img => {
                img.addEventListener('click', function(e) {
                    e.preventDefault();
                    e.stopPropagation();
                    
                    const variantIndex = parseInt(this.dataset.variantIndex);
                    const variant = selectedVariants[variantIndex];
                    
                    // Find all images for this variant
                    let variantImages = variant.images;
                    if (!variantImages || variantImages.length === 0) {
                        const sameColorVariant = selectedVariants.find(v => 
                            v.colorHex.toLowerCase() === variant.colorHex.toLowerCase() && v.images && v.images.length > 0
                        );
                        if (sameColorVariant) {
                            variantImages = sameColorVariant.images;
                        }
                    }
                    
                    if (variantImages && variantImages.length > 0) {
                        const imageUrls = variantImages.map(img => 
                            img.file ? URL.createObjectURL(img.file) : img.preview
                        );
                        showImageCarouselModal(imageUrls, 0);
                    }
                });
            });
            
            // Add remove button listeners
            document.querySelectorAll('.remove-size-btn').forEach(btn => {
                btn.addEventListener('click', function(e) {
                    e.preventDefault();
                    const index = parseInt(this.getAttribute('data-index'));
                    const removedVariant = selectedVariants[index];
                    selectedVariants.splice(index, 1);
                    updateVariantsDisplay();
                    
                    // Re-enable left form fields if all variants are removed
                    if (selectedVariants.length === 0) {
                        const productNameInput = document.getElementById('productName');
                        const productCategoryInput = document.getElementById('productCategory');
                        const productPriceInput = document.getElementById('productPrice');
                        const productDescriptionInput = document.getElementById('productDescription');
                        const productMaterialsInput = document.getElementById('productMaterials');
                        const productHandmadeInput = document.getElementById('productHandmade');
                        const productBiodegradableInput = document.getElementById('productBiodegradable');
                        
                        if (productNameInput) productNameInput.disabled = false;
                        if (productCategoryInput) productCategoryInput.disabled = false;
                        if (productPriceInput) productPriceInput.disabled = false;
                        if (productDescriptionInput) productDescriptionInput.disabled = false;
                        if (productMaterialsInput) productMaterialsInput.disabled = false;
                        if (productHandmadeInput) productHandmadeInput.disabled = false;
                        if (productBiodegradableInput) productBiodegradableInput.disabled = false;
                    }
                    
                    showNotification(`${removedVariant.colorName} - ${removedVariant.size} removed`, 'info');
                });
            });
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
                    
                    // No limit on images
                    const limitedFiles = files;
                    
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

        if (addProductForm) {
            console.log('Adding submit event listener to form');
            addProductForm.addEventListener('submit', async function(e) {
                e.preventDefault();
                console.log('Form submitted! Processing...');
                
                const submitBtn = this.querySelector('.btn-primary');
                const originalBtnText = submitBtn.textContent;
                console.log('Submit button found:', !!submitBtn);
                
                // Get input references outside try block
                const productNameInput = document.getElementById('productName');
                const productCategoryInput = document.getElementById('productCategory');
                const productPriceInput = document.getElementById('productPrice');
                const productDescriptionInput = document.getElementById('productDescription');
                const productMaterialsInput = document.getElementById('productMaterials');
                const productHandmadeInput = document.getElementById('productHandmade');
                const productBiodegradableInput = document.getElementById('productBiodegradable');
                
                const wasDisabled = {
                    name: productNameInput?.disabled,
                    category: productCategoryInput?.disabled,
                    price: productPriceInput?.disabled,
                    description: productDescriptionInput?.disabled,
                    materials: productMaterialsInput?.disabled,
                    handmade: productHandmadeInput?.disabled,
                    biodegradable: productBiodegradableInput?.disabled
                };
                
                try {
                    // Enable all fields temporarily
                    if (productNameInput) productNameInput.disabled = false;
                    if (productCategoryInput) productCategoryInput.disabled = false;
                    if (productPriceInput) productPriceInput.disabled = false;
                    if (productDescriptionInput) productDescriptionInput.disabled = false;
                    if (productMaterialsInput) productMaterialsInput.disabled = false;
                    if (productHandmadeInput) productHandmadeInput.disabled = false;
                    if (productBiodegradableInput) productBiodegradableInput.disabled = false;
                    
                    // Get form data
                    const formData = new FormData(this);
                    const productData = Object.fromEntries(formData.entries());
                    
                    // Validation
                    const productName = document.getElementById('productName').value.trim();
                    const productCategory = document.getElementById('productCategory').value;
                    const productPrice = document.getElementById('productPrice').value;
                    
                    if (!productName) {
                        throw new Error('Product name is required');
                    }
                    
                    if (!productCategory) {
                        throw new Error('Please select a product category');
                    }
                    
                    if (!productPrice || parseFloat(productPrice) <= 0) {
                        throw new Error('Please enter a valid price');
                    }
                    
                    // Check if variants are added
                    if (selectedVariants.length === 0) {
                        throw new Error('Please add at least one product variant (color + size)');
                    }
                    
                    // Calculate total stock from variants
                    const totalStock = selectedVariants.reduce((sum, item) => sum + parseInt(item.quantity || 0), 0);
                    if (totalStock <= 0) {
                        throw new Error('Total stock quantity must be greater than 0');
                    }
                    
                    // Check if all color variants have images
                    const uniqueColors = [...new Set(selectedVariants.map(v => v.colorHex.toLowerCase()))];
                    const colorsWithImages = selectedVariants.filter(v => v.images && v.images.length > 0).map(v => v.colorHex.toLowerCase());
                    const uniqueColorsWithImages = [...new Set(colorsWithImages)];
                    
                    // Debug: Log image validation
                    console.log('🎨 Image Validation:');
                    console.log('  Total unique colors:', uniqueColors.length, uniqueColors);
                    console.log('  Colors with images:', uniqueColorsWithImages.length, uniqueColorsWithImages);
                    console.log('  Selected variants:', selectedVariants);
                    
                    if (uniqueColorsWithImages.length !== uniqueColors.length) {
                        const missingColors = uniqueColors.filter(c => !uniqueColorsWithImages.includes(c));
                        throw new Error(`Each color variant must have at least one image. Missing images for: ${missingColors.join(', ')}`);
                    }
                    
                    // Show loading state
                    submitBtn.disabled = true;
                    submitBtn.innerHTML = '<span style="display: inline-block; animation: spin 1s linear infinite;">⟳</span> Adding Product...';
                    submitBtn.style.opacity = '0.7';
                    
                    // Prepare FormData for API call
                    const apiFormData = new FormData(this);
                    
                    // Add variant images to FormData
                    apiFormData.delete('productImages');
                    console.log('📸 Adding images to FormData...');
                    
                    // Track which images have already been added to avoid duplicates
                    // For same-color variants, only add images once (for the first variant)
                    const addedImagesByColor = {};
                    const addedImageFiles = new Set(); // Track actual file objects to avoid duplicates
                    const imageColorMapping = []; // Track which color each image belongs to
                    
                    selectedVariants.forEach((variant, index) => {
                        console.log(`  Variant ${index}:`, {
                            color: variant.colorName,
                            hasImages: !!variant.images,
                            imageCount: variant.images ? variant.images.length : 0
                        });
                        
                        // Check if this color's images have already been added
                        const colorHex = variant.colorHex.toLowerCase();
                        if (!addedImagesByColor[colorHex] && variant.images && variant.images.length > 0) {
                            // First variant of this color - add its images
                            variant.images.forEach(imageObj => {
                                // imageObj is {file: File, preview: "data:..."}
                                const file = imageObj.file || imageObj; // Handle both formats
                                const fileKey = file.name + file.size; // Unique key for this file
                                
                                // Only add if not already added
                                if (!addedImageFiles.has(fileKey)) {
                                    console.log('    Adding image:', file.name, file.size, 'bytes', 'for color:', variant.colorName);
                                    apiFormData.append('productImages', file);
                                    // Track which color this image belongs to
                                    imageColorMapping.push({
                                        colorHex: colorHex,
                                        colorName: variant.colorName
                                    });
                                    addedImageFiles.add(fileKey);
                                }
                            });
                            // Mark this color as processed
                            addedImagesByColor[colorHex] = true;
                        } else if (addedImagesByColor[colorHex]) {
                            console.log(`    Skipping - images for ${variant.colorName} already added`);
                        }
                    });
                    
                    // Add image-to-color mapping as JSON
                    apiFormData.append('imageColorMapping', JSON.stringify(imageColorMapping));
                    
                    console.log('📸 Total images in FormData:', apiFormData.getAll('productImages').length);
                    console.log('📸 Image-to-color mapping:', imageColorMapping);
                    
                    // Debug: Log what we're sending
                    console.log('=== SENDING TO BACKEND ===');
                    console.log('Product Name:', apiFormData.get('productName'));
                    console.log('Category:', apiFormData.get('productCategory'));
                    console.log('Price:', apiFormData.get('productPrice'));
                    console.log('Colors Data:', apiFormData.get('productColorsData'));
                    console.log('Sizes Data:', apiFormData.get('productSizesData'));
                    console.log('Stock:', apiFormData.get('productStock'));
                    console.log('Images:', apiFormData.getAll('productImages'));
                    console.log('Selected Variants:', selectedVariants);
                    console.log('==========================');
                    
                    // Call backend API
                    const response = await fetch('/api/products/add', {
                        method: 'POST',
                        body: apiFormData
                    });
                    
                    const result = await response.json();
                    
                    if (!response.ok) {
                        throw new Error(result.message || 'Failed to add product');
                    }
                    
                    console.log('Product added successfully:', result.product);
                    
                    // Show success notification
                    showNotification('Product added successfully!', 'success');
                    
                    // Reset form
                    this.reset();
                    
                    // Switch back to Product List tab after delay
                    setTimeout(() => {
                        document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
                        productListTab.classList.add('active');
                        loadProductListContent();
                    }, 1000);
                    
                } catch (error) {
                    // Show error notification
                    showNotification(error.message || 'Failed to add product. Please try again.', 'error');
                    
                    // Reset button state
                    submitBtn.disabled = false;
                    submitBtn.textContent = originalBtnText;
                    submitBtn.style.opacity = '1';
                    
                    // Log error for debugging
                    console.error('Add product error:', error);
                } finally {
                    // Re-disable fields if they were disabled before
                    if (wasDisabled.name && productNameInput) productNameInput.disabled = true;
                    if (wasDisabled.category && productCategoryInput) productCategoryInput.disabled = true;
                    if (wasDisabled.price && productPriceInput) productPriceInput.disabled = true;
                    if (wasDisabled.description && productDescriptionInput) productDescriptionInput.disabled = true;
                    if (wasDisabled.materials && productMaterialsInput) productMaterialsInput.disabled = true;
                    if (wasDisabled.handmade && productHandmadeInput) productHandmadeInput.disabled = true;
                    if (wasDisabled.biodegradable && productBiodegradableInput) productBiodegradableInput.disabled = true;
                }
            });
        }

        if (cancelBtn) {
            cancelBtn.addEventListener('click', function() {
                // Switch back to Product List tab
                document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
                productListTab.classList.add('active');
                loadProductListContent();
            });
        }
    }

    // Sub-tab click handlers
    if (ordersTab) {
        ordersTab.addEventListener('click', function() {
            document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
            ordersTab.classList.add('active');
            loadOrdersContent();
        });
    }

    if (productSoldTab) {
        productSoldTab.addEventListener('click', function() {
            document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
            productSoldTab.classList.add('active');
            loadProductSoldContent();
        });
    }

    if (productListTab) {
        productListTab.addEventListener('click', function() {
            // Set active tab
            document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
            productListTab.classList.add('active');
            loadProductListContent();
        });
    }

    if (addProductTab) {
        addProductTab.addEventListener('click', function() {
            document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
            addProductTab.classList.add('active');
            loadAddProductContent();
        });
    }

    // ============================================
    // EDIT PRODUCT MODAL FUNCTIONALITY
    // ============================================
    
    const editModal = document.getElementById('edit-product-modal');
    const editModalOverlay = document.getElementById('edit-product-modal-overlay');
    const editModalClose = document.querySelector('.edit-modal-close');
    const editCancelBtn = document.getElementById('editCancelBtn');
    const editProductForm = document.getElementById('editProductForm');
    
    // Debug: Check if modal elements exist
    console.log('Edit Modal Elements:', {
        editModal: editModal ? 'Found' : 'NOT FOUND',
        editModalOverlay: editModalOverlay ? 'Found' : 'NOT FOUND',
        editModalClose: editModalClose ? 'Found' : 'NOT FOUND',
        editCancelBtn: editCancelBtn ? 'Found' : 'NOT FOUND',
        editProductForm: editProductForm ? 'Found' : 'NOT FOUND'
    });
    
    let currentEditingProductId = null;
    let variantsToDelete = []; // Track variants marked for deletion
    let imagesToDelete = []; // Track images marked for deletion
    let originalFormData = {}; // Track original form values
    
    // ADD VARIANT MODAL FUNCTIONALITY
    // ============================================
    
    const addVariantModal = document.getElementById('add-variant-modal');
    const addVariantModalOverlay = document.getElementById('add-variant-modal-overlay');
    const addVariantModalClose = document.querySelector('.add-variant-modal-close');
    const addVariantCancelBtn = document.getElementById('addVariantCancelBtn');
    const addVariantForm = document.getElementById('addVariantForm');
    
    let addVariantModalNewVariants = [];
    let addVariantModalImageFiles = [];
    
    // Archive Modal Functions
    let pendingArchiveProductId = null;
    
    function showArchiveModal(productId, productName, isActive) {
        const modal = document.getElementById('archive-modal');
        const overlay = document.getElementById('archive-modal-overlay');
        const message = document.getElementById('archive-modal-message');
        const modalTitle = modal.querySelector('.modal-title');
        const confirmBtn = document.getElementById('confirm-archive');
        
        console.log('showArchiveModal called:', { productId, productName, isActive, type: typeof isActive });
        
        if (modal && overlay && message && modalTitle && confirmBtn) {
            pendingArchiveProductId = productId;
            
            // Update modal content based on whether archiving or unarchiving
            if (isActive === true || isActive === 'true' || isActive === 1) {
                // Archiving an active product
                console.log('Setting to ARCHIVE mode');
                modalTitle.textContent = 'Archive Product';
                message.textContent = `Are you sure you want to archive "${productName}"? You can restore it later.`;
                confirmBtn.textContent = 'Archive';
            } else {
                // Unarchiving an archived product
                console.log('Setting to UNARCHIVE mode');
                modalTitle.textContent = 'Unarchive Product';
                message.textContent = `Are you sure you want to unarchive "${productName}"? It will be visible to buyers again.`;
                confirmBtn.textContent = 'Unarchive';
            }
            
            modal.style.display = 'flex';
            overlay.classList.add('show');
        }
    }
    
    function hideArchiveModal() {
        const modal = document.getElementById('archive-modal');
        const overlay = document.getElementById('archive-modal-overlay');
        
        if (modal && overlay) {
            modal.style.display = 'none';
            overlay.classList.remove('show');
            pendingArchiveProductId = null;
        }
    }
    
    // Archive modal event listeners
    const confirmArchiveBtn = document.getElementById('confirm-archive');
    const cancelArchiveBtn = document.getElementById('cancel-archive');
    const archiveModalOverlay = document.getElementById('archive-modal-overlay');
    const archiveModal = document.getElementById('archive-modal');
    
    if (confirmArchiveBtn) {
        confirmArchiveBtn.addEventListener('click', function() {
            if (pendingArchiveProductId) {
                archiveProduct(pendingArchiveProductId);
                hideArchiveModal();
            }
        });
    }
    
    if (cancelArchiveBtn) {
        cancelArchiveBtn.addEventListener('click', hideArchiveModal);
    }
    
    if (archiveModalOverlay) {
        archiveModalOverlay.addEventListener('click', hideArchiveModal);
    }
    
    if (archiveModal) {
        archiveModal.addEventListener('click', function(e) {
            if (e.target === archiveModal) {
                hideArchiveModal();
            }
        });
    }
    
    async function archiveProduct(productId) {
        try {
            const response = await fetch(`/api/products/${productId}/archive`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            const result = await response.json().catch(() => ({}));

            if (!response.ok || !result.success) {
                // Friendlier handling for the "ongoing orders" block (HTTP 409).
                // The backend returns reason='ongoing_orders' plus a count and
                // breakdown so we can show something specific to the seller.
                if (response.status === 409 && result.reason === 'ongoing_orders') {
                    let extra = '';
                    if (Array.isArray(result.sample_order_numbers) && result.sample_order_numbers.length) {
                        extra = ` (e.g. ${result.sample_order_numbers.slice(0, 2).join(', ')})`;
                    }
                    showNotification(
                        (result.message || 'Cannot archive product right now.') + extra,
                        'error'
                    );
                    // Refresh so the UI's has_ongoing_orders flag is up to date.
                    await fetchAndDisplayProducts();
                    return;
                }
                throw new Error(result.message || 'Failed to archive product');
            }

            showNotification(result.message || 'Product archived successfully!', 'success');

            // Refresh the product list immediately (no delay needed)
            await fetchAndDisplayProducts();

        } catch (error) {
            console.error('Error archiving product:', error);
            showNotification(error.message || 'Failed to archive product', 'error');
        }
    }
    
    // Delete Product Modal Functions
    let pendingDeleteProductId = null;
    let pendingDeleteProductName = null;
    
    function showDeleteProductModal(productId, productName) {
        const modal = document.getElementById('delete-product-modal');
        const overlay = document.getElementById('delete-product-modal-overlay');
        const message = document.getElementById('delete-product-message');
        
        if (modal && overlay && message) {
            pendingDeleteProductId = productId;
            pendingDeleteProductName = productName;
            
            message.textContent = `Are you sure you want to delete "${productName}"? This action cannot be undone.`;
            
            modal.classList.add('active');
            overlay.classList.add('show');
        }
    }
    
    function hideDeleteProductModal() {
        const modal = document.getElementById('delete-product-modal');
        const overlay = document.getElementById('delete-product-modal-overlay');
        
        if (modal && overlay) {
            modal.classList.remove('active');
            overlay.classList.remove('show');
            pendingDeleteProductId = null;
            pendingDeleteProductName = null;
        }
    }
    
    // Delete modal event listeners
    const confirmDeleteProductBtn = document.getElementById('confirm-delete-product');
    const cancelDeleteProductBtn = document.getElementById('cancel-delete-product');
    const deleteProductModalOverlay = document.getElementById('delete-product-modal-overlay');
    const deleteProductModal = document.getElementById('delete-product-modal');
    
    if (confirmDeleteProductBtn) {
        confirmDeleteProductBtn.addEventListener('click', function() {
            if (pendingDeleteProductId) {
                deleteProduct(pendingDeleteProductId);
                hideDeleteProductModal();
            }
        });
    }
    
    if (cancelDeleteProductBtn) {
        cancelDeleteProductBtn.addEventListener('click', hideDeleteProductModal);
    }
    
    if (deleteProductModalOverlay) {
        deleteProductModalOverlay.addEventListener('click', hideDeleteProductModal);
    }
    
    if (deleteProductModal) {
        deleteProductModal.addEventListener('click', function(e) {
            if (e.target === deleteProductModal) {
                hideDeleteProductModal();
            }
        });
    }
    
    async function deleteProduct(productId) {
        try {
            const response = await fetch(`/api/products/${productId}`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json'
                }
            });
            
            const result = await response.json();
            
            if (!response.ok || !result.success) {
                throw new Error(result.message || 'Failed to delete product');
            }
            
            showNotification('Product deleted successfully!', 'error');
            
            // Refresh the product list immediately (no delay needed)
            await fetchAndDisplayProducts();
            
        } catch (error) {
            console.error('Error deleting product:', error);
            showNotification(error.message || 'Failed to delete product', 'error');
        }
    }
    
    async function openEditProductModal(productId) {
        try {
            console.log('Opening edit modal for product ID:', productId);
            
            // Fetch product details
            const response = await fetch(`/api/products/${productId}`);
            console.log('API Response status:', response.status);
            
            const result = await response.json();
            console.log('API Result:', result);
            
            if (!response.ok || !result.success) {
                throw new Error(result.message || 'Failed to fetch product details');
            }
            
            const product = result.product;
            currentEditingProductId = productId;
            
            console.log('Product data:', product);
            console.log('Variants:', product.variants);
            
            // Debug: Check variant images
            if (product.variants) {
                product.variants.forEach(v => {
                    console.log(`Variant ${v.variant_id} (${v.color} ${v.size}):`, {
                        images: v.images,
                        image_url: v.image_url,
                        imageCount: v.images ? v.images.length : 0
                    });
                });
            }
            
            // Populate form fields
            document.getElementById('editProductId').value = productId;
            document.getElementById('editProductName').value = product.product_name;
            document.getElementById('editProductCategory').value = product.category;
            const editPriceInput = document.getElementById('editProductPrice');
            
            // Format price with commas
            const formattedPrice = parseFloat(product.price).toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
            editPriceInput.value = formattedPrice;
            
            document.getElementById('editProductDescription').value = product.description || '';
            document.getElementById('editProductMaterials').value = product.materials || '';
            
            // Remove old event listeners by cloning the element
            const newEditPriceInput = editPriceInput.cloneNode(true);
            editPriceInput.parentNode.replaceChild(newEditPriceInput, editPriceInput);
            
            // Add fresh price formatting handlers
            newEditPriceInput.addEventListener('focus', function() {
                // Remove commas when user starts editing
                this.value = this.value.replace(/,/g, '');
            });
            
            newEditPriceInput.addEventListener('blur', function() {
                // Add commas back when user finishes editing
                const value = parseFloat(this.value.replace(/,/g, ''));
                if (!isNaN(value) && value >= 0) {
                    this.value = value.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
                }
            });
            
            // Set SDG checkboxes
            document.getElementById('editProductHandmade').checked = product.sdg === 'handmade' || product.sdg === 'both';
            document.getElementById('editProductBiodegradable').checked = product.sdg === 'biodegradable' || product.sdg === 'both';
            
            // Save original form data for change detection
            const originalVariants = product.variants.map(v => ({
                variant_id: v.variant_id,
                stock_quantity: v.stock_quantity
            }));
            // Sort variants for consistent comparison (numeric sort)
            originalVariants.sort((a, b) => a.variant_id - b.variant_id);
            
            originalFormData = {
                product_name: product.product_name,
                category: product.category,
                price: product.price,
                description: product.description || '',
                materials: product.materials || '',
                handmade: product.sdg === 'handmade' || product.sdg === 'both',
                biodegradable: product.sdg === 'biodegradable' || product.sdg === 'both',
                variants: JSON.stringify(originalVariants)
            };
            
            // Size dropdown is no longer needed since we removed add variant functionality
            
            // Display current variants
            displayEditCurrentVariants(product.variants);
            
            // Reset deletion list
            variantsToDelete = [];
            
            // Edit modal is now focused only on editing existing product info and variants
            
            // Show modal with null checks
            if (!editModal || !editModalOverlay) {
                console.error('Modal elements not found:', { editModal, editModalOverlay });
                throw new Error('Modal elements not found in DOM');
            }
            
            console.log('Showing modal...');
            editModal.classList.add('show');
            editModalOverlay.classList.add('show');
            console.log('Modal shown successfully');
            
        } catch (error) {
            console.error('Error opening edit modal:', error);
            alert('Failed to load product details: ' + error.message);
        }
    }
    
    async function openAddVariantModal(productId) {
        try {
            console.log('Opening add variant modal for product ID:', productId);
            
            // Fetch product details
            const response = await fetch(`/api/products/${productId}`);
            const result = await response.json();
            
            if (!response.ok || !result.success) {
                throw new Error(result.message || 'Failed to fetch product details');
            }
            
            const product = result.product;
            currentEditingProductId = productId;
            
            // Store product details globally for form submission
            window.currentProductDetails = product;
            
            // Get modal elements
            const addVariantModal = document.getElementById('add-variant-modal');
            const addVariantModalOverlay = document.getElementById('add-variant-modal-overlay');
            
            // Set product ID
            document.getElementById('addVariantProductId').value = productId;
            
            // Populate size dropdown
            const addVariantSize = document.getElementById('addVariantSize');
            addVariantSize.innerHTML = '<option value="">Select Size</option>';
            
            if (window.SizeConfig && window.SizeConfig.categories[product.category]) {
                const sizes = window.SizeConfig.categories[product.category].sizes;
                sizes.forEach(size => {
                    addVariantSize.innerHTML += `<option value="${size}">${size}</option>`;
                });
            }
            
            // Reset new variants
            addVariantModalNewVariants = [];
            document.getElementById('addVariantModalNewVariantsDisplay').innerHTML = '';
            
            // Reset color picker
            const addVariantColor = document.getElementById('addVariantColor');
            const addVariantColorNameDisplay = document.getElementById('addVariantColorNameDisplay');
            const addVariantColorName = document.getElementById('addVariantColorName');
            if (addVariantColor && addVariantColorNameDisplay && addVariantColorName && window.ColorNameGenerator) {
                addVariantColor.value = '#000000';
                const initialColorName = window.ColorNameGenerator.getColorName('#000000');
                addVariantColorNameDisplay.textContent = initialColorName;
                addVariantColorName.value = initialColorName;
            }
            
            // Reset variant images
            addVariantModalImageFiles = [];
            const addVariantModalImagesContainer = document.getElementById('addVariantModalImagesContainer');
            if (addVariantModalImagesContainer) {
                addVariantModalImagesContainer.innerHTML = `
                    <button type="button" class="add-variant-image-placeholder" id="addVariantModalImageBtn">
                        <i class="bi bi-plus"></i>
                        <span>Add Images</span>
                    </button>
                `;
            }
            
            // Reset quantity
            document.getElementById('addVariantQuantity').value = '1';
            
            // Show modal
            addVariantModal.classList.add('show');
            addVariantModalOverlay.classList.add('show');
            
            // Attach event listener for image upload button
            setTimeout(() => {
                const addVariantImageBtn = document.getElementById('addVariantModalImageBtn');
                const addVariantImageInput = document.getElementById('addVariantModalImageInput');
                
                if (addVariantImageBtn && addVariantImageInput) {
                    // Remove any existing listeners by cloning
                    const newBtn = addVariantImageBtn.cloneNode(true);
                    addVariantImageBtn.parentNode.replaceChild(newBtn, addVariantImageBtn);
                    
                    const newInput = addVariantImageInput.cloneNode(true);
                    addVariantImageInput.parentNode.replaceChild(newInput, addVariantImageInput);
                    
                    // Ensure multiple attribute is set
                    newInput.setAttribute('multiple', 'multiple');
                    console.log('📁 File input multiple attribute:', newInput.hasAttribute('multiple'));
                    
                    // Add click listener to trigger file input
                    newBtn.addEventListener('click', function(e) {
                        e.preventDefault();
                        e.stopPropagation();
                        newInput.click();
                    });
                    
                    // Handle file selection
                    newInput.addEventListener('change', function(e) {
                        console.log('🔍 File input changed');
                        console.log('Files selected:', e.target.files.length);
                        
                        if (e.target.files && e.target.files.length > 0) {
                            const files = Array.from(e.target.files);
                            console.log('Files array:', files.length);
                            console.log('Current addVariantModalImageFiles:', addVariantModalImageFiles.length);
                            
                            let loadedCount = 0;
                            
                            files.forEach((file, index) => {
                                console.log(`Reading file ${index + 1}:`, file.name);
                                const reader = new FileReader();
                                reader.onload = function(event) {
                                    addVariantModalImageFiles.push({
                                        file: file,
                                        preview: event.target.result
                                    });
                                    loadedCount++;
                                    console.log(`File ${index + 1} loaded. Total loaded: ${loadedCount}/${files.length}`);
                                    
                                    // Update display only after all files are loaded
                                    if (loadedCount === files.length) {
                                        console.log('✅ All files loaded. Total images:', addVariantModalImageFiles.length);
                                        updateAddVariantImagesDisplay();
                                        showNotification(`${files.length} image(s) added`, 'success');
                                    }
                                };
                                reader.readAsDataURL(file);
                            });
                            
                            this.value = ''; // Reset input
                        }
                    });
                }
            }, 100);
            
        } catch (error) {
            console.error('Error opening add variant modal:', error);
            alert('Failed to load product details. Please try again.');
        }
    }
    
    function updateAddVariantImagesDisplay() {
        const container = document.getElementById('addVariantModalImagesContainer');
        if (!container) return;
        
        console.log('📸 Updating display with', addVariantModalImageFiles.length, 'images');
        
        // Use template literals like Add Product section
        container.innerHTML = addVariantModalImageFiles.map((img, index) => `
            <div class="variant-image-item-add" draggable="true" data-index="${index}">
                <img src="${img.preview}" alt="Variant image" class="add-variant-image-preview">
                <button type="button" class="remove-add-variant-image-btn" data-index="${index}">
                    <i class="bi bi-x"></i>
                </button>
                ${index === 0 ? '<span class="primary-badge">Primary</span>' : ''}
            </div>
        `).join('') + `
            <button type="button" class="add-variant-image-placeholder" id="addVariantModalImageBtn">
                <i class="bi bi-plus"></i>
                <span>Add More</span>
            </button>
        `;
        
        // Re-attach event listeners
        const addVariantImageInput = document.getElementById('addVariantModalImageInput');
        const newAddBtn = container.querySelector('#addVariantModalImageBtn');
        if (newAddBtn) {
            newAddBtn.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                if (addVariantImageInput) {
                    addVariantImageInput.click();
                }
            });
        }
        
        // Add remove button listeners
        container.querySelectorAll('.remove-add-variant-image-btn').forEach(btn => {
            btn.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                const index = parseInt(this.dataset.index);
                addVariantModalImageFiles.splice(index, 1);
                updateAddVariantImagesDisplay();
                showNotification('Image removed', 'info');
            });
        });
        
        // Add drag and drop functionality
        const imageItems = container.querySelectorAll('.variant-image-item-add');
        let draggedIndex = null;
        
        imageItems.forEach((item, index) => {
            item.addEventListener('dragstart', function(e) {
                draggedIndex = index;
                this.style.opacity = '0.5';
            });
            
            item.addEventListener('dragend', function(e) {
                this.style.opacity = '1';
            });
            
            item.addEventListener('dragover', function(e) {
                e.preventDefault();
                this.style.borderColor = '#D3BD9B';
            });
            
            item.addEventListener('dragleave', function(e) {
                this.style.borderColor = '';
            });
            
            item.addEventListener('drop', function(e) {
                e.preventDefault();
                this.style.borderColor = '';
                
                const dropIndex = index;
                if (draggedIndex !== null && draggedIndex !== dropIndex) {
                    // Reorder array
                    const [draggedItem] = addVariantModalImageFiles.splice(draggedIndex, 1);
                    addVariantModalImageFiles.splice(dropIndex, 0, draggedItem);
                    
                    updateAddVariantImagesDisplay();
                    showNotification('Images reordered. First image is now primary.', 'success');
                }
            });
        });
    }
    
    function displayEditCurrentVariants(variants) {
        const container = document.getElementById('editCurrentVariants');
        container.innerHTML = '';
        
        if (!variants || variants.length === 0) {
            container.innerHTML = '<p style="color: #999; text-align: center;">No variants available</p>';
            return;
        }
        
        // Group variants by color
        const colorGroups = {};
        variants.forEach(variant => {
            const colorHex = (variant.hex_code || '#000000').toLowerCase();
            if (!colorGroups[colorHex]) {
                colorGroups[colorHex] = {
                    color: variant.color_name || variant.color || 'Unknown',
                    hexCode: variant.hex_code || '#000000',
                    variants: []
                };
            }
            colorGroups[colorHex].variants.push(variant);
        });
        
        // Display each color group
        Object.entries(colorGroups).forEach(([colorHex, colorGroup]) => {
            const colorDiv = document.createElement('div');
            colorDiv.className = 'edit-color-group';
            
            // Get images from variant that has images (prefer variant with images over empty ones)
            let firstVariant = colorGroup.variants[0];
            const variantWithImages = colorGroup.variants.find(v => v.images && v.images.length > 0);
            if (variantWithImages) {
                firstVariant = variantWithImages;
            }
            
            const hexColor = colorGroup.hexCode;
            const colorName = colorGroup.color;
            
            // Initialize images array for this color group
            if (!window.variantImagesData) {
                window.variantImagesData = {};
            }
            
            // Use first variant's ID as the key for images
            const imageKeyId = firstVariant.variant_id;
            window.variantImagesData[imageKeyId] = [];
            
            // Add all images from first variant (all same-color variants share these images)
            console.log(`🔍 First variant for color ${colorName}:`, firstVariant);
            console.log(`   - firstVariant.images:`, firstVariant.images);
            console.log(`   - firstVariant.images length:`, firstVariant.images ? firstVariant.images.length : 'undefined');
            
            if (firstVariant.images && firstVariant.images.length > 0) {
                console.log(`✅ Loading ${firstVariant.images.length} images for color ${colorName}`);
                firstVariant.images.forEach((img, idx) => {
                    console.log(`   Image ${idx}: ${img.url} (primary: ${img.is_primary})`);
                    
                    // Check if URL is already a full Supabase URL (starts with http:// or https://)
                    const imageUrl = img.url;
                    const displayUrl = (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) 
                        ? imageUrl 
                        : `/${imageUrl}`;
                    
                    window.variantImagesData[imageKeyId].push({
                        url: imageUrl,
                        displayUrl: displayUrl,
                        isExisting: true,
                        isPrimary: img.is_primary
                    });
                });
            } 
            else if (firstVariant.image_url) {
                console.log(`⚠️ Loading 1 image (fallback) for color ${colorName}`);
                
                // Check if URL is already a full Supabase URL
                const imageUrl = firstVariant.image_url;
                const displayUrl = (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) 
                    ? imageUrl 
                    : `/${imageUrl}`;
                
                window.variantImagesData[imageKeyId].push({
                    url: imageUrl,
                    displayUrl: displayUrl,
                    isExisting: true,
                    isPrimary: true
                });
            } else {
                console.error(`❌ No images found for color ${colorName}!`);
            }
            
            console.log(`📊 Final images for color ${colorName}:`, window.variantImagesData[imageKeyId]);
            
            // Build HTML for color group
            let colorGroupHTML = `
                <div class="edit-color-section">
                    <div class="edit-variant-images-gallery" data-variant-id="${imageKeyId}">
                        <div class="variant-images-container" data-variant-id="${imageKeyId}">
                            ${window.variantImagesData[imageKeyId].map((img, idx) => `
                                <div class="variant-image-item" draggable="true" data-variant-id="${imageKeyId}" data-image-index="${idx}">
                                    <img src="${img.displayUrl || img.url}" alt="${colorName}" class="edit-variant-image clickable-image">
                                    <button type="button" class="remove-variant-image-btn" data-variant-id="${imageKeyId}" data-image-index="${idx}">
                                        <i class="bi bi-x"></i>
                                    </button>
                                    ${idx === 0 ? '<span class="primary-badge">Primary</span>' : ''}
                                </div>
                            `).join('')}
                            <button type="button" class="add-variant-image-btn" data-variant-id="${imageKeyId}" title="Add more images">
                                <i class="bi bi-plus"></i>
                            </button>
                        </div>
                        <input type="file" class="variant-image-input" data-variant-id="${imageKeyId}" accept="image/*" multiple style="display: none;">
                        <p class="image-upload-hint"><i class="bi bi-info-circle"></i> Use a product-only image for the primary photo. Ensure a plain white background with no models or extra elements.</p>
                    </div>
                    
                    <div class="edit-color-info">
                        <div class="edit-variant-color">
                            <span class="color-swatch" style="background-color: ${hexColor};"></span>
                            <span>${colorName}</span>
                        </div>
                    </div>
                    
                    <div class="edit-sizes-list">
            `;
            
            // Add size rows for each variant of this color
            colorGroup.variants.forEach(variant => {
                colorGroupHTML += `
                    <div class="edit-size-row">
                        <div class="edit-size-info">
                            <span class="size-label">Size: ${variant.size}</span>
                            ${variant.stock_quantity === 0 ? '<span class="out-of-stock-badge">Out of Stock</span>' : ''}
                        </div>
                        <div class="edit-size-quantity">
                            <label>Stock:</label>
                            <input type="number" min="0" value="${variant.stock_quantity}" data-variant-id="${variant.variant_id}">
                        </div>
                        <button type="button" class="delete-variant-btn" data-variant-id="${variant.variant_id}">
                            <i class="bi bi-trash"></i>
                        </button>
                    </div>
                `;
            });
            
            colorGroupHTML += `
                    </div>
                </div>
            `;
            
            colorDiv.innerHTML = colorGroupHTML;
            container.appendChild(colorDiv);
        });
        
        // Add event listeners for delete buttons
        container.querySelectorAll('.delete-variant-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                const variantId = this.dataset.variantId;
                const variantItem = this.closest('.edit-size-row');
                
                // Mark variant for deletion (visual feedback)
                if (!variantsToDelete.includes(variantId)) {
                    variantsToDelete.push(variantId);
                    variantItem.style.opacity = '0.5';
                    variantItem.style.textDecoration = 'line-through';
                    this.innerHTML = '<i class="bi bi-arrow-counterclockwise"></i>';
                    this.title = 'Undo delete';
                } else {
                    // Undo deletion
                    variantsToDelete = variantsToDelete.filter(id => id !== variantId);
                    variantItem.style.opacity = '1';
                    variantItem.style.textDecoration = 'none';
                    this.innerHTML = '<i class="bi bi-trash"></i>';
                    this.title = 'Delete';
                }
            });
        });
        
        // Add event listeners for clickable images
        container.querySelectorAll('.clickable-image').forEach(img => {
            img.addEventListener('click', function() {
                showImageModal(this.src);
            });
        });
        
        // Add event listeners for add image buttons
        container.querySelectorAll('.add-variant-image-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                const variantId = this.dataset.variantId;
                const fileInput = container.querySelector(`.variant-image-input[data-variant-id="${variantId}"]`);
                if (fileInput) {
                    fileInput.click();
                }
            });
        });
        
        // Add drag-and-drop functionality and remove button listeners for initial images
        container.querySelectorAll('.edit-color-group').forEach(colorGroup => {
            // Find the images container in this color group
            const imagesContainers = colorGroup.querySelectorAll('.variant-images-container');
            imagesContainers.forEach(imagesContainer => {
                const variantId = imagesContainer.dataset.variantId;
                if (variantId) {
                    attachDragAndDropListeners(imagesContainer, variantId, container);
                }
                
                // Attach remove button listeners for initial load
                imagesContainer.querySelectorAll('.remove-variant-image-btn').forEach(btn => {
                    btn.addEventListener('click', function() {
                        const vId = this.dataset.variantId;
                        const imageIndex = parseInt(this.dataset.imageIndex);
                        
                        if (window.variantImagesData && window.variantImagesData[vId]) {
                            const imageToDelete = window.variantImagesData[vId][imageIndex];
                            
                            // Track existing images for deletion
                            if (imageToDelete.isExisting && imageToDelete.url) {
                                imagesToDelete.push({
                                    variantId: vId,
                                    imageUrl: imageToDelete.url
                                });
                                console.log('🗑️ Marked image for deletion:', imageToDelete.url);
                            }
                            
                            window.variantImagesData[vId].splice(imageIndex, 1);
                            updateVariantImagesGallery(vId, container);
                            showNotification('Image removed', 'info');
                        }
                    });
                });
            });
        });
        
        // Add event listeners for file inputs (multiple images)
        container.querySelectorAll('.variant-image-input').forEach(input => {
            input.addEventListener('change', function(e) {
                if (e.target.files && e.target.files.length > 0) {
                    const variantId = this.dataset.variantId;
                    const files = Array.from(e.target.files);
                    
                    if (!window.variantImagesData) {
                        window.variantImagesData = {};
                    }
                    if (!window.variantImagesData[variantId]) {
                        window.variantImagesData[variantId] = [];
                    }
                    
                    // Add new images
                    files.forEach(file => {
                        const reader = new FileReader();
                        reader.onload = function(event) {
                            const dataUrl = event.target.result;
                            window.variantImagesData[variantId].push({
                                url: dataUrl,  // For new images, this is the data URL
                                displayUrl: dataUrl,  // Same for display
                                file: file,
                                isExisting: false
                            });
                            
                            // Re-render the images gallery for this variant
                            updateVariantImagesGallery(variantId, container);
                        };
                        reader.readAsDataURL(file);
                    });
                    
                    showNotification(`${files.length} image(s) added. Save changes to upload.`, 'info');
                    
                    // Reset input
                    this.value = '';
                }
            });
        });
        
        // Add event listeners for remove image buttons
        container.querySelectorAll('.remove-variant-image-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                const variantId = this.dataset.variantId;
                const imageIndex = parseInt(this.dataset.imageIndex);
                
                if (window.variantImagesData && window.variantImagesData[variantId]) {
                    const imageToDelete = window.variantImagesData[variantId][imageIndex];
                    
                    // Track existing images for deletion
                    if (imageToDelete.isExisting && imageToDelete.url) {
                        imagesToDelete.push({
                            variantId: variantId,
                            imageUrl: imageToDelete.url
                        });
                        console.log('🗑️ Marked image for deletion:', imageToDelete.url);
                    }
                    
                    window.variantImagesData[variantId].splice(imageIndex, 1);
                    updateVariantImagesGallery(variantId, container);
                    showNotification('Image removed', 'info');
                }
            });
        });
    }
    
    function attachDragAndDropListeners(imagesContainer, variantId, container) {
        const imageItems = imagesContainer.querySelectorAll('.variant-image-item');
        let draggedIndex = null;
        
        imageItems.forEach((item, index) => {
            item.addEventListener('dragstart', function(e) {
                draggedIndex = index;
                this.style.opacity = '0.5';
            });
            
            item.addEventListener('dragend', function(e) {
                this.style.opacity = '1';
            });
            
            item.addEventListener('dragover', function(e) {
                e.preventDefault();
                this.style.borderColor = '#D3BD9B';
            });
            
            item.addEventListener('dragleave', function(e) {
                this.style.borderColor = '';
            });
            
            item.addEventListener('drop', function(e) {
                e.preventDefault();
                this.style.borderColor = '';
                
                const dropIndex = index;
                if (draggedIndex !== null && draggedIndex !== dropIndex) {
                    // Reorder array
                    const [draggedItem] = window.variantImagesData[variantId].splice(draggedIndex, 1);
                    window.variantImagesData[variantId].splice(dropIndex, 0, draggedItem);
                    
                    console.log(`✅ Ready to switch is_primary for variant ${variantId} - Image moved from position ${draggedIndex} to ${dropIndex}`);
                    
                    updateVariantImagesGallery(variantId, container);
                    showNotification('Images reordered. First image is now primary.', 'success');
                }
            });
        });
    }
    
    function updateVariantImagesGallery(variantId, container) {
        const imagesContainer = container.querySelector(`.variant-images-container[data-variant-id="${variantId}"]`);
        if (!imagesContainer || !window.variantImagesData || !window.variantImagesData[variantId]) {
            return;
        }
        
        const images = window.variantImagesData[variantId];
        const variantItem = container.querySelector(`.edit-variant-item[data-variant-id="${variantId}"]`);
        const colorName = variantItem?.querySelector('.edit-variant-color span:last-child')?.textContent || 'Variant';
        
        imagesContainer.innerHTML = `
            ${images.map((img, idx) => `
                <div class="variant-image-item" draggable="true" data-variant-id="${variantId}" data-image-index="${idx}">
                    <img src="${img.displayUrl || img.url}" alt="${colorName}" class="edit-variant-image clickable-image">
                    <button type="button" class="remove-variant-image-btn" data-variant-id="${variantId}" data-image-index="${idx}">
                        <i class="bi bi-x"></i>
                    </button>
                    ${idx === 0 ? '<span class="primary-badge">Primary</span>' : ''}
                </div>
            `).join('')}
            <button type="button" class="add-variant-image-btn" data-variant-id="${variantId}" title="Add more images">
                <i class="bi bi-plus"></i>
            </button>
        `;
        
        // Re-attach event listeners for the updated gallery
        imagesContainer.querySelectorAll('.clickable-image').forEach(img => {
            img.addEventListener('click', function() {
                showImageModal(this.src);
            });
        });
        
        imagesContainer.querySelectorAll('.add-variant-image-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                const vId = this.dataset.variantId;
                const fileInput = container.querySelector(`.variant-image-input[data-variant-id="${vId}"]`);
                if (fileInput) {
                    fileInput.click();
                }
            });
        });
        
        imagesContainer.querySelectorAll('.remove-variant-image-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                const vId = this.dataset.variantId;
                const imageIndex = parseInt(this.dataset.imageIndex);
                
                if (window.variantImagesData && window.variantImagesData[vId]) {
                    const imageToDelete = window.variantImagesData[vId][imageIndex];
                    
                    // Track existing images for deletion
                    if (imageToDelete.isExisting && imageToDelete.url) {
                        imagesToDelete.push({
                            variantId: vId,
                            imageUrl: imageToDelete.url
                        });
                        console.log('🗑️ Marked image for deletion:', imageToDelete.url);
                    }
                    
                    window.variantImagesData[vId].splice(imageIndex, 1);
                    updateVariantImagesGallery(vId, container);
                    showNotification('Image removed', 'info');
                }
            });
        });
        
        // Add drag-and-drop functionality
        attachDragAndDropListeners(imagesContainer, variantId, container);
    }
    
    async function deleteVariant(variantId) {
        try {
            const response = await fetch(`/api/products/variants/${variantId}`, {
                method: 'DELETE'
            });
            
            const result = await response.json();
            
            if (!response.ok || !result.success) {
                throw new Error(result.message || 'Failed to delete variant');
            }
            
            // Remove variant from UI
            const variantItem = document.querySelector(`.edit-variant-item[data-variant-id="${variantId}"]`);
            if (variantItem) {
                variantItem.remove();
            }
            
            alert('Variant deleted successfully!');
            
        } catch (error) {
            console.error('Error deleting variant:', error);
            alert('Failed to delete variant. Please try again.');
        }
    }
    
    function closeEditModal() {
        if (editModal) editModal.classList.remove('show');
        if (editModalOverlay) editModalOverlay.classList.remove('show');
        currentEditingProductId = null;
        variantsToDelete = [];
        imagesToDelete = [];
        if (editProductForm) editProductForm.reset();
    }
    
    // Edit modal close handlers
    if (editModalClose) {
        editModalClose.addEventListener('click', closeEditModal);
    }
    if (editCancelBtn) {
        editCancelBtn.addEventListener('click', closeEditModal);
    }
    if (editModalOverlay) {
        editModalOverlay.addEventListener('click', closeEditModal);
    }
    
    // Add Variant modal close handlers
    function closeAddVariantModal() {
        if (addVariantModal && addVariantModalOverlay) {
            addVariantModal.classList.remove('show');
            addVariantModalOverlay.classList.remove('show');
        }
    }
    
    if (addVariantModalClose) {
        addVariantModalClose.addEventListener('click', closeAddVariantModal);
    }
    if (addVariantCancelBtn) {
        addVariantCancelBtn.addEventListener('click', closeAddVariantModal);
    }
    if (addVariantModalOverlay) {
        addVariantModalOverlay.addEventListener('click', closeAddVariantModal);
    }
    
    // Add Variant Form submission
    if (addVariantForm) {
        addVariantForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            if (addVariantModalNewVariants.length === 0) {
                showNotification('Please add at least one variant before saving', 'error');
                return;
            }
            
            const productId = document.getElementById('addVariantProductId').value;
            
            if (!productId) {
                showNotification('Product ID is missing', 'error');
                return;
            }
            
            try {
                const formData = new FormData();
                
                // Get product details from stored data
                const product = window.currentProductDetails;
                
                if (!product) {
                    throw new Error('Product details not found. Please try again.');
                }
                
                // Add product details (required by backend) - use correct field names
                formData.append('productName', product.product_name);
                formData.append('productCategory', product.category);
                formData.append('productPrice', product.price);
                formData.append('productDescription', product.description || '');
                formData.append('productMaterials', product.materials || '');
                
                // Add SDG checkboxes
                if (product.sdg === 'handmade' || product.sdg === 'both') {
                    formData.append('productHandmade', 'on');
                }
                if (product.sdg === 'biodegradable' || product.sdg === 'both') {
                    formData.append('productBiodegradable', 'on');
                }
                
                // Prepare existing variants data (for stock calculation)
                const existingVariantsData = product.variants.map(v => ({
                    variant_id: v.variant_id,
                    quantity: v.stock_quantity
                }));
                formData.append('variantsData', JSON.stringify(existingVariantsData));
                
                // Prepare new variants data
                const newVariantsData = addVariantModalNewVariants.map(v => ({
                    hex: v.colorHex,
                    colorName: v.colorName,
                    size: v.size,
                    quantity: parseInt(v.quantity) || 1,
                    numImages: v.images ? v.images.length : 0
                }));
                
                formData.append('newVariantsData', JSON.stringify(newVariantsData));
                
                // Add all variant images in order
                addVariantModalNewVariants.forEach(variant => {
                    if (variant.images && variant.images.length > 0) {
                        variant.images.forEach(img => {
                            if (img.file) {
                                formData.append('newVariantImages', img.file);
                            }
                        });
                    }
                });
                
                console.log('Submitting variants for product:', productId);
                console.log('New variants data:', newVariantsData);
                console.log('Total images:', addVariantModalNewVariants.reduce((sum, v) => sum + (v.images?.length || 0), 0));
                
                // Send request using PUT - backend will only update variants
                const response = await fetch(`/api/products/${productId}`, {
                    method: 'PUT',
                    body: formData
                });
                
                const result = await response.json();
                
                if (!response.ok || !result.success) {
                    throw new Error(result.message || 'Failed to add variants');
                }
                
                console.log('✅ Variants added successfully:', result);
                
                // Close modal
                closeAddVariantModal();
                
                // Reset the variants array
                addVariantModalNewVariants = [];
                addVariantModalImageFiles = [];
                
                // Refresh product list immediately (no delay needed)
                await fetchAndDisplayProducts();
                
                showNotification('Variants added successfully!', 'success');
                
            } catch (error) {
                console.error('Error adding variants:', error);
                showNotification(error.message || 'Failed to add variants', 'error');
            }
        });
    }
    
    // Helper function to get color name from API
    async function getColorNameFromAPI(hexColor) {
        try {
            const cleanHex = hexColor.replace('#', '');
            const response = await fetch(`https://www.thecolorapi.com/id?hex=${cleanHex}`);
            const data = await response.json();
            return data.name.value;
        } catch (error) {
            console.error('Color API error:', error);
            return 'Custom Color';
        }
    }
    
    // Edit variant color picker removed - no longer needed
    
    // Add Variant modal color picker - auto-generate color name
    const addVariantColor = document.getElementById('addVariantColor');
    const addVariantColorNameDisplay = document.getElementById('addVariantColorNameDisplay');
    const addVariantColorName = document.getElementById('addVariantColorName');
    
    if (addVariantColor && addVariantColorNameDisplay && addVariantColorName) {
        // Set initial color name using API
        getColorNameFromAPI(addVariantColor.value).then(colorName => {
            addVariantColorNameDisplay.textContent = colorName;
            addVariantColorName.value = colorName;
        });
        
        // Function to update color name using API
        const updateAddVariantColorName = async function() {
            const colorName = await getColorNameFromAPI(addVariantColor.value);
            addVariantColorNameDisplay.textContent = colorName;
            addVariantColorName.value = colorName;
            console.log('Add Variant Color changed to:', colorName, '(' + addVariantColor.value + ')');
        };
        
        // Add both 'input' and 'change' event listeners for cross-browser compatibility
        addVariantColor.addEventListener('input', updateAddVariantColorName);
        addVariantColor.addEventListener('change', updateAddVariantColorName);
        
        // Show uploaded images when color picker is clicked
        addVariantColor.addEventListener('click', function() {
            if (addVariantModalImageFiles && addVariantModalImageFiles.length > 0) {
                const imageUrls = addVariantModalImageFiles.map(img => img.preview);
                showImageCarouselModal(imageUrls, 0);
            }
        });
    }
    
    // Edit variant image upload removed - no longer needed
    
    // Add Variant Modal - Add Variant Button
    const addVariantModalBtn = document.getElementById('addVariantModalBtn');
    if (addVariantModalBtn) {
        addVariantModalBtn.addEventListener('click', function() {
            const colorHex = document.getElementById('addVariantColor').value;
            const colorName = document.getElementById('addVariantColorName').value;
            const size = document.getElementById('addVariantSize').value;
            const quantity = parseInt(document.getElementById('addVariantQuantity').value) || 1;
            
            console.log('Adding variant:', { colorHex, colorName, size, quantity, images: addVariantModalImageFiles.length });
            
            // Validation
            if (!size) {
                showNotification('Please select a size', 'error');
                return;
            }
            
            if (quantity <= 0) {
                showNotification('Quantity must be greater than 0', 'error');
                return;
            }
            
            if (addVariantModalImageFiles.length === 0) {
                showNotification('Please upload at least one image for this variant', 'error');
                return;
            }
            
            // Check if this color-size combination already exists
            const existingVariant = addVariantModalNewVariants.find(v => 
                v.colorHex.toLowerCase() === colorHex.toLowerCase() && v.size === size
            );
            if (existingVariant) {
                showNotification(`${colorName} - ${size} already added`, 'error');
                return;
            }
            
            // Add variant
            const variant = {
                colorHex,
                colorName,
                size,
                quantity,
                images: [...addVariantModalImageFiles]
            };
            
            addVariantModalNewVariants.push(variant);
            displayAddVariantModalNewVariants();
            
            // Reset inputs
            document.getElementById('addVariantSize').value = '';
            document.getElementById('addVariantQuantity').value = '1';
            addVariantModalImageFiles = [];
            
            // Reset images display
            const addVariantModalImagesContainer = document.getElementById('addVariantModalImagesContainer');
            if (addVariantModalImagesContainer) {
                addVariantModalImagesContainer.innerHTML = `
                    <button type="button" class="add-variant-image-placeholder" id="addVariantModalImageBtn">
                        <i class="bi bi-plus"></i>
                        <span>Add Images</span>
                    </button>
                `;
                
                // Re-attach event listener
                setTimeout(() => {
                    const newAddBtn = document.getElementById('addVariantModalImageBtn');
                    const addVariantImageInput = document.getElementById('addVariantModalImageInput');
                    if (newAddBtn && addVariantImageInput) {
                        newAddBtn.addEventListener('click', function(e) {
                            e.preventDefault();
                            e.stopPropagation();
                            addVariantImageInput.click();
                        });
                    }
                }, 100);
            }
            
            showNotification(`${colorName} - ${size} added successfully`, 'success');
        });
    }
    
    function displayAddVariantModalNewVariants() {
        const container = document.getElementById('addVariantModalNewVariantsDisplay');
        if (!container) return;
        
        container.innerHTML = '';
        
        if (addVariantModalNewVariants.length === 0) {
            container.innerHTML = '<p class="no-variants-message">No variants added yet</p>';
            return;
        }
        
        addVariantModalNewVariants.forEach((variant, index) => {
            const variantTag = document.createElement('div');
            variantTag.className = 'size-tag';
            
            // Create images preview (show first image with count badge)
            let imagesPreview = '';
            if (variant.images && variant.images.length > 0) {
                const firstImage = variant.images[0];
                const imageUrl = firstImage.preview;
                
                imagesPreview = `
                    <div class="variant-image-wrapper">
                        <img src="${imageUrl}" class="variant-image-preview clickable-variant-image" data-variant-index="${index}" alt="${variant.colorName}" title="Click to view all images">
                        ${variant.images.length > 1 ? `<span class="variant-image-count">+${variant.images.length - 1}</span>` : ''}
                    </div>
                `;
            }
            
            variantTag.innerHTML = `
                ${imagesPreview}
                <div class="color-preview" style="background-color: ${variant.colorHex};"></div>
                <span class="size-info">${variant.colorName} - ${variant.size} <span class="size-qty">(${variant.quantity} pcs)</span></span>
                <button type="button" class="remove-size-btn" data-index="${index}">
                    <i class="bi bi-x"></i>
                </button>
            `;
            container.appendChild(variantTag);
        });
        
        // Add click listeners to variant images - open modal with carousel
        container.querySelectorAll('.clickable-variant-image').forEach(img => {
            img.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                
                const variantIndex = parseInt(this.dataset.variantIndex);
                const variant = addVariantModalNewVariants[variantIndex];
                
                if (variant.images && variant.images.length > 0) {
                    const imageUrls = variant.images.map(img => img.preview);
                    showImageCarouselModal(imageUrls, 0);
                }
            });
        });
        
        // Add remove button listeners
        container.querySelectorAll('.remove-size-btn').forEach(btn => {
            btn.addEventListener('click', function(e) {
                e.preventDefault();
                const index = parseInt(this.dataset.index);
                addVariantModalNewVariants.splice(index, 1);
                displayAddVariantModalNewVariants();
                showNotification('Variant removed', 'info');
            });
        });
    }
    
    
    // Edit product form submission
    if (editProductForm) {
        editProductForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            // Check if there are any changes
            const currentFormData = {
                product_name: document.getElementById('editProductName').value.trim(),
                category: document.getElementById('editProductCategory').value,
                price: document.getElementById('editProductPrice').value.trim().replace(/,/g, ''),
                description: document.getElementById('editProductDescription').value.trim(),
                materials: document.getElementById('editProductMaterials').value.trim(),
                handmade: document.getElementById('editProductHandmade').checked,
                biodegradable: document.getElementById('editProductBiodegradable').checked
            };
            
            // Get current variants data (sorted by variant_id for consistent comparison)
            const currentVariantsData = [];
            document.querySelectorAll('.edit-size-row').forEach(item => {
                const variantId = item.querySelector('input[type="number"]').dataset.variantId;
                const quantityInput = item.querySelector('input[type="number"]');
                if (variantId && quantityInput && !variantsToDelete.includes(variantId)) {
                    currentVariantsData.push({
                        variant_id: variantId,
                        stock_quantity: parseInt(quantityInput.value)
                    });
                }
            });
            
            // Sort for consistent comparison
            currentVariantsData.sort((a, b) => a.variant_id.localeCompare(b.variant_id));
            
            // Check for changes
            let hasChanges = false;
            
            // Check form fields (with proper type conversion)
            if (currentFormData.product_name !== originalFormData.product_name ||
                currentFormData.category !== originalFormData.category ||
                currentFormData.price !== String(originalFormData.price) ||
                currentFormData.description !== originalFormData.description ||
                currentFormData.materials !== originalFormData.materials ||
                currentFormData.handmade !== originalFormData.handmade ||
                currentFormData.biodegradable !== originalFormData.biodegradable) {
                hasChanges = true;
            }
            
            // Check variants changes (compare sorted arrays)
            const currentVariantsStr = JSON.stringify(currentVariantsData);
            if (currentVariantsStr !== originalFormData.variants) {
                hasChanges = true;
            }
            
            // Check if there are deleted variants
            if (variantsToDelete.length > 0) {
                hasChanges = true;
            }
            
            // If no changes, show notification and return
            if (!hasChanges) {
                showNotification('No changes were made to the product.', 'info');
                return;
            }
            
            // Show confirmation modal only if there are changes
            const saveChangesModal = document.getElementById('save-changes-modal');
            const saveChangesModalOverlay = document.getElementById('save-changes-modal-overlay');
            const confirmSaveBtn = document.getElementById('confirm-save-changes');
            const cancelSaveBtn = document.getElementById('cancel-save-changes');
            
            if (!saveChangesModal || !saveChangesModalOverlay) {
                console.error('Save changes modal not found');
                return;
            }
            
            // Show modal
            saveChangesModal.classList.add('active');
            saveChangesModalOverlay.classList.add('show');
            
            // Wait for user confirmation
            const userConfirmed = await new Promise((resolve) => {
                const confirmHandler = () => {
                    cleanup();
                    resolve(true);
                };
                
                const cancelHandler = () => {
                    cleanup();
                    resolve(false);
                };
                
                const cleanup = () => {
                    saveChangesModal.classList.remove('active');
                    saveChangesModalOverlay.classList.remove('show');
                    confirmSaveBtn.removeEventListener('click', confirmHandler);
                    cancelSaveBtn.removeEventListener('click', cancelHandler);
                    saveChangesModalOverlay.removeEventListener('click', cancelHandler);
                };
                
                confirmSaveBtn.addEventListener('click', confirmHandler);
                cancelSaveBtn.addEventListener('click', cancelHandler);
                saveChangesModalOverlay.addEventListener('click', cancelHandler);
            });
            
            if (!userConfirmed) {
                return; // User clicked Cancel
            }
            
            try {
                // Remove commas from price before creating FormData
                const priceInput = document.getElementById('editProductPrice');
                if (priceInput) {
                    priceInput.value = priceInput.value.replace(/,/g, '');
                }
                
                const formData = new FormData(this);
                
                // Get current variants data (quantities) - exclude variants marked for deletion
                const currentVariants = [];
                document.querySelectorAll('.edit-size-row').forEach(item => {
                    const quantityInput = item.querySelector('input[type="number"]');
                    const variantId = quantityInput ? quantityInput.dataset.variantId : null;
                    
                    // Skip variants marked for deletion
                    if (variantId && quantityInput && !variantsToDelete.includes(variantId)) {
                        currentVariants.push({
                            variant_id: variantId,
                            quantity: quantityInput.value
                        });
                    }
                });
                
                formData.append('variantsData', JSON.stringify(currentVariants));
                
                // Add deleted images info
                if (imagesToDelete.length > 0) {
                    formData.append('deletedImages', JSON.stringify(imagesToDelete));
                    console.log('🗑️ Sending deleted images:', imagesToDelete);
                }
                
                // Add variant images to FormData
                if (window.variantImagesData) {
                    for (const variantId in window.variantImagesData) {
                        const images = window.variantImagesData[variantId];
                        
                        // Collect new images (not existing ones)
                        const newImages = images.filter(img => !img.isExisting && img.file);
                        
                        if (newImages.length > 0) {
                            // Add each new image file
                            newImages.forEach((img, index) => {
                                formData.append(`variant_${variantId}_images`, img.file);
                            });
                            
                            // Track which variants have new images
                            formData.append(`variant_${variantId}_has_new_images`, 'true');
                        }
                        
                        // Send the complete image order (for reordering)
                        const imageOrder = images.map((img, idx) => ({
                            url: img.isExisting ? img.url : null,
                            isNew: !img.isExisting,
                            isPrimary: idx === 0,
                            displayOrder: idx
                        }));
                        formData.append(`variant_${variantId}_image_order`, JSON.stringify(imageOrder));
                    }
                }
                
                // Delete marked variants
                if (variantsToDelete.length > 0) {
                    for (const variantId of variantsToDelete) {
                        try {
                            await fetch(`/api/products/variants/${variantId}`, {
                                method: 'DELETE'
                            });
                        } catch (error) {
                            console.error(`Failed to delete variant ${variantId}:`, error);
                        }
                    }
                }
                
                // No new variants functionality in Edit modal anymore
                // Use the dedicated Add Variant modal instead
                
                // Send update request
                const response = await fetch(`/api/products/${currentEditingProductId}`, {
                    method: 'PUT',
                    body: formData
                });
                
                const result = await response.json();
                
                if (!response.ok || !result.success) {
                    throw new Error(result.message || 'Failed to update product');
                }
                
                console.log('✅ Backend response:', result);
                
                // Close modal first
                closeEditModal();
                
                // Refresh product list immediately (no delay needed)
                await fetchAndDisplayProducts();
                
                showNotification('Product updated successfully!', 'success');
                
            } catch (error) {
                console.error('Error updating product:', error);
                alert('Failed to update product. Please try again.');
            }
        });
    }

    // Initialize with Product List content
    attachProductListEventListeners();
    
    // Initialize modal event listeners
    initializeModalListeners();
});

// Global notification function for modal operations
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = 'notification';
    
    // Icon based on type
    let icon = 'info-circle';
    if (type === 'success') icon = 'check-circle';
    else if (type === 'error') icon = 'x-circle';
    
    // Colors based on type
    let bgColor = '#eff6ff';
    let textColor = '#1e40af';
    let borderColor = '#3b82f6';
    
    if (type === 'success') {
        bgColor = '#ecfdf5';
        textColor = '#059669';
        borderColor = '#10b981';
    } else if (type === 'error') {
        bgColor = '#fef2f2';
        textColor = '#dc2626';
        borderColor = '#f87171';
    }
    
    notification.innerHTML = `<i class="bi bi-${icon}"></i><span>${message}</span>`;
    notification.style.cssText = `
        position: fixed; top: 100px; right: 30px; padding: 16px 24px;
        background: ${bgColor};
        color: ${textColor};
        border: 2px solid ${borderColor};
        border-radius: 8px; box-shadow: 0 4px 16px rgba(0,0,0,0.1);
        z-index: 10000; display: flex; align-items: center; gap: 12px;
        font-family: 'Montserrat', sans-serif; font-size: 0.95rem; font-weight: 600;
        animation: slideIn 0.3s ease;
    `;
    document.body.appendChild(notification);
    setTimeout(() => notification.remove(), 2000);
}

// Modal functions for Preparing Package confirmation
let currentOrderId = null;

function showPreparingModal(orderId) {
    console.log('showPreparingModal called with orderId:', orderId, 'type:', typeof orderId);
    currentOrderId = orderId;
    console.log('currentOrderId set to:', currentOrderId);
    const modal = document.getElementById('preparing-modal');
    const overlay = document.getElementById('preparing-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.add('active');
        overlay.classList.add('show');
    }
}

function hidePreparingModal() {
    const modal = document.getElementById('preparing-modal');
    const overlay = document.getElementById('preparing-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.remove('active');
        overlay.classList.remove('show');
    }
    currentOrderId = null;
}

async function confirmPreparing() {
    if (!currentOrderId) {
        console.error('confirmPreparing called but currentOrderId is null');
        return;
    }
    
    // Store orderId before hiding modal (which resets currentOrderId)
    const orderId = currentOrderId;
    
    // Hide modal immediately for instant feedback
    hidePreparingModal();
    
    // Show loading notification
    showNotification('Updating order...', 'info');
    
    try {
        const response = await fetch(`/api/orders/${orderId}/preparing`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            console.error('Response not OK:', response.status, response.statusText);
            const errorText = await response.text();
            console.error('Error response:', errorText);
            showNotification(`Failed to update order (${response.status})`, 'error');
            if (window.refreshOrders) window.refreshOrders();
            return;
        }
        
        const data = await response.json();
        
        if (data.success) {
            showNotification('Package preparation started', 'success');
            // Refresh orders to show updated status
            if (window.refreshOrders) window.refreshOrders();
        } else {
            showNotification(data.message || 'Failed to update order', 'error');
            if (window.refreshOrders) window.refreshOrders();
        }
    } catch (error) {
        console.error('Error in confirmPreparing:', error);
        showNotification('An error occurred: ' + error.message, 'error');
        if (window.refreshOrders) window.refreshOrders();
    }
}

// Modal functions for Ready for Pickup confirmation
function showPickupModal(orderId) {
    currentOrderId = orderId;
    const modal = document.getElementById('pickup-modal');
    const overlay = document.getElementById('pickup-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.add('active');
        overlay.classList.add('show');
    }
}

function hidePickupModal() {
    const modal = document.getElementById('pickup-modal');
    const overlay = document.getElementById('pickup-modal-overlay');
    
    if (modal && overlay) {
        modal.classList.remove('active');
        overlay.classList.remove('show');
    }
    currentOrderId = null;
}

async function confirmPickup() {
    if (!currentOrderId) {
        console.error('confirmPickup called but currentOrderId is null');
        return;
    }
    
    // Store orderId before hiding modal (which resets currentOrderId)
    const orderId = currentOrderId;
    
    // Hide modal immediately for instant feedback
    hidePickupModal();
    
    // Show loading notification
    showNotification('Updating order...', 'info');
    
    try {
        const response = await fetch(`/api/orders/${orderId}/ready-for-pickup`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            console.error('Response not OK:', response.status, response.statusText);
            const errorText = await response.text();
            console.error('Error response:', errorText);
            showNotification(`Failed to update order (${response.status})`, 'error');
            if (window.refreshOrders) window.refreshOrders();
            return;
        }
        
        const data = await response.json();
        
        if (data.success) {
            showNotification(data.message || 'Order marked as ready for pickup', 'success');
            // Refresh orders to show updated status
            if (window.refreshOrders) window.refreshOrders();
        } else {
            showNotification(data.message || 'Failed to update order', 'error');
            if (window.refreshOrders) window.refreshOrders();
        }
    } catch (error) {
        console.error('Error in confirmPickup:', error);
        showNotification('An error occurred: ' + error.message, 'error');
        if (window.refreshOrders) window.refreshOrders();
    }
}

// Initialize modal event listeners
function initializeModalListeners() {
    // Preparing modal buttons
    const confirmPreparingBtn = document.getElementById('confirm-preparing');
    const cancelPreparingBtn = document.getElementById('cancel-preparing');
    const preparingOverlay = document.getElementById('preparing-modal-overlay');
    
    if (confirmPreparingBtn) {
        confirmPreparingBtn.addEventListener('click', confirmPreparing);
    }
    
    if (cancelPreparingBtn) {
        cancelPreparingBtn.addEventListener('click', hidePreparingModal);
    }
    
    if (preparingOverlay) {
        preparingOverlay.addEventListener('click', hidePreparingModal);
    }
    
    // Pickup modal buttons
    const confirmPickupBtn = document.getElementById('confirm-pickup');
    const cancelPickupBtn = document.getElementById('cancel-pickup');
    const pickupOverlay = document.getElementById('pickup-modal-overlay');
    
    if (confirmPickupBtn) {
        confirmPickupBtn.addEventListener('click', confirmPickup);
    }
    
    if (cancelPickupBtn) {
        cancelPickupBtn.addEventListener('click', hidePickupModal);
    }
    
    if (pickupOverlay) {
        pickupOverlay.addEventListener('click', hidePickupModal);
    }
}
