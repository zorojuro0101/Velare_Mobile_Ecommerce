// search-anim.js

document.addEventListener('DOMContentLoaded', function() {
    const searchIcon = document.getElementById('search-icon');
    const searchForm = document.getElementById('search-form');
    const searchInput = searchForm.querySelector('.search-input');

    let isOpen = false;

    function openSearch() {
        searchForm.classList.add('active');
        setTimeout(() => searchInput.focus(), 250);
        isOpen = true;
    }
    function closeSearch() {
        searchForm.classList.remove('active');
        isOpen = false;
    }


    searchIcon.addEventListener('click', function(e) {
        e.stopPropagation();
        if (!isOpen) {
            openSearch();
        } else {
            // If already open, treat as submit
            if (searchInput.value.trim() !== '') {
                searchForm.submit();
                closeSearch();
            } else {
                closeSearch();
            }
        }
    });

    // Press Enter to submit
    searchInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            e.preventDefault();
            if (searchInput.value.trim() !== '') {
                searchForm.submit();
            }
        }
    });

    // Close when clicking outside
    document.addEventListener('click', function(e) {
        if (isOpen && !searchForm.contains(e.target) && e.target !== searchIcon) {
            closeSearch();
        }
    });

    // Optional: ESC to close
    document.addEventListener('keydown', function(e) {
        if (isOpen && e.key === 'Escape') {
            closeSearch();
        }
    });

    // Handle form submission
    searchForm.addEventListener('submit', function(e) {
        const query = searchInput.value.trim();
        
        // If empty, prevent submission
        if (query === '') {
            e.preventDefault();
            closeSearch();
            return;
        }
        
        // Otherwise, let the form submit naturally to browse_product page
    });
});
