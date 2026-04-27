// Toggle .active class on star button to keep it yellow after click
// This script is for the cart page star icon

document.addEventListener('DOMContentLoaded', function() {
  document.querySelectorAll('.cart-action-btn.star').forEach(function(btn) {
    btn.addEventListener('click', function() {
      btn.classList.toggle('active');
    });
  });
});
