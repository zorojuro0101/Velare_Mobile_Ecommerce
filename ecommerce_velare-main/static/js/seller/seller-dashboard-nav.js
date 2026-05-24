// seller-dashboard-nav.js
// Handles the active tab highlight behavior when hovering over other navigation tabs in seller dashboard

document.addEventListener('DOMContentLoaded', function() {
    const activeTab = document.querySelector('.main-tab.active');
    const allTabs = document.querySelectorAll('.main-tab');
    const profileName = document.querySelector('.profile-name-placeholder.clickable-profile');
    
    if (activeTab && allTabs.length > 0) {
        // Add hover event listeners to all navigation tabs
        allTabs.forEach(tab => {
            // Skip the active tab itself
            if (tab !== activeTab) {
                tab.addEventListener('mouseenter', function() {
                    // Don't affect the active tab if it's being hovered
                    if (!activeTab.matches(':hover')) {
                        activeTab.classList.add('tab-hover-inactive');
                    }
                });
                
                tab.addEventListener('mouseleave', function() {
                    activeTab.classList.remove('tab-hover-inactive');
                });
            }
        });
        
        // Ensure active tab highlight is restored when hovering over it
        activeTab.addEventListener('mouseenter', function() {
            activeTab.classList.remove('tab-hover-inactive');
        });
        
        // When hovering profile name, remove highlight from Dashboard tab
        if (profileName) {
            profileName.addEventListener('mouseenter', function() {
                // Add inactive class to Dashboard tab when hovering profile name
                activeTab.classList.add('tab-hover-inactive');
            });
            
            profileName.addEventListener('mouseleave', function() {
                // Remove inactive class from Dashboard tab when leaving profile name
                activeTab.classList.remove('tab-hover-inactive');
            });
        }
    }
});
