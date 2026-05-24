// Category Navigation JavaScript
// Handles dynamic category title updates and navigation

document.addEventListener('DOMContentLoaded', function() {
    // Category mapping for display names
    const categoryMap = {
        'dresses-skirts': 'Dresses & Skirts',
        'tops-blouses': 'Tops & Blouses',
        'activewear-yoga': 'Activewear & Yoga Pants',
        'lingerie-sleepwear': 'Lingerie & Sleepwear',
        'jackets-coats': 'Jackets & Coats',
        'shoes-accessories': 'Shoes & Accessories'
    };

    // Function to get URL parameter
    function getUrlParameter(name) {
        name = name.replace(/[\[]/, '\\[').replace(/[\]]/, '\\]');
        const regex = new RegExp('[\\?&]' + name + '=([^&#]*)');
        const results = regex.exec(location.search);
        return results === null ? '' : decodeURIComponent(results[1].replace(/\+/g, ' '));
    }

    // Function to update category title
    function updateCategoryTitle() {
        const categoryTitleElement = document.getElementById('browseCategoryTitle');
        if (!categoryTitleElement) return;

        const category = getUrlParameter('category');
        
        if (category && categoryMap[category]) {
            categoryTitleElement.textContent = categoryMap[category];
        } else {
            categoryTitleElement.textContent = 'All Products';
        }
    }

    // Update title on page load
    updateCategoryTitle();

    // Handle category link clicks (for side menu navigation)
    const categoryLinks = document.querySelectorAll('.category-link');
    categoryLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            // Let the default navigation happen, the page will reload with new URL
            // The updateCategoryTitle function will handle the title change on the new page
        });
    });

    // Navigation tabs will work with default browser navigation
    // No JavaScript intervention needed for basic navigation
});
