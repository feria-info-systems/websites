#!/usr/bin/env bash
# Static-mirror build for proconnectnow.com (Odoo Website -> Netlify).
set -euo pipefail
cd "$(dirname "$0")"
SRC=pages
OUT=site
HOST='https://www.proconnectnow.com'
rm -rf "$OUT"; mkdir -p "$OUT/assets"
cp -r assets/css assets/img assets/fonts assets/shape "$OUT/assets/" 2>/dev/null || cp -r assets/css assets/img assets/fonts "$OUT/assets/"
cp assets/forms.js "$OUT/assets/forms.js"

# ---- CSS: localize icon fonts, absolutize other root-relative url()s ----
perl -0777 -pe '
  s{url\((["\x27]?)/web/static/lib/odoo_ui_icons/fonts/odoo_ui_icons\.woff2\1\)}{url(../fonts/odoo_ui_icons.woff2)}g;
  s{url\((["\x27]?)/web/static/lib/odoo_ui_icons/fonts/odoo_ui_icons\.woff\1\)}{url(../fonts/odoo_ui_icons.woff)}g;
  s{url\((["\x27]?)[^)"\x27]*fontawesome-webfont\.woff2[^)"\x27]*\1\)}{url(../fonts/fontawesome-webfont.woff2)}g;
  s{url\((["\x27]?)[^)"\x27]*fontawesome-webfont\.woff[^)"\x27]*\1\)}{url(../fonts/fontawesome-webfont.woff)}g;
  # unused Odoo decorative-shape url(/...) stay root-relative (404 harmlessly on the
  # static host) so nothing points back at Odoo; fonts above are already localized.
' assets/css/frontend.css > "$OUT/assets/css/frontend.css"

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

    $html =~ s{href="/web/assets/\d+/[0-9a-f]+/web\.assets_frontend\.min\.css"}{href="assets/css/frontend.css"}g;
    $html =~ s{href="/web/image/website/\d+/favicon[^"]*"}{href="assets/img/favicon.ico"}g;
    $html =~ s{href="/web/static/src/libs/fontawesome/fonts/fontawesome-webfont\.woff2[^"]*"}{href="assets/fonts/fontawesome-webfont.woff2"}g;
    $html =~ s{/web/image/website/\d+/logo[^"\x27()>,& ]*}{assets/img/logo.png}g;

    for my $id (sort keys %IMG){ my $loc=$IMG{$id}; $html =~ s{/web/image/\Q$id\E/[^"\x27()>,& ]*}{$loc}g; }

    # internal nav
    $html =~ s{href="/request-an-estimate"}{href="request-an-estimate.html"}g;
    $html =~ s{href="/contactus"}{href="contactus.html"}g;
    $html =~ s{href="/services"}{href="services.html"}g;
    $html =~ s{href="/"}{href="index.html"}g;
    $html =~ s{action="/website/search"}{action="index.html"}g;
    # OFF ODOO: Help -> the ERP customer portal (portal.<domain>, repointed to the
    # ERP in DNS); the spurious Odoo shop-cart chrome is removed (no store here).
    $html =~ s{href="/helpdesk"}{href="https://portal.proconnectnow.com/"}g;
    $html =~ s{href="/shop/cart"}{href="#"}g;

    # socials: only facebook configured; others neutralised
    $html =~ s{/website/social/facebook}{https://www.facebook.com/share/1GkVRKgr6C/}g;
    $html =~ s{href="/website/social/(instagram|tiktok|youtube)"}{href="#"}g;

    $html =~ s{(<link rel="canonical" href=")[^"]*(")}{${1}'"$HOST"'/${2}}g;

    $html =~ s{<script[^>]*\bid="web\.layout\.odooscript"[^>]*>.*?</script>}{}gs;
    $html =~ s{<script[^>]*web\.assets_frontend_lazy[^>]*>.*?</script>}{}gs;
    $html =~ s{<script[^>]*web\.assets_frontend_minimal[^>]*>.*?</script>}{}gs;
    $html =~ s{<script[^>]*social_push_notifications[^>]*>.*?</script>}{}gs;
    $html =~ s{<script[^>]*firebase[^>]*>.*?</script>}{}gs;
    $html =~ s{<script\b[^>]*>\s*odoo\.__session_info__.*?</script>}{}gs;
    $html =~ s{<a\b[^>]*odoo\.com[^>]*>.*?</a>}{}gs;
    $html =~ s{Powered by\s*(?=<)}{}g;
    $html =~ s{<meta[^>]*name="generator"[^>]*>}{}gi;
    $html =~ s{\s+data-original-(?:src|id|mimetype)="[^"]*"}{}g;
    $html =~ s{\.comassets/}{.com/assets/}g;
    $html =~ s{href="https://j"}{href="#"}g;
    $html =~ s{action="/website/form/?"}{action="#"}g;

    $html =~ s{</head>}{<style>.o_animate{opacity:1!important;transform:none!important;animation:none!important}.navbar .top_menu.o_menu_loading{opacity:1!important;overflow:visible!important}</style></head>}s;
    $html =~ s{</body>}{<script src="assets/site.js" defer></script><script src="assets/forms.js" defer></script></body>}s;

    print $html;
  ' idmap.tsv < "$infile" > "$outfile"
}

transform_page "$SRC/home.html"     "$OUT/index.html"
transform_page "$SRC/home.html"     "$OUT/services.html"
transform_page "$SRC/contactus.html" "$OUT/contactus.html"
transform_page "$SRC/estimate.html"  "$OUT/request-an-estimate.html"

cat > "$OUT/assets/site.js" <<'JS'
document.addEventListener('click', function (e) {
  var t = e.target.closest('.navbar-toggler, [data-bs-toggle="collapse"], [data-bs-toggle="offcanvas"]');
  if (!t) return;
  e.preventDefault();
  var sel = t.getAttribute('data-bs-target') || t.getAttribute('href');
  var target = sel && sel.charAt(0) === '#' ? document.querySelector(sel) : null;
  if (!target) target = document.querySelector('.navbar-collapse, .offcanvas');
  if (target) { target.classList.toggle('show'); target.classList.toggle('showing'); document.body.classList.toggle('modal-open'); }
}, false);
JS

printf '/services\t/\t301\n' > "$OUT/_redirects"

# Prune Odoo editor "original" images (referenced only via data-original-src).
for f in "$OUT"/assets/img/*; do
  b=$(basename "$f")
  case "$b" in logo.png|favicon.ico) continue;; esac
  if grep -rqE "([[:space:]]src=\"assets/img/$b\"|srcset=\"[^\"]*assets/img/$b[ \",]|url\(&#34;?assets/img/$b|/assets/img/$b)" "$OUT"/*.html; then :
  else rm -f "$f"; fi
done

echo "=== pages ==="; ls "$OUT"/*.html | xargs -n1 basename
echo "=== leftover /web/ refs (should be 0) ==="; grep -c -oiE "/web/(assets|image|static)" "$OUT"/*.html | grep -v ':0' || echo none
echo "=== dynamic Odoo endpoints remaining ==="; grep -hoE "(action|href)=\"/[^\"]*\"" "$OUT"/*.html | sort | uniq -c
echo "=== size ==="; du -sh "$OUT" | cut -f1
