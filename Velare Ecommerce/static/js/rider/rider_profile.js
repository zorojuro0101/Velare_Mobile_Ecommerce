// Rider Profile JavaScript

document.addEventListener('DOMContentLoaded', function() {
    initializeProfile();
    setupEventListeners();
    loadProfileData();
    
    // Check if redirected from pickup page due to missing phone number
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('error') === 'phone_required') {
        // Show the phone input field
        const addPhoneLink = document.getElementById('addPhoneLink');
        const phoneInput = document.getElementById('licenseNumber');
        if (addPhoneLink && phoneInput) {
            addPhoneLink.classList.add('hidden');
            phoneInput.classList.remove('hidden');
        }
        
        // Show error notification
        setTimeout(() => {
            showNotification('Phone number is required to accept pickup requests. Please add your phone number.', 'error');
        }, 500);
        
        // Remove the error parameter from URL
        window.history.replaceState({}, document.title, window.location.pathname);
    }
});

// Initialize profile page
function initializeProfile() {
    console.log('Profile page initialized');
}

// Setup event listeners
function setupEventListeners() {
    // Phone number 'Add' link logic (show input, hide link)
    const addPhoneLink = document.getElementById('addPhoneLink');
    const phoneInput = document.getElementById('riderPhoneNumber');
    if (addPhoneLink && phoneInput) {
        addPhoneLink.addEventListener('click', function() {
            addPhoneLink.style.display = 'none';
            phoneInput.style.display = 'block';
            phoneInput.focus();
        });
    }

    // Profile picture container click
    const profilePictureContainer = document.querySelector('.profile-picture-container');
    const profilePictureInput = document.getElementById('riderPictureInput');
    
    if (profilePictureContainer && profilePictureInput) {
        profilePictureContainer.addEventListener('click', () => {
            profilePictureInput.click();
        });
    }

    // File input change
    if (profilePictureInput) {
        profilePictureInput.addEventListener('change', handleFileSelect);
    }

    // Profile form submit
    const profileForm = document.getElementById('riderProfileForm');
    if (profileForm) {
        profileForm.addEventListener('submit', handleSaveProfile);
    }
    
    // Documents form submit
    const documentsForm = document.getElementById('documentsForm');
    if (documentsForm) {
        documentsForm.addEventListener('submit', handleDocumentsSubmit);
    }
    
    // Document image containers click
    const orcrContainer = document.getElementById('orcrImageContainer');
    const orcrInput = document.getElementById('orcrImageInput');
    if (orcrContainer && orcrInput) {
        orcrContainer.addEventListener('click', () => orcrInput.click());
        orcrInput.addEventListener('change', (e) => handleDocumentSelect(e, 'orcr'));
    }
    
    const licenseContainer = document.getElementById('licenseImageContainer');
    const licenseInput = document.getElementById('licenseImageInput');
    if (licenseContainer && licenseInput) {
        licenseContainer.addEventListener('click', () => licenseInput.click());
        licenseInput.addEventListener('change', (e) => handleDocumentSelect(e, 'license'));
    }

    // Cancel button
    const cancelBtn = document.getElementById('cancelBtn');
    if (cancelBtn) {
        cancelBtn.addEventListener('click', handleCancel);
    }

    // Sidebar profile click
    const sidebarProfile = document.getElementById('sidebarProfile');
    if (sidebarProfile) {
        sidebarProfile.addEventListener('click', () => {
            // Already on profile page, do nothing or refresh
            console.log('Already on profile page');
        });
    }

    // Delivery Management toggle
    const deliveryManagementToggle = document.getElementById('deliveryManagementToggle');
    if (deliveryManagementToggle) {
        deliveryManagementToggle.addEventListener('click', toggleDeliverySubmenu);
    }

    // Navigation items (excluding logout since it's handled by logout-modal.js)
    const navItems = document.querySelectorAll('.nav-item[data-tab]:not(#deliveryManagementToggle):not(#logout-link)');
    navItems.forEach(item => {
        item.addEventListener('click', handleNavigation);
    });

    // Navigation subitems
    const navSubitems = document.querySelectorAll('.nav-subitem');
    navSubitems.forEach(item => {
        item.addEventListener('click', handleSubNavigation);
    });

    // Form inputs - auto-save indicator (optional)
    const formInputs = document.querySelectorAll('.form-group input');
    formInputs.forEach(input => {
        input.addEventListener('input', () => {
            // Mark form as modified
            markFormAsModified();
        });
    });

    // License number validation - numbers only, max 11 digits
    const licenseNumberInput = document.getElementById('licenseNumber');
    if (licenseNumberInput) {
        licenseNumberInput.addEventListener('input', handleLicenseNumberInput);
        licenseNumberInput.addEventListener('blur', validateLicenseNumber);
    }
}

// Load profile data from server or localStorage
function loadProfileData() {
    // TODO: Fetch from server
    // For now, load from localStorage if available
    const savedProfile = localStorage.getItem('riderProfile');
    
    if (savedProfile) {
        try {
            const profileData = JSON.parse(savedProfile);
            populateForm(profileData);
            initialProfileData = { ...profileData }; // Store initial data
        } catch (error) {
            console.error('Error loading profile data:', error);
        }
    } else {
        // If no saved data, set initial data from current form values (populated by template)
        initialProfileData = {
            firstName: document.getElementById('firstName')?.value || '',
            lastName: document.getElementById('lastName')?.value || '',
            email: document.getElementById('email')?.value || '',
            phoneNumber: document.getElementById('licenseNumber')?.value || '',
            vehicle_type: document.getElementById('vehicleType')?.value || ''
        };
    }
}

// Populate form with profile data
function populateForm(data) {
    const firstName = document.getElementById('firstName');
    const lastName = document.getElementById('lastName');
    const email = document.getElementById('email');
    const licenseNumber = document.getElementById('licenseNumber');
    const vehicleType = document.getElementById('vehicleType');
    const profilePicturePreview = document.getElementById('profilePicturePreview');
    const sidebarProfileImg = document.getElementById('sidebarProfileImg');
    const sidebarProfileName = document.getElementById('sidebarProfileName');
    const uploadPlaceholder = document.getElementById('uploadPlaceholder');
    const addPhoneLink = document.getElementById('addPhoneLink');

    if (firstName && data.firstName) firstName.value = data.firstName;
    if (lastName && data.lastName) lastName.value = data.lastName;
    if (email && data.email) email.value = data.email;
    if (licenseNumber && (data.phoneNumber || data.phone_number)) licenseNumber.value = data.phoneNumber || data.phone_number;
    if (vehicleType && data.vehicle_type) vehicleType.value = data.vehicle_type;
    
    // This function is no longer needed as the template handles initial state
    // The JS will only handle the click event
    
    if (data.profilePicture) {
        const profilePictureContainer = document.getElementById('profilePictureContainer');
        if (profilePicturePreview) {
            profilePicturePreview.src = data.profilePicture;
            profilePicturePreview.classList.remove('hidden');
        }
        if (sidebarProfileImg) sidebarProfileImg.src = data.profilePicture;
        if (uploadPlaceholder) uploadPlaceholder.classList.add('hidden');
        if (profilePictureContainer) profilePictureContainer.classList.add('has-image');
    }

    if (data.firstName && data.lastName && sidebarProfileName) {
        sidebarProfileName.textContent = `${data.firstName} ${data.lastName}`;
    }
}

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
        // Update main profile picture container ONLY
        const profilePictureContainer = document.querySelector('.profile-picture-container');
        
        if (profilePictureContainer) {
            // Check if image already exists
            let img = profilePictureContainer.querySelector('img');
            if (!img) {
                // Create new image element
                img = document.createElement('img');
                img.style.width = '100%';
                img.style.height = '100%';
                img.style.objectFit = 'cover';
                profilePictureContainer.innerHTML = '';
                profilePictureContainer.appendChild(img);
                
                // Add overlay
                const overlay = document.createElement('div');
                overlay.className = 'upload-overlay';
                overlay.innerHTML = `
                    <i class="bi bi-camera"></i>
                    <span>Change Photo</span>
                `;
                profilePictureContainer.appendChild(overlay);
            }
            img.src = event.target.result;
            profilePictureContainer.classList.add('has-image');
        }

        markFormAsModified();
    };
    reader.readAsDataURL(file);
}

// Handle save profile
async function handleSaveProfile(e) {
    e.preventDefault();
    
    const firstName = document.getElementById('riderFirstName').value.trim();
    const lastName = document.getElementById('riderLastName').value.trim();
    const email = document.getElementById('riderEmail').value.trim();
    const phoneNumber = document.getElementById('riderPhoneNumber').value.trim();
    const vehicleType = document.getElementById('riderVehicleType')?.value || '';
    const plateNumber = document.getElementById('riderPlateNumber')?.value.trim() || '';
    const profilePictureInput = document.getElementById('riderPictureInput');

    // Validate required fields
    if (!firstName) {
        showNotification('First name is required', 'error');
        document.getElementById('riderFirstName').focus();
        return;
    }

    if (!lastName) {
        showNotification('Last name is required', 'error');
        document.getElementById('riderLastName').focus();
        return;
    }

    if (!phoneNumber) {
        showNotification('Phone number is required', 'error');
        const phoneInput = document.getElementById('riderPhoneNumber');
        const addPhoneLink = document.getElementById('addPhoneLink');
        if (addPhoneLink && addPhoneLink.style.display !== 'none') {
            addPhoneLink.style.display = 'none';
            phoneInput.style.display = 'block';
        }
        phoneInput.focus();
        return;
    }

    // Validate phone number format (must start with 0 and be 11 digits)
    if (!/^0\d{10}$/.test(phoneNumber)) {
        if (phoneNumber.length !== 11) {
            showNotification('Phone number must be exactly 11 digits', 'error');
        } else {
            showNotification('Phone number must start with 0', 'error');
        }
        document.getElementById('riderPhoneNumber').focus();
        return;
    }

    // Prepare form data
    const formData = new FormData();
    formData.append('first_name', firstName);
    formData.append('last_name', lastName);
    formData.append('phone_number', phoneNumber);
    formData.append('vehicle_type', vehicleType);
    formData.append('plate_number', plateNumber);
    
    // Add profile image if uploaded
    if (profilePictureInput && profilePictureInput.files.length > 0) {
        formData.append('profile_image', profilePictureInput.files[0]);
    }

    // Send to server
    try {
        const response = await fetch('/rider/profile/update', {
            method: 'POST',
            body: formData
        });

        const result = await response.json();

        if (result.success) {
            // Update sidebar name
            const sidebarProfileName = document.getElementById('sidebarProfileName');
            if (sidebarProfileName) {
                sidebarProfileName.textContent = `${firstName} ${lastName}`;
            }

            // Update sidebar profile image if new image was uploaded
            if (result.data.profile_image) {
                const sidebarProfileImg = document.getElementById('sidebarProfileImg');
                const sidebarProfileInitial = document.getElementById('sidebarProfileInitial');
                const profilePicturePreview = document.getElementById('profilePicturePreview');
                const uploadPlaceholder = document.getElementById('uploadPlaceholder');
                const profilePictureContainer = document.getElementById('profilePictureContainer');
                
                if (sidebarProfileImg) {
                    sidebarProfileImg.src = result.data.profile_image;
                    sidebarProfileImg.style.display = 'block';
                }
                if (sidebarProfileInitial) {
                    sidebarProfileInitial.style.display = 'none';
                }
                if (profilePicturePreview) {
                    profilePicturePreview.src = result.data.profile_image;
                    profilePicturePreview.classList.remove('hidden');
                }
                if (uploadPlaceholder) {
                    uploadPlaceholder.classList.add('hidden');
                }
                if (profilePictureContainer) {
                    profilePictureContainer.classList.add('has-image');
                }
            }

            showNotification(result.message, 'success');
            
            // Update initial data after successful save
            initialProfileData = {
                firstName: firstName,
                lastName: lastName,
                email: email,
                phoneNumber: phoneNumber,
                vehicle_type: vehicleType
            };

            // Clear modified flag
            clearFormModified();

        } else {
            showNotification(result.message || 'Failed to update profile', 'error');
        }
    } catch (error) {
        console.error('Error saving profile:', error);
        showNotification('Failed to save profile. Please try again.', 'error');
    }
}

// Handle cancel
function handleCancel() {
    if (isFormModified()) {
        // TODO: Show custom modal instead of confirm
        window.location.href = '/rider/dashboard';
    } else {
        window.location.href = '/rider/dashboard';
    }
}

// Toggle delivery submenu
function toggleDeliverySubmenu(e) {
    e.preventDefault();
    
    // Automatically navigate to List for Pickup page
    window.location.href = '/rider/pickup';
}

// Handle navigation
function handleNavigation(e) {
    const tab = e.currentTarget.getAttribute('data-tab');
    const href = e.currentTarget.getAttribute('href');
    
    console.log('Navigating to:', tab, 'href:', href);
    
    // Handle specific navigation
    if (href && href !== '#') {
        // Allow normal navigation for links with valid href
        console.log('Following href:', href);
        window.location.href = href;
        return;
    }
    
    // Prevent default for other cases
    e.preventDefault();
    
    // Handle specific navigation for items without href
    switch(tab) {
        case 'logout':
            handleLogout();
            break;
        case 'earnings':
            // Fallback for earnings if href is missing
            window.location.href = '/rider/earnings';
            break;
        default:
            console.log('Navigation to:', tab);
    }
}

// Handle sub-navigation
function handleSubNavigation(e) {
    const tab = e.currentTarget.getAttribute('data-tab');
    const href = e.currentTarget.getAttribute('href');
    
    console.log('Navigating to sub-tab:', tab, 'href:', href);
    
    // Handle specific navigation
    if (href && href !== '#') {
        // Allow normal navigation for links with valid href
        console.log('Following href:', href);
        window.location.href = href;
        return;
    }
    
    // Prevent default for other cases
    e.preventDefault();
    
    // Remove active class from all subitems
    document.querySelectorAll('.nav-subitem').forEach(item => {
        item.classList.remove('active');
    });
    
    // Add active class to clicked subitem
    e.currentTarget.classList.add('active');
    
    // Handle specific sub-navigation for items without href
    switch(tab) {
        case 'list-pickup':
            window.location.href = '/rider/pickup';
            break;
        case 'active-delivery':
            window.location.href = '/rider/active-delivery';
            break;
        default:
            console.log('Unknown sub-tab:', tab);
    }
}

// Handle logout
function handleLogout() {
    // Logout is now handled by logout-modal.js
}

// Store initial profile data for comparison
let initialProfileData = {};

function markFormAsModified() {
    formModified = true;
}

function clearFormModified() {
    formModified = false;
}

function isFormModified() {
    return formModified;
}

// Handle document image selection
function handleDocumentSelect(e, type) {
    const file = e.target.files[0];
    
    if (!file) return;

    // Validate file type
    if (!file.type.startsWith('image/')) {
        showNotification('Please select an image file', 'error');
        return;
    }

    // Validate file size (5MB max)
    const maxSize = 5 * 1024 * 1024;
    if (file.size > maxSize) {
        showNotification('File size must be less than 5MB', 'error');
        return;
    }

    // Read and preview the file
    const reader = new FileReader();
    reader.onload = function(event) {
        const previewId = type === 'orcr' ? 'orcrImagePreview' : 'licenseImagePreview';
        const containerId = type === 'orcr' ? 'orcrImageContainer' : 'licenseImageContainer';
        
        const preview = document.getElementById(previewId);
        const container = document.getElementById(containerId);
        
        if (preview) {
            preview.src = event.target.result;
        } else {
            // Create image element if it doesn't exist
            const img = document.createElement('img');
            img.id = previewId;
            img.src = event.target.result;
            img.style.width = '100%';
            img.style.height = '100%';
            img.style.objectFit = 'cover';
            container.innerHTML = '';
            container.appendChild(img);
            
            // Add overlay
            const overlay = document.createElement('div');
            overlay.className = 'upload-overlay';
            overlay.innerHTML = `
                <i class="bi bi-camera"></i>
                <span>Update ${type === 'orcr' ? 'OR/CR' : 'License'}</span>
            `;
            container.appendChild(overlay);
        }
        
        if (container) {
            container.classList.add('has-image');
        }
    };
    reader.readAsDataURL(file);
}

// Handle documents form submit
async function handleDocumentsSubmit(e) {
    e.preventDefault();
    
    const orcrInput = document.getElementById('orcrImageInput');
    const licenseInput = document.getElementById('licenseImageInput');
    
    if (!orcrInput.files.length && !licenseInput.files.length) {
        showNotification('Please select at least one document to upload', 'error');
        return;
    }
    
    const formData = new FormData();
    if (orcrInput.files.length) {
        formData.append('or_cr', orcrInput.files[0]);
    }
    if (licenseInput.files.length) {
        formData.append('drivers_license', licenseInput.files[0]);
    }
    
    try {
        const response = await fetch('/rider/profile/update-documents', {
            method: 'POST',
            body: formData
        });

        const result = await response.json();

        if (result.success) {
            showNotification(result.message || 'Documents uploaded successfully!', 'success');
        } else {
            showNotification(result.message || 'Failed to upload documents', 'error');
        }
    } catch (error) {
        console.error('Error uploading documents:', error);
        showNotification('Failed to upload documents. Please try again.', 'error');
    }
}

// Handle license number input - allow only numbers, max 11 digits
function handleLicenseNumberInput(e) {
    const input = e.target;
    let value = input.value;
    
    // Remove any non-digit characters
    value = value.replace(/\D/g, '');
    
    // Limit to 11 digits
    if (value.length > 11) {
        value = value.slice(0, 11);
    }
    
    input.value = value;
    
    // Remove error styling if exists
    input.classList.remove('input-error');
}

// Validate license number on blur
function validateLicenseNumber(e) {
    const input = e.target;
    const value = input.value.trim();
    
    // Remove error styling
    input.classList.remove('input-error');
    
    if (value && !/^0\d{10}$/.test(value)) {
        // Add error styling
        input.classList.add('input-error');
        
        if (value.length !== 11) {
            showNotification('Phone number must be exactly 11 digits.', 'error');
        } else {
            showNotification('Phone number must start with 0.', 'error');
        }
    }
}

// Show notification
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
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 3000);
}

// Warn user before leaving if form is modified
// Disabled to avoid showing browser's default unstyled dialog
// window.addEventListener('beforeunload', function(e) {
//     if (isFormModified()) {
//         e.preventDefault();
//         e.returnValue = '';
//         return '';
//     }
// });
