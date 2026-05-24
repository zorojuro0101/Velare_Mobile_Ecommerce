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

// Address Tabs Modal logic
document.addEventListener('DOMContentLoaded', function() {
    // Underline animation for address tabs (like register page)
    const addressTabsUnderline = document.getElementById('addressTabsUnderline');
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
            window.selectedAddressData = {
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
});

// Edit Address Tabs Modal logic
document.addEventListener('DOMContentLoaded', function() {
    const editAddressTabsUnderline = document.getElementById('editAddressTabsUnderline');
    function updateEditAddressTabsUnderline() {
        const activeTab = document.querySelector('#editAddressTabsDropdown .address-tab.active');
        if (!activeTab || !editAddressTabsUnderline) return;
        const nav = activeTab.parentElement;
        const navRect = nav.getBoundingClientRect();
        const tabRect = activeTab.getBoundingClientRect();
        const left = tabRect.left - navRect.left;
        editAddressTabsUnderline.style.width = tabRect.width + 'px';
        editAddressTabsUnderline.style.transform = `translateX(${left}px)`;
    }
    
    const editAddressField = document.getElementById('editAddressField');
    const editAddressTabsDropdown = document.getElementById('editAddressTabsDropdown');
    const cancelEditTabsBtn = document.getElementById('cancelEditAddressTabsBtn');
    const confirmEditTabsBtn = document.getElementById('confirmEditAddressTabsBtn');
    const editPostalCodeInput = document.getElementById('editPostalCode');
    const editTabRegionSelect = document.getElementById('editTabRegionSelect');
    const editTabProvinceSelect = document.getElementById('editTabProvinceSelect');
    const editTabCitySelect = document.getElementById('editTabCitySelect');
    const editTabBarangaySelect = document.getElementById('editTabBarangaySelect');
    const editAddressTabs = document.querySelectorAll('#editAddressTabsDropdown .address-tab');
    const editTabContents = {
        region: document.getElementById('editRegionTabContent'),
        province: document.getElementById('editProvinceTabContent'),
        city: document.getElementById('editCityTabContent'),
        barangay: document.getElementById('editBarangayTabContent')
    };

    const PSGC_API = 'https://psgc.gitlab.io/api';
    const POSTAL_CODE_DATA_URL = 'https://gist.githubusercontent.com/chrisbjr/784565232f10cba6530856dc7fda367a/raw/ph-zip-codes.json';
    let editPostalCodeDataPromise = null;
    let editPostalCodeDataCache = null;
    const EDIT_STOP_WORDS = new Set(['OF', 'THE', 'CITY', 'MUNICIPALITY', 'PROVINCE', 'BARANGAY', 'DISTRICT']);

    function editNormalizeName(name) {
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

    function editTokensFor(name) {
        const normalized = editNormalizeName(name);
        if (!normalized) return [];
        return normalized
            .split(' ')
            .map(token => token.trim())
            .filter(token => token && !EDIT_STOP_WORDS.has(token));
    }

    async function loadEditPostalCodeData() {
        if (editPostalCodeDataCache) return editPostalCodeDataCache;
        if (!editPostalCodeDataPromise) {
            editPostalCodeDataPromise = fetch(POSTAL_CODE_DATA_URL)
                .then(res => {
                    if (!res.ok) {
                        throw new Error('Failed to load postal code data');
                    }
                    return res.json();
                })
                .then(data => {
                    editPostalCodeDataCache = data.map(entry => {
                        const normalizedArea = editNormalizeName(entry.area);
                        return {
                            ...entry,
                            normalizedArea,
                            tokenSet: new Set(normalizedArea.split(' ').filter(Boolean))
                        };
                    });
                    return editPostalCodeDataCache;
                })
                .catch(err => {
                    console.error('Postal code data load error:', err);
                    editPostalCodeDataPromise = null;
                    throw err;
                });
        }
        return editPostalCodeDataPromise;
    }

    function findEditPostalCodeMatch(data, cityName, provinceName, regionName, barangayName) {
        const cityTokens = editTokensFor(cityName);
        if (!cityTokens.length) return '';
        const provinceTokens = editTokensFor(provinceName);
        const regionTokens = editTokensFor(regionName === 'National Capital Region' ? 'Metro Manila' : regionName);
        const barangayTokens = editTokensFor(barangayName);

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

    async function updateEditPostalCodeForSelection() {
        if (!editPostalCodeInput) return;

        const regionOption = editTabRegionSelect.options[editTabRegionSelect.selectedIndex];
        const provinceOption = editTabProvinceSelect.options[editTabProvinceSelect.selectedIndex];
        const cityOption = editTabCitySelect.options[editTabCitySelect.selectedIndex];
        const barangayOption = editTabBarangaySelect.options[editTabBarangaySelect.selectedIndex];

        const regionName = regionOption ? regionOption.text : '';
        const provinceName = editTabRegionSelect.value === '130000000' ? 'Metro Manila' : (provinceOption ? provinceOption.text : '');
        const cityName = cityOption ? cityOption.text : '';
        const barangayName = barangayOption ? barangayOption.text : '';

        if (!cityName) {
            editPostalCodeInput.value = '';
            return;
        }

        try {
            const postalData = await loadEditPostalCodeData();
            const foundPostalCode = findEditPostalCodeMatch(postalData, cityName, provinceName, regionName, barangayName);
            editPostalCodeInput.value = foundPostalCode || '';
        } catch (err) {
            console.error('Postal code lookup failed:', err);
        }
    }

    async function populateEditSelect(url, select, valueKey, labelKey) {
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

    // Show dropdown below edit address field
    if (editAddressField && editAddressTabsDropdown) {
        editAddressField.addEventListener('click', async function(e) {
            e.stopPropagation();
            editAddressTabsDropdown.style.display = 'block';
            editTabRegionSelect.setAttribute('data-label', 'Region');
            editTabProvinceSelect.setAttribute('data-label', 'Province');
            editTabCitySelect.setAttribute('data-label', 'City/Municipality');
            editTabBarangaySelect.setAttribute('data-label', 'Barangay');
            await populateEditSelect(`${PSGC_API}/regions/`, editTabRegionSelect, 'code', 'name');
            editTabProvinceSelect.innerHTML = '<option value="">Select Province</option>';
            editTabCitySelect.innerHTML = '<option value="">Select City/Municipality</option>';
            editTabBarangaySelect.innerHTML = '<option value="">Select Barangay</option>';
            // Enable all tabs and selects for edit mode
            editAddressTabs.forEach(tab => {
                tab.classList.remove('active');
                tab.disabled = false;
            });
            editTabProvinceSelect.disabled = false;
            editTabCitySelect.disabled = false;
            editTabBarangaySelect.disabled = false;
            editAddressTabs[0].classList.add('active');
            Object.values(editTabContents).forEach((el, i) => {
                el.style.display = i === 0 ? 'block' : 'none';
            });
            confirmEditTabsBtn.disabled = false;
            
            // Pre-populate existing address data
            const existingData = window.editSelectedAddressData;
            if (existingData && existingData.region) {
                // Find and select the region
                const regionCode = Array.from(editTabRegionSelect.options).find(opt => opt.text === existingData.region)?.value;
                if (regionCode) {
                    editTabRegionSelect.value = regionCode;
                    // Trigger region change to populate provinces
                    editTabRegionSelect.dispatchEvent(new Event('change'));
                    
                    // After region loads, select province if not NCR
                    setTimeout(async () => {
                        if (regionCode !== '130000000' && existingData.province) {
                            const provinceCode = Array.from(editTabProvinceSelect.options).find(opt => opt.text === existingData.province)?.value;
                            if (provinceCode) {
                                editTabProvinceSelect.value = provinceCode;
                                editTabProvinceSelect.dispatchEvent(new Event('change'));
                                
                                // After province loads, select city
                                setTimeout(async () => {
                                    if (existingData.city) {
                                        const cityCode = Array.from(editTabCitySelect.options).find(opt => opt.text === existingData.city)?.value;
                                        if (cityCode) {
                                            editTabCitySelect.value = cityCode;
                                            editTabCitySelect.dispatchEvent(new Event('change'));
                                            
                                            // After city loads, select barangay
                                            setTimeout(() => {
                                                if (existingData.barangay) {
                                                    const barangayCode = Array.from(editTabBarangaySelect.options).find(opt => opt.text === existingData.barangay)?.value;
                                                    if (barangayCode) {
                                                        editTabBarangaySelect.value = barangayCode;
                                                    }
                                                }
                                                // Ensure confirm button stays enabled in edit mode
                                                confirmEditTabsBtn.disabled = false;
                                            }, 300);
                                        }
                                    }
                                }, 300);
                            }
                        } else if (regionCode === '130000000' && existingData.city) {
                            // NCR: directly select city
                            const cityCode = Array.from(editTabCitySelect.options).find(opt => opt.text === existingData.city)?.value;
                            if (cityCode) {
                                editTabCitySelect.value = cityCode;
                                editTabCitySelect.dispatchEvent(new Event('change'));
                                
                                // After city loads, select barangay
                                setTimeout(() => {
                                    if (existingData.barangay) {
                                        const barangayCode = Array.from(editTabBarangaySelect.options).find(opt => opt.text === existingData.barangay)?.value;
                                        if (barangayCode) {
                                            editTabBarangaySelect.value = barangayCode;
                                        }
                                    }
                                    // Ensure confirm button stays enabled in edit mode
                                    confirmEditTabsBtn.disabled = false;
                                }, 300);
                            }
                        }
                        // Ensure confirm button stays enabled in edit mode
                        confirmEditTabsBtn.disabled = false;
                    }, 300);
                }
            }
            
            // Final check: ensure confirm button is enabled for edit mode
            setTimeout(() => {
                confirmEditTabsBtn.disabled = false;
            }, 600);
            
            updateEditAddressTabsUnderline();
        });
    }

    if (cancelEditTabsBtn && editAddressTabsDropdown) {
        cancelEditTabsBtn.addEventListener('click', function() {
            editAddressTabsDropdown.style.display = 'none';
        });
    }

    document.addEventListener('click', function(e) {
        if (editAddressTabsDropdown && editAddressTabsDropdown.style.display === 'block') {
            if (!editAddressTabsDropdown.contains(e.target) && e.target !== editAddressField) {
                editAddressTabsDropdown.style.display = 'none';
            }
        }
    });

    editAddressTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            if (tab.disabled) return;
            editAddressTabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            Object.values(editTabContents).forEach(el => el.style.display = 'none');
            editTabContents[tab.dataset.tab].style.display = 'block';
            updateEditAddressTabsUnderline();
        });
    });

    editTabRegionSelect.addEventListener('change', async function() {
        editTabProvinceSelect.innerHTML = '<option value="">Select Province</option>';
        editTabCitySelect.innerHTML = '<option value="">Select City/Municipality</option>';
        editTabBarangaySelect.innerHTML = '<option value="">Select Barangay</option>';
        // In edit mode, keep all tabs and selects enabled
        editTabCitySelect.disabled = false;
        editTabBarangaySelect.disabled = false;
        editAddressTabs[1].disabled = false;
        editAddressTabs[2].disabled = false;
        editAddressTabs[3].disabled = false;
        if (editPostalCodeInput) editPostalCodeInput.value = '';
        if (editTabRegionSelect.value) {
            if (editTabRegionSelect.value === '130000000') {
                if (editAddressTabs[1]) editAddressTabs[1].style.display = 'none';
                editTabProvinceSelect.disabled = false;
                editAddressTabs[1].disabled = false;
                editTabContents['province'].style.display = 'none';
                await populateEditSelect(`${PSGC_API}/regions/130000000/cities-municipalities/`, editTabCitySelect, 'code', 'name');
                editTabCitySelect.disabled = false;
                editAddressTabs[2].disabled = false;
                editAddressTabs.forEach(t => t.classList.remove('active'));
                editAddressTabs[2].classList.add('active');
                Object.values(editTabContents).forEach(el => el.style.display = 'none');
                editTabContents['city'].style.display = 'block';
                updateEditAddressTabsUnderline();
                await updateEditPostalCodeForSelection();
            } else {
                if (editAddressTabs[1]) editAddressTabs[1].style.display = 'flex';
                await populateEditSelect(`${PSGC_API}/regions/${editTabRegionSelect.value}/provinces/`, editTabProvinceSelect, 'code', 'name');
                editTabProvinceSelect.disabled = false;
                editAddressTabs[1].disabled = false;
                editAddressTabs.forEach(t => t.classList.remove('active'));
                editAddressTabs[1].classList.add('active');
                Object.values(editTabContents).forEach(el => el.style.display = 'none');
                editTabContents['province'].style.display = 'block';
                updateEditAddressTabsUnderline();
            }
        } else {
            if (editAddressTabs[1]) editAddressTabs[1].style.display = 'flex';
            editTabProvinceSelect.disabled = false;
        }
    });

    editTabProvinceSelect.addEventListener('change', async function() {
        editTabCitySelect.innerHTML = '<option value="">Select City/Municipality</option>';
        editTabBarangaySelect.innerHTML = '<option value="">Select Barangay</option>';
        // In edit mode, keep all tabs and selects enabled
        editTabCitySelect.disabled = false;
        editTabBarangaySelect.disabled = false;
        editAddressTabs[2].disabled = false;
        editAddressTabs[3].disabled = false;
        if (editPostalCodeInput) editPostalCodeInput.value = '';
        if (editTabProvinceSelect.value) {
            await populateEditSelect(`${PSGC_API}/provinces/${editTabProvinceSelect.value}/cities-municipalities/`, editTabCitySelect, 'code', 'name');
            editTabCitySelect.disabled = false;
            editAddressTabs[2].disabled = false;
            editAddressTabs.forEach(t => t.classList.remove('active'));
            editAddressTabs[2].classList.add('active');
            Object.values(editTabContents).forEach(el => el.style.display = 'none');
            editTabContents['city'].style.display = 'block';
            updateEditAddressTabsUnderline();
        }
    });

    editTabCitySelect.addEventListener('change', async function() {
        editTabBarangaySelect.innerHTML = '<option value="">Select Barangay</option>';
        // In edit mode, keep all tabs and selects enabled
        editTabBarangaySelect.disabled = false;
        editAddressTabs[3].disabled = false;
        if (editPostalCodeInput) editPostalCodeInput.value = '';
        if (editTabCitySelect.value) {
            await populateEditSelect(`${PSGC_API}/cities-municipalities/${editTabCitySelect.value}/barangays/`, editTabBarangaySelect, 'code', 'name');
            editTabBarangaySelect.disabled = false;
            editAddressTabs[3].disabled = false;
            editAddressTabs.forEach(t => t.classList.remove('active'));
            editAddressTabs[3].classList.add('active');
            Object.values(editTabContents).forEach(el => el.style.display = 'none');
            editTabContents['barangay'].style.display = 'block';
            updateEditAddressTabsUnderline();
            await updateEditPostalCodeForSelection();
        }
    });

    editTabBarangaySelect.addEventListener('change', function() {
        // In edit mode, confirm button stays enabled
        confirmEditTabsBtn.disabled = false;
        updateEditPostalCodeForSelection();
    });

    confirmEditTabsBtn.addEventListener('click', function() {
        const isNCR = editTabRegionSelect.value === '130000000';
        const regionName = editTabRegionSelect.options[editTabRegionSelect.selectedIndex].text;
        const cityName = editTabCitySelect.options[editTabCitySelect.selectedIndex].text;
        const barangayName = editTabBarangaySelect.options[editTabBarangaySelect.selectedIndex].text;

        let provinceName = '';
        if (!isNCR) {
            provinceName = editTabProvinceSelect.options[editTabProvinceSelect.selectedIndex].text;
        }

        const allFieldsSelected = isNCR
            ? (editTabRegionSelect.value && editTabCitySelect.value && editTabBarangaySelect.value)
            : (editTabRegionSelect.value && editTabProvinceSelect.value && editTabCitySelect.value && editTabBarangaySelect.value);

        if (allFieldsSelected) {
            editAddressField.value = isNCR
                ? `${regionName}, ${cityName}, ${barangayName}`
                : `${regionName}, ${provinceName}, ${cityName}, ${barangayName}`;
            
            window.editSelectedAddressData = {
                region: regionName,
                province: provinceName,
                city: cityName,
                barangay: barangayName
            };
            
            editAddressTabsDropdown.style.display = 'none';
            setTimeout(() => {
                updateEditAddressTabsUnderline();
            }, 200);
        }
    });

    updateEditAddressTabsUnderline();
    window.addEventListener('resize', updateEditAddressTabsUnderline);
});
// Add Address Modal logic
document.addEventListener('DOMContentLoaded', function() {
    const openModalBtn = document.getElementById('openAddAddressModalBtn');
    const addAddressModal = document.getElementById('addAddressModal');
    const cancelBtn = document.getElementById('cancelAddAddressBtn');
    const form = document.getElementById('addAddressForm');
    
    // Store selected address data
    let selectedAddressData = {
        region: '',
        province: '',
        city: '',
        barangay: ''
    };
    
    // Open modal
    if (openModalBtn && addAddressModal) {
        openModalBtn.addEventListener('click', async function() {
            addAddressModal.style.display = 'flex';
            
            // Pre-fill phone number from user profile (NO API CALL - INSTANT)
            const phoneInput = document.getElementById('phoneNumber');
            if (phoneInput) {
                try {
                    // Get phone number from hidden JSON in template
                    const profileDataEl = document.getElementById('profileData');
                    if (profileDataEl) {
                        const profile = JSON.parse(profileDataEl.textContent);
                        if (profile.phone_number) {
                            phoneInput.value = profile.phone_number;
                        }
                    }
                } catch (error) {
                    console.error('Error loading phone number:', error);
                    // Don't show error, just leave field empty
                }
            }
        });
    }
    // Close modal
    if (cancelBtn && addAddressModal) {
        cancelBtn.addEventListener('click', function() {
            addAddressModal.style.display = 'none';
            form.reset();
            selectedAddressData = { region: '', province: '', city: '', barangay: '' };
        });
    }
    // Close modal on outside click
    if (addAddressModal) {
        addAddressModal.addEventListener('click', function(e) {
            if (e.target === addAddressModal) {
                addAddressModal.style.display = 'none';
                form.reset();
                selectedAddressData = { region: '', province: '', city: '', barangay: '' };
            }
        });
    }
    
    // Form submission
    if (form) {
        form.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const fullName = document.getElementById('fullName').value.trim();
            const phoneNumber = document.getElementById('phoneNumber').value.trim();
            const houseNumber = document.getElementById('houseNumber').value.trim();
            const streetName = document.getElementById('streetName').value.trim();
            const addressField = document.getElementById('addressField').value.trim();
            const postalCode = document.getElementById('postalCode').value.trim();
            
            // Validate all fields are filled
            if (!fullName || !phoneNumber || !addressField || !postalCode) {
                showNotification('Please fill in all fields', 'error');
                return;
            }
            
            // Validate full name (at least 2 characters)
            if (fullName.length < 2) {
                showNotification('Full name must be at least 2 characters', 'error');
                return;
            }
            
            // Validate phone number (must be exactly 11 digits starting with 09)
            const phoneRegex = /^09\d{9}$/;
            if (!phoneRegex.test(phoneNumber)) {
                showNotification('Phone number must be 11 digits starting with 09 (e.g., 09123456789)', 'error');
                return;
            }
            
            // Validate postal code (must be 4 digits)
            const postalRegex = /^\d{4}$/;
            if (!postalRegex.test(postalCode)) {
                showNotification('Postal code must be exactly 4 digits', 'error');
                return;
            }
            
            const submitBtn = form.querySelector('button[type="submit"]');
            const originalText = submitBtn.textContent;
            submitBtn.disabled = true;
            submitBtn.textContent = 'Submitting...';
            
            try {
                const addressData = window.selectedAddressData || { region: '', province: '', city: '', barangay: '' };
                
                // Build complete full_address with house number and street name
                let fullAddressParts = [];
                if (houseNumber) fullAddressParts.push(houseNumber);
                if (streetName) fullAddressParts.push(streetName);
                if (addressField) fullAddressParts.push(addressField);
                const completeFullAddress = fullAddressParts.join(', ');
                
                const response = await fetch('/myAccount_address/add', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        recipient_name: fullName,
                        phone_number: phoneNumber,
                        house_number: houseNumber,
                        street_name: streetName,
                        full_address: completeFullAddress,
                        region: addressData.region,
                        province: addressData.province,
                        city: addressData.city,
                        barangay: addressData.barangay,
                        postal_code: postalCode,
                        is_default: false
                    })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showNotification(data.message, 'success');
                    addAddressModal.style.display = 'none';
                    form.reset();
                    selectedAddressData = { region: '', province: '', city: '', barangay: '' };
                    // Reload page to show new address
                    setTimeout(() => {
                        window.location.reload();
                    }, 1500);
                } else {
                    showNotification(data.message || 'Failed to add address', 'error');
                }
            } catch (error) {
                console.error('Error:', error);
                showNotification('An error occurred. Please try again.', 'error');
            } finally {
                submitBtn.disabled = false;
                submitBtn.textContent = originalText;
            }
        });
    }
    
    // Edit address
    document.addEventListener('click', function(e) {
        if (e.target.classList.contains('edit-address-link')) {
            const addressId = e.target.getAttribute('data-address-id');
            const addressPlaceholder = document.querySelector(`.address-placeholder[data-address-id="${addressId}"]`);
            
            if (addressPlaceholder) {
                // Get address data from data attributes
                const recipientName = addressPlaceholder.getAttribute('data-recipient-name');
                const phoneNumber = addressPlaceholder.getAttribute('data-phone-number');
                const houseNumber = addressPlaceholder.getAttribute('data-house-number');
                const streetName = addressPlaceholder.getAttribute('data-street-name');
                const fullAddress = addressPlaceholder.getAttribute('data-full-address');
                const region = addressPlaceholder.getAttribute('data-region');
                const province = addressPlaceholder.getAttribute('data-province');
                const city = addressPlaceholder.getAttribute('data-city');
                const barangay = addressPlaceholder.getAttribute('data-barangay');
                const postalCode = addressPlaceholder.getAttribute('data-postal-code');
                
                // Fill edit form
                document.getElementById('editAddressId').value = addressId;
                document.getElementById('editFullName').value = recipientName;
                document.getElementById('editPhoneNumber').value = phoneNumber;
                document.getElementById('editHouseNumber').value = houseNumber || '';
                document.getElementById('editStreetName').value = streetName || '';
                document.getElementById('editAddressField').value = fullAddress;
                document.getElementById('editPostalCode').value = postalCode;
                
                // Store edit address data
                window.editSelectedAddressData = {
                    region: region,
                    province: province,
                    city: city,
                    barangay: barangay
                };
                
                // Show edit modal
                document.getElementById('editAddressModal').style.display = 'flex';
            }
        }
    });
    
    // Close edit modal
    const editModal = document.getElementById('editAddressModal');
    const cancelEditBtn = document.getElementById('cancelEditAddressBtn');
    const editForm = document.getElementById('editAddressForm');
    
    if (cancelEditBtn && editModal) {
        cancelEditBtn.addEventListener('click', function() {
            editModal.style.display = 'none';
            editForm.reset();
            window.editSelectedAddressData = { region: '', province: '', city: '', barangay: '' };
        });
    }
    
    if (editModal) {
        editModal.addEventListener('click', function(e) {
            if (e.target === editModal) {
                editModal.style.display = 'none';
                editForm.reset();
                window.editSelectedAddressData = { region: '', province: '', city: '', barangay: '' };
            }
        });
    }
    
    // Edit form submission
    let isSubmitting = false;
    if (editForm) {
        editForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            // Prevent double submission
            if (isSubmitting) {
                console.log('[EDIT_ADDRESS] Already submitting, ignoring duplicate request');
                return;
            }
            
            const addressId = document.getElementById('editAddressId').value;
            const fullName = document.getElementById('editFullName').value.trim();
            const phoneNumber = document.getElementById('editPhoneNumber').value.trim();
            const houseNumber = document.getElementById('editHouseNumber').value.trim();
            const streetName = document.getElementById('editStreetName').value.trim();
            const addressField = document.getElementById('editAddressField').value.trim();
            const postalCode = document.getElementById('editPostalCode').value.trim();
            
            // Validate all fields are filled
            if (!fullName || !phoneNumber || !addressField || !postalCode) {
                showNotification('Please fill in all fields', 'error');
                return;
            }
            
            // Validate full name (at least 2 characters)
            if (fullName.length < 2) {
                showNotification('Full name must be at least 2 characters', 'error');
                return;
            }
            
            // Validate phone number (must be exactly 11 digits starting with 09)
            const phoneRegex = /^09\d{9}$/;
            if (!phoneRegex.test(phoneNumber)) {
                showNotification('Phone number must be 11 digits starting with 09 (e.g., 09123456789)', 'error');
                return;
            }
            
            // Validate postal code (must be 4 digits)
            const postalRegex = /^\d{4}$/;
            if (!postalRegex.test(postalCode)) {
                showNotification('Postal code must be exactly 4 digits', 'error');
                return;
            }
            
            const submitBtn = editForm.querySelector('button[type="submit"]');
            const originalText = submitBtn.textContent;
            submitBtn.disabled = true;
            submitBtn.textContent = 'Updating...';
            isSubmitting = true;
            
            console.log('[EDIT_ADDRESS] Submitting update for address_id:', addressId);
            
            try {
                const addressData = window.editSelectedAddressData || { region: '', province: '', city: '', barangay: '' };
                
                // Build complete full_address with house number, street name, and location
                // addressField should only contain "Region, Province, City, Barangay" (from the dropdown)
                // NOT the full address with house/street
                const isNCR = addressData.region === 'NCR';
                const locationPart = isNCR
                    ? `${addressData.region}, ${addressData.city}, ${addressData.barangay}`
                    : `${addressData.region}, ${addressData.province}, ${addressData.city}, ${addressData.barangay}`;
                
                let fullAddressParts = [];
                if (houseNumber) fullAddressParts.push(houseNumber);
                if (streetName) fullAddressParts.push(streetName);
                fullAddressParts.push(locationPart);
                const completeFullAddress = fullAddressParts.join(', ');
                
                const response = await fetch(`/myAccount_address/update/${addressId}`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        recipient_name: fullName,
                        phone_number: phoneNumber,
                        house_number: houseNumber,
                        street_name: streetName,
                        full_address: completeFullAddress,
                        region: addressData.region,
                        province: addressData.province,
                        city: addressData.city,
                        barangay: addressData.barangay,
                        postal_code: postalCode
                    })
                });
                
                const data = await response.json();
                
                console.log('[EDIT_ADDRESS] Response:', data);
                
                if (data.success) {
                    showNotification(data.message, 'success');
                    editModal.style.display = 'none';
                    editForm.reset();
                    window.editSelectedAddressData = { region: '', province: '', city: '', barangay: '' };
                    // Reload page to show updated address
                    console.log('[EDIT_ADDRESS] Reloading page in 1.5 seconds...');
                    setTimeout(() => {
                        window.location.reload();
                    }, 1500);
                } else {
                    showNotification(data.message || 'Failed to update address', 'error');
                    isSubmitting = false;
                }
            } catch (error) {
                console.error('[EDIT_ADDRESS] Error:', error);
                showNotification('An error occurred. Please try again.', 'error');
                isSubmitting = false;
            } finally {
                if (!isSubmitting) {
                    submitBtn.disabled = false;
                    submitBtn.textContent = originalText;
                }
            }
        });
    }
    
    // Delete address
    document.addEventListener('click', async function(e) {
        if (e.target.classList.contains('delete-address-link')) {
            e.preventDefault();
            const addressId = e.target.getAttribute('data-address-id');
            
            // Check if confirmation already exists
            const existingConfirm = document.querySelector('.delete-confirm-popup');
            if (existingConfirm) {
                existingConfirm.remove();
            }
            
            // Create confirmation popup
            const confirmPopup = document.createElement('div');
            confirmPopup.className = 'delete-confirm-popup';
            confirmPopup.innerHTML = `
                <div class="confirm-text">Delete this address?</div>
                <div class="confirm-buttons">
                    <button class="confirm-yes">Yes</button>
                    <button class="confirm-no">No</button>
                </div>
            `;
            
            // Position it to the left of the delete link
            const linkRect = e.target.getBoundingClientRect();
            confirmPopup.style.position = 'fixed';
            confirmPopup.style.top = `${linkRect.top}px`;
            confirmPopup.style.right = `${window.innerWidth - linkRect.left + 10}px`;
            
            document.body.appendChild(confirmPopup);
            
            // Handle Yes button
            confirmPopup.querySelector('.confirm-yes').addEventListener('click', async function() {
                confirmPopup.remove();
                
                try {
                    const response = await fetch(`/myAccount_address/delete/${addressId}`, {
                        method: 'DELETE'
                    });
                    
                    const data = await response.json();
                    
                    if (data.success) {
                        showNotification(data.message, 'success');
                        setTimeout(() => {
                            window.location.reload();
                        }, 1500);
                    } else {
                        showNotification(data.message || 'Failed to delete address', 'error');
                    }
                } catch (error) {
                    console.error('Error:', error);
                    showNotification('An error occurred. Please try again.', 'error');
                }
            });
            
            // Handle No button
            confirmPopup.querySelector('.confirm-no').addEventListener('click', function() {
                confirmPopup.remove();
            });
            
            // Close popup when clicking outside
            setTimeout(() => {
                document.addEventListener('click', function closePopup(event) {
                    if (!confirmPopup.contains(event.target) && event.target !== e.target) {
                        confirmPopup.remove();
                        document.removeEventListener('click', closePopup);
                    }
                });
            }, 100);
        }
    });
    
    // Set default address
    document.addEventListener('click', async function(e) {
        if (e.target.classList.contains('set-default-address-btn')) {
            const addressId = e.target.getAttribute('data-address-id');
            
            const btn = e.target;
            const originalText = btn.textContent;
            btn.disabled = true;
            btn.textContent = 'Setting...';
            
            try {
                const response = await fetch(`/myAccount_address/set_default/${addressId}`, {
                    method: 'POST'
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showNotification(data.message, 'success');
                    
                    // Remove default-address class from all addresses
                    document.querySelectorAll('.address-placeholder').forEach(addr => {
                        addr.classList.remove('default-address');
                    });
                    
                    // Add default-address class to the new default
                    const newDefaultAddress = document.querySelector(`.address-placeholder[data-address-id="${addressId}"]`);
                    if (newDefaultAddress) {
                        newDefaultAddress.classList.add('default-address');
                    }
                    
                    setTimeout(() => {
                        window.location.reload();
                    }, 1500);
                } else {
                    showNotification(data.message || 'Failed to set default address', 'error');
                    btn.disabled = false;
                    btn.textContent = originalText;
                }
            } catch (error) {
                console.error('Error:', error);
                showNotification('An error occurred. Please try again.', 'error');
                btn.disabled = false;
                btn.textContent = originalText;
            }
        }
    });

});
document.addEventListener('DOMContentLoaded', function() {
    // Sidebar hamburger functionality
    const hamburgerBtn = document.getElementById('hamburgerBtn');
    const sideMenu = document.querySelector('.side-menu');
    const overlay = document.querySelector('.side-menu-overlay');
    if (hamburgerBtn && sideMenu && overlay) {
        hamburgerBtn.addEventListener('click', function() {
            const isOpen = sideMenu.classList.toggle('open');
            overlay.classList.toggle('show', isOpen);
            hamburgerBtn.classList.toggle('open', isOpen);
        });
        overlay.addEventListener('click', function() {
            sideMenu.classList.remove('open');
            overlay.classList.remove('show');
            hamburgerBtn.classList.remove('open');
        });
    }

    // Main tab/sub-tab logic without animation
    const mainTabs = document.querySelectorAll('.main-tab');
    const myAccountTab = document.getElementById('myAccountTab');
    const myAccountSubTabs = document.getElementById('myAccountSubTabs');

    // Open My Account by default
    if (myAccountTab && myAccountSubTabs) {
        myAccountTab.classList.add('active');
        myAccountSubTabs.classList.add('open');
        myAccountSubTabs.style.display = 'flex';
    }

    mainTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            // Remove active from all main tabs
            mainTabs.forEach(t => t.classList.remove('active'));

            // Handle sub-tabs visibility
            if (myAccountSubTabs) {
                if (tab !== myAccountTab) {
                    // Hide sub-tabs immediately
                    myAccountSubTabs.classList.remove('open');
                    myAccountSubTabs.style.display = 'none';
                } else {
                    // Show sub-tabs immediately
                    myAccountSubTabs.style.display = 'flex';
                    myAccountSubTabs.classList.add('open');
                }
            }

            // Set active tab
            tab.classList.add('active');
        });
    });
});
