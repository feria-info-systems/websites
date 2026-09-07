// Minimal nav toggle to replace Odoo/Bootstrap JS on the static site.
document.addEventListener('click', function (e) {
  var t = e.target.closest('.navbar-toggler, [data-bs-toggle="collapse"], [data-bs-toggle="offcanvas"]');
  if (!t) return;
  e.preventDefault();
  var sel = t.getAttribute('data-bs-target') || t.getAttribute('href');
  var target = sel && sel.charAt(0) === '#' ? document.querySelector(sel) : null;
  if (!target) { // fallback: nearest collapse in the header
    target = document.querySelector('.navbar-collapse, .offcanvas');
  }
  if (target) {
    target.classList.toggle('show');
    target.classList.toggle('showing');
    document.body.classList.toggle('modal-open');
  }
}, false);
