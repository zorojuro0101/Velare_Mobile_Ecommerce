// logout-modal.js
// Handles logout confirmation modal logic for all pages

document.addEventListener('DOMContentLoaded', function() {
    var logoutLink = document.getElementById('logout-link');
    var modal = document.getElementById('logout-modal');
    var overlay = document.getElementById('logout-modal-overlay');
    var confirmBtn = document.getElementById('confirm-logout');
    var cancelBtn = document.getElementById('cancel-logout');
    function showModal() {
        if (modal) modal.style.display = 'flex';
        if (overlay) overlay.classList.add('show');
    }
    function hideModal() {
        if (modal) modal.style.display = 'none';
        if (overlay) overlay.classList.remove('show');
    }
    if (logoutLink && modal && confirmBtn && cancelBtn && overlay) {
        logoutLink.addEventListener('click', function(e) {
            e.preventDefault();
            showModal();
        });
        cancelBtn.addEventListener('click', function() {
            hideModal();
        });
        confirmBtn.addEventListener('click', function() {
            // Clear cached profile data on logout
            sessionStorage.removeItem('userProfile');
            sessionStorage.removeItem('sidebarProfileCache');
            localStorage.removeItem('userProfile');
            localStorage.removeItem('velareUserProfile');
            
            // Clear global state
            if (window.VelareApp) {
                window.VelareApp.userProfile = null;
            }
            
            // Call the logout route to clear server-side session
            fetch('/logout', {
                method: 'GET',
                credentials: 'same-origin'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Redirect to login page
                    window.location.href = data.redirect || '/login';
                } else {
                    // Even if logout fails, redirect to login
                    window.location.href = '/login';
                }
            })
            .catch(error => {
                console.error('Logout error:', error);
                // Even if there's an error, redirect to login
                window.location.href = '/login';
            });
        });
        // Close modal on outside click
        modal.addEventListener('click', function(e) {
            if (e.target === modal) hideModal();
        });
        overlay.addEventListener('click', hideModal);
    }
});
