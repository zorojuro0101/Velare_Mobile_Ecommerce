// Address Tabs functionality for Register page - Auto-advance to Other Info
document.addEventListener('DOMContentLoaded', function() {
    const PSGC_API = 'https://psgc.gitlab.io/api';
    const POSTAL_CODE_DATA_URL = 'https://gist.githubusercontent.com/chrisbjr/784565232f10cba6530856dc7fda367a/raw/ph-zip-codes.json';
    let postalCodeDataCache = null;
    const STOP_WORDS = new Set(['OF', 'THE', 'CITY', 'MUNICIPALITY', 'PROVINCE', 'BARANGAY', 'DISTRICT']);

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
        try {
            const res = await fetch(POSTAL_CODE_DATA_URL);
            if (!res.ok) throw new Error('Failed to load postal code data');
            const data = await res.json();
            postalCodeDataCache = data.map(entry => {
                const normalizedArea = normalizeName(entry.area);
                return {
                    ...entry,
                    normalizedArea,
                    tokenSet: new Set(normalizedArea.split(' ').filter(Boolean))
                };
            });
            return postalCodeDataCache;
        } catch (err) {
            console.error('Postal code data load error:', err);
            return [];
        }
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

    // Helper function to populate select
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

    // Initialize address dropdown for each user type (Buyer, Seller, Rider)
    function initializeAddressDropdown(prefix) {
        const addressField = document.getElementById(`${prefix}_address_field`);
        const addressTabsDropdown = document.getElementById(`${prefix}AddressTabsDropdown`);
        const cancelTabsBtn = document.getElementById(`cancel${prefix.charAt(0).toUpperCase() + prefix.slice(1)}AddressTabsBtn`);
        const confirmTabsBtn = document.getElementById(`confirm${prefix.charAt(0).toUpperCase() + prefix.slice(1)}AddressTabsBtn`);
        const tabRegionSelect = document.getElementById(`${prefix}TabRegionSelect`);
        const tabProvinceSelect = document.getElementById(`${prefix}TabProvinceSelect`);
        const tabCitySelect = document.getElementById(`${prefix}TabCitySelect`);
        const tabBarangaySelect = document.getElementById(`${prefix}TabBarangaySelect`);
        const tabPhoneInput = document.getElementById(`${prefix}TabPhoneInput`);
        const tabStreetInput = document.getElementById(`${prefix}TabStreetInput`);
        const tabHouseInput = document.getElementById(`${prefix}TabHouseInput`);
        const tabPostalInput = document.getElementById(`${prefix}TabPostalInput`);
        const addressTabs = addressTabsDropdown.querySelectorAll('.address-tab');
        const addressTabsUnderline = document.getElementById(`${prefix}AddressTabsUnderline`);
        const tabContents = {
            region: document.getElementById(`${prefix}RegionTabContent`),
            province: document.getElementById(`${prefix}ProvinceTabContent`),
            city: document.getElementById(`${prefix}CityTabContent`),
            barangay: document.getElementById(`${prefix}BarangayTabContent`),
            other: document.getElementById(`${prefix}OtherTabContent`)
        };

        // Update postal code based on selection
        async function updatePostalCode() {
            if (!tabPostalInput) return;

            const regionOption = tabRegionSelect.options[tabRegionSelect.selectedIndex];
            const provinceOption = tabProvinceSelect.options[tabProvinceSelect.selectedIndex];
            const cityOption = tabCitySelect.options[tabCitySelect.selectedIndex];
            const barangayOption = tabBarangaySelect.options[tabBarangaySelect.selectedIndex];

            const regionName = regionOption ? regionOption.text : '';
            const provinceName = tabRegionSelect.value === '130000000' ? 'Metro Manila' : (provinceOption ? provinceOption.text : '');
            const cityName = cityOption ? cityOption.text : '';
            const barangayName = barangayOption ? barangayOption.text : '';

            if (!cityName) {
                tabPostalInput.value = '';
                return;
            }

            try {
                const postalData = await loadPostalCodeData();
                const foundPostalCode = findPostalCodeMatch(postalData, cityName, provinceName, regionName, barangayName);
                tabPostalInput.value = foundPostalCode || '';
            } catch (err) {
                console.error('Postal code lookup failed:', err);
            }
        }

        // Check if all required fields are filled
        function checkRequiredFields() {
            if (tabPhoneInput && tabStreetInput && tabHouseInput) {
                const phoneValue = tabPhoneInput.value.trim();
                const phoneValid = phoneValue.length === 11 && /^\d{11}$/.test(phoneValue);
                const streetFilled = tabStreetInput.value.trim() !== '';
                const houseFilled = tabHouseInput.value.trim() !== '';
                confirmTabsBtn.disabled = !(phoneValid && streetFilled && houseFilled);
            }
        }

        // Update underline position
        function updateAddressTabsUnderline() {
            const activeTab = addressTabsDropdown.querySelector('.address-tab.active');
            if (!activeTab || !addressTabsUnderline) return;
            const nav = activeTab.parentElement;
            const navRect = nav.getBoundingClientRect();
            const tabRect = activeTab.getBoundingClientRect();
            const left = tabRect.left - navRect.left;
            addressTabsUnderline.style.width = tabRect.width + 'px';
            addressTabsUnderline.style.transform = `translateX(${left}px)`;
        }

        // Show dropdown when address field is clicked
        if (addressField && addressTabsDropdown) {
            addressField.addEventListener('click', async function(e) {
                e.stopPropagation();
                
                // Position dropdown above the address field and center it
                const rect = addressField.getBoundingClientRect();
                const dropdownWidth = 500; // Width of dropdown
                const fieldCenter = rect.left + (rect.width / 2);
                const dropdownLeft = fieldCenter - (dropdownWidth / 2);
                
                addressTabsDropdown.style.bottom = `${window.innerHeight - rect.top + window.scrollY + 6}px`;
                addressTabsDropdown.style.left = `${dropdownLeft + window.scrollX}px`;
                addressTabsDropdown.style.top = 'auto';
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
                if (tabPhoneInput) tabPhoneInput.value = '';
                if (tabStreetInput) tabStreetInput.value = '';
                if (tabHouseInput) tabHouseInput.value = '';
                if (tabPostalInput) tabPostalInput.value = '';
                
                // Reset tabs state
                addressTabs.forEach((tab, index) => {
                    tab.classList.remove('active');
                    tab.disabled = index !== 0;
                });
                addressTabs[0].classList.add('active');
                Object.values(tabContents).forEach((el, i) => {
                    if (el) el.style.display = i === 0 ? 'block' : 'none';
                });
                
                // Reset confirm button
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
                Object.values(tabContents).forEach(el => {
                    if (el) el.style.display = 'none';
                });
                if (tabContents[tab.dataset.tab]) {
                    tabContents[tab.dataset.tab].style.display = 'block';
                }
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
            addressTabs[4].disabled = true;
            if (tabPostalInput) tabPostalInput.value = '';
            
            if (tabRegionSelect.value) {
                // NCR: hide province tab, go straight to city
                if (tabRegionSelect.value === '130000000') {
                    if (addressTabs[1]) addressTabs[1].style.display = 'none';
                    tabProvinceSelect.disabled = true;
                    addressTabs[1].disabled = true;
                    if (tabContents['province']) tabContents['province'].style.display = 'none';
                    // Populate cities for NCR
                    await populateSelect(`${PSGC_API}/regions/130000000/cities-municipalities/`, tabCitySelect, 'code', 'name');
                    tabCitySelect.disabled = false;
                    addressTabs[2].disabled = false;
                    // Auto move to City tab
                    addressTabs.forEach(t => t.classList.remove('active'));
                    addressTabs[2].classList.add('active');
                    Object.values(tabContents).forEach(el => {
                        if (el) el.style.display = 'none';
                    });
                    if (tabContents['city']) tabContents['city'].style.display = 'block';
                    updateAddressTabsUnderline();
                    await updatePostalCode();
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
                    Object.values(tabContents).forEach(el => {
                        if (el) el.style.display = 'none';
                    });
                    if (tabContents['province']) tabContents['province'].style.display = 'block';
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
            addressTabs[4].disabled = true;
            if (tabPostalInput) tabPostalInput.value = '';
            
            if (tabProvinceSelect.value) {
                await populateSelect(`${PSGC_API}/provinces/${tabProvinceSelect.value}/cities-municipalities/`, tabCitySelect, 'code', 'name');
                tabCitySelect.disabled = false;
                addressTabs[2].disabled = false;
                // Auto move to City tab
                addressTabs.forEach(t => t.classList.remove('active'));
                addressTabs[2].classList.add('active');
                Object.values(tabContents).forEach(el => {
                    if (el) el.style.display = 'none';
                });
                if (tabContents['city']) tabContents['city'].style.display = 'block';
                updateAddressTabsUnderline();
            }
        });

        // City select
        tabCitySelect.addEventListener('change', async function() {
            tabBarangaySelect.innerHTML = '<option value="">Select Barangay</option>';
            tabBarangaySelect.disabled = true;
            addressTabs[3].disabled = true;
            addressTabs[4].disabled = true;
            if (tabPostalInput) tabPostalInput.value = '';
            
            if (tabCitySelect.value) {
                await populateSelect(`${PSGC_API}/cities-municipalities/${tabCitySelect.value}/barangays/`, tabBarangaySelect, 'code', 'name');
                tabBarangaySelect.disabled = false;
                addressTabs[3].disabled = false;
                // Auto move to Barangay tab
                addressTabs.forEach(t => t.classList.remove('active'));
                addressTabs[3].classList.add('active');
                Object.values(tabContents).forEach(el => {
                    if (el) el.style.display = 'none';
                });
                if (tabContents['barangay']) tabContents['barangay'].style.display = 'block';
                updateAddressTabsUnderline();
                await updatePostalCode();
            }
        });

        // Barangay select - AUTO ADVANCE to Other Info tab
        tabBarangaySelect.addEventListener('change', async function() {
            if (tabBarangaySelect.value) {
                // Enable Other Info tab
                addressTabs[4].disabled = false;
                await updatePostalCode();
                
                // AUTO ADVANCE to Other Info tab
                setTimeout(() => {
                    addressTabs.forEach(t => t.classList.remove('active'));
                    addressTabs[4].classList.add('active');
                    Object.values(tabContents).forEach(el => {
                        if (el) el.style.display = 'none';
                    });
                    if (tabContents['other']) tabContents['other'].style.display = 'block';
                    updateAddressTabsUnderline();
                    
                    // Focus on phone number input
                    if (tabPhoneInput) tabPhoneInput.focus();
                }, 300);
            } else {
                addressTabs[4].disabled = true;
            }
        });

        // Listen to Phone, Street Name and House Number inputs to enable Confirm button
        if (tabPhoneInput) {
            // Only allow digits and limit to 11 characters
            tabPhoneInput.addEventListener('input', function(e) {
                // Remove non-digit characters
                let value = e.target.value.replace(/\D/g, '');
                // Limit to 11 digits
                if (value.length > 11) {
                    value = value.slice(0, 11);
                }
                e.target.value = value;
                checkRequiredFields();
            });
        }
        if (tabStreetInput) {
            tabStreetInput.addEventListener('input', checkRequiredFields);
        }
        if (tabHouseInput) {
            tabHouseInput.addEventListener('input', checkRequiredFields);
        }

        // Confirm button
        confirmTabsBtn.addEventListener('click', function() {
            const isNCR = tabRegionSelect.value === '130000000';
            const regionName = tabRegionSelect.options[tabRegionSelect.selectedIndex].text;
            const cityName = tabCitySelect.options[tabCitySelect.selectedIndex].text;
            const barangayName = tabBarangaySelect.options[tabBarangaySelect.selectedIndex].text;
            const phoneNumber = tabPhoneInput ? tabPhoneInput.value : '';
            const streetName = tabStreetInput ? tabStreetInput.value : '';
            const houseNumber = tabHouseInput ? tabHouseInput.value : '';
            const postalCode = tabPostalInput ? tabPostalInput.value : '';

            let provinceName = '';
            if (!isNCR) {
                provinceName = tabProvinceSelect.options[tabProvinceSelect.selectedIndex].text;
            }

            // Validate phone number is exactly 11 digits
            if (phoneNumber.length !== 11 || !/^\d{11}$/.test(phoneNumber)) {
                alert('Phone number must be exactly 11 digits.');
                return;
            }

            const allFieldsSelected = isNCR
                ? (tabRegionSelect.value && tabCitySelect.value && tabBarangaySelect.value && phoneNumber && streetName && houseNumber)
                : (tabRegionSelect.value && tabProvinceSelect.value && tabCitySelect.value && tabBarangaySelect.value && phoneNumber && streetName && houseNumber);

            if (allFieldsSelected) {
                let addressParts = [];
                if (houseNumber) addressParts.push(houseNumber);
                if (streetName) addressParts.push(streetName);
                addressParts.push(barangayName);
                addressParts.push(cityName);
                if (!isNCR) addressParts.push(provinceName);
                addressParts.push(regionName);
                if (postalCode) addressParts.push(postalCode);

                addressField.value = addressParts.join(', ');
                
                // Store the selected address data for form submission
                window[`${prefix}SelectedAddressData`] = {
                    region: regionName,
                    province: provinceName,
                    city: cityName,
                    barangay: barangayName,
                    phone: phoneNumber,
                    street: streetName,
                    house: houseNumber,
                    postal: postalCode
                };
                
                // Populate all hidden fields for form submission
                const hiddenPhoneField = document.getElementById(`${prefix}_phone_number_hidden`);
                const hiddenRegionField = document.getElementById(`${prefix}_region_hidden`);
                const hiddenProvinceField = document.getElementById(`${prefix}_province_hidden`);
                const hiddenCityField = document.getElementById(`${prefix}_city_hidden`);
                const hiddenBarangayField = document.getElementById(`${prefix}_barangay_hidden`);
                const hiddenStreetField = document.getElementById(`${prefix}_street_hidden`);
                const hiddenHouseField = document.getElementById(`${prefix}_house_number_hidden`);
                const hiddenPostalField = document.getElementById(`${prefix}_postal_code_hidden`);
                
                if (hiddenPhoneField) hiddenPhoneField.value = phoneNumber;
                if (hiddenRegionField) hiddenRegionField.value = regionName;
                if (hiddenProvinceField) hiddenProvinceField.value = provinceName;
                if (hiddenCityField) hiddenCityField.value = cityName;
                if (hiddenBarangayField) hiddenBarangayField.value = barangayName;
                if (hiddenStreetField) hiddenStreetField.value = streetName;
                if (hiddenHouseField) hiddenHouseField.value = houseNumber;
                if (hiddenPostalField) hiddenPostalField.value = postalCode;
                
                addressTabsDropdown.style.display = 'none';
            }
        });

        // Initial underline position
        updateAddressTabsUnderline();
        // On window resize, recalculate
        window.addEventListener('resize', updateAddressTabsUnderline);
    }

    // Initialize for all three user types
    initializeAddressDropdown('buyer');
    initializeAddressDropdown('seller');
    initializeAddressDropdown('rider');
});
