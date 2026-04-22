// Receipt Folder — promotional site interactivity.
// Kept intentionally small: no frameworks, no dependencies.
(() => {
  'use strict';

  // ---------- Mobile nav toggle ----------
  const toggle = document.querySelector('.nav__toggle');
  const links = document.querySelector('.nav__links');
  if (toggle && links) {
    toggle.addEventListener('click', () => {
      const open = links.classList.toggle('nav__links--open');
      toggle.setAttribute('aria-expanded', String(open));
    });
  }

  // ---------- Reveal-on-scroll ----------
  // Uses IntersectionObserver so elements fade up when scrolled into view.
  // Respects prefers-reduced-motion via CSS (elements start visible).
  const reveals = document.querySelectorAll('.reveal');
  if (reveals.length && 'IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          io.unobserve(entry.target);
        }
      });
    }, { rootMargin: '0px 0px -10% 0px', threshold: 0.12 });
    reveals.forEach(el => io.observe(el));
  } else {
    // Fallback: reveal all immediately.
    reveals.forEach(el => el.classList.add('is-visible'));
  }

  // ---------- Countdown card live ticker ----------
  // Picks a pretend deadline 14 days out so the "14 DAYS" stays plausible.
  // On mouse-move, tilts slightly toward the cursor — a subtle delight that
  // mirrors how a real receipt might lift off a cream page.
  const card = document.querySelector('[data-countdown]');
  if (card) {
    const daysEl = card.querySelector('[data-days]');
    const deadline = new Date();
    deadline.setDate(deadline.getDate() + 14);

    const tick = () => {
      if (!daysEl) return;
      const ms = deadline - Date.now();
      const days = Math.max(0, Math.floor(ms / 86400000));
      daysEl.textContent = String(days);
    };
    tick();
    setInterval(tick, 60000);

    // Tilt on mouse move (disabled for touch / reduced motion).
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!reduceMotion && window.matchMedia('(hover: hover)').matches) {
      const parent = card.parentElement;
      parent.addEventListener('mousemove', (e) => {
        const rect = parent.getBoundingClientRect();
        const x = (e.clientX - rect.left) / rect.width - 0.5;
        const y = (e.clientY - rect.top) / rect.height - 0.5;
        card.style.transform = `perspective(900px) rotateY(${x * 6}deg) rotateX(${y * -6}deg)`;
      });
      parent.addEventListener('mouseleave', () => {
        card.style.transform = '';
      });
    }
  }

  // ---------- Contact form (front-end only) ----------
  // Posts to a mailto: so it works with zero backend. For real production use,
  // replace with a Formspree / email service endpoint.
  const form = document.querySelector('[data-contact-form]');
  if (form) {
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const data = new FormData(form);
      const name = encodeURIComponent(data.get('name') || '');
      const subject = encodeURIComponent(data.get('subject') || 'Receipt Folder');
      const message = encodeURIComponent(
        `Name: ${data.get('name') || ''}\nFrom: ${data.get('email') || ''}\n\n${data.get('message') || ''}`
      );
      const mailto = `mailto:honorius@neogy.dev?subject=${subject}&body=${message}`;
      // Open the user's mail client; show a confirmation message either way.
      window.location.href = mailto;
      const status = form.querySelector('[data-form-status]');
      if (status) {
        status.textContent = `Opening your mail app${name ? `, ${decodeURIComponent(name)}` : ''}…`;
        status.hidden = false;
      }
    });
  }

  // ---------- Highlight current nav link ----------
  // Useful when each page is served separately.
  const path = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.nav__links a, .footer__col a').forEach(a => {
    const href = a.getAttribute('href') || '';
    if (href === path) a.setAttribute('aria-current', 'page');
  });
})();
