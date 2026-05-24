// Global variables for profile data
let currentProfileData = null;
let selectedGender = null;

// Initialize profile page
function initializeProfilePage() {
    // Load profile data from server-rendered template (NO API CALL)
    loadProfileDataFromTemplate();
    
    // Load ID data from server-rendered template (NO API CALL)
    loadIdDataFromTemplate();

    // Phone number 'Add' link logic (show input, hide link)
    const addPhoneLink = document.getElementById('addPhoneLink');
    const phoneInput = document.getElementById('profilePhone');
    if (addPhoneLink && phoneInput) {
        addPhoneLink.addEventListener('click', function() {
            addPhoneLink.style.display = 'none';
            phoneInput.style.display = '';
            phoneInput.focus();
        });
    }

    // Gender button selection
    const genderButtons = document.querySelectorAll('.gender-btn');
    genderButtons.forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            genderButtons.forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            selectedGender = this.textContent;
        });
    });

    // Handle form submission
    const profileForm = document.querySelector('.profile-form');
    if (profileForm) {
        profileForm.addEventListener('submit', handleProfileSubmit);
    }
 
    // Profile picture container click
    const profilePictureContainer = document.getElementById('profilePictureContainer');
    const profilePictureInput = document.getElementById('profilePictureInput');
    
    if (profilePictureContainer && profilePictureInput) {
        profilePictureContainer.addEventListener('click', () => {
            profilePictureInput.click();
        });
    }

    // File input change
    if (profilePictureInput) {
        profilePictureInput.addEventListener('change', handleFileSelect);
    }
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
    const profileTab = document.getElementById('profileTab');
    const addressesTab = document.getElementById('addressesTab');
    const accountCardContainer = document.getElementById('accountCardContainer');

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

    // Sub-tab navigation is now handled by myAccount_navigation.js
    // This code is disabled to prevent conflicts
    
    // Note: The myAccount_navigation.js script handles all navigation
    // between myAccount pages using AJAX to prevent page refresh and
    // preserve the sidebar profile image/name
}

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', initializeProfilePage);

// Re-initialize when content is loaded via AJAX
window.addEventListener('myAccountContentLoaded', function() {
    if (window.location.pathname.includes('/myAccount/profile')) {
        initializeProfilePage();
    }
});

// Track if notification is currently showing
let isNotificationShowing = false;

// Handle file selection for profile picture
function handleFileSelect(e) {
    const file = e.target.files[0];
    
    if (!file) return;

    // Validate file type
    if (!file.type.startsWith('image/')) {
        showNotification('Please select an image file', 'error');
        return;
    }

    // Validate file size (5MB max)
    const maxSize = 5 * 1024 * 1024; // 5MB in bytes
    if (file.size > maxSize) {
        showNotification('File size must be less than 5MB', 'error');
        return;
    }

    // Read and preview the file
    const reader = new FileReader();
    reader.onload = function(event) {
        const profilePicturePreview = document.getElementById('profilePicturePreview');
        const uploadPlaceholder = document.getElementById('uploadPlaceholder');
        const profilePictureContainer = document.getElementById('profilePictureContainer');
        
        if (profilePicturePreview) {
            profilePicturePreview.src = event.target.result;
            profilePicturePreview.style.display = 'block';
        }
        if (uploadPlaceholder) {
            uploadPlaceholder.style.display = 'none';
        }
        if (profilePictureContainer) {
            profilePictureContainer.classList.add('has-image');
        }
    };
    reader.readAsDataURL(file);
}

// Load profile data from server-rendered template (NO API CALL - INSTANT)
function loadProfileDataFromTemplate() {
    try {
        // Get profile data from hidden JSON in template
        const profileDataEl = document.getElementById('profileData');
        if (profileDataEl) {
            const profile = JSON.parse(profileDataEl.textContent);
            
            // Only use if profile has data
            if (profile.first_name) {
                currentProfileData = profile;
                populateProfileForm(profile);
                return;
            }
        }
        
        // Fallback: Get profile data from sidebar
        const sidebarName = document.getElementById('sidebarProfileName');
        const sidebarImg = document.getElementById('sidebarProfileImg');
        
        if (!sidebarName) return;
        
        const fullName = sidebarName.textContent.trim();
        if (fullName === 'Guest User') return;
        
        const [firstName, ...lastNameParts] = fullName.split(' ');
        const lastName = lastNameParts.join(' ');
        
        // Build profile object from template data
        const profile = {
            first_name: firstName,
            last_name: lastName,
            email: '',
            phone_number: '',
            gender: '',
            profile_image: null
        };
        
        // Get profile image from sidebar
        if (sidebarImg) {
            const bgImage = sidebarImg.style.backgroundImage;
            if (bgImage && bgImage !== 'none') {
                profile.profile_image = bgImage.replace(/^url\(['"]?|['"]?\)$/g, '');
            }
        }
        
        currentProfileData = profile;
        populateProfileForm(profile);
        
    } catch (error) {
        console.error('Error loading profile from template:', error);
    }
}

// Load ID data from server-rendered template (NO API CALL - INSTANT)
function loadIdDataFromTemplate() {
    try {
        // Get ID data from hidden JSON in template
        const idDataEl = document.getElementById('idData');
        if (!idDataEl) return;
        
        const idData = JSON.parse(idDataEl.textContent);
        
        // Only proceed if ID data exists
        if (!idData.id_file_path) return;
        
        const idImageContainer = document.getElementById('idImageContainer');
        const idTypeSelect = document.getElementById('idTypeSelect');
        
        if (idImageContainer) {
            let img = idImageContainer.querySelector('img');
            if (!img) {
                img = document.createElement('img');
                idImageContainer.insertBefore(img, idImageContainer.firstChild);
            }
            img.src = idData.id_file_path;
            
            // Show overlay, hide placeholder
            idImageContainer.classList.add('has-image');
            const placeholder = idImageContainer.querySelector('.upload-placeholder');
            const overlay = idImageContainer.querySelector('.upload-overlay');
            if (placeholder) placeholder.style.display = 'none';
            if (overlay) overlay.style.display = 'flex';
        }
        
        if (idTypeSelect && idData.id_type) {
            idTypeSelect.value = idData.id_type;
        }
    } catch (error) {
        console.error('Error loading ID from template:', error);
    }
}

// Populate form with profile data
function populateProfileForm(profile) {
    // Set text inputs
    const firstNameInput = document.getElementById('profileFirstName');
    const lastNameInput = document.getElementById('profileLastName');
    const emailInput = document.getElementById('profileEmail');
    
    if (firstNameInput) firstNameInput.value = profile.first_name || '';
    if (lastNameInput) lastNameInput.value = profile.last_name || '';
    if (emailInput) emailInput.value = profile.email || '';
    
    // Handle phone number
    const phoneInput = document.getElementById('profilePhone');
    const addPhoneLink = document.getElementById('addPhoneLink');
    if (profile.phone_number && phoneInput && addPhoneLink) {
        phoneInput.value = profile.phone_number;
        phoneInput.style.display = '';
        addPhoneLink.style.display = 'none';
    }

    // Set gender button
    if (profile.gender) {
        selectedGender = profile.gender;
        const genderButtons = document.querySelectorAll('.gender-btn');
        genderButtons.forEach(btn => {
            if (btn.textContent === profile.gender) {
                btn.classList.add('active');
            }
        });
    }

    // Set profile image with proper URL handling
    const profilePicturePreview = document.getElementById('profilePicturePreview');
    const uploadPlaceholder = document.getElementById('uploadPlaceholder');
    const profilePictureContainer = document.getElementById('profilePictureContainer');
    const sidebarProfileImg = document.getElementById('sidebarProfileImg');
    
    if (profile.profile_image) {
        // Handle both Supabase URLs and local paths
        let imageSrc = profile.profile_image;
        if (!imageSrc.startsWith('http://') && !imageSrc.startsWith('https://')) {
            // Local path - add prefix if needed
            if (imageSrc.startsWith('static/')) {
                imageSrc = '/' + imageSrc;
            } else if (!imageSrc.startsWith('/')) {
                imageSrc = '/static/' + imageSrc;
            }
        }
        
        if (profilePicturePreview) {
            profilePicturePreview.src = imageSrc;
            profilePicturePreview.style.display = 'block';
        }
        if (uploadPlaceholder) {
            uploadPlaceholder.style.display = 'none';
        }
        if (profilePictureContainer) {
            profilePictureContainer.classList.add('has-image');
        }
        // Update sidebar profile image
        if (sidebarProfileImg) {
            sidebarProfileImg.style.backgroundImage = `url('${imageSrc}')`;
        }
    } else {
        // Clear profile image if user has none
        if (profilePicturePreview) {
            profilePicturePreview.style.display = 'none';
        }
        if (uploadPlaceholder) {
            uploadPlaceholder.style.display = 'block';
        }
        if (profilePictureContainer) {
            profilePictureContainer.classList.remove('has-image');
        }
        // Clear sidebar profile image
        if (sidebarProfileImg) {
            sidebarProfileImg.style.backgroundImage = 'none';
        }
    }

    // Update sidebar profile name
    const profileNamePlaceholder = document.getElementById('sidebarProfileName');
    if (profileNamePlaceholder && profile.first_name && profile.last_name) {
        profileNamePlaceholder.textContent = `${profile.first_name} ${profile.last_name}`;
    } else if (profileNamePlaceholder) {
        profileNamePlaceholder.textContent = 'Guest User';
    }
    
    // Update navigation cache
    if (profile.first_name && profile.last_name) {
        const navCache = {
            name: `${profile.first_name} ${profile.last_name}`,
            image: profile.profile_image ? `url('${profile.profile_image}')` : null
        };
        sessionStorage.setItem('sidebarProfileCache', JSON.stringify(navCache));

        // Also refresh `userProfile` so other account sub-tabs (Addresses,
        // Purchases, Notifications, etc.) pick up the latest image. Their
        // inline preload scripts read `userProfile` first, so if we don't
        // update it here, switching tabs after the server-side image changed
        // (e.g. uploaded from another device) keeps showing the stale photo.
        const fullProfileCache = {
            first_name: profile.first_name,
            last_name: profile.last_name,
            email: profile.email || null,
            phone_number: profile.phone_number || null,
            gender: profile.gender || null,
            profile_image: profile.profile_image || null
        };
        const fullProfileJson = JSON.stringify(fullProfileCache);
        sessionStorage.setItem('userProfile', fullProfileJson);
        localStorage.setItem('userProfile', fullProfileJson);
    }
}

// Handle profile form submission
async function handleProfileSubmit(e) {
    e.preventDefault();

    // Prevent multiple submissions
    if (isNotificationShowing) return;

    // Get form data
    const firstName = document.getElementById('profileFirstName').value.trim();
    const lastName = document.getElementById('profileLastName').value.trim();
    const phoneInput = document.getElementById('profilePhone');
    const phoneNumber = phoneInput ? phoneInput.value.trim() : '';
    const profilePictureInput = document.getElementById('profilePictureInput');

    // Validate required fields
    if (!firstName || !lastName) {
        showNotification('First name and last name are required', 'error');
        return;
    }

    // Validate phone number
    const oldPhone = currentProfileData ? (currentProfileData.phone_number || '') : '';
    
    // If phone number was previously filled but is now empty, show error and restore old value
    if (oldPhone && !phoneNumber && phoneInput) {
        showNotification('Phone number cannot be empty. Please enter a valid phone number.', 'error');
        // Restore the previous phone number
        phoneInput.value = oldPhone;
        return;
    }
    
    // Validate phone number format if provided
    if (phoneNumber) {
        // Check if phone number contains only digits
        if (!/^\d+$/.test(phoneNumber)) {
            showNotification('Phone number must contain only numbers', 'error');
            return;
        }
        
        // Check if phone number is exactly 11 digits
        if (phoneNumber.length !== 11) {
            showNotification('Phone number must be exactly 11 digits', 'error');
            return;
        }
    }

    // Check if any changes were made
    let hasChanges = false;
    
    if (currentProfileData) {
        // Check if name changed
        if (firstName !== currentProfileData.first_name || lastName !== currentProfileData.last_name) {
            hasChanges = true;
        }
        
        // Check if email changed
        const emailInput = document.getElementById('profileEmail');
        const currentEmail = emailInput ? emailInput.value.trim() : '';
        const oldEmail = currentProfileData.email || '';
        if (currentEmail !== oldEmail) {
            hasChanges = true;
        }
        
        // Check if phone number changed
        const oldPhone = currentProfileData.phone_number || '';
        if (phoneNumber !== oldPhone) {
            hasChanges = true;
        }
        
        // Check if gender changed
        const oldGender = currentProfileData.gender || '';
        const newGender = selectedGender || '';
        if (newGender !== oldGender) {
            hasChanges = true;
        }
        
        // Check if new profile image was selected
        if (profilePictureInput.files.length > 0) {
            hasChanges = true;
        }
    } else {
        // If no current profile data, consider it as new data (has changes)
        hasChanges = true;
    }
    
    // If no changes, show error and return
    if (!hasChanges) {
        showNotification('No changes detected. Please modify your profile before saving.', 'error');
        return;
    }

    // Create FormData object
    const formData = new FormData();
    formData.append('first_name', firstName);
    formData.append('last_name', lastName);
    
    // Add email
    const emailInput = document.getElementById('profileEmail');
    const email = emailInput ? emailInput.value.trim() : '';
    if (email) {
        formData.append('email', email);
    }
    
    if (phoneNumber) {
        formData.append('phone_number', phoneNumber);
    }
    
    if (selectedGender) {
        formData.append('gender', selectedGender);
    }

    // Add profile image if selected
    if (profilePictureInput.files.length > 0) {
        formData.append('profile_image', profilePictureInput.files[0]);
    }

    try {
        const response = await fetch('/api/profile/update', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (data.success) {
            showNotification(data.message, 'success');
            
            // Clear cached profile data so it refreshes
            sessionStorage.removeItem('userProfile');
            localStorage.removeItem('userProfile');
            localStorage.removeItem('velareUserProfile');
            
            // Clear global state
            if (window.VelareApp) {
                window.VelareApp.userProfile = null;
            }
            
            // Update sidebar name
            const profileNamePlaceholder = document.getElementById('sidebarProfileName');
            if (profileNamePlaceholder) {
                profileNamePlaceholder.textContent = `${firstName} ${lastName}`;
            }

            // Update profile image if new one was uploaded
            if (data.profile_image) {
                // Handle both Supabase URLs and local paths
                let imageSrc = data.profile_image;
                if (!imageSrc.startsWith('http://') && !imageSrc.startsWith('https://')) {
                    // Local path - add prefix if needed
                    if (imageSrc.startsWith('static/')) {
                        imageSrc = '/' + imageSrc;
                    } else if (!imageSrc.startsWith('/')) {
                        imageSrc = '/static/' + imageSrc;
                    }
                }
                
                const profilePicturePreview = document.getElementById('profilePicturePreview');
                const sidebarProfileImg = document.getElementById('sidebarProfileImg');
                const sidebarProfileInitial = document.getElementById('sidebarProfileInitial');
                
                if (profilePicturePreview) {
                    profilePicturePreview.src = imageSrc;
                }
                // Update sidebar profile image
                if (sidebarProfileImg) {
                    sidebarProfileImg.style.backgroundImage = `url('${imageSrc}')`;
                }
                // Hide initial when image is uploaded
                if (sidebarProfileInitial) {
                    sidebarProfileInitial.style.display = 'none';
                }
            }
            
            // Reload profile data to update cache with fresh data from server
            fetch('/api/profile/get')
                .then(r => r.json())
                .then(d => {
                    if (d.success && d.profile) {
                        currentProfileData = d.profile;
                        const profileData = JSON.stringify(d.profile);
                        sessionStorage.setItem('userProfile', profileData);
                        localStorage.setItem('userProfile', profileData);
                        
                        // Update navigation cache with fresh data
                        const navCache = {
                            name: `${d.profile.first_name} ${d.profile.last_name}`,
                            profile_image: d.profile.profile_image || null,
                            image: d.profile.profile_image ? `url('${d.profile.profile_image}')` : null
                        };
                        sessionStorage.setItem('sidebarProfileCache', JSON.stringify(navCache));
                        
                        // Update the initial display based on fresh data
                        const sidebarProfileImg = document.getElementById('sidebarProfileImg');
                        const sidebarProfileInitial = document.getElementById('sidebarProfileInitial');
                        
                        if (d.profile.profile_image) {
                            // Handle both Supabase URLs and local paths
                            let imageSrc = d.profile.profile_image;
                            if (!imageSrc.startsWith('http://') && !imageSrc.startsWith('https://')) {
                                // Local path - add prefix if needed
                                if (imageSrc.startsWith('static/')) {
                                    imageSrc = '/' + imageSrc;
                                } else if (!imageSrc.startsWith('/')) {
                                    imageSrc = '/static/' + imageSrc;
                                }
                            }
                            
                            if (sidebarProfileImg) {
                                sidebarProfileImg.style.backgroundImage = `url('${imageSrc}')`;
                            }
                            if (sidebarProfileInitial) {
                                sidebarProfileInitial.style.display = 'none';
                            }
                        } else {
                            if (sidebarProfileImg) {
                                sidebarProfileImg.style.backgroundImage = '';
                            }
                            if (sidebarProfileInitial) {
                                sidebarProfileInitial.style.display = 'flex';
                            }
                        }
                    }
                });
        } else {
            showNotification(data.message || 'Failed to update profile', 'error');
        }
    } catch (error) {
        console.error('Error updating profile:', error);
        showNotification('Failed to update profile', 'error');
    }
}

// Show notification
function showNotification(message, type = 'info') {
    // Remove any existing notifications first
    const existingNotifications = document.querySelectorAll('.notification');
    existingNotifications.forEach(notif => {
        notif.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notif.remove();
        }, 300);
    });
    
    // Set flag to prevent multiple notifications
    isNotificationShowing = true;
    
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
            // Reset flag after notification is completely removed
            isNotificationShowing = false;
        }, 300);
    }, 3000);
}


// ID Verification Modal
document.addEventListener('DOMContentLoaded', function() {
    const viewIdBtn = document.getElementById('viewIdBtn');
    const idModal = document.getElementById('idModal');
    const closeIdModal = document.getElementById('closeIdModal');
    const idImageContainer = document.getElementById('idImageContainer');
    const idImageInput = document.getElementById('idImageInput');
    const idUploadForm = document.getElementById('idUploadForm');
    
    // Open modal
    if (viewIdBtn && idModal) {
        viewIdBtn.addEventListener('click', function(e) {
            e.preventDefault();
            idModal.classList.add('show');
        });
    }
    
    // Close modal
    if (closeIdModal && idModal) {
        closeIdModal.addEventListener('click', function() {
            idModal.classList.remove('show');
        });
    }
    
    // Close modal when clicking outside
    if (idModal) {
        idModal.addEventListener('click', function(e) {
            if (e.target === idModal) {
                idModal.classList.remove('show');
            }
        });
    }
    
    // Click to upload
    if (idImageContainer && idImageInput) {
        idImageContainer.addEventListener('click', function() {
            idImageInput.click();
        });
        
        // Preview image
        idImageInput.addEventListener('change', function(e) {
            const file = e.target.files[0];
            if (file) {
                const reader = new FileReader();
                reader.onload = function(event) {
                    // Check if image already exists
                    let img = idImageContainer.querySelector('img');
                    if (!img) {
                        img = document.createElement('img');
                        idImageContainer.insertBefore(img, idImageContainer.firstChild);
                    }
                    img.src = event.target.result;
                    
                    // Show overlay, hide placeholder
                    idImageContainer.classList.add('has-image');
                    const placeholder = idImageContainer.querySelector('.upload-placeholder');
                    const overlay = idImageContainer.querySelector('.upload-overlay');
                    if (placeholder) placeholder.style.display = 'none';
                    if (overlay) overlay.style.display = 'flex';
                };
                reader.readAsDataURL(file);
            }
        });
    }
    
    // Submit ID form
    if (idUploadForm) {
        idUploadForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const submitBtn = this.querySelector('.submit-id-btn');
            const originalText = submitBtn.textContent;
            
            // Check if file is selected
            if (!idImageInput.files || idImageInput.files.length === 0) {
                showNotification('Please select an ID image to upload', 'error');
                return;
            }
            
            submitBtn.disabled = true;
            submitBtn.textContent = 'Uploading...';
            
            // Check ID type
            const idTypeSelect = document.getElementById('idTypeSelect');
            const idType = idTypeSelect ? idTypeSelect.value : '';
            
            if (!idType) {
                showNotification('Please select an ID type', 'error');
                submitBtn.disabled = false;
                submitBtn.textContent = originalText;
                return;
            }
            
            try {
                const formData = new FormData();
                formData.append('valid_id', idImageInput.files[0]);
                formData.append('id_type', idType);
                
                const response = await fetch('/api/profile/upload-id', {
                    method: 'POST',
                    body: formData
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showNotification('ID uploaded successfully!', 'success');
                    // Close modal after successful upload
                    setTimeout(() => {
                        idModal.classList.remove('show');
                    }, 1500);
                } else {
                    showNotification(data.message || 'Failed to upload ID', 'error');
                }
            } catch (error) {
                console.error('Error uploading ID:', error);
                showNotification('An error occurred while uploading', 'error');
            } finally {
                submitBtn.disabled = false;
                submitBtn.textContent = originalText;
            }
        });
    }
});
