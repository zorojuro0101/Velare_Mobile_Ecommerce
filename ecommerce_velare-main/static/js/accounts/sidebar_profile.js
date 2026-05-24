// Shared sidebar profile loader for all account pages
// Only load if preload script hasn't already handled it
(function() {
    // Check if preload script already handled the profile
    if (window.__profilePreloadActive) {
        // Preload script is active, only load from server if no cache exists
        const cachedProfile = sessionStorage.getItem('userProfile') || localStorage.getItem('userProfile');
        if (!cachedProfile) {
            // No cache exists, load from server
            document.addEventListener('DOMContentLoaded', function() {
                loadSidebarProfile();
            });
        }
        // Otherwise, preload script already handled it, do nothing
        return;
    }
    
    // Fallback: preload script not active (shouldn't happen normally)
    const cachedProfile = sessionStorage.getItem('userProfile');
    
    if (cachedProfile) {
        // Use cached data immediately when DOM is ready
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function() {
                try {
                    const profile = JSON.parse(cachedProfile);
                    updateSidebarProfile(profile);
                } catch (e) {
                    console.error('Error parsing cached profile:', e);
                    loadSidebarProfile();
                }
            });
        } else {
            // DOM already loaded
            try {
                const profile = JSON.parse(cachedProfile);
                updateSidebarProfile(profile);
            } catch (e) {
                console.error('Error parsing cached profile:', e);
                loadSidebarProfile();
            }
        }
    } else {
        // No cache - load from server
        document.addEventListener('DOMContentLoaded', function() {
            loadSidebarProfile();
        });
    }
})();

async function loadSidebarProfile() {
    try {
        const response = await fetch('/api/profile/get');
        const data = await response.json();

        if (data.success && data.profile) {
            // Cache the profile data in BOTH storages for reliability
            const profileData = JSON.stringify(data.profile);
            sessionStorage.setItem('userProfile', profileData);
            localStorage.setItem('userProfile', profileData);
            updateSidebarProfile(data.profile);
        } else {
            // Show placeholders if no profile data
            showPlaceholders();
        }
    } catch (error) {
        console.error('Error loading sidebar profile:', error);
        showPlaceholders();
    }
}

function updateSidebarProfile(profile) {
    // Update profile name
    const sidebarProfileName = document.getElementById('sidebarProfileName');
    if (sidebarProfileName) {
        if (profile.first_name && profile.last_name) {
            sidebarProfileName.textContent = `${profile.first_name} ${profile.last_name}`;
        } else {
            sidebarProfileName.textContent = 'Guest User';
        }
        sidebarProfileName.classList.add('loaded');
    }

    // Update profile image
    const sidebarProfileImg = document.getElementById('sidebarProfileImg');
    if (sidebarProfileImg) {
        if (profile.profile_image) {
            sidebarProfileImg.style.backgroundImage = `url('${profile.profile_image}')`;
            sidebarProfileImg.style.backgroundSize = 'cover';
            sidebarProfileImg.style.backgroundPosition = 'center';
            sidebarProfileImg.style.backgroundRepeat = 'no-repeat';
            // Hide the placeholder icon/text inside the circle
            sidebarProfileImg.innerHTML = '';
        }
        sidebarProfileImg.classList.add('loaded');
    }
}

function showPlaceholders() {
    const sidebarProfileName = document.getElementById('sidebarProfileName');
    const sidebarProfileImg = document.getElementById('sidebarProfileImg');
    
    if (sidebarProfileName) {
        sidebarProfileName.textContent = 'Guest User';
        sidebarProfileName.classList.add('loaded');
    }
    if (sidebarProfileImg) {
        sidebarProfileImg.classList.add('loaded');
    }
}
