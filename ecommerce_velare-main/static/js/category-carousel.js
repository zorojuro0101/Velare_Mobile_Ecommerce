// Category Carousel with Continuous Smooth Scroll
(function() {
    'use strict';

    const carouselTrack = document.querySelector('.carousel-track');
    const prevBtn = document.getElementById('carouselPrev');
    const nextBtn = document.getElementById('carouselNext');
    
    if (!carouselTrack || !prevBtn || !nextBtn) return;

    const cardWidth = 420; // Card width
    const gap = 24; // Gap between cards
    const scrollAmount = cardWidth + gap;
    const cards = Array.from(carouselTrack.children);
    const totalCards = cards.length;

    // Clone cards multiple times for seamless infinite scroll
    for (let i = 0; i < 3; i++) {
        cards.forEach(card => {
            const clone = card.cloneNode(true);
            carouselTrack.appendChild(clone);
        });
    }

    let currentPosition = 0;
    let isAnimating = false;
    let autoScrollAnimation;

    // Continuous smooth auto-scroll
    function startAutoScroll() {
        function animate() {
            if (!isAnimating) {
                currentPosition -= 1; // Smooth continuous movement
                
                // Reset position for infinite loop
                const resetPoint = -(scrollAmount * totalCards);
                if (currentPosition <= resetPoint) {
                    currentPosition = 0;
                }
                
                carouselTrack.style.transform = `translateX(${currentPosition}px)`;
            }
            autoScrollAnimation = requestAnimationFrame(animate);
        }
        animate();
    }

    function stopAutoScroll() {
        if (autoScrollAnimation) {
            cancelAnimationFrame(autoScrollAnimation);
        }
    }

    // Manual navigation
    function scrollCarousel(direction) {
        isAnimating = true;
        const targetPosition = direction === 'next' 
            ? currentPosition - scrollAmount 
            : currentPosition + scrollAmount;
        
        // Smooth transition for manual scroll
        carouselTrack.style.transition = 'transform 0.5s ease';
        currentPosition = targetPosition;
        
        // Reset position if needed
        const resetPoint = -(scrollAmount * totalCards);
        if (currentPosition <= resetPoint) {
            currentPosition = 0;
        } else if (currentPosition > 0) {
            currentPosition = resetPoint + scrollAmount;
        }
        
        carouselTrack.style.transform = `translateX(${currentPosition}px)`;
        
        setTimeout(() => {
            carouselTrack.style.transition = 'none';
            isAnimating = false;
        }, 500);
    }

    // Event listeners
    nextBtn.addEventListener('click', () => scrollCarousel('next'));
    prevBtn.addEventListener('click', () => scrollCarousel('prev'));

    // Pause on hover
    carouselTrack.addEventListener('mouseenter', function() {
        isAnimating = true;
        stopAutoScroll();
    });

    carouselTrack.addEventListener('mouseleave', function() {
        isAnimating = false;
        carouselTrack.style.transition = 'none';
        startAutoScroll();
    });

    // Start auto-scroll
    startAutoScroll();
})();
