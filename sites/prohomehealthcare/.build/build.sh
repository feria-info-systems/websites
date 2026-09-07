#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
SRC=pages
OUT=site
HOST='https://www.prohomehealthcare.com'
rm -rf "$OUT"; mkdir -p "$OUT/assets"
cp -r assets/css assets/img assets/fonts assets/shape "$OUT/assets/"
cp assets/forms.js "$OUT/assets/forms.js"

# ---- Transform the CSS bundle: localize fonts, absolutize other root-relative urls ----
perl -0777 -pe '
  # localize the two icon-font families
  s{url\((["\x27]?)/web/static/lib/odoo_ui_icons/fonts/odoo_ui_icons\.woff2\1\)}{url(../fonts/odoo_ui_icons.woff2)}g;
  s{url\((["\x27]?)/web/static/lib/odoo_ui_icons/fonts/odoo_ui_icons\.woff\1\)}{url(../fonts/odoo_ui_icons.woff)}g;
  s{url\((["\x27]?)[^)"\x27]*fontawesome-webfont\.woff2[^)"\x27]*\1\)}{url(../fonts/fontawesome-webfont.woff2)}g;
  s{url\((["\x27]?)[^)"\x27]*fontawesome-webfont\.woff[^)"\x27]*\1\)}{url(../fonts/fontawesome-webfont.woff)}g;
  # any remaining root-relative url(/...) -> absolute to Odoo host (unused decorative shapes; safe fallback)
  s{url\((["\x27]?)/(?!/)}{url($1'"$HOST"'/}g;
' assets/css/frontend.css > "$OUT/assets/css/frontend.css"

# ---- Build authoritative id->local map from the downloaded images ----
: > idmap.tsv
for f in assets/img/*; do
  b=$(basename "$f"); case "$b" in logo.png|favicon.ico) continue;; esac
  printf '%s\t%s\n' "${b%.*}" "assets/img/$b" >> idmap.tsv
done

transform_page () {
  local infile="$1" outfile="$2"
  perl -e '
    my $map = shift @ARGV;
    my %IMG; { local $/ = "\n"; open(my $M,"<",$map) or die "map: $!";
      while(my $l=<$M>){ chomp $l; my($id,$loc)=split(/\t/,$l,2); $IMG{$id}=$loc if $id; } }
    my $html = do { local $/; <STDIN> };
    my $HOST = "'"$HOST"'";

    # --- stylesheet + favicon + preload font ---
    $html =~ s{href="/web/assets/\d+/[0-9a-f]+/web\.assets_frontend\.min\.css"}{href="assets/css/frontend.css"}g;
    $html =~ s{href="/web/image/website/15/favicon[^"]*"}{href="assets/img/favicon.ico"}g;
    $html =~ s{href="/web/static/src/libs/fontawesome/fonts/fontawesome-webfont\.woff2[^"]*"}{href="assets/fonts/fontawesome-webfont.woff2"}g;

    # --- logo (all website logo variants) ---
    $html =~ s{/web/image/website/15/logo[^"\x27()>,& ]*}{assets/img/logo.png}g;

    # --- content images (from idmap) ---
    for my $id (sort keys %IMG){ my $loc=$IMG{$id}; $html =~ s{/web/image/\Q$id\E/[^"\x27()>,& ]*}{$loc}g; }

    # --- shape svgs used on pages ---
    $html =~ s{/html_editor/shape/html_builder%2FConnections%2F12\.svg[^"\x27()>,& ]*}{assets/shape/connections-12.svg}g;
    $html =~ s{/html_editor/shape/html_builder%2FBold%2F26\.svg[^"\x27()>,& ]*}{assets/shape/bold-26.svg}g;
    $html =~ s{/html_editor/shape/html_builder/Bold/26\.svg[^"\x27()>,& ]*}{assets/shape/bold-26.svg}g;

    # --- internal nav links -> local files ---
    $html =~ s{href="/jobs/apply/nurse-assistance-25"}{href="apply-nurse-assistance-25.html"}g;
    $html =~ s{href="/jobs/apply/live-in-nurse-24"}{href="apply-live-in-nurse-24.html"}g;
    $html =~ s{href="/jobs/detail/nurse-assistance-25"}{href="job-nurse-assistance-25.html"}g;
    $html =~ s{href="/jobs/detail/live-in-nurse-24"}{href="job-live-in-nurse-24.html"}g;
    $html =~ s{href="/jobs/nurse-assistance-25"}{href="job-nurse-assistance-25.html"}g;
    $html =~ s{href="/jobs/live-in-nurse-24"}{href="job-live-in-nurse-24.html"}g;
    $html =~ s{href="/home-1"}{href="index.html"}g;
    $html =~ s{href="/services"}{href="services.html"}g;
    $html =~ s{href="/forms"}{href="forms.html"}g;
    $html =~ s{href="/jobs"}{href="jobs.html"}g;
    $html =~ s{href="/"}{href="index.html"}g;
    # search box has no static backend -> point at home
    $html =~ s{action="/website/search"}{action="index.html"}g;
    # device-frame image shape
    $html =~ s{/html_editor/image_shape/[^"\x27()>,& ]*macbook_front\.svg}{assets/shape/macbook_front.svg}g;

    # --- social redirects -> real profiles; dead tiktok neutralised ---
    $html =~ s{/website/social/facebook}{https://www.facebook.com/share/1ELkiCZwGb/}g;
    $html =~ s{/website/social/instagram}{https://www.instagram.com/pro.homehealthcare/}g;
    $html =~ s{href="/website/social/tiktok"}{href="https://www.tiktok.com/@pro.homehealthcare"}g;

    # --- login / cart -> stay on Odoo portal (dynamic, not migrated) ---
    $html =~ s{href="/web/login"}{href="https://portal.prohomehealthcare.com/"}g;
    $html =~ s{href="/shop/cart"}{href="https://portal.prohomehealthcare.com/"}g;

    # --- canonical/og urls: point at production domain root ---
    $html =~ s{(<link rel="canonical" href=")[^"]*(")}{${1}https://www.prohomehealthcare.com/${2}}g;

    # --- strip Odoo runtime + editor scripts (keep gtag + ld+json) ---
    $html =~ s{<script[^>]*\bid="web\.layout\.odooscript"[^>]*>.*?</script>}{}gs;
    $html =~ s{<script[^>]*web\.assets_frontend_lazy[^>]*>.*?</script>}{}gs;
    $html =~ s{<script[^>]*web\.assets_frontend_minimal[^>]*>.*?</script>}{}gs;
    $html =~ s{<script[^>]*social_push_notifications[^>]*>.*?</script>}{}gs;
    $html =~ s{<script[^>]*firebase[^>]*>.*?</script>}{}gs;

    # --- remove Odoo "Powered by" promo anchors ---
    $html =~ s{<a\b[^>]*odoo\.com[^>]*>.*?</a>}{}gs;
    $html =~ s{Powered by\s*(?=<)}{}g;

    # --- inject: neutralise scroll-animation invisibility + local nav JS ---
    $html =~ s{</head>}{<style>.o_animate{opacity:1!important;transform:none!important;animation:none!important}.navbar .top_menu.o_menu_loading{opacity:1!important;overflow:visible!important}</style></head>}s;
    $html =~ s{</body>}{<script src="assets/site.js" defer></script><script src="assets/forms.js" defer></script></body>}s;

    print $html;
  ' idmap.tsv < "$infile" > "$outfile"
}

transform_page "$SRC/home.html"     "$OUT/index.html"
transform_page "$SRC/services.html" "$OUT/services.html"
transform_page "$SRC/forms.html"    "$OUT/forms.html"
transform_page "$SRC/jobs.html"     "$OUT/jobs.html"
transform_page "$SRC/job-nurse-assistance-25.html" "$OUT/job-nurse-assistance-25.html"
transform_page "$SRC/job-live-in-nurse-24.html"    "$OUT/job-live-in-nurse-24.html"
transform_page "$SRC/apply-nurse-assistance-25.html" "$OUT/apply-nurse-assistance-25.html"
transform_page "$SRC/apply-live-in-nurse-24.html"    "$OUT/apply-live-in-nurse-24.html"

# ---- tiny runtime: mobile navbar toggle (Bootstrap-less) ----
cat > "$OUT/assets/site.js" <<'JS'
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
JS

# ---- Netlify config ----
cat > "$OUT/_redirects" <<'RD'
/home-1    /    301
RD

# ---- Prune Odoo editor "original" images: files referenced ONLY via
# data-original-src (never by a real src/srcset/url()), so the browser never
# fetches them. Removes multi-MB PNG originals behind the served webp. ----
for f in "$OUT"/assets/img/*; do
  b=$(basename "$f")
  if grep -rqF "assets/img/$b\"" "$OUT"/*.html \
     && grep -rqE "(src=\"assets/img/$b\"|srcset=\"[^\"]*assets/img/$b[ \",]|url\(&#34;?assets/img/$b)" "$OUT"/*.html; then
    :  # genuinely displayed — keep
  elif grep -rqF "data-original-src=\"assets/img/$b\"" "$OUT"/*.html; then
    echo "prune editor-original: $b ($(( $(wc -c < "$f") / 1024 )) KB)"; rm -f "$f"
  fi
done

echo "=== built site tree ==="
find "$OUT" -maxdepth 2 -type f | sort
echo "=== sanity: leftover Odoo asset refs in HTML (should be minimal) ==="
grep -oiE "/web/(assets|image|static)/[^\"'()>,& ]*" "$OUT"/*.html | sort | uniq -c | head -30 || true
echo "=== leftover odoo.com refs ==="
grep -oiE "odoo\.com" "$OUT"/*.html | wc -l
