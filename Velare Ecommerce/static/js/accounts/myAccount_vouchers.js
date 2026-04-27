document.addEventListener('DOMContentLoaded', () => {
    const hamburgerBtn = document.getElementById('hamburgerBtn');
    const sideMenu = document.querySelector('.side-menu');
    const overlay = document.querySelector('.side-menu-overlay');
    const myAccountTab = document.getElementById('myAccountTab');
    const myAccountSubTabs = document.getElementById('myAccountSubTabs');
    const mainTabs = document.querySelectorAll('.main-tab');
    const vouchersTab = document.getElementById('vouchersTab');

    // Sidebar (hamburger menu) functionality
    if (hamburgerBtn && sideMenu && overlay) {
        hamburgerBtn.addEventListener('click', () => {
            const isOpen = sideMenu.classList.toggle('open');
            overlay.classList.toggle('show', isOpen);
            hamburgerBtn.classList.toggle('open', isOpen);
        });

        overlay.addEventListener('click', () => {
            sideMenu.classList.remove('open');
            overlay.classList.remove('show');
            hamburgerBtn.classList.remove('open');
        });
    }

    // Set the active tab on page load
    if (vouchersTab) {
        mainTabs.forEach(tab => {
            if (tab !== myAccountTab) { // Don't deactivate My Account if a sub-tab is active
                tab.classList.remove('active');
            }
        });
        vouchersTab.classList.add('active');
    }

    const openSubTabs = () => {
        if (!myAccountSubTabs) return;
        myAccountSubTabs.style.display = 'flex';
        requestAnimationFrame(() => {
            myAccountSubTabs.classList.add('open');
            myAccountSubTabs.classList.remove('closing');
        });
        if (myAccountTab) {
            myAccountTab.classList.add('active');
        }
    };

    const closeSubTabs = () => {
        if (!myAccountSubTabs) return;
        myAccountSubTabs.classList.remove('open');
        myAccountSubTabs.classList.add('closing');
        myAccountSubTabs.addEventListener('transitionend', () => {
            myAccountSubTabs.classList.remove('closing');
            myAccountSubTabs.style.display = 'none';
        }, { once: true });
    };

    // Initialize sub-tabs as closed
    if (myAccountSubTabs) {
        myAccountSubTabs.style.display = 'none';
        myAccountSubTabs.classList.remove('open', 'closing');
    }

    // Since 'My Account' is a link, we don't need a click handler to toggle.
    // The profile page script will handle opening the sub-tabs.
    // However, for other main tabs, we ensure sub-tabs are closed.
    mainTabs.forEach(tab => {
        if (tab !== myAccountTab) {
            tab.addEventListener('click', () => {
                if (myAccountSubTabs && myAccountSubTabs.classList.contains('open')) {
                    closeSubTabs();
                    if (myAccountTab) {
                        myAccountTab.classList.remove('active');
                    }
                }
            });
        }
    });
});
