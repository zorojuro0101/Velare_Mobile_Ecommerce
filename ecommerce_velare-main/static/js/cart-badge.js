// Cart badge functionality
function updateCartBadge() {
    fetch('/get_cart_count')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                const badge = document.getElementById('cart-badge');
                if (badge) {
                    if (data.count > 0) {
                        badge.textContent = data.count > 99 ? '99+' : data.count;
                        badge.style.display = 'flex';
                    } else {
                        badge.style.display = 'none';
                    }
                }
            }
        })
        .catch(error => {
            console.error('Error fetching cart count:', error);
        });
}

// Update cart badge on page load
document.addEventListener('DOMContentLoaded', function() {
    updateCartBadge();
});

// Export function for use in other scripts
if (typeof window !== 'undefined') {
    window.updateCartBadge = updateCartBadge;
}
