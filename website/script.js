/* ═══════════════════════════════════════════════════════════
   SentinelFlow Landing Page — Interactions & Animations
   ═══════════════════════════════════════════════════════════ */

document.addEventListener('DOMContentLoaded', () => {

    // ── Navbar Scroll Effect ────────────────────────────────
    const navbar = document.getElementById('navbar');
    window.addEventListener('scroll', () => {
        navbar.classList.toggle('scrolled', window.scrollY > 40);
    });

    // ── Mobile Nav Toggle ───────────────────────────────────
    const navToggle = document.getElementById('navToggle');
    const navLinks = document.getElementById('navLinks');
    const navActions = document.querySelector('.nav-actions');
    if (navToggle) {
        navToggle.addEventListener('click', () => {
            navLinks.classList.toggle('nav-open');
            navToggle.classList.toggle('active');
            if (navActions) navActions.classList.toggle('nav-open');
        });
    }

    // ── Smooth Scroll for Anchor Links ──────────────────────
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
            // Skip if this button has a modal trigger
            if (anchor.dataset.modal) return;
            e.preventDefault();
            const target = document.querySelector(anchor.getAttribute('href'));
            if (target) {
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                // Close mobile menu
                if (navLinks) navLinks.classList.remove('nav-open');
                if (navActions) navActions.classList.remove('nav-open');
                if (navToggle) navToggle.classList.remove('active');
            }
        });
    });

    // ── Animated Counter ────────────────────────────────────
    const counters = document.querySelectorAll('.hero-stat-value');
    let countersAnimated = false;

    function animateCounters() {
        if (countersAnimated) return;
        countersAnimated = true;

        counters.forEach(counter => {
            const target = parseFloat(counter.getAttribute('data-count'));
            const isDecimal = target % 1 !== 0;
            const duration = 2000;
            const startTime = performance.now();

            function updateCounter(currentTime) {
                const elapsed = currentTime - startTime;
                const progress = Math.min(elapsed / duration, 1);
                const eased = 1 - Math.pow(1 - progress, 3);

                const current = eased * target;
                counter.textContent = isDecimal ? current.toFixed(1) : Math.floor(current);

                if (progress < 1) {
                    requestAnimationFrame(updateCounter);
                } else {
                    counter.textContent = isDecimal ? target.toFixed(1) : Math.floor(target);
                }
            }

            requestAnimationFrame(updateCounter);
        });
    }

    // ── Intersection Observer for Scroll Animations ─────────
    const observerOptions = {
        threshold: 0.15,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('fade-in-up');
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    document.querySelectorAll('.feature-card, .step, .arch-card, .pricing-card').forEach((el, i) => {
        el.style.animationDelay = `${i * 0.08}s`;
        observer.observe(el);
    });

    const heroStats = document.querySelector('.hero-stats');
    if (heroStats) {
        const statsObserver = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    animateCounters();
                    statsObserver.unobserve(entry.target);
                }
            });
        }, { threshold: 0.5 });
        statsObserver.observe(heroStats);
    }

    // ── Parallax on Hero Orbs ───────────────────────────────
    const orbs = document.querySelectorAll('.hero-orb');
    window.addEventListener('mousemove', (e) => {
        const x = (e.clientX / window.innerWidth - 0.5) * 2;
        const y = (e.clientY / window.innerHeight - 0.5) * 2;

        orbs.forEach((orb, i) => {
            const speed = (i + 1) * 8;
            orb.style.transform = `translate(${x * speed}px, ${y * speed}px)`;
        });
    });

    // ── Tilt Effect on Feature Cards ────────────────────────
    document.querySelectorAll('.feature-card').forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            const centerX = rect.width / 2;
            const centerY = rect.height / 2;
            const rotateX = ((y - centerY) / centerY) * -3;
            const rotateY = ((x - centerX) / centerX) * 3;

            card.style.transform = `perspective(800px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) translateY(-4px)`;
        });

        card.addEventListener('mouseleave', () => {
            card.style.transform = 'perspective(800px) rotateX(0deg) rotateY(0deg) translateY(0)';
        });
    });

    // ═══════════════════ MODAL SYSTEM ═══════════════════
    const modalOverlay = document.getElementById('modalOverlay');
    const modal = document.getElementById('modal');
    const modalClose = document.getElementById('modalClose');
    const modalIcon = document.getElementById('modalIcon');
    const modalTitle = document.getElementById('modalTitle');
    const modalDesc = document.getElementById('modalDesc');
    const modalForm = document.getElementById('modalForm');
    const modalSuccess = document.getElementById('modalSuccess');
    const modalSubmitBtn = document.getElementById('modalSubmitBtn');
    const messageGroup = document.getElementById('messageGroup');
    const selectedPlan = document.getElementById('selectedPlan');

    const MODAL_CONFIG = {
        trial: {
            icon: '⚡',
            title: 'Start Your Free Trial',
            desc: 'Enter your details and we\'ll get you set up in under 2 minutes.',
            submitText: 'Start Trial',
            showMessage: false
        },
        demo: {
            icon: '🎯',
            title: 'Schedule a Demo',
            desc: 'Tell us about your needs and our team will set up a personalized walkthrough.',
            submitText: 'Request Demo',
            showMessage: true
        }
    };

    function openModal(type, plan) {
        const config = MODAL_CONFIG[type] || MODAL_CONFIG.trial;

        modalIcon.textContent = config.icon;
        modalTitle.textContent = config.title;
        modalDesc.textContent = config.desc;
        modalSubmitBtn.textContent = config.submitText;
        messageGroup.style.display = config.showMessage ? 'flex' : 'none';
        selectedPlan.value = plan || '';

        // Reset to form view
        modalForm.style.display = 'flex';
        modalSuccess.style.display = 'none';
        modalForm.reset();

        modalOverlay.classList.add('active');
        document.body.style.overflow = 'hidden';
    }

    function closeModal() {
        modalOverlay.classList.remove('active');
        document.body.style.overflow = '';
    }

    // Wire up ALL buttons with data-modal attribute
    document.querySelectorAll('[data-modal]').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            const type = btn.dataset.modal;
            const plan = btn.dataset.plan || '';
            openModal(type, plan);
        });
    });

    // Close modal
    modalClose.addEventListener('click', closeModal);
    modalOverlay.addEventListener('click', (e) => {
        if (e.target === modalOverlay) closeModal();
    });
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') closeModal();
    });

    // Form submission
    let isSubmitting = false;

    modalForm.addEventListener('submit', (e) => {
        // We DO NOT preventDefault here because we want the form to natively POST 
        // to the action URL targeting the hidden iframe.
        if (isSubmitting) {
            e.preventDefault();
            return;
        }
        isSubmitting = true;
        
        modalSubmitBtn.disabled = true;
        modalSubmitBtn.textContent = 'Submitting...';
        
        console.log('🚀 Sending lead to Salesforce Web-to-Lead...');
    });

    // Listen for the iframe load event
    // This fires when Salesforce finishes processing and redirects the iframe to the retURL
    const w2lIframe = document.getElementById('w2l_iframe');
    if (w2lIframe) {
        w2lIframe.addEventListener('load', () => {
            if (isSubmitting) {
                console.log('✅ Lead captured successfully!');
                
                // Show success state
                modalForm.style.display = 'none';
                modalSuccess.style.display = 'block';

                // Reset form state
                isSubmitting = false;
                modalSubmitBtn.disabled = false;

                // Auto-close after 3 seconds
                setTimeout(closeModal, 3000);
            }
        });
    }

});
