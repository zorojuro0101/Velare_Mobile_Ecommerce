// myAccount Navigation - Prevents page refresh and flicker
(function() {
    'use strict';
    
    console.log('MyAccount Navigation Script Loaded');
    
    // Store current page state
    let currentPage = window.location.pathname;
    
    // Cache profile data on initial load
    function cacheProfileData() {
        const profileName = document.getElementById('sidebarProfileName');
        const profileImg = document.getElementById('sidebarProfileImg');
        
        if (profileName && profileName.textContent.trim() !== 'Guest User') {
            const profileData = {
                name: profileName.textContent.trim(),
                image: profileImg ? window.getComputedStyle(profileImg).backgroundImage : null
            };
            sessionStorage.setItem('sidebarProfileCache', JSON.stringify(profileData));
        }
    }
    
    // Restore profile data from cache
    function restoreProfileData() {
        const cached = sessionStorage.getItem('sidebarProfileCache');
        if (!cached) return;
        
        try {
            const profileData = JSON.parse(cached);
            const profileName = document.getElementById('sidebarProfileName');
            const profileImg = document.getElementById('sidebarProfileImg');
            
            if (profileName && profileData.name) {
                profileName.textContent = profileData.name;
                profileName.classList.add('loaded');
            }
            
            if (profileImg) {
                if (profileData.image && profileData.image !== 'none' && profileData.image !== 'null') {
                    profileImg.style.backgroundImage = profileData.image;
                } else {
                    // Clear any previous image if current user has no image
                    profileImg.style.backgroundImage = 'none';
                }
                profileImg.classList.add('loaded');
            }
        } catch (e) {
            console.error('Error restoring profile data:', e);
        }
    }
    
    // Function to load page content via AJAX
    function loadPageContent(url, pushState = true) {
        // Show loading state
        const contentContainer = document.querySelector('.account-card-bg');
        if (contentContainer) {
            contentContainer.style.opacity = '0.6';
        }
        
        // Fetch the new page
        fetch(url)
            .then(response => response.text())
            .then(html => {
                // Parse the HTML
                const parser = new DOMParser();
                const doc = parser.parseFromString(html, 'text/html');
                
                // Extract ONLY the content inside account-card-bg (NOT the sidebar)
                const newContent = doc.querySelector('.account-card-bg');
                const currentContent = document.querySelector('.account-card-bg');
                
                if (newContent && currentContent) {
                    // Replace ONLY the main content area, sidebar stays untouched
                    currentContent.innerHTML = newContent.innerHTML;
                    
                    // Restore opacity smoothly
                    setTimeout(() => {
                        currentContent.style.opacity = '1';
                    }, 50);
                    
                    // Update active tab in sidebar
                    updateActiveTab(url);
                    
                    // Update page title
                    const newTitle = doc.querySelector('title');
                    if (newTitle) {
                        document.title = newTitle.textContent;
                    }
                    
                    // Update browser history
                    if (pushState) {
                        history.pushState({ url: url }, '', url);
                        currentPage = url;
                    }
                    
                    // Re-initialize any page-specific scripts
                    reinitializeScripts();
                    
                    // Scroll to top of content
                    if (currentContent) {
                        currentContent.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    }
                }
            })
            .catch(error => {
                console.error('Error loading page:', error);
                // Fallback to normal navigation
                window.location.href = url;
            });
    }
    
    // Update active tab styling
    function updateActiveTab(url) {
        // Remove all active classes
        document.querySelectorAll('.sub-tab').forEach(tab => {
            tab.classList.remove('active');
        });
        
        // Add active class to matching tab
        const tabs = {
            '/myAccount/profile': '#profileTab',
            '/myAccount/address': '#addressesTab',
            '/myAccount/changepass': '#changePasswordTab'
        };
        
        for (const [path, selector] of Object.entries(tabs)) {
            if (url.includes(path)) {
                const tab = document.querySelector(selector);
                if (tab) {
                    tab.classList.add('active');
                }
                break;
            }
        }
    }
    
    // Re-initialize page-specific scripts
    function reinitializeScripts() {
        // Re-attach navigation listeners after content change
        interceptNavigation();
        
        // If we're on the profile page, reload profile data
        if (window.location.pathname.includes('/myAccount/profile')) {
            if (typeof loadProfileData === 'function') {
                loadProfileData();
            }
        }
        
        // Dispatch a custom event for other scripts to hook into
        window.dispatchEvent(new CustomEvent('myAccountContentLoaded'));
    }
    
    // Handle browser back/forward buttons
    window.addEventListener('popstate', function(event) {
        if (event.state && event.state.url) {
            loadPageContent(event.state.url, false);
        }
    });
    
    // Intercept navigation clicks
    function interceptNavigation() {
        // Get all navigation links in the sidebar (including <a> tags with sub-tab class)
        const navLinks = document.querySelectorAll('a.sub-tab, a.main-tab, .sub-tab[href], .main-tab[href]');
        
        console.log('MyAccount Navigation: Found', navLinks.length, 'navigation links');
        
        navLinks.forEach(link => {
            // Remove any existing listeners to prevent duplicates
            const newLink = link.cloneNode(true);
            link.parentNode.replaceChild(newLink, link);
            
            newLink.addEventListener('click', function(e) {
                const href = this.getAttribute('href');
                
                console.log('Navigation clicked:', href);
                
                // Only intercept myAccount pages, but exclude reports page (it has different structure)
                if (href && href.includes('/myAccount/') && !href.includes('/reports')) {
                    e.preventDefault();
                    e.stopPropagation();
                    console.log('Intercepting navigation to:', href);
                    loadPageContent(href);
                    return false;
                }
            });
        });
    }
    
    // Initialize when DOM is ready
    function initialize() {
        console.log('Initializing myAccount navigation...');
        
        // Mark profile elements as loaded immediately to prevent CSS hiding
        const profileName = document.getElementById('sidebarProfileName');
        const profileImg = document.getElementById('sidebarProfileImg');
        if (profileName) profileName.classList.add('loaded');
        if (profileImg) profileImg.classList.add('loaded');
        
        interceptNavigation();
        cacheProfileData();
        restoreProfileData(); // Restore immediately on load to prevent flicker
        
        console.log('MyAccount navigation initialized');
    }
    
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initialize);
    } else {
        initialize();
    }
    
    // Store initial state
    history.replaceState({ url: currentPage }, '', currentPage);
})();
