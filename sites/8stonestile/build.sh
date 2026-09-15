#!/usr/bin/env bash
# Static storefront generator for 8Stones Tiles.
# Reads products.tsv (id,slug,name,price,category,img) and emits static pages
# into public/. Odoo's product detail pages are all 500ing, so this is a fresh
# clean catalog: browse -> Order on WhatsApp / Enquire (form -> ERP intake).
set -euo pipefail
cd "$(dirname "$0")"
OUT="public"; mkdir -p "$OUT/assets/img"
SITE="8stonestile.com"
WA="233549295514"                 # WhatsApp digits
TEL="+233 54 929 5514"
EMAIL="info@8stonestile.com"
BRAND="8Stones Tiles"
CATS=("Interlock Tiles" "Slabs" "Heavy Duty Tiles" "Kerbs" "Stones & Pebbles")

# map a product id to its downloaded image filename
imgfile(){ ls "$OUT/assets/img/$1".* 2>/dev/null | head -1 | sed "s#$OUT/##"; }
esc(){ sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g'; }
enc(){ python - "$1" 2>/dev/null <<'P' || printf '%s' "$1" | sed 's/ /%20/g'
import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))
P
}

head_html(){ # $1=title $2=active
cat <<EOF
<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$1 | $BRAND</title>
<meta name="description" content="8Stones — leading Ghanaian manufacturer of designer pavers, interlock tiles, slabs and kerbs. Browse our catalogue and order on WhatsApp.">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,600&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/styles.css?v=1">
</head><body>
<header class="site-head"><div class="wrap">
  <a class="brand" href="index.html"><span class="mark">8S</span> 8Stones<span style="color:var(--accent)">Tiles</span></a>
  <button class="nav-toggle" aria-label="Menu" onclick="document.getElementById('nav').classList.toggle('open')">&#9776;</button>
  <nav class="nav" id="nav">
    <a href="index.html"$([ "$2" = home ] && echo ' class=active')>Home</a>
    <a href="shop.html"$([ "$2" = shop ] && echo ' class=active')>Catalogue</a>
    <a href="index.html#about">About</a>
    <a href="contact.html"$([ "$2" = contact ] && echo ' class=active')>Contact</a>
    <a class="btn btn-primary btn-sm" href="https://wa.me/$WA" target="_blank" rel="noopener">WhatsApp us</a>
  </nav>
</div></header>
EOF
}

foot_html(){
cat <<EOF
<footer class="site-foot"><div class="wrap"><div class="foot-grid">
  <div>
    <a class="brand" href="index.html" style="color:#fff"><span class="mark">8S</span> 8Stones Tiles</a>
    <p class="muted" style="margin-top:.8rem;max-width:34ch">Leading manufacturers of designer pavers and tiles — unlimited choice of colours, shapes and designs, with zero-maintenance quality built for Ghana.</p>
  </div>
  <div><h4>Explore</h4><ul>
    <li><a href="index.html">Home</a></li><li><a href="shop.html">Catalogue</a></li>
    <li><a href="index.html#about">About us</a></li><li><a href="contact.html">Contact</a></li>
  </ul></div>
  <div><h4>Get in touch</h4><ul>
    <li><a href="tel:$WA">$TEL</a></li>
    <li><a href="mailto:$EMAIL">$EMAIL</a></li>
    <li><a href="https://wa.me/$WA" target="_blank" rel="noopener">Order on WhatsApp</a></li>
  </ul></div>
</div><div class="foot-bot"><span>&copy; $(date +%Y) 8Stones Tiles. All rights reserved.</span><span>Proudly manufactured in Ghana</span></div></div></footer>
<a class="wa-float" href="https://wa.me/$WA" target="_blank" rel="noopener" aria-label="Chat on WhatsApp">&#128172;</a>
<script src="assets/forms.js?v=1" defer></script>
</body></html>
EOF
}

# product card: $1 id $2 name $3 price $4 category
card(){
  local id="$1" name="$2" price="$3" cat="$4"
  local f; f=$(imgfile "$id"); [ -z "$f" ] && f="assets/img/$id.jpg"
  local ename; ename=$(printf '%s' "$name" | esc)
  local watext; watext=$(enc "Hi 8Stones, I'm interested in $name (GHS $price). Please share availability, sizes and delivery.")
  local pslug; pslug=$(enc "$name")
  cat <<EOF
      <article class="product" data-cat="$(printf '%s' "$cat" | esc)">
        <a class="ph" href="contact.html?product=$pslug"><img src="$f" alt="$ename paver tile" loading="lazy"></a>
        <div class="body">
          <span class="cat">$(printf '%s' "$cat" | esc)</span>
          <span class="nm">$ename</span>
          <span class="pr">GHS $price <small>/ unit</small></span>
          <div class="acts">
            <a class="btn btn-wa btn-sm" href="https://wa.me/$WA?text=$watext" target="_blank" rel="noopener">Order</a>
            <a class="btn btn-ghost btn-sm" href="contact.html?product=$pslug">Enquire</a>
          </div>
        </div>
      </article>
EOF
}

count_cat(){ awk -F'\t' -v c="$1" '$5==c{n++}END{print n+0}' products.tsv; }

# ---------- HOME ----------
{
head_html "Designer Pavers & Tiles" home
# hero art: 4 product images
mapfile -t HImg < <(awk -F'\t' 'NR<=4{print $1}' products.tsv)
cat <<EOF
<section class="hero"><div class="wrap">
  <div>
    <span class="eyebrow">Manufactured in Ghana</span>
    <h1>Designer pavers &amp; tiles that last a lifetime</h1>
    <p>From interlock pavers and heavy-duty tiles to slabs and kerbs — unlimited colours, shapes and designs with zero-maintenance quality. Browse the catalogue and order on WhatsApp.</p>
    <div class="hero-cta">
      <a class="btn btn-primary" href="shop.html">Browse catalogue</a>
      <a class="btn btn-wa" href="https://wa.me/$WA" target="_blank" rel="noopener">&#128172; Order on WhatsApp</a>
    </div>
    <div class="hero-stats">
      <div><b>27+</b><span>designs in stock</span></div>
      <div><b>5</b><span>product ranges</span></div>
      <div><b>0</b><span>maintenance cost</span></div>
    </div>
  </div>
  <div class="hero-art">
    <img src="$(imgfile ${HImg[0]})" alt=""><img src="$(imgfile ${HImg[1]})" alt="">
    <img src="$(imgfile ${HImg[2]})" alt=""><img src="$(imgfile ${HImg[3]})" alt="">
  </div>
</div></section>

<section><div class="wrap">
  <div class="section-head"><span class="eyebrow">Our ranges</span><h2>Explore by category</h2></div>
  <div class="cats">
    <a class="cat-card" href="shop.html#interlock-tiles"><div class="ico">&#9639;</div><b>Interlock Tiles</b><span>$(count_cat "Interlock Tiles") designs</span></a>
    <a class="cat-card" href="shop.html#slabs"><div class="ico">&#9635;</div><b>Slabs</b><span>$(count_cat "Slabs") designs</span></a>
    <a class="cat-card" href="shop.html#heavy-duty-tiles"><div class="ico">&#9641;</div><b>Heavy Duty Tiles</b><span>$(count_cat "Heavy Duty Tiles") designs</span></a>
    <a class="cat-card" href="shop.html#kerbs"><div class="ico">&#9644;</div><b>Kerbs</b><span>$(count_cat "Kerbs") design</span></a>
    <a class="cat-card" href="shop.html#stones-pebbles"><div class="ico">&#9679;</div><b>Stones &amp; Pebbles</b><span>$(count_cat "Stones & Pebbles") design</span></a>
    <a class="cat-card" href="contact.html"><div class="ico">&#128736;</div><b>Installation</b><span>Ask about fitting</span></a>
  </div>
</div></section>

<section style="padding-top:0"><div class="wrap">
  <div class="section-head"><span class="eyebrow">Popular designs</span><h2>Featured this season</h2></div>
  <div class="grid">
EOF
awk -F'\t' 'NR<=8{print}' products.tsv | while IFS=$'\t' read -r id slug name price cat img; do card "$id" "$name" "$price" "$cat"; done
cat <<EOF
  </div>
  <div style="text-align:center;margin-top:2rem"><a class="btn btn-ghost" href="shop.html">View all designs &rarr;</a></div>
</div></section>

<section class="band" id="about"><div class="wrap split">
  <div>
    <span class="eyebrow">About 8Stones</span>
    <h2 style="color:#fff">Ghana's designer paver &amp; tile manufacturer</h2>
    <p class="muted">We are the leading manufacturers of designer pavers and tiles, providing an unlimited choice of colours, shapes and designs. Our products have superior characteristics with zero maintenance costs, custom-designed to suit your specific requirements — a cost-effective flooring solution for driveways, walkways, compounds and commercial spaces.</p>
    <ul class="feature-list">
      <li><span class="tick">&#10003;</span> High-strength, heavy-duty finishes for real traffic</li>
      <li><span class="tick">&#10003;</span> Custom colours, shapes and designs on request</li>
      <li><span class="tick">&#10003;</span> Delivery and professional installation available</li>
    </ul>
    <div class="hero-cta"><a class="btn btn-primary" href="contact.html">Request a quote</a></div>
  </div>
  <div class="hero-art" style="transform:rotate(2deg)">
    <img src="$(imgfile ${HImg[0]})" alt=""><img src="$(imgfile ${HImg[2]})" alt="">
  </div>
</div></section>

<section><div class="wrap" style="text-align:center;max-width:60ch;margin-inline:auto">
  <span class="eyebrow">Ready to order?</span>
  <h2>Tell us what you need — we'll quote same day</h2>
  <p class="muted">Share your design, quantity and location. Order the fastest way on WhatsApp, or send an enquiry and our team will get back to you.</p>
  <div class="hero-cta" style="justify-content:center">
    <a class="btn btn-wa" href="https://wa.me/$WA" target="_blank" rel="noopener">&#128172; Chat on WhatsApp</a>
    <a class="btn btn-ghost" href="contact.html">Send an enquiry</a>
  </div>
</div></section>
EOF
foot_html
} > "$OUT/index.html"

# ---------- SHOP ----------
{
head_html "Catalogue" shop
cat <<EOF
<section style="padding-bottom:1rem"><div class="wrap">
  <div class="section-head"><span class="eyebrow">Catalogue</span><h2>Browse our designs</h2>
  <p class="muted">Every design below is available to order. Prices are per unit — tap <strong>Order</strong> to send us the design on WhatsApp, or <strong>Enquire</strong> for a full quote with delivery.</p></div>
  <div class="chips" id="chips">
    <button class="chip active" data-f="all">All</button>
EOF
for c in "${CATS[@]}"; do echo "    <button class=\"chip\" data-f=\"$(printf '%s' "$c" | esc)\">$(printf '%s' "$c" | esc)</button>"; done
cat <<EOF
  </div>
</div></section>
<section style="padding-top:0"><div class="wrap">
EOF
for c in "${CATS[@]}"; do
  anchor=$(printf '%s' "$c" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z-')
  echo "  <div class=\"cat-group\" data-group=\"$(printf '%s' "$c" | esc)\" id=\"$anchor\"><h2>$(printf '%s' "$c" | esc) <span>$(count_cat "$c") designs</span></h2><div class=\"grid\">"
  awk -F'\t' -v c="$c" '$5==c{print}' products.tsv | while IFS=$'\t' read -r id slug name price cat img; do card "$id" "$name" "$price" "$cat"; done
  echo "  </div></div>"
done
cat <<EOF
</div></section>
<script>
(function(){var chips=document.querySelectorAll('#chips .chip');var groups=document.querySelectorAll('.cat-group');
chips.forEach(function(ch){ch.addEventListener('click',function(){chips.forEach(c=>c.classList.remove('active'));ch.classList.add('active');var f=ch.dataset.f;groups.forEach(function(g){g.style.display=(f==='all'||g.dataset.group===f)?'':'none';});});});})();
</script>
EOF
foot_html
} > "$OUT/shop.html"

# ---------- CONTACT ----------
{
head_html "Contact & Enquiries" contact
cat <<EOF
<section><div class="wrap split">
  <div>
    <span class="eyebrow">Get in touch</span>
    <h2>Request a quote or place an order</h2>
    <p class="muted">Send your design, quantity and delivery location and we'll come back with pricing and availability. For the fastest response, order on WhatsApp.</p>
    <div style="margin:1.6rem 0">
      <div class="info-row"><div class="ico">&#128241;</div><div><b>Call / WhatsApp</b><span>$TEL</span></div></div>
      <div class="info-row"><div class="ico">&#9993;</div><div><b>Email</b><span>$EMAIL</span></div></div>
      <div class="info-row"><div class="ico">&#128666;</div><div><b>Delivery &amp; installation</b><span>Available across Ghana</span></div></div>
    </div>
    <a class="btn btn-wa" href="https://wa.me/$WA" target="_blank" rel="noopener">&#128172; Order on WhatsApp</a>
  </div>
  <div class="form-card">
    <h3>Send an enquiry</h3>
    <form id="enquiry" data-kind="contact">
      <input class="hp" type="text" name="company_website" tabindex="-1" autocomplete="off" aria-hidden="true">
      <div class="field"><label for="f-name">Your name</label><input id="f-name" name="name" required></div>
      <div class="field"><label for="f-phone">Phone / WhatsApp</label><input id="f-phone" name="phone" type="tel" required></div>
      <div class="field"><label for="f-email">Email (optional)</label><input id="f-email" name="email" type="email"></div>
      <div class="field"><label for="f-subject">Product / design of interest</label><input id="f-subject" name="subject" placeholder="e.g. Interlock — Torus T12"></div>
      <div class="field"><label for="f-location">Delivery location</label><input id="f-location" name="location" placeholder="Town / city"></div>
      <div class="field"><label for="f-message">Details (quantity, area, timeline)</label><textarea id="f-message" name="message" placeholder="How many units / what area (m²), and when do you need it?"></textarea></div>
      <button class="btn btn-primary" type="submit" style="width:100%;justify-content:center">Send enquiry</button>
    </form>
  </div>
</div></section>
EOF
foot_html
} > "$OUT/contact.html"

# _redirects: apex/www handled at DNS; SPA-ish niceties + old odoo paths -> home/shop
cat > "$OUT/_redirects" <<EOF
/shop/*        /shop.html   301
/shop          /shop.html   301
/contactus     /contact.html 301
/form          /contact.html 301
/galary        /shop.html   301
/videos        /index.html  301
EOF

echo "built: $(ls -1 "$OUT"/*.html | wc -l) pages, $(ls -1 "$OUT"/assets/img | wc -l) images"
