document.addEventListener('DOMContentLoaded', function() {
    // Load featured products for slideshow
    async function loadFeaturedProducts() {
        console.log('🔄 Loading featured products...');
        try {
            const response = await fetch('/api/featured-products');
            console.log('📡 API Response status:', response.status);
            const data = await response.json();
            console.log('📦 API Data:', data);
            
            if (data.success && data.products && data.products.length > 0) {
                console.log('✅ Found', data.products.length, 'products');
                const imageSection = document.getElementById('imageSection');
                imageSection.innerHTML = ''; // Clear loading placeholder
                
                data.products.forEach((product, index) => {
                    const img = document.createElement('img');
                    
                    // Handle both Supabase URLs and local paths
                    let imagePath = product.image_path;
                    if (imagePath) {
                        if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
                            // Full Supabase URL
                            img.src = imagePath;
                        } else if (imagePath.startsWith('static/')) {
                            // Local path with static/ prefix
                            img.src = `/${imagePath}`;
                        } else {
                            // Relative path - add /static/ prefix
                            img.src = `/static/${imagePath}`;
                        }
                    } else {
                        // Fallback image
                        img.src = '/static/images/user.png';
                    }
                    
                    img.alt = product.product_name;
                    img.className = 'slideshow-image';
                    if (index === 0) {
                        img.classList.add('active');
                    }
                    imageSection.appendChild(img);
                });
                
                // Start slideshow after images are loaded
                startSlideshow();
            } else {
                // Fallback to default images if no products found
                console.warn('⚠️ No featured products found, using fallback');
                console.warn('API Response:', data);
                loadFallbackImages();
            }
        } catch (error) {
            console.error('❌ Error loading featured products:', error);
            loadFallbackImages();
        }
    }
    
    function loadFallbackImages() {
        console.log('📸 Loading fallback images...');
        const imageSection = document.getElementById('imageSection');
        const fallbackImages = [
            '/static/images/sampleimage1.jpg',
            '/static/images/sampleimage2.webp',
            '/static/images/sampleimage3.webp',
            '/static/images/sampleimage4.webp',
            '/static/images/sampleimage5.webp'
        ];
        
        imageSection.innerHTML = '';
        fallbackImages.forEach((src, index) => {
            const img = document.createElement('img');
            img.src = src;
            img.alt = 'Fashion Image';
            img.className = 'slideshow-image';
            if (index === 0) {
                img.classList.add('active');
            }
            imageSection.appendChild(img);
        });
        
        startSlideshow();
    }
    
    function startSlideshow() {
        const images = document.querySelectorAll('.slideshow-image');
        let currentIndex = 0;

        function showNextImage() {
            images[currentIndex].classList.remove('active');
            currentIndex = (currentIndex + 1) % images.length;
            images[currentIndex].classList.add('active');
        }

        // Change image every 4 seconds
        if (images.length > 0) {
            setInterval(showNextImage, 4000);
        }
    }
    
    // Load products on page load
    loadFeaturedProducts();
    
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

    const signInTab = document.getElementById('signInTab');
    const registerTab = document.getElementById('registerTab');

    if (signInTab && registerTab) {
        const signInForm = document.getElementById('signInForm');
        const registerForm = document.getElementById('registerForm');
        const underline = document.querySelector('.tab-underline-active');
        const welcomeMessage = document.getElementById('welcomeMessage');
        const registerMessage = document.getElementById('registerMessage');

        signInTab.addEventListener('click', function() {
            signInTab.classList.add('active');
            registerTab.classList.remove('active');
            if (signInForm) signInForm.style.display = 'block';
            if (registerForm) registerForm.style.display = 'none';
            if (underline) underline.style.transform = 'translateX(0%)';
            if (welcomeMessage) welcomeMessage.style.display = 'block';
            if (registerMessage) registerMessage.style.display = 'none';
        });

        registerTab.addEventListener('click', function() {
            registerTab.classList.add('active');
            signInTab.classList.remove('active');
            if (signInForm) signInForm.style.display = 'none';
            if (registerForm) registerForm.style.display = 'block';
            if (underline) underline.style.transform = 'translateX(100%)';
            if (welcomeMessage) welcomeMessage.style.display = 'none';
            if (registerMessage) registerMessage.style.display = 'block';
        });
    }

    const passwordToggles = document.querySelectorAll('.password-toggle');
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

    // Login form submission
    const signInForm = document.getElementById('signInForm');
    if (signInForm) {
        signInForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            const submitBtn = this.querySelector('.sign-in-btn');
            const originalText = submitBtn.textContent;
            
            // Disable button and show loading
            submitBtn.disabled = true;
            submitBtn.textContent = 'Signing in...';
            
            try {
                const response = await fetch('/login', {
                    method: 'POST',
                    body: formData
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showNotification(data.message, 'success');
                    if (data.redirect) {
                        setTimeout(() => {
                            window.location.href = data.redirect;
                        }, 1500);
                    }
                } else {
                    showNotification(data.message || 'Login failed. Please try again.', 'error');
                    submitBtn.disabled = false;
                    submitBtn.textContent = originalText;
                }
            } catch (error) {
                showNotification('An error occurred. Please try again.', 'error');
                console.error('Error:', error);
                submitBtn.disabled = false;
                submitBtn.textContent = originalText;
            }
        });
    }
});