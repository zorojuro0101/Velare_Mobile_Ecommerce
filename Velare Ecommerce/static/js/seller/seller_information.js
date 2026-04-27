// Seller Information Page JavaScript

document.addEventListener('DOMContentLoaded', function() {
    console.log('Seller Information page loaded');
    
    // Address Tabs Dropdown Functionality with PSGC API
    const addressField = document.getElementById('sellerAddressField');
    const addressTabsDropdown = document.getElementById('sellerAddressTabsDropdown');
    const cancelTabsBtn = document.getElementById('cancelSellerAddressTabsBtn');
    const confirmTabsBtn = document.getElementById('confirmSellerAddressTabsBtn');
    const postalCodeInput = document.getElementById('sellerPostalCode');
    
    const tabRegionSelect = document.getElementById('sellerTabRegionSelect');
    const tabProvinceSelect = document.getElementById('sellerTabProvinceSelect');
    const tabCitySelect = document.getElementById('sellerTabCitySelect');
    const tabBarangaySelect = document.getElementById('sellerTabBarangaySelect');
    
    const addressTabs = document.querySelectorAll('#sellerAddressTabsDropdown .address-tab');
    const addressTabsUnderline = document.getElementById('sellerAddressTabsUnderline');
    
    const tabContents = {
        region: document.getElementById('sellerRegionTabContent'),
        province: document.getElementById('sellerProvinceTabContent'),
        city: document.getElementById('sellerCityTabContent'),
        barangay: document.getElementById('sellerBarangayTabContent')
    };
    
    // PSGC API endpoints
    const PSGC_API = 'https://psgc.gitlab.io/api';
    const POSTAL_CODE_DATA_URL = 'https://gist.githubusercontent.com/chrisbjr/784565232f10cba6530856dc7fda367a/raw/ph-zip-codes.json';
    let postalCodeDataPromise = null;
    let postalCodeDataCache = null;
    const STOP_WORDS = new Set(['OF', 'THE', 'CITY', 'MUNICIPALITY', 'PROVINCE', 'BARANGAY', 'DISTRICT']);
    
    let selectedAddressData = {
        region: '',
        province: '',
        city: '',
        barangay: ''
    };
    
    // Update underline position
    function updateAddressTabsUnderline() {
        const activeTab = document.querySelector('#sellerAddressTabsDropdown .address-tab.active');
        if (!activeTab || !addressTabsUnderline) return;
        const nav = activeTab.parentElement;
        const navRect = nav.getBoundingClientRect();
        const tabRect = activeTab.getBoundingClientRect();
        const left = tabRect.left - navRect.left;
        addressTabsUnderline.style.width = tabRect.width + 'px';
        addressTabsUnderline.style.transform = `translateX(${left}px)`;
    }
    
    // Postal code helper functions
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
                    if (!res.ok) throw new Error('Failed to load postal code data');
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
            tabRegionSelect.setAttribute('data-label', 'Region');
            tabProvinceSelect.setAttribute('data-label', 'Province');
            tabCitySelect.setAttribute('data-label', 'City/Municipality');
            tabBarangaySelect.setAttribute('data-label', 'Barangay');
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
            
            // Store the selected address data for form submission
            selectedAddressData = {
                region: regionName,
                province: provinceName,
                city: cityName,
                barangay: barangayName
            };
            
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
    
    // Phone Number 'Add' link logic (show input, hide link)
    const addPhoneLink = document.getElementById('addPhoneLink');
    const phoneInput = document.getElementById('sellerPhoneNumber');
    if (addPhoneLink && phoneInput) {
        addPhoneLink.addEventListener('click', function() {
            addPhoneLink.style.display = 'none';
            phoneInput.style.display = '';
            phoneInput.focus();
        });
    }
    
    // File Upload Functionality
    const pictureInput = document.getElementById('sellerPictureInput');
    const pictureContainer = document.querySelector('.profile-picture-container');
    const uploadPlaceholder = document.querySelector('.upload-placeholder');
    const uploadOverlay = document.querySelector('.upload-overlay');
    
    console.log('🖼️ Picture input element:', pictureInput);
    console.log('📦 Picture container:', pictureContainer);
    
    if (pictureContainer && pictureInput) {
        pictureContainer.addEventListener('click', function() {
            console.log('📸 Picture container clicked, triggering file input');
            pictureInput.click();
        });
        
        pictureInput.addEventListener('change', function(e) {
            const file = e.target.files[0];
            console.log('📁 File selected:', file ? file.name : 'No file');
            if (file) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    // Create image element
                    const img = document.createElement('img');
                    img.src = e.target.result;
                    img.style.width = '100%';
                    img.style.height = '100%';
                    img.style.objectFit = 'cover';
                    
                    // Clear container and add image
                    pictureContainer.innerHTML = '';
                    pictureContainer.appendChild(img);
                    
                    // Add overlay for changing image
                    const newOverlay = document.createElement('div');
                    newOverlay.className = 'upload-overlay';
                    newOverlay.innerHTML = '<i class="bi bi-camera"></i><span>Change Logo</span>';
                    pictureContainer.appendChild(newOverlay);
                    
                    // Add has-image class
                    pictureContainer.classList.add('has-image');
                    
                    console.log('✅ Image preview updated');
                };
                reader.readAsDataURL(file);
            }
        });
    } else {
        console.error('❌ Picture container or input not found!');
    }
    
    // Populate address field on page load if data exists
    const regionInput = document.getElementById('sellerRegion');
    const provinceInput = document.getElementById('sellerProvince');
    const cityInput = document.getElementById('sellerCity');
    const barangayInput = document.getElementById('sellerBarangay');
    
    if (regionInput && regionInput.value && cityInput && cityInput.value && barangayInput && barangayInput.value) {
        const isNCR = !provinceInput.value;
        if (isNCR) {
            addressField.value = `${regionInput.value}, ${cityInput.value}, ${barangayInput.value}`;
        } else {
            addressField.value = `${regionInput.value}, ${provinceInput.value}, ${cityInput.value}, ${barangayInput.value}`;
        }
        
        // Store in selectedAddressData
        selectedAddressData = {
            region: regionInput.value,
            province: provinceInput.value,
            city: cityInput.value,
            barangay: barangayInput.value
        };
    }
    
    // Seller Information Form Submission
    const sellerForm = document.getElementById('sellerInfoForm');
    if (sellerForm) {
        sellerForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            // Update hidden inputs with selected address data
            if (selectedAddressData.region) {
                document.getElementById('sellerRegion').value = selectedAddressData.region;
                document.getElementById('sellerProvince').value = selectedAddressData.province || '';
                document.getElementById('sellerCity').value = selectedAddressData.city;
                document.getElementById('sellerBarangay').value = selectedAddressData.barangay;
            }
            
            // Get form data
            const formData = new FormData(sellerForm);
            
            // Log form data contents
            console.log('📤 Seller Info Form data being sent:');
            for (let [key, value] of formData.entries()) {
                if (value instanceof File) {
                    console.log(`   ${key}: ${value.name} (${value.size} bytes)`);
                } else {
                    console.log(`   ${key}: ${value}`);
                }
            }
            
            try {
                const response = await fetch('/seller/information/save', {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (result.success) {
                    alert('Seller information saved successfully!');
                    // Optionally reload the page to show updated data
                    window.location.reload();
                } else {
                    alert('Error: ' + result.message);
                }
            } catch (error) {
                console.error('Error saving seller information:', error);
                alert('An error occurred while saving. Please try again.');
            }
        });
    }
    
    // Documents Form Submission
    const documentsForm = document.getElementById('documentsForm');
    if (documentsForm) {
        documentsForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            // Get form data
            const formData = new FormData(documentsForm);
            
            // Log form data contents
            console.log('📤 Documents Form data being sent:');
            for (let [key, value] of formData.entries()) {
                if (value instanceof File) {
                    console.log(`   ${key}: ${value.name} (${value.size} bytes)`);
                } else {
                    console.log(`   ${key}: ${value}`);
                }
            }
            
            try {
                const response = await fetch('/seller/documents/save', {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (result.success) {
                    alert('Documents submitted successfully!');
                    // Optionally reload the page to show updated data
                    window.location.reload();
                } else {
                    alert('Error: ' + result.message);
                }
            } catch (error) {
                console.error('Error saving documents:', error);
                alert('An error occurred while saving documents. Please try again.');
            }
        });
    }
});

    // ID Image Upload Functionality
    const idImageInput = document.getElementById('idImageInput');
    const idImageContainer = document.getElementById('idImageContainer');
    
    if (idImageContainer && idImageInput) {
        idImageContainer.addEventListener('click', function() {
            console.log('📸 ID Image container clicked');
            idImageInput.click();
        });
        
        idImageInput.addEventListener('change', function(e) {
            const file = e.target.files[0];
            console.log('📁 ID Image file selected:', file ? file.name : 'No file');
            if (file) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    // Create image element
                    const img = document.createElement('img');
                    img.src = e.target.result;
                    img.id = 'idImagePreview';
                    img.style.width = '100%';
                    img.style.height = '100%';
                    img.style.objectFit = 'cover';
                    
                    // Clear container and add image
                    idImageContainer.innerHTML = '';
                    idImageContainer.appendChild(img);
                    
                    // Add overlay for changing image
                    const newOverlay = document.createElement('div');
                    newOverlay.className = 'upload-overlay';
                    newOverlay.innerHTML = '<i class="bi bi-camera"></i><span>Change ID</span>';
                    idImageContainer.appendChild(newOverlay);
                    
                    // Add has-image class
                    idImageContainer.classList.add('has-image');
                    
                    console.log('✅ ID Image preview updated');
                };
                reader.readAsDataURL(file);
            }
        });
    }
    
    // Business Permit Upload Functionality
    const businessPermitInput = document.getElementById('businessPermitInput');
    const businessPermitContainer = document.getElementById('businessPermitContainer');
    
    if (businessPermitContainer && businessPermitInput) {
        businessPermitContainer.addEventListener('click', function() {
            console.log('📸 Business Permit container clicked');
            businessPermitInput.click();
        });
        
        businessPermitInput.addEventListener('change', function(e) {
            const file = e.target.files[0];
            console.log('📁 Business Permit file selected:', file ? file.name : 'No file');
            if (file) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    // Create image element
                    const img = document.createElement('img');
                    img.src = e.target.result;
                    img.id = 'businessPermitPreview';
                    img.style.width = '100%';
                    img.style.height = '100%';
                    img.style.objectFit = 'cover';
                    
                    // Clear container and add image
                    businessPermitContainer.innerHTML = '';
                    businessPermitContainer.appendChild(img);
                    
                    // Add overlay for changing image
                    const newOverlay = document.createElement('div');
                    newOverlay.className = 'upload-overlay';
                    newOverlay.innerHTML = '<i class="bi bi-camera"></i><span>Change Permit</span>';
                    businessPermitContainer.appendChild(newOverlay);
                    
                    // Add has-image class
                    businessPermitContainer.classList.add('has-image');
                    
                    console.log('✅ Business Permit preview updated');
                };
                reader.readAsDataURL(file);
            }
        });
    }
    
    // ID Type Select - Update display text when changed
    const idTypeSelect = document.getElementById('idTypeSelect');
    const idTypeText = document.getElementById('idTypeText');
    
    if (idTypeSelect && idTypeText) {
        idTypeSelect.addEventListener('change', function() {
            const selectedValue = this.value;
            idTypeText.textContent = selectedValue || 'Not specified';
            console.log('✅ ID Type updated:', selectedValue);
        });
    }
