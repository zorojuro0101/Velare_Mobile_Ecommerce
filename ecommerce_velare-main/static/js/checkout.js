// Checkout page functionality
document.addEventListener('DOMContentLoaded', function() {
    console.log('Checkout page loaded');
    
    // Initialize checkout functionality
    initializeCheckout();
    initializeTabs();
    initializeQuantityControls();
    initializeNextButton();
    
    // Initialize address functionality
    initializeAddressModal();
    initializeAddressSelection();
    
    // Initialize voucher functionality
    initializeVouchers();
    
    // Calculate and display order total
    calculateOrderTotal();
});

function initializeCheckout() {
    // Initialize image slider with book-like page flip effect
    initializeImageSlider();
}

function initializeImageSlider() {
    const imageList = document.querySelector('.product-image-list');
    const images = document.querySelectorAll('.product-main-image');
    const prevBtn = document.getElementById('prevImageBtn');
    const nextBtn = document.getElementById('nextImageBtn');
    
    if (!imageList || images.length === 0) return;
    
    let currentIndex = 0;
    const totalImages = images.length;
    const imageWidth = 1000; // var(--image-list-width)
    
    // Auto-slide every 5 seconds
    let autoSlideInterval = setInterval(() => {
        nextImage();
    }, 5000);
    
    function updateSlider() {
        const translateX = -(currentIndex * imageWidth);
        imageList.style.transform = `translateX(${translateX}px)`;
    }
    
    function nextImage() {
        currentIndex = (currentIndex + 1) % totalImages;
        updateSlider();
    }
    
    function prevImage() {
        currentIndex = (currentIndex - 1 + totalImages) % totalImages;
        updateSlider();
    }
    
    function resetAutoSlide() {
        clearInterval(autoSlideInterval);
        autoSlideInterval = setInterval(() => {
            nextImage();
        }, 5000);
    }
    
    // Next button click
    if (nextBtn) {
        nextBtn.addEventListener('click', function() {
            nextImage();
            resetAutoSlide();
        });
    }
    
    // Previous button click
    if (prevBtn) {
        prevBtn.addEventListener('click', function() {
            prevImage();
            resetAutoSlide();
        });
    }
    
    // Click image to go next
    images.forEach((image) => {
        image.addEventListener('click', function() {
            nextImage();
            resetAutoSlide();
        });
    });
}

function initializeTabs() {
    const tabs = document.querySelectorAll('.checkout-tab');
    const tabContents = document.querySelectorAll('.checkout-tab-content');
    const underline = document.querySelector('.checkout-tab-underline');
    const nextBtn = document.getElementById('next-btn');
    const placeOrderBtn = document.getElementById('place-order-btn');
    
    // Check if we need to restore a saved tab state
    const savedTab = sessionStorage.getItem('checkoutActiveTab');
    if (savedTab) {
        // Find and activate the saved tab
        const targetTab = document.querySelector(`.checkout-tab[data-tab="${savedTab}"]`);
        if (targetTab) {
            // Enable the tab if it's disabled
            targetTab.disabled = false;
            targetTab.classList.remove('disabled');
            
            // Remove active from all tabs
            tabs.forEach(t => t.classList.remove('active'));
            targetTab.classList.add('active');
            
            // Hide all contents
            tabContents.forEach(content => {
                content.style.display = 'none';
            });
            
            // Show target content
            const targetContent = document.getElementById('tab-' + savedTab);
            if (targetContent) {
                targetContent.style.display = 'block';
            }
            
            // Toggle buttons
            if (savedTab === 'address') {
                if (nextBtn) nextBtn.style.display = 'none';
                if (placeOrderBtn) placeOrderBtn.style.display = 'block';
            } else if (savedTab === 'product-details') {
                if (nextBtn) nextBtn.style.display = 'block';
                if (placeOrderBtn) placeOrderBtn.style.display = 'none';
            }
        }
    }
    
    // Set underline position immediately without transition to prevent flash
    if (underline) {
        underline.style.transition = 'none';
        updateUnderline();
        // Re-enable transition after positioning
        requestAnimationFrame(() => {
            underline.style.transition = '';
        });
    }
    
    tabs.forEach(tab => {
        tab.addEventListener('click', function() {
            // Check if tab is disabled
            if (this.disabled || this.classList.contains('disabled')) {
                return;
            }
            
            const targetTab = this.getAttribute('data-tab');
            
            // Remove active class from all tabs
            tabs.forEach(t => t.classList.remove('active'));
            
            // Add active class to clicked tab
            this.classList.add('active');
            
            // Hide all tab contents
            tabContents.forEach(content => {
                content.style.display = 'none';
            });
            
            // Show target tab content
            const targetContent = document.getElementById('tab-' + targetTab);
            if (targetContent) {
                targetContent.style.display = 'block';
            }
            
            // Toggle buttons based on active tab
            if (targetTab === 'address') {
                if (nextBtn) nextBtn.style.display = 'none';
                if (placeOrderBtn) placeOrderBtn.style.display = 'block';
            } else if (targetTab === 'product-details') {
                if (nextBtn) nextBtn.style.display = 'block';
                if (placeOrderBtn) placeOrderBtn.style.display = 'none';
            }
            
            // Save active tab to sessionStorage
            sessionStorage.setItem('checkoutActiveTab', targetTab);
            
            // Update underline position
            updateUnderline();
        });
    });
    
    function updateUnderline() {
        const activeTab = document.querySelector('.checkout-tab.active');
        const tabNav = document.querySelector('.checkout-tab-nav');
        
        if (activeTab && underline && tabNav) {
            const tabNavRect = tabNav.getBoundingClientRect();
            const activeTabRect = activeTab.getBoundingClientRect();
            
            const leftOffset = activeTabRect.left - tabNavRect.left;
            const width = activeTabRect.width;
            
            underline.style.width = width + 'px';
            underline.style.transform = `translateX(${leftOffset}px)`;
        }
    }
    
    // Update underline on window resize
    window.addEventListener('resize', updateUnderline);
}

function initializeQuantityControls() {
    const decrementBtn = document.querySelector('.qty-btn.decrement');
    const incrementBtn = document.querySelector('.qty-btn.increment');
    const quantityInput = document.querySelector('.qty-input');
    
    if (decrementBtn && incrementBtn && quantityInput) {
        let quantity = parseInt(quantityInput.value) || 1;
        
        decrementBtn.addEventListener('click', function() {
            if (quantity > 1) {
                quantity--;
                quantityInput.value = quantity;
            }
        });
        
        incrementBtn.addEventListener('click', function() {
            quantity++;
            quantityInput.value = quantity;
        });
    }
    
    // Handle address modal functionality
    initializeAddressModal();
    initializeAddressSelection();
}

function initializeNextButton() {
    const nextBtn = document.getElementById('next-btn');
    const placeOrderBtn = document.getElementById('place-order-btn');
    const vouchersTab = document.querySelector('.checkout-tab[data-tab="vouchers"]');
    const addressTab = document.querySelector('.checkout-tab[data-tab="address"]');
    
    if (nextBtn) {
        nextBtn.addEventListener('click', function() {
            const tabs = document.querySelectorAll('.checkout-tab');
            const tabContents = document.querySelectorAll('.checkout-tab-content');
            const activeTab = document.querySelector('.checkout-tab.active');
            const currentTab = activeTab ? activeTab.getAttribute('data-tab') : null;
            
            // Determine next tab based on current tab
            let nextTab = null;
            let nextTabElement = null;
            let nextTabContent = null;
            
            if (currentTab === 'product-details') {
                // Move directly to Address tab (vouchers removed)
                nextTab = 'address';
                nextTabElement = addressTab;
                nextTabContent = document.getElementById('tab-address');
            }
            
            if (nextTabElement && nextTabContent) {
                // Enable the next tab
                nextTabElement.disabled = false;
                nextTabElement.classList.remove('disabled');
                
                // Remove active class from all tabs
                tabs.forEach(t => t.classList.remove('active'));
                
                // Add active class to next tab
                nextTabElement.classList.add('active');
                
                // Hide all tab contents
                tabContents.forEach(content => {
                    content.style.display = 'none';
                });
                
                // Show next tab content
                nextTabContent.style.display = 'block';
                
                // Save active tab to sessionStorage
                sessionStorage.setItem('checkoutActiveTab', nextTab);
                
                // Update underline position
                updateUnderlinePosition();
                
                // If moving to Address tab, show Place Order button
                if (nextTab === 'address') {
                    nextBtn.style.display = 'none';
                    if (placeOrderBtn) {
                        placeOrderBtn.style.display = 'block';
                    }
                }
                
                console.log('Next button clicked - Moved to ' + nextTab + ' tab');
            }
        });
    }
    
    // Initialize Place Order button
    if (placeOrderBtn) {
        placeOrderBtn.addEventListener('click', function() {
            // Check if default address is set
            const defaultAddress = document.querySelector('.default-address-section .address-info');
            
            if (!defaultAddress || !defaultAddress.dataset.addressId) {
                alert('Please select a delivery address before placing your order.');
                return;
            }
            
            // Get cart IDs from URL
            const urlParams = new URLSearchParams(window.location.search);
            const cartIds = urlParams.get('cart_ids');
            
            if (!cartIds) {
                alert('No items found in checkout.');
                return;
            }
            
            // Get order totals
            const subtotalText = document.getElementById('orderSubtotal').textContent.replace('₱', '').replace(',', '');
            const shippingText = document.getElementById('orderShipping').textContent;
            const discountText = document.getElementById('orderDiscount').textContent.replace('-₱', '').replace(',', '');
            const totalText = document.getElementById('orderTotal').textContent.replace('₱', '').replace(',', '');
            
            const subtotal = parseFloat(subtotalText) || 0;
            const shipping = (shippingText === 'FREE' || shippingText === '-₱0.00') ? 0 : parseFloat(shippingText.replace('₱', '').replace(',', '')) || 0;
            const discount = parseFloat(discountText) || 0;
            const total = parseFloat(totalText) || 0;
            
            // Prepare order data
            const orderData = {
                cart_ids: cartIds.split(',').map(id => parseInt(id)),
                address_id: defaultAddress.dataset.addressId,
                subtotal: subtotal,
                shipping_fee: shipping,
                discount_amount: discount,
                total_amount: total,
                voucher_type: appliedVoucherType,
                voucher_id: appliedVoucherId
            };
            
            // Disable button to prevent double submission
            placeOrderBtn.disabled = true;
            placeOrderBtn.textContent = 'Processing...';
            
            // Call API to place order
            fetch('/place_order', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(orderData)
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Show success modal
                    showOrderSuccessModal();
                } else {
                    alert(data.message || 'Failed to place order');
                    placeOrderBtn.disabled = false;
                    placeOrderBtn.textContent = 'Place Order';
                }
            })
            .catch(error => {
                console.error('Error:', error);
                alert('An error occurred while placing your order');
                placeOrderBtn.disabled = false;
                placeOrderBtn.textContent = 'Place Order';
            });
        });
    }
    
    // Initialize order success modal
    initializeOrderSuccessModal();
}

function updateUnderlinePosition() {
    const activeTab = document.querySelector('.checkout-tab.active');
    const tabNav = document.querySelector('.checkout-tab-nav');
    const underline = document.querySelector('.checkout-tab-underline');
    
    if (activeTab && underline && tabNav) {
        const tabNavRect = tabNav.getBoundingClientRect();
        const activeTabRect = activeTab.getBoundingClientRect();
        
        const leftOffset = activeTabRect.left - tabNavRect.left;
        const width = activeTabRect.width;
        
        underline.style.width = width + 'px';
        underline.style.transform = `translateX(${leftOffset}px)`;
    }
}

// Address Modal functionality
function initializeAddressModal() {
    const openModalBtn = document.getElementById('openAddressModalBtn');
    const addressModal = document.getElementById('addressModal');
    const cancelBtn = document.getElementById('cancelAddAddressBtn');
    const form = document.getElementById('addAddressForm');
    const phoneInput = document.getElementById('phoneNumber');
    
    // Add phone number input validation
    if (phoneInput) {
        phoneInput.addEventListener('input', function(e) {
            // Remove any non-digit characters
            let value = e.target.value.replace(/\D/g, '');
            
            // Limit to 11 digits
            if (value.length > 11) {
                value = value.substring(0, 11);
            }
            
            e.target.value = value;
        });
        
        // Prevent pasting non-numeric characters
        phoneInput.addEventListener('paste', function(e) {
            e.preventDefault();
            const pastedText = (e.clipboardData || window.clipboardData).getData('text');
            const numericOnly = pastedText.replace(/\D/g, '').substring(0, 11);
            e.target.value = numericOnly;
        });
    }
    
    // Open modal
    if (openModalBtn && addressModal) {
        openModalBtn.addEventListener('click', function() {
            addressModal.style.display = 'flex';
            initializeAddressTabsInModal();
        });
    }
    
    // Close modal
    if (cancelBtn && addressModal) {
        cancelBtn.addEventListener('click', function() {
            addressModal.style.display = 'none';
            resetAddressForm();
        });
    }
    
    // Close modal on outside click
    if (addressModal) {
        addressModal.addEventListener('click', function(e) {
            if (e.target === addressModal) {
                addressModal.style.display = 'none';
                resetAddressForm();
            }
        });
    }
    
    // Handle form submission
    if (form) {
        form.addEventListener('submit', function(e) {
            e.preventDefault();
            addNewAddress();
        });
    }
}

// Address selection functionality
function initializeAddressSelection() {
    const selectBtns = document.querySelectorAll('.select-address-btn');
    
    selectBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            const addressInfo = this.closest('.address-info');
            const addressId = addressInfo.dataset.addressId;
            
            // Call API to set as default
            fetch('/set_default_address', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    address_id: addressId
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Update UI without reloading
                    updateAddressDisplay(addressInfo, addressId);
                } else {
                    alert(data.message || 'Failed to set default address');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                alert('An error occurred while setting default address');
            });
        });
    });
}

// Update address display without reloading
function updateAddressDisplay(selectedAddressInfo, selectedAddressId) {
    const defaultAddressSection = document.querySelector('.default-address-section .address-details');
    const defaultAddressContainer = document.querySelector('.default-address-section .address-info');
    const selectedAddressDetails = selectedAddressInfo.querySelector('.address-details');
    const otherAddressesList = document.getElementById('otherAddressesList');
    
    if (defaultAddressSection && selectedAddressDetails) {
        // Get current default address ID
        const currentDefaultAddressId = defaultAddressContainer ? defaultAddressContainer.dataset.addressId : null;
        
        // Store current default address data
        const currentDefaultName = defaultAddressSection.querySelector('.address-name').textContent;
        const currentDefaultText = defaultAddressSection.querySelector('.address-text').textContent;
        const currentDefaultPhone = defaultAddressSection.querySelector('.address-phone').textContent;
        
        // Get selected address data
        const newDefaultName = selectedAddressDetails.querySelector('.address-name').textContent;
        const newDefaultText = selectedAddressDetails.querySelector('.address-text').textContent;
        const newDefaultPhone = selectedAddressDetails.querySelector('.address-phone').textContent;
        
        // Remove selected address from list FIRST
        selectedAddressInfo.remove();
        
        // Update default address display
        defaultAddressSection.innerHTML = `
            <div class="address-name">${newDefaultName}</div>
            <div class="address-text">${newDefaultText}</div>
            <div class="address-phone">${newDefaultPhone}</div>
            <div class="address-default-badge">Default</div>
        `;
        
        // Update the address ID on the default container
        if (defaultAddressContainer) {
            defaultAddressContainer.dataset.addressId = selectedAddressId;
        }
        
        // Only add previous default to list if it has a valid ID
        if (currentDefaultAddressId && currentDefaultAddressId !== selectedAddressId) {
            const previousDefaultDiv = document.createElement('div');
            previousDefaultDiv.className = 'address-info selectable-address';
            previousDefaultDiv.dataset.addressId = currentDefaultAddressId;
            
            previousDefaultDiv.innerHTML = `
                <div class="address-details">
                    <div class="address-name">${currentDefaultName}</div>
                    <div class="address-text">${currentDefaultText}</div>
                    <div class="address-phone">${currentDefaultPhone}</div>
                </div>
                <div class="address-actions">
                    <button class="select-address-btn">Select</button>
                </div>
            `;
            
            // Add event listener to new select button
            const newSelectBtn = previousDefaultDiv.querySelector('.select-address-btn');
            newSelectBtn.addEventListener('click', function() {
                const newAddressInfo = this.closest('.address-info');
                const newAddressId = newAddressInfo.dataset.addressId;
                
                fetch('/set_default_address', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ address_id: newAddressId })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        updateAddressDisplay(newAddressInfo, newAddressId);
                    } else {
                        alert(data.message || 'Failed to set default address');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    alert('An error occurred');
                });
            });
            
            // Add previous default to list
            otherAddressesList.insertBefore(previousDefaultDiv, otherAddressesList.firstChild);
        }
    }
}

// Address tabs functionality in modal (adapted from myAccount_address.js)
function initializeAddressTabsInModal() {
    const addressTabsUnderline = document.getElementById('addressTabsUnderline');
    const addressField = document.getElementById('addressField');
    const addressTabsDropdown = document.getElementById('addressTabsDropdown');
    const cancelTabsBtn = document.getElementById('cancelAddressTabsBtn');
    const confirmTabsBtn = document.getElementById('confirmAddressTabsBtn');
    const postalCodeInput = document.getElementById('postalCode');
    const tabRegionSelect = document.getElementById('tabRegionSelect');
    const tabProvinceSelect = document.getElementById('tabProvinceSelect');
    const tabCitySelect = document.getElementById('tabCitySelect');
    const tabBarangaySelect = document.getElementById('tabBarangaySelect');
    const addressTabs = document.querySelectorAll('.address-tab');
    const tabContents = {
        region: document.getElementById('regionTabContent'),
        province: document.getElementById('provinceTabContent'),
        city: document.getElementById('cityTabContent'),
        barangay: document.getElementById('barangayTabContent')
    };
    
    // PSGC API endpoints
    const PSGC_API = 'https://psgc.gitlab.io/api';
    const POSTAL_CODE_DATA_URL = 'https://gist.githubusercontent.com/chrisbjr/784565232f10cba6530856dc7fda367a/raw/ph-zip-codes.json';
    let postalCodeDataPromise = null;
    let postalCodeDataCache = null;
    const STOP_WORDS = new Set(['OF', 'THE', 'CITY', 'MUNICIPALITY', 'PROVINCE', 'BARANGAY', 'DISTRICT']);
    
    function updateAddressTabsUnderline() {
        const activeTab = document.querySelector('.address-tab.active');
        if (!activeTab || !addressTabsUnderline) return;
        const nav = activeTab.parentElement;
        const navRect = nav.getBoundingClientRect();
        const tabRect = activeTab.getBoundingClientRect();
        const left = tabRect.left - navRect.left;
        addressTabsUnderline.style.width = tabRect.width + 'px';
        addressTabsUnderline.style.transform = `translateX(${left}px)`;
    }
    
    // Postal code lookup functions
    function normalizeName(name) {
        if (!name) return '';
        const sanitized = name.replace(/\?/g, 'N');
        return sanitized
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .toUpperCase()
            .replace(/[^A-Z0-9\s]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    function tokensFor(name) {
        const normalized = normalizeName(name);
        if (!normalized) return [];
        return normalized
            .split(' ')
            .map(token => token.trim())
            .filter(token => token && !STOP_WORDS.has(token));
    }

    async function loadPostalCodeData() {
        if (postalCodeDataCache) return postalCodeDataCache;
        if (!postalCodeDataPromise) {
            postalCodeDataPromise = fetch(POSTAL_CODE_DATA_URL)
                .then(res => {
                    if (!res.ok) {
                        throw new Error('Failed to load postal code data');
                    }
                    return res.json();
                })
                .then(data => {
                    postalCodeDataCache = data.map(entry => {
                        const normalizedArea = normalizeName(entry.area);
                        return {
                            ...entry,
                            normalizedArea,
                            tokenSet: new Set(normalizedArea.split(' ').filter(Boolean))
                        };
                    });
                    return postalCodeDataCache;
                })
                .catch(err => {
                    console.error('Postal code data load error:', err);
                    postalCodeDataPromise = null;
                    throw err;
                });
        }
        return postalCodeDataPromise;
    }

    function findPostalCodeMatch(data, cityName, provinceName, regionName, barangayName) {
        const cityTokens = tokensFor(cityName);
        if (!cityTokens.length) return '';
        const provinceTokens = tokensFor(provinceName);
        const regionTokens = tokensFor(regionName === 'National Capital Region' ? 'Metro Manila' : regionName);
        const barangayTokens = tokensFor(barangayName);

        const matchesAllTokens = (tokenSet, tokens) => tokens.length === 0 || tokens.every(token => tokenSet.has(token));
        const matchesSomeTokens = (tokenSet, tokens) => tokens.some(token => tokenSet.has(token));

        const barangayMatch = data.find(entry => {
            const tokens = entry.tokenSet;
            if (!matchesAllTokens(tokens, cityTokens)) return false;
            if (!matchesAllTokens(tokens, barangayTokens)) return false;
            if (provinceTokens.length && !matchesAllTokens(tokens, provinceTokens) && !matchesAllTokens(tokens, regionTokens)) return false;
            return true;
        });
        if (barangayMatch) return barangayMatch.zip;

        let bestEntry = null;
        let bestScore = -1;
        data.forEach(entry => {
            const tokens = entry.tokenSet;
            if (!matchesAllTokens(tokens, cityTokens)) return;

            let score = 0;
            if (matchesAllTokens(tokens, provinceTokens)) score += 3;
            else if (matchesAllTokens(tokens, regionTokens)) score += 1;

            if (barangayTokens.length && matchesSomeTokens(tokens, barangayTokens)) score += 1;

            if (score > bestScore) {
                bestScore = score;
                bestEntry = entry;
            }
        });

        return bestEntry ? bestEntry.zip : '';
    }

    async function updatePostalCodeForSelection() {
        if (!postalCodeInput) return;

        const regionOption = tabRegionSelect.options[tabRegionSelect.selectedIndex];
        const provinceOption = tabProvinceSelect.options[tabProvinceSelect.selectedIndex];
        const cityOption = tabCitySelect.options[tabCitySelect.selectedIndex];
        const barangayOption = tabBarangaySelect.options[tabBarangaySelect.selectedIndex];

        const regionName = regionOption ? regionOption.text : '';
        const provinceName = tabRegionSelect.value === '130000000' ? 'Metro Manila' : (provinceOption ? provinceOption.text : '');
        const cityName = cityOption ? cityOption.text : '';
        const barangayName = barangayOption ? barangayOption.text : '';

        if (!cityName) {
            postalCodeInput.value = '';
            return;
        }

        try {
            const postalData = await loadPostalCodeData();
            const foundPostalCode = findPostalCodeMatch(postalData, cityName, provinceName, regionName, barangayName);
            postalCodeInput.value = foundPostalCode || '';
        } catch (err) {
            console.error('Postal code lookup failed:', err);
        }
    }
    
    // Helper: fetch and populate select
    async function populateSelect(url, select, valueKey, labelKey) {
        select.innerHTML = `<option value="">Select ${select.getAttribute('data-label') || ''}</option>`;
        try {
            const res = await fetch(url);
            const data = await res.json();
            data.forEach(item => {
                const opt = document.createElement('option');
                opt.value = item[valueKey];
                opt.textContent = item[labelKey];
                select.appendChild(opt);
            });
        } catch (e) {
            const opt = document.createElement('option');
            opt.value = '';
            opt.textContent = 'Failed to load';
            select.appendChild(opt);
        }
    }
    
    // Show dropdown below address field
    if (addressField && addressTabsDropdown) {
        addressField.addEventListener('click', async function(e) {
            e.stopPropagation();
            addressTabsDropdown.style.display = 'block';
            // Reset all
            await populateSelect(`${PSGC_API}/regions/`, tabRegionSelect, 'code', 'name');
            tabProvinceSelect.innerHTML = '<option value="">Select Province</option>';
            tabProvinceSelect.disabled = true;
            tabCitySelect.innerHTML = '<option value="">Select City/Municipality</option>';
            tabCitySelect.disabled = true;
            tabBarangaySelect.innerHTML = '<option value="">Select Barangay</option>';
            tabBarangaySelect.disabled = true;
            // Tabs state
            addressTabs.forEach(tab => {
                tab.classList.remove('active');
                tab.disabled = tab.dataset.tab !== 'region';
            });
            addressTabs[0].classList.add('active');
            Object.values(tabContents).forEach((el, i) => {
                el.style.display = i === 0 ? 'block' : 'none';
            });
            confirmTabsBtn.disabled = true;
            updateAddressTabsUnderline();
        });
    }
    
    // Cancel button
    if (cancelTabsBtn && addressTabsDropdown) {
        cancelTabsBtn.addEventListener('click', function() {
            addressTabsDropdown.style.display = 'none';
        });
    }
    
    // Click outside closes dropdown
    document.addEventListener('click', function(e) {
        if (addressTabsDropdown && addressTabsDropdown.style.display === 'block') {
            if (!addressTabsDropdown.contains(e.target) && e.target !== addressField) {
                addressTabsDropdown.style.display = 'none';
            }
        }
    });
    
    // Tab navigation
    addressTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            if (tab.disabled) return;
            addressTabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            Object.values(tabContents).forEach(el => el.style.display = 'none');
            tabContents[tab.dataset.tab].style.display = 'block';
            updateAddressTabsUnderline();
        });
    });
    
    // Region select
    tabRegionSelect.addEventListener('change', async function() {
        tabProvinceSelect.innerHTML = '<option value="">Select Province</option>';
        tabCitySelect.innerHTML = '<option value="">Select City/Municipality</option>';
        tabBarangaySelect.innerHTML = '<option value="">Select Barangay</option>';
        tabCitySelect.disabled = true;
        tabBarangaySelect.disabled = true;
        addressTabs[1].disabled = true;
        addressTabs[2].disabled = true;
        addressTabs[3].disabled = true;
        if (postalCodeInput) postalCodeInput.value = '';
        if (tabRegionSelect.value) {
            // NCR: hide province tab, go straight to city
            if (tabRegionSelect.value === '130000000') { 
                if (addressTabs[1]) addressTabs[1].style.display = 'none';
                tabProvinceSelect.disabled = true;
                addressTabs[1].disabled = true;
                tabContents['province'].style.display = 'none';
                // Populate cities for NCR
                await populateSelect(`${PSGC_API}/regions/130000000/cities-municipalities/`, tabCitySelect, 'code', 'name');
                tabCitySelect.disabled = false;
                addressTabs[2].disabled = false;
                // Auto move to City tab
                addressTabs.forEach(t => t.classList.remove('active'));
                addressTabs[2].classList.add('active');
                Object.values(tabContents).forEach(el => el.style.display = 'none');
                tabContents['city'].style.display = 'block';
                updateAddressTabsUnderline();
                await updatePostalCodeForSelection();
            } else {
                // Show province tab if hidden
                if (addressTabs[1]) addressTabs[1].style.display = 'flex';
                // Normal region: show province
                await populateSelect(`${PSGC_API}/regions/${tabRegionSelect.value}/provinces/`, tabProvinceSelect, 'code', 'name');
                tabProvinceSelect.disabled = false;
                addressTabs[1].disabled = false;
                // Auto move to Province tab
                addressTabs.forEach(t => t.classList.remove('active'));
                addressTabs[1].classList.add('active');
                Object.values(tabContents).forEach(el => el.style.display = 'none');
                tabContents['province'].style.display = 'block';
                updateAddressTabsUnderline();
            }
        } else {
            // Show province tab if hidden
            if (addressTabs[1]) addressTabs[1].style.display = 'flex';
            tabProvinceSelect.disabled = true;
        }
    });
    
    // Province select
    tabProvinceSelect.addEventListener('change', async function() {
        tabCitySelect.innerHTML = '<option value="">Select City/Municipality</option>';
        tabBarangaySelect.innerHTML = '<option value="">Select Barangay</option>';
        tabCitySelect.disabled = true;
        tabBarangaySelect.disabled = true;
        addressTabs[2].disabled = true;
        addressTabs[3].disabled = true;
        if (postalCodeInput) postalCodeInput.value = '';
        if (tabProvinceSelect.value) {
            await populateSelect(`${PSGC_API}/provinces/${tabProvinceSelect.value}/cities-municipalities/`, tabCitySelect, 'code', 'name');
            tabCitySelect.disabled = false;
            addressTabs[2].disabled = false;
            // Auto move to City tab
            addressTabs.forEach(t => t.classList.remove('active'));
            addressTabs[2].classList.add('active');
            Object.values(tabContents).forEach(el => el.style.display = 'none');
            tabContents['city'].style.display = 'block';
            updateAddressTabsUnderline();
            await updatePostalCodeForSelection();
        }
    });
    
    // City select
    tabCitySelect.addEventListener('change', async function() {
        tabBarangaySelect.innerHTML = '<option value="">Select Barangay</option>';
        tabBarangaySelect.disabled = true;
        addressTabs[3].disabled = true;
        if (postalCodeInput) postalCodeInput.value = '';
        if (tabCitySelect.value) {
            await populateSelect(`${PSGC_API}/cities-municipalities/${tabCitySelect.value}/barangays/`, tabBarangaySelect, 'code', 'name');
            tabBarangaySelect.disabled = false;
            addressTabs[3].disabled = false;
            // Auto move to Barangay tab
            addressTabs.forEach(t => t.classList.remove('active'));
            addressTabs[3].classList.add('active');
            Object.values(tabContents).forEach(el => el.style.display = 'none');
            tabContents['barangay'].style.display = 'block';
            updateAddressTabsUnderline();
            await updatePostalCodeForSelection();
        }
    });
    
    // Barangay select
    tabBarangaySelect.addEventListener('change', function() {
        if (tabBarangaySelect.value) {
            confirmTabsBtn.disabled = false;
        } else {
            confirmTabsBtn.disabled = true;
        }
        updatePostalCodeForSelection();
    });
    
    // Confirm button
    confirmTabsBtn.addEventListener('click', function() {
        const isNCR = tabRegionSelect.value === '130000000';
        const regionName = tabRegionSelect.options[tabRegionSelect.selectedIndex].text;
        const cityName = tabCitySelect.options[tabCitySelect.selectedIndex].text;
        const barangayName = tabBarangaySelect.options[tabBarangaySelect.selectedIndex].text;
        
        let provinceName = '';
        if (!isNCR) {
            provinceName = tabProvinceSelect.options[tabProvinceSelect.selectedIndex].text;
        }
        
        const allFieldsSelected = isNCR
            ? (tabRegionSelect.value && tabCitySelect.value && tabBarangaySelect.value)
            : (tabRegionSelect.value && tabProvinceSelect.value && tabCitySelect.value && tabBarangaySelect.value);
        
        if (allFieldsSelected) {
            addressField.value = isNCR
                ? `${regionName}, ${cityName}, ${barangayName}`
                : `${regionName}, ${provinceName}, ${cityName}, ${barangayName}`;
            
            addressTabsDropdown.style.display = 'none';
            // Reset underline position when closed
            setTimeout(() => {
                updateAddressTabsUnderline();
            }, 200);
        }
    });
    
    // Initial underline position
    updateAddressTabsUnderline();
    // On window resize, recalculate
    window.addEventListener('resize', updateAddressTabsUnderline);
}

// Helper functions
function resetAddressForm() {
    const form = document.getElementById('addAddressForm');
    if (form) {
        form.reset();
    }
    const addressTabsDropdown = document.getElementById('addressTabsDropdown');
    if (addressTabsDropdown) {
        addressTabsDropdown.style.display = 'none';
    }
}

// Flag to prevent duplicate submissions
let isSubmittingAddress = false;

function addNewAddress() {
    // Prevent duplicate submissions
    if (isSubmittingAddress) {
        return;
    }
    
    const form = document.getElementById('addAddressForm');
    const formData = new FormData(form);
    
    // Validate phone number
    const phoneNumber = formData.get('phoneNumber');
    if (!phoneNumber) {
        alert('Phone number is required');
        return;
    }
    
    // Remove any non-digit characters for validation
    const cleanPhone = phoneNumber.replace(/\D/g, '');
    
    // Check if phone number is exactly 11 digits
    if (cleanPhone.length !== 11) {
        alert('Phone number must be exactly 11 digits');
        return;
    }
    
    // Check if phone number contains only digits
    if (!/^\d+$/.test(cleanPhone)) {
        alert('Phone number must contain only numbers');
        return;
    }
    
    // Get address field value and parse it
    const addressFieldValue = formData.get('addressField');
    if (!addressFieldValue) {
        alert('Please select a complete address');
        return;
    }
    
    // Parse the address field (format: "Barangay, City, Province, Region")
    const addressParts = addressFieldValue.split(',').map(part => part.trim());
    
    // Extract region, province, city, barangay from the hidden selects
    const regionSelect = document.getElementById('tabRegionSelect');
    const provinceSelect = document.getElementById('tabProvinceSelect');
    const citySelect = document.getElementById('tabCitySelect');
    const barangaySelect = document.getElementById('tabBarangaySelect');
    
    const region = regionSelect.options[regionSelect.selectedIndex]?.text || '';
    const province = provinceSelect.options[provinceSelect.selectedIndex]?.text || '';
    const city = citySelect.options[citySelect.selectedIndex]?.text || '';
    const barangay = barangaySelect.options[barangaySelect.selectedIndex]?.text || '';
    
    // Prepare data for API
    const addressData = {
        recipient_name: formData.get('fullName'),
        phone_number: formData.get('phoneNumber'),
        region: region,
        province: province,
        city: city,
        barangay: barangay,
        street_name: formData.get('streetName') || '',
        house_number: formData.get('houseNumber') || '',
        postal_code: formData.get('postalCode')
    };
    
    // Set flag to prevent duplicate submissions
    isSubmittingAddress = true;
    
    // Send to backend
    fetch('/add_address', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(addressData)
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Close modal and reset form
            document.getElementById('addressModal').style.display = 'none';
            resetAddressForm();
            
            // Save current tab state before reload
            sessionStorage.setItem('checkoutActiveTab', 'address');
            
            // Reload page to show new address
            window.location.reload();
        } else {
            // Reset flag on error
            isSubmittingAddress = false;
            alert(data.message || 'Failed to add address');
        }
    })
    .catch(error => {
        // Reset flag on error
        isSubmittingAddress = false;
        console.error('Error:', error);
        alert('An error occurred while adding address');
    });
}

function addAddressToList(address) {
    const addressList = document.getElementById('otherAddressesList');
    
    const addressDiv = document.createElement('div');
    addressDiv.className = 'address-info selectable-address';
    addressDiv.dataset.addressId = address.id;
    
    addressDiv.innerHTML = `
        <div class="address-details">
            <div class="address-name">${address.name}</div>
            <div class="address-text">${address.address}</div>
            <div class="address-phone">${address.phone}</div>
        </div>
        <div class="address-actions">
            <button class="select-address-btn">Select</button>
        </div>
    `;
    
    // Add event listener to new select button
    const selectBtn = addressDiv.querySelector('.select-address-btn');
    selectBtn.addEventListener('click', function() {
        selectAddress(address.id, addressDiv);
    });
    
    addressList.appendChild(addressDiv);
}

function selectAddress(addressId, addressElement) {
    // Get current default address details
    const defaultAddressSection = document.querySelector('.default-address-section .address-details');
    const selectedAddressDetails = addressElement.querySelector('.address-details');
    const addressList = document.getElementById('otherAddressesList');
    
    if (defaultAddressSection && selectedAddressDetails && addressList) {
        // Store current default address data
        const currentDefaultName = defaultAddressSection.querySelector('.address-name').textContent;
        const currentDefaultText = defaultAddressSection.querySelector('.address-text').textContent;
        const currentDefaultPhone = defaultAddressSection.querySelector('.address-phone').textContent;
        
        // Get selected address data
        const newDefaultName = selectedAddressDetails.querySelector('.address-name').textContent;
        const newDefaultText = selectedAddressDetails.querySelector('.address-text').textContent;
        const newDefaultPhone = selectedAddressDetails.querySelector('.address-phone').textContent;
        
        // Update default address display with selected address
        defaultAddressSection.innerHTML = `
            <div class="address-name">${newDefaultName}</div>
            <div class="address-text">${newDefaultText}</div>
            <div class="address-phone">${newDefaultPhone}</div>
            <div class="address-default-badge">Default</div>
        `;
        
        // Create new selectable address element for the previous default
        const previousDefaultDiv = document.createElement('div');
        previousDefaultDiv.className = 'address-info selectable-address';
        previousDefaultDiv.dataset.addressId = 'prev-default-' + Date.now(); // Generate unique ID
        
        previousDefaultDiv.innerHTML = `
            <div class="address-details">
                <div class="address-name">${currentDefaultName}</div>
                <div class="address-text">${currentDefaultText}</div>
                <div class="address-phone">${currentDefaultPhone}</div>
            </div>
            <div class="address-actions">
                <button class="select-address-btn">Select</button>
            </div>
        `;
        
        // Add event listener to the new select button for previous default
        const prevDefaultSelectBtn = previousDefaultDiv.querySelector('.select-address-btn');
        prevDefaultSelectBtn.addEventListener('click', function() {
            selectAddress(previousDefaultDiv.dataset.addressId, previousDefaultDiv);
        });
        
        // Add previous default to other addresses list (at the beginning)
        addressList.insertBefore(previousDefaultDiv, addressList.firstChild);
        
        // Remove the selected address from other addresses list
        addressElement.remove();
        
        console.log('Address selected as default:', addressId);
        console.log('Previous default moved to other addresses');
    }
}

// Order Success Modal functionality
function initializeOrderSuccessModal() {
    const continueShoppingBtn = document.getElementById('continue-shopping');
    
    if (continueShoppingBtn) {
        continueShoppingBtn.addEventListener('click', function() {
            // Redirect to browse_product page
            window.location.href = '/browse_product';
        });
    }
}

function showOrderSuccessModal() {
    const modal = document.getElementById('order-success-modal');
    const overlay = document.getElementById('order-success-modal-overlay');
    
    if (modal && overlay) {
        overlay.classList.add('show');
        modal.classList.add('active');
        
        console.log('Order placed successfully');
    }
}

function hideOrderSuccessModal() {
    const modal = document.getElementById('order-success-modal');
    const overlay = document.getElementById('order-success-modal-overlay');
    
    if (modal && overlay) {
        overlay.classList.remove('show');
        modal.classList.remove('active');
    }
}

// Voucher functionality
function initializeVouchers() {
    const applyBtns = document.querySelectorAll('.apply-voucher-btn');
    const originalPriceEl = document.getElementById('original-price');
    const discountInfoEl = document.getElementById('discount-info');
    const finalPriceEl = document.getElementById('final-price');
    const quantityInput = document.querySelector('.qty-input');
    
    let appliedVoucher = null;
    // Note: appliedVoucherId is now a global variable
    const basePrice = 1299.00; // Base price per item
    
    function updatePriceDisplay() {
        const quantity = parseInt(quantityInput.value) || 1;
        const totalPrice = basePrice * quantity;
        
        if (appliedVoucher) {
            const discountPercent = parseInt(appliedVoucher.discountPercent) || 0;
            const discountAmount = (totalPrice * discountPercent) / 100;
            const finalPrice = totalPrice - discountAmount;
            
            // Show discount information
            originalPriceEl.classList.add('has-discount');
            originalPriceEl.textContent = `₱ ${totalPrice.toFixed(2)}`;
            discountInfoEl.style.display = 'block';
            discountInfoEl.textContent = `-₱ ${discountAmount.toFixed(2)} (${discountPercent}% OFF)`;
            finalPriceEl.style.display = 'block';
            finalPriceEl.textContent = `₱ ${finalPrice.toFixed(2)}`;
        } else {
            // Reset to original display
            originalPriceEl.classList.remove('has-discount');
            originalPriceEl.textContent = `₱ ${totalPrice.toFixed(2)}`;
            discountInfoEl.style.display = 'none';
            finalPriceEl.style.display = 'none';
        }
    }
    
    applyBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            const voucherType = this.getAttribute('data-voucher-type');
            const discountPercent = this.getAttribute('data-discount-percent');
            const voucherId = this.getAttribute('data-voucher-id');
            
            // If this voucher is already applied, remove it
            if (this.classList.contains('applied')) {
                this.classList.remove('applied');
                this.textContent = 'Apply';
                appliedVoucher = null;
                appliedVoucherId = null;
                
                // Reset global voucher variables
                appliedVoucherType = null;
                currentDiscountPercent = 0;
                
                // Recalculate order total
                calculateOrderTotal();
                
                console.log('Voucher removed:', voucherType);
                return;
            }
            
            // Remove applied state from all other vouchers
            applyBtns.forEach(otherBtn => {
                otherBtn.classList.remove('applied');
                otherBtn.textContent = 'Apply';
            });
            
            // Apply this voucher
            this.classList.add('applied');
            this.textContent = 'Applied';
            appliedVoucher = {
                type: voucherType,
                discountPercent: discountPercent
            };
            appliedVoucherId = voucherId;
            
            // Update global voucher variables
            appliedVoucherType = voucherType;
            currentDiscountPercent = parseInt(discountPercent) || 0;
            
            // Recalculate order total
            calculateOrderTotal();
            
            console.log('Voucher applied:', voucherType, 'ID:', voucherId, 'Discount:', discountPercent + '%');
        });
    });
    
    // Update price when quantity changes
    const decrementBtn = document.querySelector('.qty-btn.decrement');
    const incrementBtn = document.querySelector('.qty-btn.increment');
    
    if (decrementBtn) {
        decrementBtn.addEventListener('click', function() {
            setTimeout(updatePriceDisplay, 10);
        });
    }
    
    if (incrementBtn) {
        incrementBtn.addEventListener('click', function() {
            setTimeout(updatePriceDisplay, 10);
        });
    }
}

// Global variables for order calculation
let currentShippingFee = 49.00;
let currentDiscount = 0;
let currentDiscountPercent = 0;
let appliedVoucherType = null;
let appliedVoucherId = null;

// Calculate and display order total
function calculateOrderTotal() {
    const productSummaries = document.querySelectorAll('.product-summary');
    let subtotal = 0;
    
    productSummaries.forEach(product => {
        const price = parseFloat(product.dataset.price) || 0;
        const quantity = parseInt(product.dataset.quantity) || 0;
        subtotal += price * quantity;
    });
    
    // Calculate shipping (free if free_shipping voucher applied)
    let shippingFee = appliedVoucherType === 'free_shipping' ? 0 : currentShippingFee;
    
    // Calculate discount on subtotal
    let discount = 0;
    if (appliedVoucherType === 'discount' && currentDiscountPercent > 0) {
        discount = (subtotal * currentDiscountPercent) / 100;
    }
    
    // Calculate total: subtotal + shipping - discount
    // Note: 5% commission is deducted from seller's earnings, not added to buyer's total
    let total = subtotal + shippingFee - discount;
    
    // Update the display
    const subtotalElement = document.getElementById('orderSubtotal');
    const shippingElement = document.getElementById('orderShipping');
    const discountElement = document.getElementById('orderDiscount');
    const discountRow = document.getElementById('discountRow');
    const commissionElement = document.getElementById('orderCommission');
    const commissionRow = document.getElementById('commissionRow');
    const totalElement = document.getElementById('orderTotal');
    
    if (subtotalElement) {
        subtotalElement.textContent = '₱' + subtotal.toFixed(2);
    }
    
    if (shippingElement) {
        if (shippingFee === 0 && appliedVoucherType === 'free_shipping') {
            shippingElement.textContent = '-₱0.00';
            shippingElement.style.color = '#059669';
            shippingElement.style.fontWeight = '700';
        } else {
            shippingElement.textContent = '₱' + shippingFee.toFixed(2);
            shippingElement.style.color = '#181818';
            shippingElement.style.fontWeight = '600';
        }
    }
    
    if (discountElement && discountRow) {
        if (discount > 0) {
            discountRow.style.display = 'flex';
            discountElement.textContent = '-₱' + discount.toFixed(2);
        } else {
            discountRow.style.display = 'none';
        }
    }
    
    // Hide commission row (commission is deducted from seller, not charged to buyer)
    if (commissionRow) {
        commissionRow.style.display = 'none';
    }
    
    if (totalElement) {
        totalElement.textContent = '₱' + total.toFixed(2);
    }
}