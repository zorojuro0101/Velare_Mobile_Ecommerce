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

    // Buyer ID Type to File Upload toggle
    const buyerIdTypeSelect = document.getElementById('buyer_id_type');
    const buyerIdTypeContainer = document.getElementById('buyer_id_type_container');
    const buyerIdFileContainer = document.getElementById('buyer_id_file_container');
    const buyerIdBackBtn = document.getElementById('buyerIdBackBtn');
    const buyerFileInput = document.getElementById('buyer_id_upload');
    const buyerFileLabel = document.getElementById('buyerFileLabel');
    
    // Always show dropdown and hide file upload on page load
    if (buyerIdTypeContainer) buyerIdTypeContainer.style.display = 'flex';
    if (buyerIdFileContainer) buyerIdFileContainer.style.display = 'none';

    if (buyerIdTypeSelect) {
        buyerIdTypeSelect.addEventListener('change', function() {
            if (this.value) {
                // Hide dropdown, show file upload
                if (buyerIdTypeContainer) buyerIdTypeContainer.style.display = 'none';
                if (buyerIdFileContainer) buyerIdFileContainer.style.display = 'flex';
            } else {
                // Show dropdown, hide file upload
                if (buyerIdTypeContainer) buyerIdTypeContainer.style.display = 'flex';
                if (buyerIdFileContainer) buyerIdFileContainer.style.display = 'none';
            }
        });
    }

    // Buyer ID Back button
    if (buyerIdBackBtn) {
        buyerIdBackBtn.addEventListener('click', function(e) {
            e.preventDefault();
            // Clear the file input
            if (buyerFileInput) {
                buyerFileInput.value = '';
                if (buyerFileLabel) buyerFileLabel.textContent = 'Choose File';
            }
            // Reset ID type dropdown
            if (buyerIdTypeSelect) buyerIdTypeSelect.value = '';
            // Show dropdown, hide file upload
            if (buyerIdTypeContainer) buyerIdTypeContainer.style.display = 'flex';
            if (buyerIdFileContainer) buyerIdFileContainer.style.display = 'none';
        });
    }

    // Custom file input logic for Buyer
    if (buyerFileInput && buyerFileLabel) {
        buyerFileInput.addEventListener('change', function() {
            if (buyerFileInput.files && buyerFileInput.files.length > 0) {
                buyerFileLabel.textContent = buyerFileInput.files[0].name;
            } else {
                buyerFileLabel.textContent = 'Choose File';
            }
        });
    }

    // Custom file input logic for Seller
    const sellerFileInput = document.getElementById('seller_id_upload');
    const sellerFileLabel = document.getElementById('sellerFileLabel');
    if (sellerFileInput && sellerFileLabel) {
        sellerFileInput.addEventListener('change', function() {
            if (sellerFileInput.files && sellerFileInput.files.length > 0) {
                sellerFileLabel.textContent = sellerFileInput.files[0].name;
            } else {
                sellerFileLabel.textContent = 'Choose File';
            }
        });
    }

    // Seller ID Type to File Upload toggle
    const sellerIdTypeSelect = document.getElementById('seller_id_type');
    const sellerIdTypeContainer = document.getElementById('seller_id_type_container');
    const sellerIdFileContainer = document.getElementById('seller_id_file_container');
    const sellerIdBackBtn = document.getElementById('sellerIdBackBtn');
    
    // Always show dropdown and hide file upload on page load
    if (sellerIdTypeContainer) sellerIdTypeContainer.style.display = 'flex';
    if (sellerIdFileContainer) sellerIdFileContainer.style.display = 'none';

    if (sellerIdTypeSelect) {
        sellerIdTypeSelect.addEventListener('change', function() {
            if (this.value) {
                // Hide dropdown, show file upload
                if (sellerIdTypeContainer) sellerIdTypeContainer.style.display = 'none';
                if (sellerIdFileContainer) sellerIdFileContainer.style.display = 'flex';
            } else {
                // Show dropdown, hide file upload
                if (sellerIdTypeContainer) sellerIdTypeContainer.style.display = 'flex';
                if (sellerIdFileContainer) sellerIdFileContainer.style.display = 'none';
            }
        });
    }

    // Seller ID Back button
    if (sellerIdBackBtn) {
        sellerIdBackBtn.addEventListener('click', function(e) {
            e.preventDefault();
            // Clear the file input
            const sellerIdUpload = document.getElementById('seller_id_upload');
            if (sellerIdUpload) {
                sellerIdUpload.value = '';
                const sellerFileLabel = document.getElementById('sellerFileLabel');
                if (sellerFileLabel) sellerFileLabel.textContent = 'Choose File';
            }
            // Reset ID type dropdown
            if (sellerIdTypeSelect) sellerIdTypeSelect.value = '';
            // Show dropdown, hide file upload
            if (sellerIdTypeContainer) sellerIdTypeContainer.style.display = 'flex';
            if (sellerIdFileContainer) sellerIdFileContainer.style.display = 'none';
        });
    }

    // Custom file input logic for Seller Business Permit
    const sellerBusinessPermitInput = document.getElementById('seller_business_permit_upload');
    const sellerBusinessPermitLabel = document.getElementById('sellerBusinessPermitLabel');
    if (sellerBusinessPermitInput && sellerBusinessPermitLabel) {
        sellerBusinessPermitInput.addEventListener('change', function() {
            if (sellerBusinessPermitInput.files && sellerBusinessPermitInput.files.length > 0) {
                sellerBusinessPermitLabel.textContent = sellerBusinessPermitInput.files[0].name;
            } else {
                sellerBusinessPermitLabel.textContent = 'Choose File';
            }
        });
    }

    // Custom file input logic for Rider
    const riderFileInput = document.getElementById('rider_id_upload');
    const riderFileLabel = document.getElementById('riderFileLabel');
    if (riderFileInput && riderFileLabel) {
        riderFileInput.addEventListener('change', function() {
            if (riderFileInput.files && riderFileInput.files.length > 0) {
                riderFileLabel.textContent = riderFileInput.files[0].name;
            } else {
                riderFileLabel.textContent = 'Choose File';
            }
        });
    }

    const tabs = document.querySelectorAll('.register-tab');
    const underline = document.querySelector('.register-tab-underline');
    const welcomeSub = document.getElementById('registerWelcomeSub');

    function updateUnderline() {
        const activeTab = document.querySelector('.register-tab.active');
        if (!activeTab || !underline) return;
        const nav = activeTab.parentElement;
        const navRect = nav.getBoundingClientRect();
        const tabRect = activeTab.getBoundingClientRect();
        // Calculate left offset relative to nav
        const left = tabRect.left - navRect.left;
        underline.style.width = tabRect.width + 'px';
        underline.style.transform = `translateX(${left}px)`;
    }

    const tabContents = {
        'Buyer': document.getElementById('buyer-form'),
        'Seller': document.getElementById('seller-form'),
        'Rider': document.getElementById('rider-form')
    };
    const tabWelcomeSubs = {
        'Buyer': 'Shop your favorite products with ease.',
        'Seller': 'Grow your business and reach more customers.',
        'Rider': 'Deliver, earn, and be part of our trusted team.'
    };

    tabs.forEach(tab => {
        tab.addEventListener('click', function() {
            tabs.forEach(t => t.classList.remove('active'));
            this.classList.add('active');
            // Hide all forms
            Object.values(tabContents).forEach(content => {
                if (content) content.style.display = 'none';
            });
            // Show the selected form
            const tabName = this.textContent.trim();
            if (tabContents[tabName]) {
                tabContents[tabName].style.display = 'block';
            }
            // Update welcome subtext
            if (welcomeSub && tabWelcomeSubs[tabName]) {
                welcomeSub.textContent = tabWelcomeSubs[tabName];
            }
            updateUnderline();
        });
    });

    // Initial position
    updateUnderline();
    // On window resize, recalculate
    window.addEventListener('resize', updateUnderline);
    // Set initial welcome subtext
    if (welcomeSub) welcomeSub.textContent = tabWelcomeSubs['Buyer'];

    const requirementChecks = {
        length: password => password.length >= 6,
        uppercase: password => /[A-Z]/.test(password),
        lowercase: password => /[a-z]/.test(password),
        number: password => /\d/.test(password)
    };

    function updateRequirementStates(passwordInput) {
        const form = passwordInput.closest('form');
        if (!form) return;

        const guidelines = form.querySelector('.password-guidelines');
        const requirementItems = form.querySelectorAll('.password-guidelines-list li');
        const password = passwordInput.value;

        let allMet = true;

        requirementItems.forEach(item => {
            const requirement = item.dataset.requirement;
            if (requirement && requirementChecks[requirement]) {
                const isMet = requirementChecks[requirement](password);
                item.classList.toggle('met', isMet);
                item.classList.toggle('unmet', !isMet);
                if (!isMet) {
                    allMet = false;
                }
            }
        });

        if (password.length > 0 && !allMet) {
            guidelines.classList.add('visible');
        } else {
            guidelines.classList.remove('visible');
        }
    }

    const passwordInputs = document.querySelectorAll('input[type="password"][id$="_password"]');
    passwordInputs.forEach(input => {
        input.addEventListener('input', () => updateRequirementStates(input));
        // Initial check in case of pre-filled values
        updateRequirementStates(input);
    });

    // Password toggle functionality
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

    // Form submission handlers
    const buyerForm = document.querySelector('#buyer-form form');
    const sellerForm = document.querySelector('#seller-form form');
    const riderForm = document.querySelector('#rider-form form');

    // Buyer form submission
    if (buyerForm) {
        buyerForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            const submitBtn = this.querySelector('.register-btn');
            const originalText = submitBtn.textContent;
            
            // Disable button and show loading
            submitBtn.disabled = true;
            submitBtn.textContent = 'Registering...';
            
            try {
                const response = await fetch('/register/buyer', {
                    method: 'POST',
                    body: formData
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showNotification(data.message, 'success');
                    if (data.redirect) {
                        setTimeout(() => {
                            window.location.href = data.redirect;
                        }, 4000);
                    }
                } else {
                    showNotification(data.message || 'Registration failed. Please try again.', 'error');
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

    // Seller form submission
    if (sellerForm) {
        sellerForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const submitBtn = this.querySelector('.register-btn');
            const originalText = submitBtn.textContent;
            
            // Client-side validation
            const firstName = this.querySelector('input[name="seller_first_name"]').value.trim();
            const lastName = this.querySelector('input[name="seller_last_name"]').value.trim();
            const email = this.querySelector('input[name="seller_email"]').value.trim();
            const password = this.querySelector('input[name="seller_password"]').value;
            const idType = this.querySelector('select[name="seller_id_type"]').value.trim();
            const addressField = this.querySelector('input[name="seller_address_field"]').value.trim();
            const idFileInput = this.querySelector('input[name="seller_id_upload"]');
            const businessPermitInput = this.querySelector('input[name="seller_business_permit_upload"]');
            
            // Validate required fields
            if (!firstName) {
                showNotification('First name is required', 'error');
                return;
            }
            
            if (!lastName) {
                showNotification('Last name is required', 'error');
                return;
            }
            
            if (!email) {
                showNotification('Email is required', 'error');
                return;
            }
            
            if (!password) {
                showNotification('Password is required', 'error');
                return;
            }
            
            if (!idType) {
                showNotification('ID Type is required. Please select your ID type.', 'error');
                return;
            }
            
            if (!addressField) {
                showNotification('Address is required. Please select your address details.', 'error');
                return;
            }
            
            // Validate ID file upload
            if (!idFileInput || !idFileInput.files || idFileInput.files.length === 0) {
                showNotification('ID file is required. Please upload your ID file.', 'error');
                return;
            }
            
            // Validate business permit file upload
            if (!businessPermitInput || !businessPermitInput.files || businessPermitInput.files.length === 0) {
                showNotification('Business permit is required. Please upload your business permit file.', 'error');
                return;
            }
            
            const formData = new FormData(this);
            
            // Disable button and show loading
            submitBtn.disabled = true;
            submitBtn.textContent = 'Registering...';
            
            try {
                const response = await fetch('/register/seller', {
                    method: 'POST',
                    body: formData
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showNotification(data.message, 'success');
                    if (data.redirect) {
                        setTimeout(() => {
                            window.location.href = data.redirect;
                        }, 4000);
                    }
                } else {
                    showNotification(data.message || 'Registration failed. Please try again.', 'error');
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

    // Rider form submission
    if (riderForm) {
        riderForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const submitBtn = this.querySelector('.register-btn');
            const originalText = submitBtn.textContent;
            
            // Client-side validation
            const firstName = this.querySelector('input[name="rider_first_name"]').value.trim();
            const lastName = this.querySelector('input[name="rider_last_name"]').value.trim();
            const email = this.querySelector('input[name="rider_email"]').value.trim();
            const password = this.querySelector('input[name="rider_password"]').value;
            const addressField = this.querySelector('input[name="rider_address_field"]').value.trim();
            
            // Validate required fields
            if (!firstName) {
                showNotification('First name is required', 'error');
                return;
            }
            
            if (!lastName) {
                showNotification('Last name is required', 'error');
                return;
            }
            
            if (!email) {
                showNotification('Email is required', 'error');
                return;
            }
            
            if (!password) {
                showNotification('Password is required', 'error');
                return;
            }
            
            if (!addressField) {
                showNotification('Address is required. Please select your address details.', 'error');
                return;
            }
            
            // Validate ID documents uploaded
            if (typeof riderOrcrFileObj === 'undefined' || !riderOrcrFileObj) {
                showNotification('ORCR document is required. Please upload your ORCR file.', 'error');
                return;
            }
            
            if (typeof riderDriverLicenseFileObj === 'undefined' || !riderDriverLicenseFileObj) {
                showNotification('Driver License is required. Please upload your Driver License file.', 'error');
                return;
            }
            
            // Validate vehicle and plate details
            if (typeof riderVehicleType === 'undefined' || !riderVehicleType) {
                showNotification('Vehicle type is required. Please select your vehicle details.', 'error');
                return;
            }
            
            if (typeof riderPlateNumber === 'undefined' || !riderPlateNumber) {
                showNotification('Plate number is required. Please enter your plate number.', 'error');
                return;
            }
            
            const formData = new FormData(this);
            
            // Add file objects from modal
            formData.append('rider_orcr_upload', riderOrcrFileObj);
            formData.append('rider_driver_license_upload', riderDriverLicenseFileObj);
            
            // Add vehicle type and plate number from modal
            formData.append('rider_vehicle_type', riderVehicleType);
            formData.append('rider_plate_number', riderPlateNumber);
            
            // Disable button and show loading
            submitBtn.disabled = true;
            submitBtn.textContent = 'Registering...';
            
            try {
                const response = await fetch('/register/rider', {
                    method: 'POST',
                    body: formData
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showNotification(data.message, 'success');
                    if (data.redirect) {
                        setTimeout(() => {
                            window.location.href = data.redirect;
                        }, 4000);
                    }
                } else {
                    showNotification(data.message || 'Registration failed. Please try again.', 'error');
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
