#!/bin/bash
set -Eeuo pipefail

LABEL="com.openai.stormylakewallpaper"
ROOT="$HOME/Library/Application Support/StormyLakeWallpaper"
IMAGE="$ROOT/stormy-lake-hd.jpg"
HTML="$ROOT/wallpaper.html"
JXA="$ROOT/wallpaper.js"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_NUMBER="$(id -u)"

# High-resolution mountain-lake source. The fallback is a 5712px-wide NPS image.
PRIMARY_IMAGE_URL='https://images.unsplash.com/photo-1476041178066-aa562074def7?auto=format&fit=crop&fm=jpg&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&ixlib=rb-4.1.0&q=60&w=3000'
FALLBACK_IMAGE_URL='https://upload.wikimedia.org/wikipedia/commons/e/ef/Sprague_Lake_at_Sunset_%2829560309357%29.jpg'

fail() {
  local message="$1"
  printf '\nRepair stopped: %s\n' "$message" >&2
  /usr/bin/osascript -e "display dialog \"Stormy wallpaper could not be repaired.\\n\\n$message\" buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null 2>&1 || true
  exit 1
}

printf '\nRepairing the storm wallpaper at full resolution…\n'
mkdir -p "$ROOT" "$HOME/Library/LaunchAgents"

# Remove the broken player first, so the distorted wallpaper disappears immediately.
/bin/launchctl bootout "gui/$UID_NUMBER" "$PLIST" >/dev/null 2>&1 || true
/usr/bin/pkill -f "$ROOT/wallpaper.js" >/dev/null 2>&1 || true
sleep 1

TMP_IMAGE="$ROOT/stormy-lake-hd.download"
rm -f "$TMP_IMAGE"
printf 'Downloading a full-resolution background…\n'
if ! /usr/bin/curl -fL --retry 4 --retry-delay 1 --connect-timeout 20 \
     -A 'Mozilla/5.0' "$PRIMARY_IMAGE_URL" -o "$TMP_IMAGE"; then
  printf 'Primary image host was unavailable; using the high-resolution fallback…\n'
  /usr/bin/curl -fL --retry 4 --retry-delay 1 --connect-timeout 20 \
     -A 'Mozilla/5.0' "$FALLBACK_IMAGE_URL" -o "$TMP_IMAGE" \
     || fail "The high-resolution background could not be downloaded."
fi

[[ -s "$TMP_IMAGE" ]] || fail "The downloaded background was empty."

WIDTH="$(/usr/bin/sips -g pixelWidth "$TMP_IMAGE" 2>/dev/null | /usr/bin/awk '/pixelWidth/ {print $2; exit}')"
HEIGHT="$(/usr/bin/sips -g pixelHeight "$TMP_IMAGE" 2>/dev/null | /usr/bin/awk '/pixelHeight/ {print $2; exit}')"
if [[ ! "$WIDTH" =~ ^[0-9]+$ || ! "$HEIGHT" =~ ^[0-9]+$ ]]; then
  fail "macOS could not read the downloaded background image."
fi

# A normal desktop needs enough source pixels to avoid the blocky result from the old build.
if (( WIDTH < 1800 || HEIGHT < 850 )); then
  printf 'The first image was only %sx%s; fetching the larger fallback…\n' "$WIDTH" "$HEIGHT"
  /usr/bin/curl -fL --retry 4 --retry-delay 1 --connect-timeout 20 \
     -A 'Mozilla/5.0' "$FALLBACK_IMAGE_URL" -o "$TMP_IMAGE" \
     || fail "The high-resolution fallback could not be downloaded."
  WIDTH="$(/usr/bin/sips -g pixelWidth "$TMP_IMAGE" 2>/dev/null | /usr/bin/awk '/pixelWidth/ {print $2; exit}')"
  HEIGHT="$(/usr/bin/sips -g pixelHeight "$TMP_IMAGE" 2>/dev/null | /usr/bin/awk '/pixelHeight/ {print $2; exit}')"
fi

if [[ ! "$WIDTH" =~ ^[0-9]+$ || ! "$HEIGHT" =~ ^[0-9]+$ ]] || (( WIDTH < 1800 || HEIGHT < 850 )); then
  fail "The replacement background was not large enough to use safely."
fi
mv -f "$TMP_IMAGE" "$IMAGE"
printf 'Background ready at %sx%s.\n' "$WIDTH" "$HEIGHT"

cat > "$HTML" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: #06111a; }
  .scene {
    position: fixed;
    inset: -10px;
    background-image: url('stormy-lake-hd.jpg');
    background-repeat: no-repeat;
    background-position: center center;
    background-size: cover;
    image-rendering: auto;
    transform: translateZ(0);
    will-change: transform;
  }
  #base {
    filter: brightness(.76) saturate(.92) contrast(1.07);
  }
  #leftTrees, #rightTrees {
    pointer-events: none;
    filter: brightness(.76) saturate(.92) contrast(1.07);
  }
  #leftTrees {
    opacity: .56;
    -webkit-mask-image: radial-gradient(ellipse 47% 72% at 4% 45%, #000 0 43%, rgba(0,0,0,.7) 55%, transparent 76%);
    transform-origin: 8% 78%;
    animation: leftSway 8.5s ease-in-out infinite;
  }
  #rightTrees {
    opacity: .48;
    -webkit-mask-image: radial-gradient(ellipse 35% 60% at 92% 48%, #000 0 42%, rgba(0,0,0,.65) 58%, transparent 82%);
    transform-origin: 91% 78%;
    animation: rightSway 7.4s ease-in-out infinite;
  }
  @keyframes leftSway {
    0%,100% { transform: translate3d(-1px,0,0) rotate(-.035deg); }
    50% { transform: translate3d(3px,0,0) rotate(.055deg); }
  }
  @keyframes rightSway {
    0%,100% { transform: translate3d(1.5px,0,0) rotate(.03deg); }
    50% { transform: translate3d(-2px,0,0) rotate(-.045deg); }
  }
  #stormLight {
    position: fixed;
    inset: 0;
    pointer-events: none;
    background:
      radial-gradient(ellipse 42% 45% at 91% 42%, rgba(255,132,59,.18), transparent 65%),
      linear-gradient(to bottom, rgba(1,12,23,.18), rgba(0,6,13,.05) 55%, rgba(0,8,17,.22));
    mix-blend-mode: screen;
  }
  #fx { position: fixed; inset: 0; width: 100%; height: 100%; display: block; pointer-events: none; }
  #vignette {
    position: fixed;
    inset: 0;
    pointer-events: none;
    background: radial-gradient(ellipse at 52% 48%, transparent 38%, rgba(0,5,12,.12) 72%, rgba(0,3,8,.40) 100%);
  }
</style>
</head>
<body>
  <div id="base" class="scene"></div>
  <div id="leftTrees" class="scene"></div>
  <div id="rightTrees" class="scene"></div>
  <div id="stormLight"></div>
  <canvas id="fx"></canvas>
  <div id="vignette"></div>
<script>
'use strict';
const canvas = document.getElementById('fx');
const ctx = canvas.getContext('2d', {alpha: true, desynchronized: true});
let W = 0, H = 0, DPR = 1, last = 0;
let rain = [], rings = [], mist = [], splashes = [];

function randomRain() {
  const depth = Math.random();
  return {
    x: Math.random() * (W + 180),
    y: Math.random() * (H + 120) - 120,
    speed: 360 + depth * 680,
    length: 10 + depth * 27,
    alpha: .10 + depth * .34,
    width: .45 + depth * 1.0
  };
}

function resize() {
  W = Math.max(1, innerWidth);
  H = Math.max(1, innerHeight);
  DPR = Math.min(devicePixelRatio || 1, 2);
  canvas.width = Math.round(W * DPR);
  canvas.height = Math.round(H * DPR);
  canvas.style.width = W + 'px';
  canvas.style.height = H + 'px';
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);

  const count = Math.min(620, Math.round(300 * W * H / (1440 * 900)));
  rain = Array.from({length: count}, randomRain);
  rings = Array.from({length: 24}, () => ({
    x: W * (.23 + Math.random() * .73),
    y: H * (.64 + Math.random() * .32),
    age: Math.random(),
    speed: .15 + Math.random() * .22
  }));
  mist = Array.from({length: 6}, (_, i) => ({
    baseX: W * (.19 + i * .105),
    y: H * (.28 + Math.random() * .25),
    rx: W * (.11 + Math.random() * .11),
    ry: H * (.035 + Math.random() * .045),
    phase: Math.random() * Math.PI * 2,
    rate: .055 + Math.random() * .06,
    alpha: .018 + Math.random() * .026
  }));
  splashes = Array.from({length: 18}, () => ({
    x: W * (.20 + Math.random() * .77),
    y: H * (.65 + Math.random() * .31),
    age: Math.random(),
    speed: .35 + Math.random() * .38
  }));
}
addEventListener('resize', resize, {passive:true});
resize();

function drawMist(t) {
  ctx.save();
  ctx.globalCompositeOperation = 'screen';
  for (const m of mist) {
    const x = m.baseX + Math.sin(t * m.rate + m.phase) * W * .07;
    const g = ctx.createRadialGradient(x, m.y, 0, x, m.y, m.rx);
    g.addColorStop(0, `rgba(205,222,232,${m.alpha})`);
    g.addColorStop(.55, `rgba(185,207,220,${m.alpha * .55})`);
    g.addColorStop(1, 'rgba(180,205,220,0)');
    ctx.save();
    ctx.translate(x, m.y);
    ctx.scale(1, m.ry / m.rx);
    ctx.translate(-x, -m.y);
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(x, m.y, m.rx, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
  ctx.restore();
}

function drawWater(t) {
  const top = H * .60;
  ctx.save();
  ctx.beginPath();
  ctx.rect(0, top, W, H - top);
  ctx.clip();
  ctx.globalCompositeOperation = 'screen';

  // Fine moving wave highlights—an overlay only, never a warped copy of the image.
  for (let j = 0; j < 19; j++) {
    const baseY = top + (j + .6) * (H - top) / 19;
    const alpha = .020 + j / 19 * .028;
    ctx.strokeStyle = `rgba(175,211,229,${alpha})`;
    ctx.lineWidth = .55 + j / 19 * .5;
    ctx.beginPath();
    for (let x = -20; x <= W + 20; x += 12) {
      const y = baseY + Math.sin(x * .018 + t * 1.3 + j * .71) * (1.1 + j * .045)
                    + Math.sin(x * .041 - t * .75) * .65;
      if (x === -20) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.stroke();
  }

  for (const r of rings) {
    r.age += r.speed / 30;
    if (r.age > 1) {
      r.age = 0;
      r.x = W * (.23 + Math.random() * .73);
      r.y = H * (.64 + Math.random() * .32);
    }
    const radius = 2 + r.age * 30;
    ctx.strokeStyle = `rgba(218,235,244,${(1-r.age) * .30})`;
    ctx.lineWidth = .7;
    ctx.beginPath();
    ctx.ellipse(r.x, r.y, radius, radius * .24, 0, 0, Math.PI * 2);
    ctx.stroke();
  }

  for (const s of splashes) {
    s.age += s.speed / 30;
    if (s.age > 1) {
      s.age = 0;
      s.x = W * (.20 + Math.random() * .77);
      s.y = H * (.65 + Math.random() * .31);
    }
    if (s.age < .16) {
      const a = (.16 - s.age) * 1.3;
      const h = 2 + s.age * 24;
      ctx.strokeStyle = `rgba(230,242,248,${a})`;
      ctx.lineWidth = .7;
      ctx.beginPath();
      ctx.moveTo(s.x, s.y);
      ctx.quadraticCurveTo(s.x - 2, s.y - h * .7, s.x - 4, s.y - h);
      ctx.moveTo(s.x, s.y);
      ctx.quadraticCurveTo(s.x + 2, s.y - h * .65, s.x + 4, s.y - h * .9);
      ctx.stroke();
    }
  }
  ctx.restore();
}

function drawRain(dt) {
  ctx.save();
  ctx.lineCap = 'round';
  for (const p of rain) {
    p.y += p.speed * dt;
    p.x -= p.speed * .19 * dt;
    if (p.y > H + 50 || p.x < -60) {
      Object.assign(p, randomRain());
      p.y = -40 - Math.random() * H * .20;
      p.x = Math.random() * W + W * .06;
    }
    ctx.strokeStyle = `rgba(207,227,239,${p.alpha})`;
    ctx.lineWidth = p.width;
    ctx.beginPath();
    ctx.moveTo(p.x, p.y);
    ctx.lineTo(p.x - p.length * .26, p.y + p.length);
    ctx.stroke();
  }
  ctx.restore();
}

function render(ms) {
  requestAnimationFrame(render);
  if (ms - last < 31) return; // About 30 fps: smooth without wasting the GPU.
  const dt = Math.min(.05, (ms - last) / 1000 || .033);
  last = ms;
  const t = ms / 1000;
  ctx.clearRect(0, 0, W, H);
  drawMist(t);
  drawWater(t);
  drawRain(dt);

  // Rare, soft cloud illumination rather than a harsh full-screen flash.
  const pulse = Math.pow(Math.max(0, Math.sin(t * .31 - 1.1)), 42) * .08;
  if (pulse > .001) {
    const g = ctx.createRadialGradient(W * .50, H * .15, 0, W * .50, H * .15, W * .48);
    g.addColorStop(0, `rgba(205,225,245,${pulse})`);
    g.addColorStop(1, 'rgba(205,225,245,0)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H * .62);
  }
}
requestAnimationFrame(render);
</script>
</body>
</html>
HTML

cat > "$JXA" <<'JXA'
ObjC.import('Cocoa');
ObjC.import('WebKit');
ObjC.import('CoreGraphics');

const app = $.NSApplication.sharedApplication;
app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
const root = ObjC.unwrap($.NSProcessInfo.processInfo.environment.objectForKey('STORMY_ROOT'));
const htmlURL = $.NSURL.fileURLWithPath(root + '/wallpaper.html');
const rootURL = $.NSURL.fileURLWithPath(root);
const windows = [];
const webviews = [];
const screens = $.NSScreen.screens;
const desktopLevel = $.CGWindowLevelForKey($.kCGDesktopWindowLevelKey) + 1;

for (let i = 0; i < screens.count; i++) {
  const screen = screens.objectAtIndex(i);
  const frame = screen.frame;
  const window = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
    frame,
    $.NSWindowStyleMaskBorderless,
    $.NSBackingStoreBuffered,
    false
  );
  window.opaque = true;
  window.backgroundColor = $.NSColor.blackColor;
  window.hasShadow = false;
  window.ignoresMouseEvents = true;
  window.hidesOnDeactivate = false;
  window.releasedWhenClosed = false;
  window.level = desktopLevel;
  window.collectionBehavior =
    $.NSWindowCollectionBehaviorCanJoinAllSpaces |
    $.NSWindowCollectionBehaviorStationary |
    $.NSWindowCollectionBehaviorIgnoresCycle;

  const configuration = $.WKWebViewConfiguration.alloc.init;
  const web = $.WKWebView.alloc.initWithFrameConfiguration(
    $.NSMakeRect(0, 0, frame.size.width, frame.size.height),
    configuration
  );
  web.autoresizingMask = $.NSViewWidthSizable | $.NSViewHeightSizable;
  web.loadFileURLAllowingReadAccessToURL(htmlURL, rootURL);
  window.contentView = web;
  window.setFrameDisplay(frame, true);
  window.orderFrontRegardless;
  windows.push(window);
  webviews.push(web);
}
app.run;
JXA

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/osascript</string>
    <string>-l</string>
    <string>JavaScript</string>
    <string>$JXA</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict><key>STORMY_ROOT</key><string>$ROOT</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
  <key>StandardOutPath</key><string>$ROOT/wallpaper.log</string>
  <key>StandardErrorPath</key><string>$ROOT/wallpaper-error.log</string>
</dict>
</plist>
PLIST

/bin/launchctl bootstrap "gui/$UID_NUMBER" "$PLIST" \
  || fail "macOS would not register the repaired wallpaper player."
/bin/launchctl kickstart -k "gui/$UID_NUMBER/$LABEL" >/dev/null 2>&1 || true
sleep 3

if /usr/bin/pgrep -f "$JXA" >/dev/null 2>&1; then
  printf '\nDone — the full-resolution animated wallpaper is now running.\n'
  /usr/bin/osascript -e 'display notification "The sharp storm wallpaper is now running." with title "Wallpaper repaired"' >/dev/null 2>&1 || true
else
  ERROR_TAIL="$(/usr/bin/tail -n 10 "$ROOT/wallpaper-error.log" 2>/dev/null || true)"
  fail "The repaired player did not stay running. $ERROR_TAIL"
fi
