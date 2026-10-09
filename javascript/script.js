/* ============================================
   SANTI BLINDS — script.js
   ============================================ */

'use strict';

/* ---- NAV: Scroll & Mobile Toggle ---- */
(function initNav() {
  const nav = document.getElementById('nav');
  const hamburger = document.getElementById('hamburger');
  const navLinks = document.getElementById('navLinks');
  if (!nav || !hamburger || !navLinks) return;

  // Scroll state
  window.addEventListener('scroll', () => {
    nav.classList.toggle('scrolled', window.scrollY > 40);
  }, { passive: true });

  // Hamburger toggle
  hamburger.addEventListener('click', () => {
    const isOpen = navLinks.classList.toggle('open');
    hamburger.classList.toggle('open', isOpen);
    hamburger.setAttribute('aria-expanded', isOpen);
  });

  // Close on link click (mobile)
  navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      navLinks.classList.remove('open');
      hamburger.classList.remove('open');
    });
  });

  // Close on outside click
  document.addEventListener('click', (e) => {
    if (!nav.contains(e.target)) {
      navLinks.classList.remove('open');
      hamburger.classList.remove('open');
    }
  });
})();


/* ---- SCROLL REVEAL ---- */
(function initReveal() {
  const elements = document.querySelectorAll('.reveal');
  if (!elements.length) return;

  function revealIfVisible(el) {
    const rect = el.getBoundingClientRect();
    return rect.top < window.innerHeight * 0.92;
  }

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const el = entry.target;
        const delay = el.dataset.delay ? parseInt(el.dataset.delay) : 0;
        setTimeout(() => {
          el.classList.add('in-view');
        }, delay);
        observer.unobserve(el);
      }
    });
  }, {
    threshold: 0.08,
    rootMargin: '0px 0px -40px 0px'
  });

  elements.forEach(el => {
    if (revealIfVisible(el)) {
      const delay = el.dataset.delay ? parseInt(el.dataset.delay) : 0;
      setTimeout(() => el.classList.add('in-view'), 100 + delay);
    } else {
      observer.observe(el);
    }
  });
})();


/* ---- HERO: Animate in on load (index page only) ---- */
(function initHeroLoad() {
  const heroReveals = document.querySelectorAll('.hero .reveal');
  if (!heroReveals.length) return;
  let delay = 200;
  heroReveals.forEach(el => {
    setTimeout(() => {
      el.classList.add('in-view');
    }, delay);
    delay += 120;
  });
})();


/* ---- PAGE HERO INNER PAGES: Animate in on load ---- */
(function initPageHeroLoad() {
  const pageHeroReveals = document.querySelectorAll('.page-hero .reveal');
  if (!pageHeroReveals.length) return;
  let delay = 150;
  pageHeroReveals.forEach(el => {
    setTimeout(() => {
      el.classList.add('in-view');
    }, delay);
    delay += 140;
  });
})();


/* ---- TESTIMONIALS SLIDER ---- */
(function initTestimonials() {
  const slides = document.querySelectorAll('.testimonial');
  const dotsContainer = document.getElementById('tDots');
  const prevBtn = document.getElementById('tPrev');
  const nextBtn = document.getElementById('tNext');
  if (!slides.length || !dotsContainer) return;

  let current = 0;
  let autoTimer;

  slides.forEach((_, i) => {
    const dot = document.createElement('button');
    dot.className = 't-dot' + (i === 0 ? ' active' : '');
    dot.setAttribute('aria-label', `Go to testimonial ${i + 1}`);
    dot.addEventListener('click', () => goTo(i));
    dotsContainer.appendChild(dot);
  });

  function goTo(index) {
    slides[current].classList.remove('active');
    dotsContainer.children[current].classList.remove('active');
    current = (index + slides.length) % slides.length;
    slides[current].classList.add('active');
    dotsContainer.children[current].classList.add('active');
    resetAuto();
  }

  function resetAuto() {
    clearInterval(autoTimer);
    autoTimer = setInterval(() => goTo(current + 1), 5000);
  }

  if (prevBtn) prevBtn.addEventListener('click', () => goTo(current - 1));
  if (nextBtn) nextBtn.addEventListener('click', () => goTo(current + 1));

  let touchStartX = 0;
  const slider = document.getElementById('testimonialSlider');
  if (slider) {
    slider.addEventListener('touchstart', e => {
      touchStartX = e.touches[0].clientX;
    }, { passive: true });
    slider.addEventListener('touchend', e => {
      const diff = touchStartX - e.changedTouches[0].clientX;
      if (Math.abs(diff) > 40) goTo(diff > 0 ? current + 1 : current - 1);
    }, { passive: true });
  }

  resetAuto();
})();


/* ---- CONTACT FORM ---- */
(function initForm() {

  const form = document.getElementById('contactForm');
  if (!form) return;

  // ── Field error helpers ──────────────────────────────────

  function setError(field, msg) {
    const group = field.closest('.form-group') || field.closest('.form-check') || field.parentElement;
    group.classList.add('field--error');
    let hint = group.querySelector('.field-error-msg');
    if (!hint) {
      hint = document.createElement('span');
      hint.className = 'field-error-msg';
      group.appendChild(hint);
    }
    hint.textContent = msg;
  }

  function clearError(field) {
    const group = field.closest('.form-group') || field.closest('.form-check') || field.parentElement;
    group.classList.remove('field--error');
    const hint = group.querySelector('.field-error-msg');
    if (hint) hint.textContent = '';
  }

  function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  function shakeField(field) {
    field.style.animation = 'none';
    field.offsetHeight;
    field.style.animation = 'shake 0.4s ease';
  }

  // Product list comes from the database (inquiry.product_id).
  (async function loadProducts() {
    try {
      const res = await fetch('portal/catalog.php', { credentials: 'include' });
      const data = await res.json();
      if (!data.success) return;
      form.interest.insertAdjacentHTML('beforeend',
        data.products.map(p => `<option value="${p.product_id}">${p.name.replace(/[&<>"]/g, '')}</option>`).join(''));
    } catch (_) { /* the select just stays empty; submit will ask for a product */ }
  })();

  // Clear error on input/change
  form.querySelectorAll('input, select, textarea').forEach(el => {
    el.addEventListener('input', () => clearError(el));
    el.addEventListener('change', () => clearError(el));
  });

  // ── Validate all fields ──────────────────────────────────

  function validateForm() {
    let valid = true;

    const fields = [
      { el: form.fname,     msg: 'First name is required.' },
      { el: form.lname,     msg: 'Last name is required.' },
      { el: form.phone,     msg: 'Phone / mobile number is required.' },
      { el: form.city,      msg: 'City / municipality is required.' },
    ];

    fields.forEach(({ el, msg }) => {
      if (!el.value.trim()) {
        setError(el, msg);
        shakeField(el);
        valid = false;
      }
    });

    const emailVal = form.email.value.trim();
    if (!emailVal) {
      setError(form.email, 'Email address is required.');
      shakeField(form.email);
      valid = false;
    } else if (!isValidEmail(emailVal)) {
      setError(form.email, 'Please enter a valid email address.');
      shakeField(form.email);
      valid = false;
    }

    const selects = [
      { el: form.interest,  msg: "Please select a product you're interested in." },
      { el: form.preferred, msg: 'Please select a preferred schedule.' },
      { el: form.rooms,     msg: 'Please select the number of windows / rooms.' },
      { el: form.budget,    msg: 'Please select a budget range.' },
    ];

    selects.forEach(({ el, msg }) => {
      if (!el.value) {
        setError(el, msg);
        shakeField(el);
        valid = false;
      }
    });

    const consent = form.consent;
    if (!consent.checked) {
      setError(consent, 'You must agree to be contacted before submitting.');
      valid = false;
    }

    return valid;
  }

  // ── Success modal ────────────────────────────────────────

  function showSuccessModal() {
    const existing = document.getElementById('enquirySuccessModal');
    if (existing) existing.remove();

    const modal = document.createElement('div');
    modal.id = 'enquirySuccessModal';
    modal.style.cssText = `
      position:fixed;inset:0;z-index:9999;
      display:flex;align-items:center;justify-content:center;
      background:rgba(18,18,18,0.72);
      backdrop-filter:blur(6px);
      padding:20px;
      animation:fadeInModal 0.3s ease;
    `;

    modal.innerHTML = `
      <div style="
        background:#1a1a1a;
        border:1px solid rgba(201,169,110,0.3);
        border-radius:12px;
        padding:48px 40px 40px;
        max-width:460px;width:100%;
        text-align:center;
        position:relative;
        animation:scaleInModal 0.35s cubic-bezier(.34,1.56,.64,1);
      ">
        <button id="enquiryModalClose" aria-label="Close" style="
          position:absolute;top:16px;right:18px;
          background:none;border:none;cursor:pointer;
          color:#888;font-size:22px;line-height:1;padding:4px 8px;
        ">&#x2715;</button>

        <div style="
          width:56px;height:56px;border-radius:50%;
          background:rgba(201,169,110,0.12);
          border:1.5px solid rgba(201,169,110,0.4);
          display:flex;align-items:center;justify-content:center;
          margin:0 auto 24px;font-size:22px;color:#c9a96e;
        ">&#x2726;</div>

        <h2 style="
          margin:0 0 10px;
          font-family:'Anton',sans-serif;
          font-size:clamp(1.6rem,4vw,2rem);
          letter-spacing:.06em;
          color:#c9a96e;
        ">Enquiry Sent</h2>

        <p style="
          margin:0 0 6px;
          font-family:'Quicksand',sans-serif;
          font-size:1rem;
          color:#e0dbd2;
          line-height:1.6;
        ">Thank you! We'll be in touch within one business day.</p>

        <p style="
          margin:0 0 32px;
          font-family:'Quicksand',sans-serif;
          font-size:.875rem;
          color:#888;
          line-height:1.6;
        ">In the meantime, feel free to browse our collection.</p>

        <a href="products.html" style="
          display:inline-block;
          padding:.75rem 2rem;
          background:#c9a96e;
          color:#1a1a1a;
          font-family:'Quicksand',sans-serif;
          font-weight:700;
          font-size:.875rem;
          letter-spacing:.08em;
          text-transform:uppercase;
          text-decoration:none;
          border-radius:4px;
        ">View Our Products</a>
      </div>
    `;

    if (!document.getElementById('enquiryModalStyles')) {
      const style = document.createElement('style');
      style.id = 'enquiryModalStyles';
      style.textContent = `
        @keyframes fadeInModal  { from { opacity:0 } to { opacity:1 } }
        @keyframes scaleInModal { from { opacity:0; transform:scale(.88) } to { opacity:1; transform:scale(1) } }
      `;
      document.head.appendChild(style);
    }

    document.body.appendChild(modal);
    document.body.style.overflow = 'hidden';

    function closeModal() {
      modal.style.animation = 'fadeInModal 0.2s ease reverse';
      setTimeout(() => {
        modal.remove();
        document.body.style.overflow = '';
      }, 200);
    }

    document.getElementById('enquiryModalClose').addEventListener('click', closeModal);
    modal.addEventListener('click', (e) => { if (e.target === modal) closeModal(); });
    document.addEventListener('keydown', function handler(e) {
      if (e.key === 'Escape') { closeModal(); document.removeEventListener('keydown', handler); }
    });
  }

  // ── Form submit ──────────────────────────────────────────

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    if (!validateForm()) {
      const firstError = form.querySelector('.field--error input, .field--error select, .field--error textarea, .field--error');
      if (firstError) firstError.scrollIntoView({ behavior: 'smooth', block: 'center' });
      return;
    }

    const submitBtn = form.querySelector('button[type="submit"]');
    const originalText = submitBtn ? submitBtn.textContent : '';
    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.textContent = 'Sending\u2026';
    }

    try {
      const v = (el) => el.value.trim();
      // ERD's INQUIRY has no schedule/rooms/budget columns, so they go into the message.
      const extra = [
        form.preferred.value && `Preferred schedule: ${form.preferred.value}`,
        form.rooms.value && `Windows / rooms: ${form.rooms.value}`,
        form.budget.value && `Budget: ${form.budget.value}`,
      ].filter(Boolean);
      const response = await fetch('portal/inquiry.php', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          customer: { full_name: `${v(form.fname)} ${v(form.lname)}`, email: v(form.email), phone: v(form.phone), address: v(form.city) },
          product_id: Number(form.interest.value),
          message: [v(form.message), ...extra].filter(Boolean).join('\n'),
        }),
      });
      let json = null;
      try { json = JSON.parse(await response.text()); } catch (_) { /* handled below */ }

      if (json && json.success) {
        form.reset();
        showSuccessModal();
      } else {
        showFormError(form, (json && (Array.isArray(json.errors) ? json.errors.join(' ') : json.message)) || 'Something went wrong. Please try again.');
      }
    } catch (err) {
      showFormError(form, 'Could not reach the server. Please check your connection and try again.');
    } finally {
      if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = originalText; }
    }
  });

  function showFormError(form, message) {
    let errEl = form.querySelector('.form-error-banner');
    if (!errEl) {
      errEl = document.createElement('p');
      errEl.className = 'form-error-banner';
      errEl.style.cssText = 'color:#c0392b;background:#fff0f0;border:1px solid #f5c6c6;border-radius:6px;padding:.75rem 1rem;margin-bottom:1rem;font-size:.9rem;';
      form.prepend(errEl);
    }
    errEl.textContent = message;
    errEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
})();


/* ---- GALLERY: Filter + Lightbox ---- */
(function initGallery() {
  const filterBtns = document.querySelectorAll('.filter-btn');
  const galleryItems = document.querySelectorAll('.gallery-grid__item');

  if (filterBtns.length) {
    filterBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        filterBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const filter = btn.dataset.filter;
        galleryItems.forEach(item => {
          if (filter === 'all' || item.dataset.room === filter) {
            item.classList.remove('hidden');
          } else {
            item.classList.add('hidden');
          }
        });
      });
    });
  }

  const productFilterBtns = document.querySelectorAll('.filter-btn[data-filter]');
  const productCards = document.querySelectorAll('.product-card[data-category]');
  if (productCards.length && productFilterBtns.length) {
    productFilterBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        productFilterBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const filter = btn.dataset.filter;
        productCards.forEach(card => {
          if (filter === 'all' || card.dataset.category === filter) {
            card.style.display = '';
          } else {
            card.style.display = 'none';
          }
        });
      });
    });
  }

  const lightbox   = document.getElementById('lightbox');
  const lbBackdrop = document.getElementById('lightboxBackdrop');
  const lbImg      = document.getElementById('lightboxImg');
  const lbInfo     = document.getElementById('lightboxInfo');
  const lbClose    = document.getElementById('lightboxClose');
  const lbPrev     = document.getElementById('lightboxPrev');
  const lbNext     = document.getElementById('lightboxNext');
  if (!lightbox) return;

  let currentIdx = 0;
  const getVisible = () => [...galleryItems].filter(i => !i.classList.contains('hidden'));

  function openLightbox(idx) {
    const visible = getVisible();
    if (!visible.length) return;
    currentIdx = ((idx % visible.length) + visible.length) % visible.length;
    const item = visible[currentIdx];
    const fill = item.querySelector('.gallery-grid__fill');
    const label = item.querySelector('.gallery-grid__label');
    const product = item.querySelector('.gallery-grid__product');

    if (fill && lbImg) {
      lbImg.style.background = getComputedStyle(fill).background;
      lbImg.style.backgroundImage = getComputedStyle(fill).backgroundImage;
    }
    if (lbInfo) {
      lbInfo.textContent = (label ? label.textContent : '') + (product ? '  \xb7  ' + product.textContent : '');
    }
    lightbox.classList.add('open');
    lightbox.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
  }

  function closeLightbox() {
    lightbox.classList.remove('open');
    lightbox.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
  }

  galleryItems.forEach((item) => {
    item.addEventListener('click', () => {
      const visible = getVisible();
      const visIdx = visible.indexOf(item);
      openLightbox(visIdx);
    });
    item.setAttribute('tabindex', '0');
    item.setAttribute('role', 'button');
    item.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') {
        const visible = getVisible();
        openLightbox(visible.indexOf(item));
      }
    });
  });

  if (lbClose) lbClose.addEventListener('click', closeLightbox);
  if (lbBackdrop) lbBackdrop.addEventListener('click', closeLightbox);
  if (lbPrev) lbPrev.addEventListener('click', () => openLightbox(currentIdx - 1));
  if (lbNext) lbNext.addEventListener('click', () => openLightbox(currentIdx + 1));

  document.addEventListener('keydown', e => {
    if (!lightbox.classList.contains('open')) return;
    if (e.key === 'Escape') closeLightbox();
    if (e.key === 'ArrowLeft') openLightbox(currentIdx - 1);
    if (e.key === 'ArrowRight') openLightbox(currentIdx + 1);
  });

  let lbTouchX = 0;
  lightbox.addEventListener('touchstart', e => { lbTouchX = e.touches[0].clientX; }, { passive: true });
  lightbox.addEventListener('touchend', e => {
    const diff = lbTouchX - e.changedTouches[0].clientX;
    if (Math.abs(diff) > 40) openLightbox(diff > 0 ? currentIdx + 1 : currentIdx - 1);
  }, { passive: true });
})();


/* ---- FAQ ACCORDION ---- */
(function initFAQ() {
  const items = document.querySelectorAll('.faq__item, .faq-item');
  if (!items.length) return;

  items.forEach(item => {
    const btn = item.querySelector('.faq__q, .faq-item__q');
    if (!btn) return;
    btn.addEventListener('click', () => {
      const isOpen = item.classList.contains('open');
      items.forEach(i => {
        i.classList.remove('open');
        const b = i.querySelector('.faq__q, .faq-item__q');
        if (b) b.setAttribute('aria-expanded', 'false');
      });
      if (!isOpen) {
        item.classList.add('open');
        btn.setAttribute('aria-expanded', 'true');
      }
    });
  });
})();


/* ---- SMOOTH SCROLL ---- */
(function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', (e) => {
      const target = document.querySelector(anchor.getAttribute('href'));
      if (!target) return;
      e.preventDefault();
      const navH = parseInt(getComputedStyle(document.documentElement).getPropertyValue('--nav-h')) || 72;
      const top = target.getBoundingClientRect().top + window.scrollY - navH;
      window.scrollTo({ top, behavior: 'smooth' });
    });
  });
})();


/* ---- PARALLAX: Hero slat overlay subtle shift ---- */
(function initParallax() {
  const overlay = document.querySelector('.hero__slats-overlay');
  if (!overlay) return;
  window.addEventListener('scroll', () => {
    const y = window.scrollY;
    overlay.style.transform = `translateY(${y * 0.15}px)`;
  }, { passive: true });
})();


/* ---- MARQUEE: Seamless infinite loop ---- */
(function initMarquee() {
  document.querySelectorAll('.marquee').forEach(marquee => {
    const track = marquee.querySelector('.marquee__track');
    if (!track) return;

    track.style.animation = 'none';

    const originalChildren = Array.from(track.children);
    if (!originalChildren.length) return;

    const minWidth = window.innerWidth * 2;

    function getTotalWidth() {
      return track.scrollWidth;
    }

    let safetyLimit = 20;
    while (getTotalWidth() < minWidth && safetyLimit-- > 0) {
      originalChildren.forEach(child => {
        track.appendChild(child.cloneNode(true));
      });
    }

    const oneSetWidth = originalChildren.reduce((sum, el) => {
      return sum + el.getBoundingClientRect().width;
    }, 0);

    const uid = 'mq' + Math.random().toString(36).slice(2, 7);
    const style = document.createElement('style');
    style.textContent = `
      @keyframes ${uid} {
        from { transform: translateX(0); }
        to   { transform: translateX(-${oneSetWidth}px); }
      }
    `;
    document.head.appendChild(style);

    const basePx = 120;
    const duration = Math.round(oneSetWidth / basePx);
    track.style.animation = `${uid} ${duration}s linear infinite`;
  });
})();

/* ---- GALLERY LIGHTBOX: Real image support ---- */
(function initPhotoLightbox() {
  if (!document.getElementById('galleryGrid')) return;

  const lightbox   = document.getElementById('lightbox');
  const lbBackdrop = document.getElementById('lightboxBackdrop');
  const lbImg      = document.getElementById('lightboxImg');
  const lbInfo     = document.getElementById('lightboxInfo');
  const lbCounter  = document.getElementById('lightboxCounter');
  const lbClose    = document.getElementById('lightboxClose');
  const lbPrev     = document.getElementById('lightboxPrev');
  const lbNext     = document.getElementById('lightboxNext');
  if (!lightbox) return;

  let currentIdx = 0;

  function getVisible() {
    return [...document.querySelectorAll('.gallery-grid__item')]
      .filter(i => !i.classList.contains('hidden'));
  }

  function openLightbox(idx) {
    const visible = getVisible();
    if (!visible.length) return;
    currentIdx = ((idx % visible.length) + visible.length) % visible.length;
    const item = visible[currentIdx];

    const photo   = item.querySelector('.gallery-grid__photo');
    const tag     = item.querySelector('.gallery-grid__tag');
    const label   = item.querySelector('.gallery-grid__label');
    const product = item.querySelector('.gallery-grid__product');

    lbImg.innerHTML = '';
    if (photo) {
      const img = document.createElement('img');
      img.src = photo.src;
      img.alt = photo.alt || '';
      lbImg.appendChild(img);
    }

    if (lbInfo) {
      lbInfo.textContent =
        (tag     ? tag.textContent + '  \xb7  ' : '') +
        (label   ? label.textContent             : '') +
        (product ? '  \u2014  ' + product.textContent : '');
    }

    if (lbCounter) {
      lbCounter.textContent = (currentIdx + 1) + ' / ' + visible.length;
    }

    lightbox.classList.add('open');
    lightbox.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
  }

  function closeLightbox() {
    lightbox.classList.remove('open');
    lightbox.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
  }

  document.querySelectorAll('.gallery-grid__item').forEach(item => {
    item.addEventListener('click', () => {
      openLightbox(getVisible().indexOf(item));
    });
  });

  if (lbClose)    lbClose.addEventListener('click', closeLightbox);
  if (lbBackdrop) lbBackdrop.addEventListener('click', closeLightbox);
  if (lbPrev)     lbPrev.addEventListener('click', () => openLightbox(currentIdx - 1));
  if (lbNext)     lbNext.addEventListener('click', () => openLightbox(currentIdx + 1));

  document.addEventListener('keydown', e => {
    if (!lightbox.classList.contains('open')) return;
    if (e.key === 'Escape')     closeLightbox();
    if (e.key === 'ArrowLeft')  openLightbox(currentIdx - 1);
    if (e.key === 'ArrowRight') openLightbox(currentIdx + 1);
  });

  let lbTouchX = 0;
  lightbox.addEventListener('touchstart', e => { lbTouchX = e.touches[0].clientX; }, { passive: true });
  lightbox.addEventListener('touchend', e => {
    const diff = lbTouchX - e.changedTouches[0].clientX;
    if (Math.abs(diff) > 40) openLightbox(diff > 0 ? currentIdx + 1 : currentIdx - 1);
  }, { passive: true });
})();

/* ---- VIDEO SHOWCASE PLAYER ---- */
(function initVideoShowcase() {
  const video    = document.getElementById('vsVideo');
  const overlay  = document.getElementById('vsOverlay');
  const playBtn  = document.getElementById('vsPlayBtn');
  const pauseBtn = document.getElementById('vsPauseBtn');
  const durEl    = document.getElementById('vsDur');

  if (!video) return;

  video.addEventListener('loadedmetadata', function () {
    const t = Math.round(video.duration);
    const m = Math.floor(t / 60);
    const s = String(t % 60).padStart(2, '0');
    if (durEl) durEl.textContent = m + ':' + s;
  });

  function play() {
    video.play();
    overlay.style.opacity       = '0';
    overlay.style.pointerEvents = 'none';
    if (pauseBtn) pauseBtn.style.display = 'flex';
  }

  function pause() {
    video.pause();
    overlay.style.opacity       = '1';
    overlay.style.pointerEvents = 'auto';
    if (pauseBtn) pauseBtn.style.display = 'none';
  }

  if (playBtn)  playBtn.addEventListener('click',  play);
  if (pauseBtn) pauseBtn.addEventListener('click', pause);

  video.addEventListener('click', function () {
    video.paused ? play() : pause();
  });

  video.addEventListener('ended', function () {
    video.currentTime = 0;
    pause();
  });
})();
// ============================================================
//  SANTI BLINDS — ADMIN PANEL (aligned with the ERD)
//  Appended below the public-site script. Everything here is
//  guarded behind element checks, so it's harmless on the
//  public pages — it does nothing when the admin elements
//  aren't on the page.
//  Talks to admin/api/*.php using the PHP session cookie.
//  Pages: dashboard, orders, inventory, sales, customers (+ login).
// ============================================================

(function () {
  const ADMIN_API = 'api';

  // Escape anything that comes from the database before putting it in innerHTML.
  function esc(v) {
    return String(v ?? '').replace(/[&<>"']/g, ch => (
      { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]
    ));
  }

  // MySQL gives "2026-10-02 14:30:00"; Safari needs the "T". Treat as local time.
  function parseDate(v) {
    return new Date(String(v || '').replace(' ', 'T'));
  }
  function fmtDate(v) {
    const d = parseDate(v);
    return isNaN(d) ? '—' : d.toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric' });
  }

  // Read the response as text first so a PHP error page gives a useful message
  // instead of "Unexpected token <" from res.json().
  async function parseJson(res) {
    const raw = await res.text();
    try {
      return JSON.parse(raw);
    } catch (_) {
      console.error('Non-JSON response from', res.url, '\n', raw.slice(0, 500));
      throw new Error('Server returned an unexpected response (check Apache error.log).');
    }
  }

  async function adminApiGet(endpoint, params = {}) {
    const qs = new URLSearchParams(params).toString();
    const res = await fetch(`${ADMIN_API}/${endpoint}${qs ? '?' + qs : ''}`, { credentials: 'include' });
    if (res.status === 401) { window.location.href = 'admin-login.html'; return null; }
    return parseJson(res);
  }

  async function adminApiPost(endpoint, body = {}) {
    const res = await fetch(`${ADMIN_API}/${endpoint}`, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    // login.php answers 401 for a wrong password; let the login form show that message.
    if (res.status === 401 && endpoint !== 'login.php') { window.location.href = 'admin-login.html'; return null; }
    return parseJson(res);
  }

  function money(n) {
    return '₱' + Number(n || 0).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  function statusBadgeClass(status) {
    return {
      'Pending': 'admin-badge--pending',
      'Processing': 'admin-badge--processing',
      'Ready for Install': 'admin-badge--ready',
      'Completed': 'admin-badge--completed',
      'Cancelled': 'admin-badge--cancelled',
    }[status] || '';
  }
  const badge = s => `<span class="admin-badge ${statusBadgeClass(s)}">${esc(s)}</span>`;

  function statCard(label, value) {
    return `<div class="admin-stat-card"><span class="admin-stat-card__label">${label}</span><span class="admin-stat-card__value">${value}</span></div>`;
  }
  function emptyRow(cols, msg) {
    return `<tr><td colspan="${cols}" class="admin-empty">${esc(msg || 'No data yet.')}</td></tr>`;
  }
  function debounce(fn, ms) {
    let t;
    return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
  }

  // ---------- Runs on every admin-*.html page except admin-login.html ----------
  const sidebar = document.querySelector('.admin-sidebar');
  if (sidebar) {
    (async () => {
      const session = await adminApiGet('session.php');
      if (!session) return; // redirected to login
      const nameEl = document.getElementById('adminName');
      if (nameEl) nameEl.textContent = session.name;
    })();

    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) {
      logoutBtn.addEventListener('click', async () => {
        await adminApiPost('logout.php');
        window.location.href = 'admin-login.html';
      });
    }

    // Close buttons, click on the backdrop, and Escape.
    document.querySelectorAll('[data-close]').forEach((btn) => {
      btn.addEventListener('click', () => btn.closest('.admin-modal').hidden = true);
    });
    document.querySelectorAll('.admin-modal').forEach((m) => {
      m.addEventListener('click', (e) => { if (e.target === m) m.hidden = true; });
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') document.querySelectorAll('.admin-modal:not([hidden])').forEach(m => m.hidden = true);
    });
  }

  // ---------- admin-login.html (owner/manager signs in with email) ----------
  const loginForm = document.getElementById('loginForm');
  if (loginForm) {
    loginForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const errEl = document.getElementById('loginError');
      errEl.hidden = true;

      const email = document.getElementById('email').value.trim();
      const password = document.getElementById('password').value;

      try {
        const data = await adminApiPost('login.php', { email, password });
        if (data && data.success) {
          window.location.href = 'admin-dashboard.html';
        } else {
          errEl.textContent = (data && data.message) || 'Login failed.';
          errEl.hidden = false;
        }
      } catch (err) {
        errEl.textContent = (err && err.message && !/Failed to fetch/i.test(err.message)) ? err.message : 'Could not reach the server. Is Apache running?';
        errEl.hidden = false;
      }
    });
  }

  // ---------- admin-dashboard.html ----------
  const dashboardStats = document.getElementById('dashboardStats');
  if (dashboardStats) {
    (async () => {
      const data = await adminApiGet('dashboard.php');
      if (!data || !data.success) return;

      const s = data.stats;
      dashboardStats.innerHTML = `
        ${statCard('Total Orders', s.total_orders)}
        ${statCard('Pending Orders', s.pending_orders)}
        ${statCard('Total Customers', s.total_customers)}
        ${statCard('Revenue (This Month)', money(s.revenue_this_month))}
        ${statCard('Revenue (All Time)', money(s.revenue_total))}
        ${statCard('Low-Stock Products', s.low_stock_items)}
      `;

      const recent = document.querySelector('#recentOrdersTable tbody');
      if (recent) {
        recent.innerHTML = data.recent_orders.length ? data.recent_orders.map(o => `
          <tr><td>#${o.order_id}</td><td>${esc(o.full_name)}</td><td>${esc(o.products)}</td>
          <td>${badge(o.status)}</td><td>${money(o.amount)}</td></tr>
        `).join('') : emptyRow(5, 'No orders yet.');
      }

      const breakdown = document.getElementById('statusBreakdown');
      if (breakdown) {
        breakdown.innerHTML = data.status_breakdown.map(r => `
          <li>${badge(r.status)} <strong>${r.count}</strong></li>
        `).join('') || '<li class="admin-empty">No orders yet.</li>';
      }
    })();
  }

  // ---------- admin-orders.html ----------
  const ordersTable = document.getElementById('ordersTable');
  if (ordersTable) {
    const tbody = ordersTable.querySelector('tbody');
    const modal = document.getElementById('orderModal');
    const statusSel = document.getElementById('omStatus');
    const payWrap = document.getElementById('omPayWrap');
    const msgEl = document.getElementById('omMsg');
    let currentId = null;

    async function loadOrders() {
      const search = document.getElementById('orderSearch').value.trim();
      const status = document.getElementById('orderStatusFilter').value;
      const data = await adminApiGet('orders.php', { search, status });
      if (!data) return;
      if (!data.success) { tbody.innerHTML = emptyRow(8, data.message); return; }
      tbody.innerHTML = data.orders.length ? data.orders.map(o => `
        <tr>
          <td>#${o.order_id}</td>
          <td>${esc(o.full_name)}${o.quotation_ref ? `<br><small>from ${esc(o.quotation_ref)}</small>` : ''}</td>
          <td>${esc(o.products)}</td>
          <td>${o.quantity}</td><td>${money(o.amount)}</td><td>${badge(o.status)}</td>
          <td>${fmtDate(o.order_date)}</td>
          <td><button class="btn btn--ghost" data-view="${o.order_id}">View</button></td>
        </tr>
      `).join('') : emptyRow(8, 'No orders found.');
    }

    // Payment method only matters when the order is being marked Completed (it records the sale).
    const syncPay = () => { payWrap.hidden = statusSel.value !== 'Completed'; };
    statusSel.addEventListener('change', syncPay);

    tbody.addEventListener('click', async (e) => {
      const btn = e.target.closest('[data-view]');
      if (!btn) return;
      const data = await adminApiGet('orders.php', { id: btn.dataset.view });
      if (!data) return;
      if (!data.success) { alert(data.message); return; }

      const o = data.order;
      currentId = o.order_id;
      document.getElementById('omId').textContent = o.order_id;
      document.getElementById('omCustomer').textContent = o.full_name;
      document.getElementById('omPhone').textContent = o.phone || '—';
      document.getElementById('omEmail').textContent = o.email || '—';
      document.getElementById('omAddress').textContent = o.address || '—';
      document.getElementById('omDate').textContent = fmtDate(o.order_date);
      document.getElementById('omTotal').textContent = money(o.amount);
      document.getElementById('omSource').textContent = o.quotation_ref
        ? `From quotation ${o.quotation_ref}` : 'Direct order (from design)';

      // Customer specification: one row per item
      document.querySelector('#omItems tbody').innerHTML = data.items.map(i => `
        <tr>
          <td>${esc(i.product)}<br><small>${esc(i.blind_type)}</small></td>
          <td>${esc(i.material)}</td>
          <td><span style="display:inline-block;width:.8rem;height:.8rem;border:1px solid #888;border-radius:50%;margin-right:.35rem;vertical-align:middle;background:${esc(i.hex_code)}"></span>${esc(i.color)}</td>
          <td>${Number(i.width_cm)} × ${Number(i.height_cm)}</td>
          <td>${i.quantity}</td><td>${money(i.unit_price)}</td><td>${money(i.total_amount)}</td>
        </tr>
      `).join('');

      statusSel.value = o.status;
      document.getElementById('omPayment').value = data.sale ? data.sale.payment_method : 'Cash';
      msgEl.textContent = '';
      syncPay();
      modal.hidden = false;
    });

    document.getElementById('omSaveBtn').addEventListener('click', async () => {
      msgEl.textContent = 'Saving…';
      try {
        const res = await adminApiPost('orders.php', {
          id: currentId,
          status: statusSel.value,
          payment_method: document.getElementById('omPayment').value,
        });
        if (res && res.success) { modal.hidden = true; loadOrders(); }
        else msgEl.textContent = (res && res.message) || 'Could not save.';
      } catch (err) { msgEl.textContent = err.message; }
    });

    document.getElementById('orderSearch').addEventListener('input', debounce(loadOrders, 250));
    document.getElementById('orderStatusFilter').addEventListener('change', loadOrders);
    loadOrders();
  }

  // ---------- admin-inventory.html (product.stock_qty) ----------
  const inventoryTable = document.getElementById('inventoryTable');
  if (inventoryTable) {
    const tbody = inventoryTable.querySelector('tbody');

    async function loadInventory() {
      const data = await adminApiGet('inventory.php');
      if (!data) return;
      if (!data.success) { tbody.innerHTML = emptyRow(6, data.message); return; }
      const note = document.getElementById('lowStockNote');
      if (note) note.textContent = `Products with ${data.low_stock_level} or fewer in stock are flagged as low.`;

      tbody.innerHTML = data.inventory.length ? data.inventory.map(p => {
        const low = Number(p.low_stock) === 1;
        return `
          <tr>
            <td>${esc(p.name)}</td><td>${esc(p.category)}</td><td>${esc(p.blind_type)}</td>
            <td>${money(p.base_price)}</td>
            <td><span class="admin-badge ${low ? 'admin-badge--low' : 'admin-badge--ok'}">${p.stock_qty}${low ? ' (low)' : ''}</span></td>
            <td>
              <input type="number" min="0" value="${p.stock_qty}" data-qty="${p.product_id}" style="width:5.5rem" />
              <button class="btn btn--ghost" data-save="${p.product_id}">Save</button>
            </td>
          </tr>`;
      }).join('') : emptyRow(6, 'No products.');
    }

    tbody.addEventListener('click', async (e) => {
      const btn = e.target.closest('[data-save]');
      if (!btn) return;
      const input = tbody.querySelector(`[data-qty="${btn.dataset.save}"]`);
      btn.disabled = true;
      const res = await adminApiPost('inventory.php', { id: Number(btn.dataset.save), stock_qty: Number(input.value) });
      if (res && res.success) loadInventory();
      else { alert((res && res.message) || 'Could not update stock.'); btn.disabled = false; }
    });
    loadInventory();
  }

  // ---------- admin-sales.html (sale table) ----------
  const salesStats = document.getElementById('salesStats');
  if (salesStats) {
    (async () => {
      const data = await adminApiGet('sales.php');
      if (!data || !data.success) return;

      salesStats.innerHTML = `
        ${statCard('Total Revenue', money(data.total_revenue))}
        ${statCard('Average Sale', money(data.avg_sale_value))}
        ${statCard('Sales Recorded', data.sales_count)}
      `;

      const byMonth = document.querySelector('#salesByMonthTable tbody');
      if (byMonth) {
        byMonth.innerHTML = data.by_month.length ? data.by_month.map(m => `
          <tr><td>${esc(m.month)}</td><td>${m.orders}</td><td>${money(m.revenue)}</td></tr>
        `).join('') : emptyRow(3, 'No sales yet.');
      }

      const byProduct = document.querySelector('#salesByProductTable tbody');
      if (byProduct) {
        byProduct.innerHTML = data.by_product.length ? data.by_product.map(p => `
          <tr><td>${esc(p.product)}</td><td>${p.units}</td><td>${money(p.revenue)}</td></tr>
        `).join('') : emptyRow(3, 'No completed orders yet.');
      }
    })();
  }

  // ---------- admin-customers.html (customer profile + contact info) ----------
  const customersTable = document.getElementById('customersTable');
  if (customersTable) {
    const tbody = customersTable.querySelector('tbody');
    const modal = document.getElementById('customerModal');

    async function loadCustomers() {
      const search = document.getElementById('customerSearch').value.trim();
      const data = await adminApiGet('customers.php', { search });
      if (!data) return;
      if (!data.success) { tbody.innerHTML = emptyRow(6, data.message); return; }
      tbody.innerHTML = data.customers.length ? data.customers.map(c => `
        <tr>
          <td>${esc(c.full_name)}</td><td>${esc(c.phone || '—')}</td><td>${esc(c.email || '—')}</td>
          <td>${esc(c.address || '—')}</td><td>${c.order_count}</td>
          <td><button class="btn btn--ghost" data-view="${c.customer_id}">View</button></td>
        </tr>
      `).join('') : emptyRow(6, 'No customers found.');
    }

    tbody.addEventListener('click', async (e) => {
      const btn = e.target.closest('[data-view]');
      if (!btn) return;
      const data = await adminApiGet('customers.php', { id: btn.dataset.view });
      if (!data) return;
      if (!data.success) { alert(data.message); return; }

      const c = data.customer;
      document.getElementById('cmName').textContent = c.full_name;
      document.getElementById('cmPhone').textContent = c.phone || '—';
      document.getElementById('cmEmail').textContent = c.email || '—';
      document.getElementById('cmAddress').textContent = c.address || '—';
      document.getElementById('cmSince').textContent = fmtDate(c.created_at);

      document.querySelector('#cmOrdersTable tbody').innerHTML = data.orders.length ? data.orders.map(o => `
        <tr><td>#${o.order_id}</td>
        <td>${esc(o.products)}${o.quotation_ref ? `<br><small>from ${esc(o.quotation_ref)}</small>` : ''}</td>
        <td>${badge(o.status)}</td>
        <td>${money(o.amount)}</td><td>${fmtDate(o.order_date)}</td></tr>
      `).join('') : emptyRow(5, 'No orders yet.');

      document.querySelector('#cmInquiriesTable tbody').innerHTML = data.inquiries.length ? data.inquiries.map(q => `
        <tr><td>${fmtDate(q.created_at)}</td><td>${esc(q.product)}</td><td>${esc(q.message || '')}</td><td>${esc(q.status)}</td></tr>
      `).join('') : emptyRow(4, 'No inquiries.');

      renderQuotations(data.quotations || []);
      modal.hidden = false;
    });

    // ----- Quotations inside the customer profile -----
    const quotesBody = document.querySelector('#cmQuotesTable tbody');
    const QUOTE_BADGE = { Active: 'admin-badge--processing', Ordered: 'admin-badge--completed', Expired: 'admin-badge--cancelled' };

    function renderQuotations(quotes) {
      if (!quotes.length) { quotesBody.innerHTML = emptyRow(6, 'No quotations yet.'); return; }

      quotesBody.innerHTML = quotes.map(q => {
        const status = `<span class="admin-badge ${QUOTE_BADGE[q.status] || ''}">${esc(q.status)}</span>`
          + (q.order_id
              ? ` <small>→ order #${q.order_id}</small> ${badge(q.order_status)}`
              : '');
        return `
          <tr class="cm-quote-row" data-quote="${q.quotation_id}" style="cursor:pointer;">
            <td>${esc(q.reference)}</td><td>${fmtDate(q.created_at)}</td>
            <td>${q.item_count}</td><td>${money(q.total_amount)}</td>
            <td>${fmtDate(q.valid_until)}</td><td>${status}</td>
          </tr>
          <tr class="cm-quote-detail" data-detail="${q.quotation_id}" hidden>
            <td colspan="6">
              <table class="admin-table">
                <thead><tr><th>Product</th><th>Material</th><th>Color</th><th>Size (cm)</th><th>Qty</th><th>Unit Price</th><th>Amount</th></tr></thead>
                <tbody>
                  ${q.items.map(i => `
                    <tr><td>${esc(i.product)}</td><td>${esc(i.material)}</td><td>${esc(i.color)}</td>
                    <td>${i.width_cm} × ${i.height_cm}</td><td>${i.quantity}</td>
                    <td>${money(i.unit_price)}</td><td>${money(i.total_amount)}</td></tr>
                  `).join('')}
                </tbody>
              </table>
            </td>
          </tr>`;
      }).join('');
    }

    quotesBody.addEventListener('click', (e) => {
      const row = e.target.closest('.cm-quote-row');
      if (!row) return;
      const detail = quotesBody.querySelector(`[data-detail="${row.dataset.quote}"]`);
      if (detail) detail.hidden = !detail.hidden;
    });

    document.getElementById('customerSearch').addEventListener('input', debounce(loadCustomers, 250));
    loadCustomers();
  }
})();


/* ============================================================
   ORDER PAGE — order.html
   Register > Login > Customize > (optional Quotation) > Place order.
   A quotation is optional: an order can be placed straight from
   the cart (portal/order.php with items) or from a quotation
   (portal/order.php with quotation_id).
   Prices shown while designing are previews only; the server
   recomputes every price before saving, and an order keeps the
   prices it was placed at.
   ============================================================ */
(function initOrderPortal() {
  const app = document.getElementById('orderApp');
  if (!app) return;

  const API = 'portal';
  const $ = (id) => document.getElementById(id);
  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, ch => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
  const money = (n) => '₱' + Number(n || 0).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  // MySQL gives "2026-10-02 14:30:00"; Safari needs the "T".
  const fmtDate = (v) => {
    const d = new Date(String(v || '').replace(' ', 'T'));
    return isNaN(d) ? '—' : d.toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric' });
  };

  const state = { catalog: null, productId: null, colorId: null, cart: [], customer: null, quote: null };
  const PANELS = { auth: 'panelAuth', customize: 'panelCustomize', quote: 'panelQuote', review: 'panelReview', done: 'panelDone' };
  const STEP_INDEX = { auth: 0, customize: 1, quote: 2, review: 3, done: 4 };

  /* ---------- API ---------- */
  async function api(endpoint, body) {
    let res;
    try {
      res = await fetch(`${API}/${endpoint}`, {
        credentials: 'include',
        ...(body !== undefined ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : {}),
      });
    } catch (_) {
      throw new Error('Could not reach the server. Please check your connection and try again.');
    }
    const raw = await res.text();
    let data;
    try { data = JSON.parse(raw); } catch (_) {
      console.error('Non-JSON response from', res.url, raw.slice(0, 500));
      throw new Error('The server returned an unexpected response. Please try again.');
    }
    // A 401 from anywhere except the login form means the session ended.
    if (res.status === 401 && !endpoint.startsWith('customer_login')) {
      const err = new Error('Your session has ended. Please log in again.');
      err.auth = true;
      throw err;
    }
    return data;
  }

  /* ---------- UI helpers ---------- */
  function showAlert(msg, ok) {
    const el = $('orderAlert');
    const list = Array.isArray(msg) ? msg : [msg];
    el.className = 'order-alert' + (ok ? ' order-alert--ok' : '');
    el.innerHTML = list.length > 1 ? '<ul>' + list.map(m => `<li>${esc(m)}</li>`).join('') + '</ul>' : esc(list[0]);
    el.hidden = false;
  }
  function clearAlert() { $('orderAlert').hidden = true; }
  function resultErrors(res, fallback) { return res.errors || res.message || fallback; }
  function fail(err) {
    if (err && err.auth) return sessionEnded();
    showAlert((err && err.message) || 'Something went wrong.');
  }

  function go(step) {
    Object.entries(PANELS).forEach(([k, id]) => { $(id).hidden = k !== step; });
    const cur = STEP_INDEX[step];
    document.querySelectorAll('#orderSteps li').forEach((li, i) => {
      li.classList.toggle('is-done', i < cur);
      li.classList.toggle('is-current', i === cur);
      li.toggleAttribute('aria-current', i === cur);
    });
    const h = $(PANELS[step]).querySelector('.order-panel__title');
    if (h) h.focus({ preventScroll: true });
    window.scrollTo({ top: Math.max(0, app.offsetTop - 100), behavior: 'smooth' });
    if (step === 'customize') updatePreview();
  }

  /* ---------- Account: log in / register ---------- */
  function renderUser() {
    $('orderUser').hidden = !state.customer;
    $('userName').textContent = state.customer ? state.customer.full_name : '';
  }

  function showAuth(mode) {
    const reg = mode === 'register';
    $('custLoginForm').hidden = reg;
    $('custRegisterForm').hidden = !reg;
    $('authTitle').textContent = reg ? 'Create your account' : 'Log in';
    $('authLead').textContent = reg
      ? 'One account lets you design blinds, keep your quotations and place orders.'
      : 'Log in to design your blinds and place your order.';
  }

  function sessionEnded() {
    state.customer = null; state.quote = null;
    renderUser(); showAuth('login'); go('auth');
    showAlert('Your session has ended. Please log in again.');
  }

  async function startSession(customer) {
    state.customer = customer;
    renderUser();
    go('customize');
    loadSavedQuotes();
  }

  $('showRegisterBtn').addEventListener('click', () => { clearAlert(); showAuth('register'); });
  $('showLoginBtn').addEventListener('click', () => { clearAlert(); showAuth('login'); });

  $('custRegisterForm').addEventListener('submit', async (e) => {
    e.preventDefault(); clearAlert();
    const f = {
      full_name: $('rName').value.trim(), email: $('rEmail').value.trim(), phone: $('rPhone').value.trim(),
      address: $('rAddress').value.trim(), password: $('rPassword').value,
    };
    const errs = [];
    if (!f.full_name) errs.push('Please enter your full name.');
    if (!/^\S+@\S+\.\S+$/.test(f.email)) errs.push('Please enter a valid email address.');
    if (!/^[0-9+()\-\s]{7,20}$/.test(f.phone)) errs.push('Please enter a valid contact number.');
    if (!f.address) errs.push('Please enter your installation / delivery address.');
    if (f.password.length < 8) errs.push('Password must be at least 8 characters.');
    else if (f.password !== $('rConfirm').value) errs.push('The two passwords do not match.');
    if (!$('rConsent').checked) errs.push('Please agree to the terms to create an account.');
    if (errs.length) return showAlert(errs);

    const btn = $('registerBtn'); btn.disabled = true;
    try {
      const res = await api('customer_register.php', { ...f, consent: true });
      if (!res.success) return showAlert(resultErrors(res, 'Could not create your account.'));
      $('custRegisterForm').reset();
      showAuth('login');
      $('lEmail').value = f.email;
      $('lPassword').focus();
      showAlert('Account created. Log in to continue.', true);
    } catch (err) { fail(err); } finally { btn.disabled = false; }
  });

  $('custLoginForm').addEventListener('submit', async (e) => {
    e.preventDefault(); clearAlert();
    const email = $('lEmail').value.trim(), password = $('lPassword').value;
    if (!/^\S+@\S+\.\S+$/.test(email) || !password) return showAlert('Please enter your email and password.');

    const btn = $('loginBtn'); btn.disabled = true;
    try {
      const res = await api('customer_login.php', { email, password });
      if (!res.success) return showAlert(resultErrors(res, 'Could not log you in.'));
      $('custLoginForm').reset();
      await startSession(res.customer);
    } catch (err) { fail(err); } finally { btn.disabled = false; }
  });

  $('customerLogoutBtn').addEventListener('click', async () => {
    clearAlert();
    try { await api('customer_logout.php', {}); } catch (_) { /* log out locally either way */ }
    state.customer = null; state.quote = null; state.cart = [];
    renderCart(); renderSavedQuotes([]); renderUser(); showAuth('login'); go('auth');
    showAlert('You have been logged out.', true);
  });

  /* ---------- Catalog lookups ---------- */
  const productById  = (id) => state.catalog.products.find(p => +p.product_id === +id);
  const materialById = (id) => state.catalog.materials.find(m => +m.material_id === +id);
  const colorById    = (id) => state.catalog.colors.find(c => +c.color_id === +id);

  /* ---------- Design form ---------- */
  function buildForm() {
    const c = state.catalog;
    const box = $('typeTiles');
    box.setAttribute('role', 'radiogroup');
    box.innerHTML = '';
    c.products.forEach(p => {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'order-type'; b.dataset.product = p.product_id;
      b.setAttribute('role', 'radio');
      b.innerHTML = `<strong>${esc(p.name)}</strong><small>${esc(p.description || p.blind_type)}</small>`;
      b.addEventListener('click', () => selectProduct(p.product_id));
      box.appendChild(b);
    });

    $('cMaterial').innerHTML = c.materials.map(m =>
      `<option value="${m.material_id}">${esc(m.name)}${+m.price_modifier > 0 ? ` (+${money(m.price_modifier)})` : ''}</option>`).join('');

    const sw = $('swatches');
    sw.setAttribute('role', 'radiogroup');
    sw.innerHTML = '';
    c.colors.forEach(col => {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'order-swatch'; b.dataset.color = col.color_id;
      b.style.setProperty('--sw', col.hex_code);
      b.setAttribute('role', 'radio'); b.setAttribute('aria-label', col.name); b.title = col.name;
      b.addEventListener('click', () => { setColor(col.color_id); updatePreview(); });
      sw.appendChild(b);
    });

    ['cWidth', 'cHeight'].forEach(id => { $(id).min = c.limits.min_cm; $(id).max = c.limits.max_cm; });
    $('cQty').max = c.limits.max_qty;
    resetForm();

    $('customizeForm').addEventListener('input', updatePreview);
    $('customizeForm').addEventListener('change', updatePreview);
    window.addEventListener('resize', updatePreview);
  }

  function resetForm() {
    $('cWidth').value = 120; $('cHeight').value = 150; $('cQty').value = 1;
    $('cMaterial').selectedIndex = 0;
    setColor(state.catalog.colors[0].color_id);
    selectProduct(state.catalog.products[0].product_id);
  }

  function selectProduct(id) {
    state.productId = +id;
    document.querySelectorAll('#typeTiles .order-type').forEach(b => b.setAttribute('aria-checked', String(+b.dataset.product === +id)));
    updatePreview();
  }

  function setColor(id) {
    state.colorId = +id;
    document.querySelectorAll('#swatches .order-swatch').forEach(b => b.setAttribute('aria-checked', String(+b.dataset.color === +id)));
    const col = colorById(id);
    $('colorName').textContent = col ? '— ' + col.name : '';
  }

  function readSpec() {
    return {
      product_id: state.productId, material_id: +$('cMaterial').value, color_id: state.colorId,
      width_cm: parseFloat($('cWidth').value), height_cm: parseFloat($('cHeight').value),
      quantity: parseInt($('cQty').value, 10),
    };
  }

  // Mirrors unitPrice() in portal/catalog_lib.php (preview only; the server is the authority).
  function estimate(sp) {
    const L = state.catalog.limits, p = productById(sp.product_id), m = materialById(sp.material_id);
    if (!p || !m || !colorById(sp.color_id)) return null;
    if (!(sp.width_cm >= L.min_cm && sp.width_cm <= L.max_cm && sp.height_cm >= L.min_cm && sp.height_cm <= L.max_cm)
        || !(sp.quantity >= 1 && sp.quantity <= L.max_qty)) return null;
    const area = Math.max(L.min_area, (sp.width_cm * sp.height_cm) / 10000);
    const unit = Math.round((area * parseFloat(p.base_price) + parseFloat(m.price_modifier)) * 100) / 100;
    return { unit, total: Math.round(unit * sp.quantity * 100) / 100 };
  }

  function blindStyle(type) {
    const t = String(type || '').toLowerCase();
    if (/venetian|slat/.test(t)) return 'slats';
    if (/roman/.test(t)) return 'roman';
    if (/vertical/.test(t)) return 'vertical';
    if (/cellular|honeycomb/.test(t)) return 'cellular';
    if (/zebra/.test(t)) return 'zebra';
    return 'roller';
  }

  function blindBackground(style, hex) {
    switch (style) {
      case 'slats':    return `repeating-linear-gradient(180deg, ${hex} 0 9px, rgba(0,0,0,.35) 9px 11px)`;
      case 'roman':    return `repeating-linear-gradient(180deg, ${hex} 0 34px, rgba(0,0,0,.3) 34px 38px, rgba(255,255,255,.08) 38px 42px)`;
      case 'vertical': return `repeating-linear-gradient(90deg, ${hex} 0 16px, rgba(0,0,0,.35) 16px 18px)`;
      case 'cellular': return `repeating-linear-gradient(180deg, ${hex} 0 7px, rgba(0,0,0,.22) 7px 8px)`;
      case 'zebra':    return `repeating-linear-gradient(180deg, ${hex} 0 14px, rgba(255,255,255,.55) 14px 28px)`;
      default:         return hex;
    }
  }

  function updatePreview() {
    if (!state.catalog || !state.productId) return;
    const sp = readSpec(), p = productById(sp.product_id), m = materialById(sp.material_id), col = colorById(sp.color_id), L = state.catalog.limits;
    if (!p || !m || !col) return;

    const stage = document.querySelector('.order-preview__stage'), win = $('previewWindow');
    const ratio = Math.min(2.5, Math.max(0.4, (sp.width_cm / sp.height_cm) || 0.8));
    const sw = stage.clientWidth, sh = stage.clientHeight;
    if (sw && sh) {
      const w = Math.min(sw, sh * ratio);
      win.style.width = w + 'px'; win.style.height = (w / ratio) + 'px';
    }
    const blind = $('previewBlind');
    blind.style.background = blindBackground(blindStyle(p.blind_type), col.hex_code);
    blind.style.opacity = /Sheer/i.test(m.name) ? 0.65 : /Sunscreen|Light-filtering/i.test(m.name) ? 0.85 : 1;

    const rows = [['Type', p.name], ['Size', `${sp.width_cm || '—'} × ${sp.height_cm || '—'} cm`],
      ['Quantity', sp.quantity || '—'], ['Material', m.name], ['Colour', col.name]];
    $('previewList').innerHTML = rows.map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join('');

    const est = estimate(sp);
    $('previewTotal').textContent = est ? money(est.total) : '₱0.00';
    $('previewUnit').textContent = est
      ? (sp.quantity > 1 ? `${money(est.unit)} each × ${sp.quantity}` : '')
      : `Width and height must be ${L.min_cm}–${L.max_cm} cm; quantity 1–${L.max_qty}.`;
  }

  /* ---------- Cart (blinds going into the order) ---------- */
  const cartTotal = () => state.cart.reduce((s, i) => s + i.total, 0);

  function renderCart() {
    $('cartCard').hidden = !state.cart.length;
    $('cartBody').innerHTML = state.cart.map((it, i) => `<tr>
      <td>${esc(it.product)}<br><small>${esc(it.material)} · ${esc(it.color)}</small></td>
      <td>${esc(it.width_cm)} × ${esc(it.height_cm)}</td><td>${esc(it.quantity)}</td><td>${money(it.total)}</td>
      <td><button type="button" data-remove="${i}">Remove</button></td></tr>`).join('');
    $('cartTotal').textContent = money(cartTotal());
  }

  /* ---------- Saved quotations ---------- */
  function renderSavedQuotes(list) {
    const active = list.filter(q => q.status === 'Active');
    $('savedQuotesCard').hidden = !active.length;
    $('savedQuotesBody').innerHTML = active.map(q => `<tr>
      <td>${esc(q.reference)}</td><td>${esc(q.item_count)}</td><td>${money(q.total_amount)}</td>
      <td>${esc(fmtDate(q.valid_until))}</td>
      <td><button type="button" data-quote="${esc(q.quotation_id)}">View</button></td></tr>`).join('');
  }

  async function loadSavedQuotes() {
    try {
      const res = await api('quotation.php');
      renderSavedQuotes(res.success ? res.quotations : []);
    } catch (err) { if (err.auth) sessionEnded(); /* otherwise the list simply stays hidden */ }
  }

  $('savedQuotesBody').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-quote]'); if (!b) return;
    clearAlert(); b.disabled = true;
    try {
      const res = await api(`quotation.php?id=${encodeURIComponent(b.dataset.quote)}`);
      if (!res.success) return showAlert(resultErrors(res, 'Could not open that quotation.'));
      state.quote = res.quotation; renderQuote(); go('quote');
    } catch (err) { fail(err); } finally { b.disabled = false; }
  });

  /* ---------- Quotation (optional) ---------- */
  function quoteRow(it) {
    return `<tr>
      <td>${esc(it.product)}<br><small>${esc(it.material)} · ${esc(it.color)}</small></td>
      <td>${esc(it.width_cm)} × ${esc(it.height_cm)}</td><td>${esc(it.quantity)}</td>
      <td>${money(it.unit_price)}</td><td>${money(it.total_amount)}</td></tr>`;
  }

  function renderQuote() {
    const q = state.quote;
    $('quoteRef').textContent = `Quotation ${q.reference}`;
    $('quoteMeta').textContent = `Prepared for ${state.customer.full_name} on ${fmtDate(q.created_at)} · valid until ${fmtDate(q.valid_until)}`
      + (q.status === 'Ordered' ? ' · already ordered' : q.status === 'Expired' ? ' · expired' : '');
    $('quoteBody').innerHTML = q.items.map(quoteRow).join('');
    $('quoteTotal').textContent = money(q.total_amount);
    $('quoteContinueBtn').disabled = q.status !== 'Active';
  }

  // Review works from either a quotation (state.quote) or straight from the cart (no quotation).
  function renderReview() {
    const c = state.customer;
    const direct = !state.quote;
    const lines = direct
      ? state.cart.map(it => ({ ...it, total_amount: it.total }))
      : state.quote.items;
    const total = direct ? cartTotal() : state.quote.total_amount;

    $('reviewRef').textContent = direct ? '' : `(${state.quote.reference})`;
    $('reviewBody').innerHTML = lines.map(it => `<tr>
      <td>${esc(it.product)}<br><small>${esc(it.material)} · ${esc(it.color)}</small></td>
      <td>${esc(it.width_cm)} × ${esc(it.height_cm)}</td><td>${esc(it.quantity)}</td><td>${money(it.total_amount)}</td></tr>`).join('');
    $('reviewTotal').textContent = money(total);
    $('reviewAccount').innerHTML = [['Name', c.full_name], ['Email', c.email], ['Contact', c.phone]]
      .map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join('');
    $('oAddress').value = c.address || '';
  }

  /* ---------- Events ---------- */
  $('customizeForm').addEventListener('submit', (e) => {
    e.preventDefault(); clearAlert();
    const sp = readSpec(), est = estimate(sp), L = state.catalog.limits;
    if (!est) return showAlert(`Please enter a width and height of ${L.min_cm}–${L.max_cm} cm and a quantity of 1–${L.max_qty}.`);
    if (state.cart.length >= L.max_items) return showAlert(`An order can have at most ${L.max_items} items.`);
    state.cart.push({
      ...sp, unit: est.unit, total: est.total,
      product: productById(sp.product_id).name, material: materialById(sp.material_id).name, color: colorById(sp.color_id).name,
    });
    renderCart();
    showAlert('Added. Add another blind, or place your order.', true);
    $('cartCard').scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  });

  $('cartBody').addEventListener('click', (e) => {
    const b = e.target.closest('[data-remove]'); if (!b) return;
    state.cart.splice(+b.dataset.remove, 1);
    renderCart();
  });

  // Optional: place the order straight from the cart, skipping the quotation.
  $('orderNowBtn').addEventListener('click', () => {
    clearAlert();
    if (!state.cart.length) return showAlert('Add at least one blind first.');
    state.quote = null;
    renderReview(); go('review');
  });

  // Optional: get a saved, price-locked quotation first.
  $('getQuoteBtn').addEventListener('click', async () => {
    clearAlert();
    if (!state.cart.length) return showAlert('Add at least one blind first.');
    const btn = $('getQuoteBtn'); btn.disabled = true;
    try {
      const items = state.cart.map(({ product_id, material_id, color_id, width_cm, height_cm, quantity }) =>
        ({ product_id, material_id, color_id, width_cm, height_cm, quantity }));
      const res = await api('quotation.php', { items });
      if (!res.success) return showAlert(resultErrors(res, 'Could not prepare your quotation.'));
      state.quote = res.quotation;
      state.cart = []; renderCart();           // the quotation now holds these blinds
      loadSavedQuotes();
      renderQuote(); go('quote');
    } catch (err) { fail(err); } finally { btn.disabled = false; }
  });

  $('quoteBackBtn').addEventListener('click', () => { clearAlert(); go('customize'); });

  $('quotePrintBtn').addEventListener('click', () => {
    document.body.classList.add('printing-quote');
    window.addEventListener('afterprint', () => document.body.classList.remove('printing-quote'), { once: true });
    window.print();
  });

  $('quoteContinueBtn').addEventListener('click', () => {
    clearAlert();
    if (!state.quote || state.quote.status !== 'Active') return showAlert('This quotation can no longer be ordered. Please design again.');
    renderReview(); go('review');
  });

  $('reviewBackBtn').addEventListener('click', () => { clearAlert(); go(state.quote ? 'quote' : 'customize'); });

  $('orderForm').addEventListener('submit', async (e) => {
    e.preventDefault(); clearAlert();
    const btn = $('placeOrderBtn');
    const address = $('oAddress').value.trim();
    if (!state.quote && !state.cart.length) return showAlert('Add at least one blind first.');
    if (!address) return showAlert('Please enter the installation / delivery address.');

    const fromQuote = !!state.quote;
    const payload = fromQuote
      ? { quotation_id: state.quote.quotation_id, address }
      : { address, items: state.cart.map(({ product_id, material_id, color_id, width_cm, height_cm, quantity }) =>
          ({ product_id, material_id, color_id, width_cm, height_cm, quantity })) };

    btn.disabled = true;
    try {
      const res = await api('order.php', payload);
      if (!res.success) return showAlert(resultErrors(res, 'Could not place your order.'));
      state.customer.address = address;
      const first = state.customer.full_name.split(' ')[0];
      const basis = res.order.quotation ? `from quotation ${res.order.quotation}` : 'directly from your design';
      $('doneRef').textContent = `Reference ${res.order.reference}`;
      $('doneMsg').textContent = `Thank you, ${first}! We've received your order for ${money(res.order.amount)} ${basis}. Our team will contact you on ${state.customer.phone} within one business day to confirm and schedule your measurement.`;
      if (!fromQuote) { state.cart = []; renderCart(); }
      state.quote = null;
      loadSavedQuotes();
      go('done');
    } catch (err) { fail(err); } finally { btn.disabled = false; }
  });

  $('newDesignBtn').addEventListener('click', () => { clearAlert(); resetForm(); go('customize'); });

  /* ---------- Boot ---------- */
  (async function boot() {
    try {
      const cat = await api('catalog.php');
      if (!cat.success || !cat.products.length || !cat.materials.length || !cat.colors.length) {
        throw new Error('The blind catalog is not available right now. Please try again later.');
      }
      state.catalog = cat;
      buildForm();
      renderCart();

      const me = await api('customer_session.php');
      if (me.success && me.logged_in) { await startSession(me.customer); }
      else { showAuth('login'); go('auth'); }
    } catch (err) {
      showAlert((err && err.message) || 'Could not reach the server. Is Apache running? Open this page through http://localhost/…');
    }
  })();
})();
