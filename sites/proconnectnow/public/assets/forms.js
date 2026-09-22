/* forms.js — wire the (migrated) Odoo website forms to the ERP intake function.
 * Replaces Odoo's form runtime: intercepts the `.s_website_form_send` trigger,
 * builds a normalized multipart payload, POSTs to the website-intake edge
 * function, and shows an inline success / error message. No dependencies.
 *
 * Field mapping targets the ERP's convert-worthy columns (see
 * website-submissions convertSubmission): a `contact` becomes a CRM lead
 * (title=subject, contact_name/email/phone, notes=message+location+extras); a
 * `job_application` becomes a recruitment applicant (name/email/phone,
 * notes="Applied for: <job_ref>"+message+extras). Everything unmapped is folded
 * into `extra.<label>` so nothing is lost. */
(function () {
  "use strict";
  var FN_URL = "https://uradcwdwxsokqgdpeinq.supabase.co/functions/v1/website-intake";
  var WHATSAPP = "+233 55 667 2249";
  var SITE = (location.hostname || "proconnectnow.com").replace(/^www\./, "");
  if (/^(localhost|127\.|\[?::1)/.test(SITE)) SITE = "proconnectnow.com"; // local preview

  // Odoo internal / structural fields we never forward.
  var SKIP = new Set(["search", "order", "csrf_token", "team_id", "job_id",
    "department_id", "email_to", "email_cc", "website_form_signature",
    "record_id", "id", "company_website"]);

  // Resolve an Odoo field to a canonical intake key, else null (-> extra.<label>).
  // The `name` field is ambiguous in Odoo: helpdesk.ticket uses it for the
  // SUBJECT (with `partner_name` holding the contact), while some contact forms
  // use it for the contact NAME. So `name` -> subject only when a `partner_name`
  // field is also present; otherwise `name` -> name.
  function canonicalKey(el, nm, hasPartnerName) {
    var low = nm.toLowerCase();
    switch (nm) {
      case "partner_name": return "name";
      case "name": return hasPartnerName ? "subject" : "name";
      case "partner_phone": return "phone";
      case "email_from": return "email";
      case "description": return "message";
      case "x_studio_location": return "location";
    }
    if (low === "phone") return "phone";
    if (low === "email") return "email";
    if (low === "location") return "location";
    if (low === "service needed" || low === "subject") return "subject";
    if (el.tagName === "TEXTAREA") return "message"; // the main free-text answer
    return null;
  }

  function clean(s) { return s.replace(/\s+/g, " ").replace(/\s*\*\s*$/, "").trim(); }
  function labelFor(el, form) {
    if (el.id) {
      var l = form.querySelector('label[for="' + CSS.escape(el.id) + '"]');
      if (l && l.textContent.trim()) return clean(l.textContent);
    }
    var wrap = el.closest(".s_website_form_field");
    var t = wrap && wrap.querySelector(".s_website_form_label_content, label");
    if (t && t.textContent.trim()) return clean(t.textContent);
    return el.getAttribute("name") || "field";
  }

  function fieldValue(el) {
    if (el.tagName === "SELECT") {
      var o = el.selectedOptions && el.selectedOptions[0];
      return o ? (o.text || o.value) : el.value;
    }
    return el.value;
  }

  function showMessage(form, ok, text) {
    var box = document.createElement("div");
    box.setAttribute("role", "status");
    box.style.cssText = "margin:1rem 0;padding:1rem 1.25rem;border-radius:.75rem;font-size:1rem;" +
      (ok ? "background:#e7f5ec;color:#0f5132;border:1px solid #badbcc;"
          : "background:#fbe9e7;color:#842029;border:1px solid #f5c2c7;");
    box.textContent = text;
    if (ok) {
      form.replaceWith(box);
    } else {
      var old = form.querySelector(".wf-msg");
      if (old) old.remove();
      box.className = "wf-msg";
      form.prepend(box);
    }
  }

  function missingRequired(form) {
    var els = form.querySelectorAll("[required]");
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      if (el.type === "file") { if (!el.files.length) return el; continue; }
      if (!String(fieldValue(el) || "").trim()) return el;
    }
    return null;
  }

  function buildPayload(form) {
    var model = form.getAttribute("data-model_name") || "";
    var kind = model === "hr.applicant" ? "job_application" : "contact";
    var hasPartnerName = !!form.querySelector('[name="partner_name"]');
    var fd = new FormData();
    fd.append("kind", kind);
    fd.append("site", SITE);
    fd.append("company_website", ""); // honeypot (stays empty for humans)

    var seen = {};
    form.querySelectorAll("input[name], select[name], textarea[name]").forEach(function (el) {
      var nm = el.getAttribute("name");
      if (!nm || SKIP.has(nm)) return;
      if (el.type === "file") {
        for (var i = 0; i < el.files.length; i++) fd.append("file", el.files[i]);
        return;
      }
      if (el.type === "checkbox" && !el.checked) return;
      if (el.type === "radio" && !el.checked) return;
      var val = String(fieldValue(el) || "").trim();
      if (!val) return;
      var key = canonicalKey(el, nm, hasPartnerName);
      if (key && !seen[key]) { fd.append(key, val); seen[key] = 1; }
      else { fd.append("extra." + labelFor(el, form), val); } // unmapped or duplicate -> keep in payload
    });

    if (kind === "job_application") {
      // Netlify serves CLEAN URLs (no .html): take the last non-empty path
      // segment, drop a trailing slash and any .html, then strip the leading
      // "apply-" prefix. Handles /apply-live-in-nurse-24, the same with a
      // trailing slash, and the legacy /apply-live-in-nurse-24.html.
      var seg = (location.pathname.replace(/\/+$/, "").split("/").pop() || "")
        .replace(/\.html$/i, "").replace(/^apply-/, "");
      fd.append("job_ref", seg);
      var h1 = document.querySelector("h1, .h1");
      if (h1 && !fd.get("subject")) fd.append("subject", h1.textContent.trim().slice(0, 200));
    }
    return fd;
  }

  function wire(form) {
    var trigger = form.querySelector(".s_website_form_send, .o_website_form_send, [type=submit]");
    var busy = false;
    function submit(e) {
      if (e) e.preventDefault();
      if (busy) return;
      var miss = missingRequired(form);
      if (miss) {
        showMessage(form, false, "Please complete: " + labelFor(miss, form));
        if (miss.focus) miss.focus();
        return;
      }
      busy = true;
      if (trigger) { trigger.style.pointerEvents = "none"; trigger.style.opacity = "0.6"; }
      fetch(FN_URL, { method: "POST", body: buildPayload(form) })
        .then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { return { ok: r.ok, j: j }; }); })
        .then(function (res) {
          if (res.ok && res.j && res.j.ok) {
            var ref = res.j.number ? " (ref " + res.j.number + ")" : "";
            showMessage(form, true,
              "Thank you — we’ve received your submission" + ref +
              ". Our team will be in touch shortly. For anything urgent, call or WhatsApp " + WHATSAPP + ".");
          } else {
            busy = false;
            if (trigger) { trigger.style.pointerEvents = ""; trigger.style.opacity = ""; }
            showMessage(form, false,
              (res.j && res.j.error ? "Could not submit: " + res.j.error : "Sorry, something went wrong.") +
              " Please try again, or call/WhatsApp " + WHATSAPP + ".");
          }
        })
        .catch(function () {
          busy = false;
          if (trigger) { trigger.style.pointerEvents = ""; trigger.style.opacity = ""; }
          showMessage(form, false, "Network error — please try again, or call/WhatsApp " + WHATSAPP + ".");
        });
    }
    if (trigger) trigger.addEventListener("click", submit);
    form.addEventListener("submit", submit);
  }

  function init() {
    document.querySelectorAll("form[data-model_name]").forEach(wire);
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
