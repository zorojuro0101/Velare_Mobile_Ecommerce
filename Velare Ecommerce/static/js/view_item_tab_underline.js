// Animated tab underline for view_item page (like register)
document.addEventListener('DOMContentLoaded', function() {
  const tabs = document.querySelectorAll('.tab');
  const underline = document.querySelector('.tab-underline');
  const tabNav = document.querySelector('.product-tabs');
  const tabContents = {
    description: document.getElementById('tab-description'),
    feedbacks: document.getElementById('tab-feedbacks')
  };

  function updateUnderline() {
    const activeTab = document.querySelector('.tab.active');
    const underlineBg = document.querySelector('.tab-underline-bg');
    if (!activeTab || !underline || !underlineBg) return;
    const bgRect = underlineBg.getBoundingClientRect();
    const tabRect = activeTab.getBoundingClientRect();
    const left = tabRect.left - bgRect.left;
    underline.style.width = tabRect.width + 'px';
    underline.style.transform = `translateX(${left}px)`;
  }

  tabs.forEach(tab => {
    tab.addEventListener('click', function() {
      tabs.forEach(t => t.classList.remove('active'));
      this.classList.add('active');
      // Show/hide tab content
      Object.keys(tabContents).forEach(key => {
        tabContents[key].style.display = 'none';
      });
      const tabKey = this.getAttribute('data-tab');
      if (tabContents[tabKey]) {
        tabContents[tabKey].style.display = 'block';
      }
      updateUnderline();
    });
  });

  // Initial position
  updateUnderline();
  // Show only the active tab's content on load
  tabs.forEach(tab => {
    if (tab.classList.contains('active')) {
      const tabKey = tab.getAttribute('data-tab');
      Object.keys(tabContents).forEach(key => {
        tabContents[key].style.display = (key === tabKey) ? 'block' : 'none';
      });
    }
  });
  window.addEventListener('resize', updateUnderline);
});
