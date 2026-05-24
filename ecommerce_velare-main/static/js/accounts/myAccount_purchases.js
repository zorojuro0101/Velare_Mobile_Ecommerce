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

document.addEventListener('DOMContentLoaded', () => {
    const hamburgerBtn = document.getElementById('hamburgerBtn');
    const sideMenu = document.querySelector('.side-menu');
    const overlay = document.querySelector('.side-menu-overlay');
    const myAccountTab = document.getElementById('myAccountTab');
    const myAccountSubTabs = document.getElementById('myAccountSubTabs');
    const mainTabs = document.querySelectorAll('.main-tab');
    const myPurchasesTab = document.getElementById('myPurchasesTab');
    const purchaseTabs = document.querySelectorAll('.purchase-tab');
    const orders = document.querySelectorAll('.order-card');
    const emptyState = document.querySelector('.purchase-empty-state');
    const detailToggles = document.querySelectorAll('.order-details-toggle');

    if (hamburgerBtn && sideMenu && overlay) {
        hamburgerBtn.addEventListener('click', () => {
            const isOpen = sideMenu.classList.toggle('open');
            overlay.classList.toggle('show', isOpen);
            hamburgerBtn.classList.toggle('open', isOpen);
        });

        overlay.addEventListener('click', () => {
            sideMenu.classList.remove('open');
            overlay.classList.remove('show');
            hamburgerBtn.classList.remove('open');
        });
    }

    if (myPurchasesTab) {
        mainTabs.forEach(tab => {
            if (tab !== myAccountTab) {
                tab.classList.remove('active');
            }
        });
        myPurchasesTab.classList.add('active');
    }

    const openSubTabs = () => {
        if (!myAccountSubTabs) return;
        myAccountSubTabs.style.display = 'flex';
        requestAnimationFrame(() => {
            myAccountSubTabs.classList.add('open');
            myAccountSubTabs.classList.remove('closing');
        });
        if (myAccountTab) {
            myAccountTab.classList.add('active');
        }
    };

    const closeSubTabs = () => {
        if (!myAccountSubTabs) return;
        myAccountSubTabs.classList.remove('open');
        myAccountSubTabs.classList.add('closing');
        const handleTransitionEnd = () => {
            myAccountSubTabs.classList.remove('closing');
            myAccountSubTabs.style.display = 'none';
        };
        myAccountSubTabs.addEventListener('transitionend', handleTransitionEnd, { once: true });
    };

    if (myAccountSubTabs) {
        myAccountSubTabs.style.display = 'none';
        myAccountSubTabs.classList.remove('open', 'closing');
    }

    // My Account tab now redirects to profile page, so we don't need click handler
    // The link will handle the navigation automatically

    mainTabs.forEach(tab => {
        if (tab === myAccountTab) {
            return;
        }
        tab.addEventListener('click', () => {
            mainTabs.forEach(t => {
                if (t !== myAccountTab) {
                    t.classList.remove('active');
                }
            });
            tab.classList.add('active');
            if (myAccountSubTabs && myAccountSubTabs.classList.contains('open')) {
                closeSubTabs();
                if (myAccountTab) {
                    myAccountTab.classList.remove('active');
                }
            }
        });
    });

    function filterOrders(status) {
        let visibleCount = 0;
        orders.forEach(order => {
            const matches = order.dataset.status === status;
            order.style.display = matches ? '' : 'none';
            if (matches) {
                visibleCount += 1;
            }
        });
        if (emptyState) {
            emptyState.hidden = visibleCount !== 0;
        }
    }

    function updateTabUnderline(activeTab) {
        const underline = document.querySelector('.purchase-tab-underline');
        const underlineBg = document.querySelector('.purchase-tab-underline-bg');
        if (!activeTab || !underline || !underlineBg) return;
        
        const bgRect = underlineBg.getBoundingClientRect();
        const tabRect = activeTab.getBoundingClientRect();
        const left = tabRect.left - bgRect.left;
        
        // Center the fixed-width underline under the tab
        const tabWidth = tabRect.width;
        const underlineWidth = 120; // Fixed width from CSS
        const centeredLeft = left + (tabWidth - underlineWidth) / 2;
        
        underline.style.transform = `translateX(${centeredLeft}px)`;
    }

    purchaseTabs.forEach((tab, index) => {
        tab.addEventListener('click', () => {
            purchaseTabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            const status = tab.dataset.status;
            filterOrders(status);
            updateTabUnderline(tab);
            // Save active tab to localStorage
            localStorage.setItem('activePurchaseTab', status);
        });
    });

    // Initialize with saved tab or first tab
    if (purchaseTabs.length > 0) {
        // Ensure empty state is hidden on page load
        if (emptyState) {
            emptyState.hidden = true;
        }
        
        // FIRST: Remove all active classes from tabs
        purchaseTabs.forEach(t => t.classList.remove('active'));
        
        // Check if there's a saved active tab
        const savedTab = localStorage.getItem('activePurchaseTab');
        let activeTab = purchaseTabs[0]; // default to first tab
        
        if (savedTab) {
            // Find the tab with the saved status
            const foundTab = Array.from(purchaseTabs).find(tab => tab.dataset.status === savedTab);
            if (foundTab) {
                activeTab = foundTab;
            }
        }
        
        // Set active class on the correct tab
        activeTab.classList.add('active');
        
        // Set underline position immediately without transition BEFORE filtering
        const underline = document.querySelector('.purchase-tab-underline');
        if (underline) {
            underline.style.transition = 'none'; // Disable transition
            updateTabUnderline(activeTab);
            // Show underline and re-enable transition
            requestAnimationFrame(() => {
                underline.classList.add('ready');
                underline.style.transition = '';
            });
        }
        
        // Filter orders after underline is positioned
        filterOrders(activeTab.dataset.status);
        
        // Show orders after filtering
        const ordersContainer = document.querySelector('.purchase-orders');
        if (ordersContainer) {
            requestAnimationFrame(() => {
                ordersContainer.classList.add('ready');
            });
        }
    }

    // Update underline position on window resize
    window.addEventListener('resize', () => {
        const activeTab = document.querySelector('.purchase-tab.active');
        if (activeTab) {
            setTimeout(() => {
                updateTabUnderline(activeTab);
            }, 100);
        }
    });

    detailToggles.forEach(toggle => {
        const orderCard = toggle.closest('.order-card');
        if (!orderCard) {
            return;
        }
        const detailSection = orderCard.querySelector('.order-details');
        if (!detailSection) {
            return;
        }
        toggle.addEventListener('click', () => {
            const isHidden = detailSection.hasAttribute('hidden');
            if (isHidden) {
                detailSection.removeAttribute('hidden');
                toggle.textContent = 'Hide Details';
            } else {
                detailSection.setAttribute('hidden', '');
                toggle.textContent = 'View Details';
            }
        });
    });

    // Order Received Confirmation Functionality (Popup style like notification page)
    const confirmReceivedButtons = document.querySelectorAll('.confirm-received-btn');
    
    confirmReceivedButtons.forEach(button => {
        button.addEventListener('click', (e) => {
            e.stopPropagation();
            const orderId = button.dataset.orderId;
            
            // Remove any existing popup
            const existingPopup = document.querySelector('.confirm-received-popup');
            if (existingPopup) {
                existingPopup.remove();
            }
            
            // Make button's parent relative for positioning
            const buttonParent = button.parentElement;
            const originalPosition = buttonParent.style.position;
            buttonParent.style.position = 'relative';
            
            // Create confirmation popup
            const confirmPopup = document.createElement('div');
            confirmPopup.className = 'confirm-received-popup';
            confirmPopup.innerHTML = `
                <div class="confirm-text">Confirm order received?</div>
                <div class="confirm-buttons">
                    <button class="confirm-yes">Yes</button>
                    <button class="confirm-no">No</button>
                </div>
            `;
            
            buttonParent.appendChild(confirmPopup);
            
            // Handle Yes button
            confirmPopup.querySelector('.confirm-yes').addEventListener('click', async function() {
                this.disabled = true;
                this.textContent = 'Confirming...';
                
                // Immediately remove popup and show success message for better UX
                confirmPopup.remove();
                showNotification('Processing your confirmation...', 'info');
                
                // Disable the original button immediately
                button.disabled = true;
                button.textContent = 'Processing...';
                
                try {
                    const response = await fetch(`/api/confirm_order_received/${orderId}`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        credentials: 'same-origin'
                    });
                    
                    const data = await response.json();
                    
                    if (response.ok && data.success) {
                        // Update button to show success
                        button.disabled = true;
                        button.textContent = 'Order Received ✓';
                        button.style.opacity = '0.6';
                        
                        showNotification(data.message, 'success');
                        
                        // Reload after a short delay to show the updated state
                        setTimeout(() => {
                            window.location.reload();
                        }, 1500);
                    } else {
                        // Re-enable button on error
                        button.disabled = false;
                        button.textContent = 'Order Received';
                        button.style.opacity = '1';
                        
                        showNotification(data.message || 'Failed to confirm order received', 'error');
                    }
                } catch (error) {
                    console.error('Error confirming order received:', error);
                    
                    // Re-enable button on error
                    button.disabled = false;
                    button.textContent = 'Order Received';
                    button.style.opacity = '1';
                    
                    showNotification('An error occurred. Please try again.', 'error');
                }
            });
            
            // Handle No button
            confirmPopup.querySelector('.confirm-no').addEventListener('click', function() {
                confirmPopup.remove();
            });
        });
    });

    // Review Modal Functionality
    const reviewModal = document.getElementById('review-modal');
    const reviewModalOverlay = document.getElementById('review-modal-overlay');
    const writeReviewButtons = document.querySelectorAll('.write-review-btn');
    const cancelReviewBtn = document.getElementById('cancel-review');
    const closeReviewModalBtn = document.getElementById('close-review-modal');
    const submitAllReviewsBtn = document.getElementById('submit-all-reviews');
    const reviewProductsContainer = document.getElementById('review-products-container');
    let currentOrderId = null;
    let currentOrderProducts = [];

    // Open review modal when "Write a Review" or "See Reviews" button is clicked
    writeReviewButtons.forEach(button => {
        button.addEventListener('click', async () => {
            const orderCard = button.closest('.order-card');
            currentOrderId = button.dataset.orderId;
            const buttonText = button.textContent.trim();
            
            // Check if this is "See Reviews" (existing reviews) or "Write a Review" (new)
            const isEditMode = buttonText === 'See Reviews';
            
            if (isEditMode) {
                // Fetch existing reviews from server
                try {
                    const response = await fetch(`/api/get_order_reviews/${currentOrderId}`);
                    const data = await response.json();
                    
                    if (response.ok && data.success && data.reviews) {
                        currentOrderProducts = data.reviews.map(review => ({
                            product_id: review.product_id,
                            name: review.product_name,
                            variant: `${review.variant_color || ''}${review.variant_color && review.variant_size ? ' • ' : ''}${review.variant_size ? 'Size: ' + review.variant_size : ''}`,
                            price: `₱${parseFloat(review.unit_price).toFixed(2)}`,
                            imageUrl: review.image_url ? (review.image_url.startsWith('/') ? review.image_url : '/' + review.image_url) : '',
                            rating: review.rating,
                            reviewText: review.review_text || ''
                        }));
                        
                        // Save original data for comparison
                        originalReviewData = currentOrderProducts.map(p => ({
                            rating: p.rating,
                            reviewText: p.reviewText
                        }));
                    }
                } catch (error) {
                    console.error('Error fetching reviews:', error);
                    showNotification('Failed to load reviews', 'error');
                    return;
                }
            } else {
                // Extract product information from the order card for new reviews
                currentOrderProducts = [];
                originalReviewData = []; // Clear original data for new reviews
                const orderItems = orderCard.querySelectorAll('.order-item');
                orderItems.forEach(item => {
                    // Get image URL from <img> tag inside .item-thumb
                    const imageElement = item.querySelector('.item-thumb img');
                    const imageUrl = imageElement ? imageElement.src : '';
                    
                    const name = item.querySelector('.item-name')?.textContent.trim() || '';
                    const variant = item.querySelector('.item-variant')?.textContent.trim() || '';
                    const price = item.querySelector('.item-price')?.textContent.trim() || '';
                    const productId = item.dataset.productId || '';
                    
                    console.log('Product:', name, 'Image URL:', imageUrl); // Debug log
                    
                    currentOrderProducts.push({ 
                        product_id: productId,
                        name, 
                        variant,
                        price,
                        imageUrl,
                        rating: 0,
                        reviewText: ''
                    });
                });
            }
            
            // Populate the product review sections in the modal
            reviewProductsContainer.innerHTML = '';
            
            currentOrderProducts.forEach((product, index) => {
                const productReviewItem = document.createElement('div');
                productReviewItem.className = 'review-product-item';
                productReviewItem.dataset.productIndex = index;
                productReviewItem.innerHTML = `
                    <div class="review-product-info">
                        <img src="${product.imageUrl || '/static/images/placeholder.png'}" class="review-product-image" alt="${product.name}">
                        <div class="review-product-details">
                            <div class="review-product-name">${product.name}</div>
                            <div class="review-product-price">${product.price}</div>
                            <div class="review-product-variant">${product.variant}</div>
                        </div>
                    </div>
                    <div class="review-rating-section">
                        <label>Rating:</label>
                        <div class="star-rating" data-product-index="${index}">
                            <i class="bi bi-star" data-rating="1"></i>
                            <i class="bi bi-star" data-rating="2"></i>
                            <i class="bi bi-star" data-rating="3"></i>
                            <i class="bi bi-star" data-rating="4"></i>
                            <i class="bi bi-star" data-rating="5"></i>
                        </div>
                    </div>
                    <div class="review-text-section">
                        <label>Your Review:</label>
                        <textarea class="review-textarea" data-product-index="${index}" placeholder="Share your experience with this product..." rows="3">${product.reviewText}</textarea>
                    </div>
                `;
                reviewProductsContainer.appendChild(productReviewItem);
            });
            
            // Setup star rating for each product
            setupStarRatings();
            
            // Pre-fill ratings for existing reviews
            if (isEditMode) {
                currentOrderProducts.forEach((product, index) => {
                    if (product.rating > 0) {
                        const starRating = document.querySelector(`.star-rating[data-product-index="${index}"]`);
                        if (starRating) {
                            const stars = starRating.querySelectorAll('i');
                            updateStarDisplay(stars, product.rating);
                        }
                    }
                });
            }
            
            reviewModal.classList.add('active');
            reviewModalOverlay.classList.add('show');
        });
    });

    // Setup star rating functionality for all products
    function setupStarRatings() {
        const allStarRatings = document.querySelectorAll('.star-rating');
        
        allStarRatings.forEach(starRatingContainer => {
            const productIndex = parseInt(starRatingContainer.dataset.productIndex);
            const stars = starRatingContainer.querySelectorAll('i');
            
            stars.forEach((star, starIndex) => {
                star.addEventListener('click', () => {
                    const rating = parseInt(star.dataset.rating);
                    currentOrderProducts[productIndex].rating = rating;
                    updateStarDisplay(stars, rating);
                });

                star.addEventListener('mouseenter', () => {
                    const rating = parseInt(star.dataset.rating);
                    updateStarDisplay(stars, rating);
                });
            });

            starRatingContainer.addEventListener('mouseleave', () => {
                updateStarDisplay(stars, currentOrderProducts[productIndex].rating);
            });
        });
        
        // Setup textarea listeners
        const allTextareas = document.querySelectorAll('.review-textarea');
        allTextareas.forEach(textarea => {
            const productIndex = parseInt(textarea.dataset.productIndex);
            textarea.addEventListener('input', (e) => {
                currentOrderProducts[productIndex].reviewText = e.target.value.trim();
            });
        });
    }

    function updateStarDisplay(stars, rating) {
        stars.forEach((star, index) => {
            if (index < rating) {
                star.classList.remove('bi-star');
                star.classList.add('bi-star-fill');
            } else {
                star.classList.remove('bi-star-fill');
                star.classList.add('bi-star');
            }
        });
    }

    // Close review modal
    const closeReviewModal = () => {
        reviewModal.classList.remove('active');
        reviewModalOverlay.classList.remove('show');
        currentOrderId = null;
        currentOrderProducts = [];
    };

    if (cancelReviewBtn) {
        cancelReviewBtn.addEventListener('click', closeReviewModal);
    }
    
    if (closeReviewModalBtn) {
        closeReviewModalBtn.addEventListener('click', closeReviewModal);
    }
    
    reviewModalOverlay.addEventListener('click', closeReviewModal);

    // Store original review data for comparison
    let originalReviewData = [];
    
    // Submit all reviews
    if (submitAllReviewsBtn) {
        submitAllReviewsBtn.addEventListener('click', async () => {
            // Validate that all products have ratings
            const unratedProducts = currentOrderProducts.filter(p => p.rating === 0);
            
            if (unratedProducts.length > 0) {
                showNotification('Please rate all products before submitting.', 'error');
                return;
            }
            
            // Check if any changes were made (for edit mode)
            if (originalReviewData.length > 0) {
                let hasChanges = false;
                for (let i = 0; i < currentOrderProducts.length; i++) {
                    const current = currentOrderProducts[i];
                    const original = originalReviewData[i];
                    
                    if (current.rating !== original.rating || current.reviewText !== original.reviewText) {
                        hasChanges = true;
                        break;
                    }
                }
                
                if (!hasChanges) {
                    showNotification('No changes detected. Please modify your review before saving.', 'error');
                    return;
                }
            }
            
            submitAllReviewsBtn.disabled = true;
            submitAllReviewsBtn.textContent = 'Submitting...';
            
            // Submit each review
            let successCount = 0;
            let errorCount = 0;
            
            for (const product of currentOrderProducts) {
                try {
                    const response = await fetch('/api/submit_review', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        credentials: 'same-origin',
                        body: JSON.stringify({
                            order_id: currentOrderId,
                            product_id: product.product_id || 0,
                            rating: product.rating,
                            review_text: product.reviewText
                        })
                    });
                    
                    const data = await response.json();
                    
                    if (response.ok && data.success) {
                        successCount++;
                    } else {
                        errorCount++;
                        console.error('Failed to submit review:', data.message);
                    }
                } catch (error) {
                    errorCount++;
                    console.error('Error submitting review:', error);
                }
            }
            
            if (successCount > 0) {
                showNotification(`Successfully updated ${successCount} review(s)!`, 'success');
                setTimeout(() => {
                    window.location.reload();
                }, 1500);
            } else {
                showNotification('Failed to submit reviews. Please try again.', 'error');
                submitAllReviewsBtn.disabled = false;
                submitAllReviewsBtn.textContent = 'Submit Reviews';
            }
            
            closeReviewModal();
        });
    }

    // Cancel Order Modal Functionality
    const cancelOrderModal = document.getElementById('cancel-order-modal');
    const cancelOrderModalOverlay = document.getElementById('cancel-order-modal-overlay');
    const confirmCancelOrderBtn = document.getElementById('confirm-cancel-order');
    const cancelCancelOrderBtn = document.getElementById('cancel-cancel-order');
    const cancelOrderButtons = document.querySelectorAll('.cancel-order-btn');
    let currentCancelOrderId = null;

    // Function to show cancel order modal
    function showCancelOrderModal(orderId) {
        currentCancelOrderId = orderId;
        if (cancelOrderModal && cancelOrderModalOverlay) {
            cancelOrderModal.classList.add('active');
            cancelOrderModalOverlay.classList.add('show');
        }
    }

    // Function to hide cancel order modal
    function hideCancelOrderModal() {
        currentCancelOrderId = null;
        if (cancelOrderModal && cancelOrderModalOverlay) {
            cancelOrderModal.classList.remove('active');
            cancelOrderModalOverlay.classList.remove('show');
        }
    }

    // Open cancel order modal when cancel button is clicked
    cancelOrderButtons.forEach(button => {
        button.addEventListener('click', () => {
            const orderId = button.dataset.orderId;
            showCancelOrderModal(orderId);
        });
    });

    // Cancel button - close modal without action
    if (cancelCancelOrderBtn) {
        cancelCancelOrderBtn.addEventListener('click', hideCancelOrderModal);
    }

    // Close modal on overlay click
    if (cancelOrderModalOverlay) {
        cancelOrderModalOverlay.addEventListener('click', hideCancelOrderModal);
    }

    // Confirm cancel order button - process the cancellation
    if (confirmCancelOrderBtn) {
        confirmCancelOrderBtn.addEventListener('click', async () => {
            if (!currentCancelOrderId) {
                console.error('No order ID set for cancellation');
                showNotification('An error occurred. Please try again.', 'error');
                hideCancelOrderModal();
                return;
            }

            // Disable button to prevent double-clicks
            confirmCancelOrderBtn.disabled = true;
            confirmCancelOrderBtn.textContent = 'Cancelling...';

            try {
                const response = await fetch(`/api/cancel_order/${currentCancelOrderId}`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    credentials: 'same-origin'
                });

                const data = await response.json();

                if (response.ok && data.success) {
                    // Success - hide modal first, show notification, then reload
                    hideCancelOrderModal();
                    showNotification('Order cancelled successfully!', 'success');
                    
                    // Reload after showing notification
                    setTimeout(() => {
                        window.location.reload();
                    }, 1500);
                } else {
                    // Server returned an error
                    const errorMessage = data.message || 'Failed to cancel order. Please try again.';
                    hideCancelOrderModal();
                    showNotification(errorMessage, 'error');
                    
                    // Re-enable button
                    confirmCancelOrderBtn.disabled = false;
                    confirmCancelOrderBtn.textContent = 'Yes, Cancel Order';
                }
            } catch (error) {
                // Network or other error
                console.error('Error cancelling order:', error);
                hideCancelOrderModal();
                showNotification('An error occurred while cancelling the order. Please check your connection and try again.', 'error');
                
                // Re-enable button
                confirmCancelOrderBtn.disabled = false;
                confirmCancelOrderBtn.textContent = 'Yes, Cancel Order';
            }
        });
    }
});


// Handle URL tab parameter for notifications
document.addEventListener('DOMContentLoaded', function() {
    const urlParams = new URLSearchParams(window.location.search);
    const tab = urlParams.get('tab');
    
    if (tab) {
        // Map tab names to data-status values
        const tabMap = {
            'pending': 'pending-shipment',
            'pending-shipment': 'pending-shipment',
            'in-transit': 'in-transit',
            'delivered': 'delivered',
            'cancelled': 'cancelled'
        };
        
        const statusValue = tabMap[tab];
        if (statusValue) {
            const button = document.querySelector(`.purchase-tab[data-status="${statusValue}"]`);
            if (button) {
                // Trigger click on the appropriate tab
                setTimeout(() => {
                    button.click();
                }, 100);
            }
        }
    }
});


// Function to update tab counts dynamically
function updateTabCounts() {
    const orders = document.querySelectorAll('.order-card');
    const counts = {
        'pending-shipment': 0,
        'in-transit': 0,
        'delivered': 0,
        'cancelled': 0
    };
    
    orders.forEach(order => {
        const status = order.dataset.status;
        if (status && counts.hasOwnProperty(status)) {
            // For delivered tab, only count if "Order Received" button exists (not yet confirmed)
            if (status === 'delivered') {
                const orderReceivedBtn = order.querySelector('.confirm-received-btn');
                if (orderReceivedBtn) {
                    counts[status]++;
                }
            } else {
                counts[status]++;
            }
        }
    });
    
    // Update count badges
    Object.keys(counts).forEach(status => {
        const countElement = document.getElementById(`count-${status}`);
        if (countElement) {
            countElement.textContent = `(${counts[status]})`;
            // Hide if count is 0
            if (counts[status] === 0) {
                countElement.style.display = 'none';
            } else {
                countElement.style.display = 'inline';
            }
        }
    });
}

// Update counts on page load
document.addEventListener('DOMContentLoaded', () => {
    updateTabCounts();
});
