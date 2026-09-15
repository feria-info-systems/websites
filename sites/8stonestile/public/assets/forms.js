/* forms.js — 8Stones Tiles enquiry form -> ERP website-intake edge function.
 * Fields are already canonical (name/phone/email/subject/location/message), so
 * no Odoo mapping is needed. Prefills the product of interest from ?product=. */
(function () {
  "use strict";
  var FN_URL = "https://uradcwdwxsokqgdpeinq.supabase.co/functions/v1/website-intake";
  var WHATSAPP = "+233 54 929 5514";
  var SITE = (location.hostname || "8stonestile.com").replace(/^www\./, "");
  if (/^(localhost|127\.|\[?::1)/.test(SITE)) SITE = "8stonestile.com";

  // Prefill "Product / design of interest" from the ?product= link on cards.
  try {
    var p = new URLSearchParams(location.search).get("product");
    var subj = document.querySelector('#enquiry [name="subject"]');
    if (p && subj && !subj.value) subj.value = p;
  } catch (e) { /* no-op */ }

  function showMessage(form, ok, text) {
    var box = document.createElement("div");
    box.className = "status-msg " + (ok ? "status-ok" : "status-err");
    box.setAttribute("role", "status");
    box.textContent = text;
    if (ok) { form.replaceWith(box); }
    else {
      var old = form.parentNode.querySelector(".status-msg"); if (old) old.remove();
      form.parentNode.insertBefore(box, form);
    }
  }

  function wire(form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var btn = form.querySelector('[type="submit"]');
      var fd = new FormData(form);
      fd.append("kind", form.getAttribute("data-kind") || "contact");
      fd.append("site", SITE);
      // honeypot already named company_website in the markup

      var name = String(fd.get("name") || "").trim();
      var phone = String(fd.get("phone") || "").trim();
      if (!name || !phone) {
        showMessage(form, false, "Please add your name and phone number so we can reach you.");
        return;
      }
      if (btn) { btn.disabled = true; btn.style.opacity = "0.6"; btn.textContent = "Sending…"; }
      fetch(FN_URL, { method: "POST", body: fd })
        .then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { return { ok: r.ok, j: j }; }); })
        .then(function (res) {
          if (res.ok && res.j && res.j.ok) {
            showMessage(form, true,
              "Thank you — we've received your enquiry" + (res.j.number ? " (ref " + res.j.number + ")" : "") +
              ". Our team will get back to you shortly with pricing and availability. For anything urgent, call or WhatsApp " + WHATSAPP + ".");
          } else {
            if (btn) { btn.disabled = false; btn.style.opacity = ""; btn.textContent = "Send enquiry"; }
            showMessage(form, false,
              (res.j && res.j.error ? "Could not send: " + res.j.error : "Sorry, something went wrong.") +
              " Please try again, or WhatsApp " + WHATSAPP + ".");
          }
        })
        .catch(function () {
          if (btn) { btn.disabled = false; btn.style.opacity = ""; btn.textContent = "Send enquiry"; }
          showMessage(form, false, "Network error — please try again, or WhatsApp " + WHATSAPP + ".");
        });
    });
  }

  function init() { document.querySelectorAll("form[data-kind]").forEach(wire); }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
