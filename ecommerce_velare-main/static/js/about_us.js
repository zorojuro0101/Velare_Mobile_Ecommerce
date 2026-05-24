// About Us Page - Scroll Animation with Sequential Effects
document.addEventListener('DOMContentLoaded', function() {
    // Slideshow functionality for Section 1
    const slideshowImages = document.querySelectorAll('.section-1 .slideshow-image');
    let currentSlide = 0;
    
    function showNextSlide() {
        // Fade out current slide
        slideshowImages[currentSlide].classList.remove('active');
        
        // Move to next slide
        currentSlide = (currentSlide + 1) % slideshowImages.length;
        
        // Fade in next slide
        slideshowImages[currentSlide].classList.add('active');
    }
    
    // Start slideshow - change image every 4 seconds
    if (slideshowImages.length > 0) {
        setInterval(showNextSlide, 4000);
    }
    
    // Slideshow functionality for Section 4
    const slideshowImagesSection4 = document.querySelectorAll('.section-4 .slideshow-image-section4');
    let currentSlideSection4 = 0;
    
    function showNextSlideSection4() {
        // Fade out current slide
        slideshowImagesSection4[currentSlideSection4].classList.remove('active');
        
        // Move to next slide
        currentSlideSection4 = (currentSlideSection4 + 1) % slideshowImagesSection4.length;
        
        // Fade in next slide
        slideshowImagesSection4[currentSlideSection4].classList.add('active');
    }
    
    // Start slideshow - change image every 4 seconds
    if (slideshowImagesSection4.length > 0) {
        setInterval(showNextSlideSection4, 4000);
    }
    
    // Slideshow functionality for Section 5
    const slideshowImagesSection5 = document.querySelectorAll('.section-5 .slideshow-image-section5');
    let currentSlideSection5 = 0;
    
    function showNextSlideSection5() {
        // Fade out current slide
        slideshowImagesSection5[currentSlideSection5].classList.remove('active');
        
        // Move to next slide
        currentSlideSection5 = (currentSlideSection5 + 1) % slideshowImagesSection5.length;
        
        // Fade in next slide
        slideshowImagesSection5[currentSlideSection5].classList.add('active');
    }
    
    // Start slideshow - change image every 4 seconds
    if (slideshowImagesSection5.length > 0) {
        setInterval(showNextSlideSection5, 4000);
    }
    
    // Slideshow functionality for Section 6
    const slideshowImagesSection6 = document.querySelectorAll('.section-6 .slideshow-image-section6');
    let currentSlideSection6 = 0;
    
    function showNextSlideSection6() {
        // Fade out current slide
        slideshowImagesSection6[currentSlideSection6].classList.remove('active');
        
        // Move to next slide
        currentSlideSection6 = (currentSlideSection6 + 1) % slideshowImagesSection6.length;
        
        // Fade in next slide
        slideshowImagesSection6[currentSlideSection6].classList.add('active');
    }
    
    // Start slideshow - change image every 4 seconds
    if (slideshowImagesSection6.length > 0) {
        setInterval(showNextSlideSection6, 4000);
    }
    
    // Get all sections with fade-in animation
    const fadeInSections = document.querySelectorAll('.fade-in-section');
    
    // Options for Intersection Observer
    const observerOptions = {
        root: null, // viewport
        rootMargin: '0px',
        threshold: 0.15 // Trigger when 15% of the element is visible
    };
    
    // Callback function for Intersection Observer
    const observerCallback = (entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                // Add the visible class when element enters viewport
                entry.target.classList.add('is-visible');
                
                // Handle sequential animations for specific sections
                if (entry.target.classList.contains('section-1')) {
                    animateSection1(entry.target);
                } else if (entry.target.classList.contains('section-2')) {
                    animateSection2(entry.target);
                } else if (entry.target.classList.contains('section-3')) {
                    animateSection3(entry.target);
                } else if (entry.target.classList.contains('section-4')) {
                    animateSection4(entry.target);
                } else if (entry.target.classList.contains('section-5')) {
                    animateSection5(entry.target);
                } else if (entry.target.classList.contains('section-6')) {
                    animateSection6(entry.target);
                } else if (entry.target.classList.contains('section-7')) {
                    animateSection7(entry.target);
                } else if (entry.target.classList.contains('section-8')) {
                    animateSection8(entry.target);
                } else if (entry.target.classList.contains('section-9')) {
                    animateSection9(entry.target);
                }
            }
        });
    };
    
    // Section 1: Text first, then image (slow animation from bottom)
    function animateSection1(section) {
        const textContent = section.querySelector('.text-content');
        const imageContent = section.querySelector('.image-placeholder');
        
        if (textContent && imageContent) {
            setTimeout(() => {
                textContent.style.opacity = '1';
                textContent.style.transform = 'translateY(0)';
            }, 200);
            
            setTimeout(() => {
                imageContent.style.opacity = '1';
                imageContent.style.transform = 'translateY(0)';
            }, 1400);
        }
    }
    
    // Section 2: Our Story, Born from, Elegance, Guided by, Conscience, story-description (slow one by one)
    function animateSection2(section) {
        const storyTitle = section.querySelector('.story-title');
        const storySubtitles = section.querySelectorAll('.story-subtitle');
        const storyDescription = section.querySelector('.story-description');
        
        // 1. Our Story
        if (storyTitle) {
            setTimeout(() => {
                storyTitle.style.opacity = '1';
                storyTitle.style.transform = 'translateY(0)';
            }, 200);
        }
        
        // 2. Born from (first subtitle without highlight)
        if (storySubtitles.length > 0) {
            setTimeout(() => {
                storySubtitles[0].style.opacity = '1';
                storySubtitles[0].style.transform = 'translateY(0)';
            }, 1200);
            
            // 3. Elegance (first highlight)
            const firstHighlight = storySubtitles[0].querySelector('.highlight');
            if (firstHighlight) {
                setTimeout(() => {
                    firstHighlight.style.opacity = '1';
                    firstHighlight.style.transform = 'translateY(0)';
                }, 2200);
            }
            
            // 4. Guided by (second subtitle without highlight)
            if (storySubtitles.length > 1) {
                setTimeout(() => {
                    storySubtitles[1].style.opacity = '1';
                    storySubtitles[1].style.transform = 'translateY(0)';
                }, 3200);
                
                // 5. Conscience (second highlight)
                const secondHighlight = storySubtitles[1].querySelector('.highlight');
                if (secondHighlight) {
                    setTimeout(() => {
                        secondHighlight.style.opacity = '1';
                        secondHighlight.style.transform = 'translateY(0)';
                    }, 4200);
                }
            }
        }
        
        // 6. Story description
        if (storyDescription) {
            setTimeout(() => {
                storyDescription.style.opacity = '1';
                storyDescription.style.transform = 'translateY(0)';
            }, 5200);
        }
    }
    
    // Section 3: sustainability-statement, sdg-intro, then SDGs one by one (very slow)
    function animateSection3(section) {
        const sustainabilityStatement = section.querySelector('.sustainability-statement');
        const sdgIntro = section.querySelector('.sdg-intro');
        const sdgPlaceholders = section.querySelectorAll('.sdg-placeholder');
        
        if (sustainabilityStatement) {
            setTimeout(() => {
                sustainabilityStatement.style.opacity = '1';
                sustainabilityStatement.style.transform = 'translateY(0)';
            }, 200);
        }
        
        if (sdgIntro) {
            setTimeout(() => {
                sdgIntro.style.opacity = '1';
                sdgIntro.style.transform = 'translateY(0)';
            }, 1200);
        }
        
        // Animate SDGs sequentially - one by one slowly from bottom
        sdgPlaceholders.forEach((sdg, index) => {
            setTimeout(() => {
                sdg.style.opacity = '1';
                sdg.style.transform = 'translateY(0)';
            }, 2200 + (index * 800));
        });
    }
    
    // Section 4: Text first, then image
    function animateSection4(section) {
        const empowermentContent = section.querySelector('.empowerment-content');
        const imageContent = section.querySelector('.image-placeholder');
        
        if (empowermentContent) {
            setTimeout(() => {
                empowermentContent.style.opacity = '1';
                empowermentContent.style.transform = 'translateY(0)';
            }, 200);
        }
        
        if (imageContent) {
            setTimeout(() => {
                imageContent.style.opacity = '1';
                imageContent.style.transform = 'translateY(0)';
            }, 1400);
        }
    }
    
    // Section 5: Hero background first, then text
    function animateSection5(section) {
        const sustainabilityHero = section.querySelector('.sustainability-hero');
        const sustainabilityDetails = section.querySelector('.sustainability-details');
        
        if (sustainabilityHero) {
            setTimeout(() => {
                sustainabilityHero.style.opacity = '1';
                sustainabilityHero.style.transform = 'translateY(0)';
            }, 200);
        }
        
        if (sustainabilityDetails) {
            setTimeout(() => {
                sustainabilityDetails.style.opacity = '1';
                sustainabilityDetails.style.transform = 'translateY(0)';
            }, 1400);
        }
    }
    
    // Section 6: Text first, then image
    function animateSection6(section) {
        const traditionContent = section.querySelector('.tradition-content');
        const imageContent = section.querySelector('.image-placeholder');
        
        if (traditionContent) {
            setTimeout(() => {
                traditionContent.style.opacity = '1';
                traditionContent.style.transform = 'translateY(0)';
            }, 200);
        }
        
        if (imageContent) {
            setTimeout(() => {
                imageContent.style.opacity = '1';
                imageContent.style.transform = 'translateY(0)';
            }, 1400);
        }
    }
    
    // Section 7: All elements appear together at the same time
    function animateSection7(section) {
        const collaborationTitle = section.querySelector('.collaboration-title');
        const collaborationSubtitle = section.querySelector('.collaboration-subtitle');
        const collaborationDescription = section.querySelector('.collaboration-description');
        const collaborationSdg = section.querySelector('.collaboration-sdg');
        
        // All appear at the same time
        if (collaborationTitle) {
            setTimeout(() => {
                collaborationTitle.style.opacity = '1';
                collaborationTitle.style.transform = 'translateY(0)';
            }, 200);
        }
        
        if (collaborationSubtitle) {
            setTimeout(() => {
                collaborationSubtitle.style.opacity = '1';
                collaborationSubtitle.style.transform = 'translateY(0)';
            }, 200);
        }
        
        if (collaborationDescription) {
            setTimeout(() => {
                collaborationDescription.style.opacity = '1';
                collaborationDescription.style.transform = 'translateY(0)';
            }, 200);
        }
        
        if (collaborationSdg) {
            setTimeout(() => {
                collaborationSdg.style.opacity = '1';
                collaborationSdg.style.transform = 'translateY(0)';
            }, 200);
        }
    }
    
    // Section 8: Partnership items one by one
    function animateSection8(section) {
        const partnershipItems = section.querySelectorAll('.partnership-item');
        
        partnershipItems.forEach((item, index) => {
            setTimeout(() => {
                item.style.opacity = '1';
                item.style.transform = 'translateY(0)';
            }, 200 + (index * 800));
        });
    }
    
    // Section 9: Promise hero first, then description
    function animateSection9(section) {
        const promiseHero = section.querySelector('.promise-hero');
        const promiseDescription = section.querySelector('.promise-description-container');
        
        if (promiseHero) {
            setTimeout(() => {
                promiseHero.style.opacity = '1';
                promiseHero.style.transform = 'translateY(0)';
            }, 200);
        }
        
        if (promiseDescription) {
            setTimeout(() => {
                promiseDescription.style.opacity = '1';
                promiseDescription.style.transform = 'translateY(0)';
            }, 1400);
        }
    }
    
    // Create the observer
    const observer = new IntersectionObserver(observerCallback, observerOptions);
    
    // Observe all fade-in sections
    fadeInSections.forEach(section => {
        observer.observe(section);
    });
});
