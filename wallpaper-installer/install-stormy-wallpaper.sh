#!/bin/bash
set -Eeuo pipefail

OLD_LABEL="com.openai.stormylakewallpaper"
LABEL="com.openai.stormylakewallpaper.crisp"
OLD_ROOT="$HOME/Library/Application Support/StormyLakeWallpaper"
ROOT="$HOME/Library/Application Support/StormyLakeWallpaperCrisp"
IMAGE="$ROOT/stormy-lake-5712.jpg"
HTML="$ROOT/wallpaper.html"
JXA="$ROOT/wallpaper-crisp.js"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
OLD_PLIST="$HOME/Library/LaunchAgents/$OLD_LABEL.plist"
UID_NUMBER="$(id -u)"
IMAGE_URL='https://upload.wikimedia.org/wikipedia/commons/e/ef/Sprague_Lake_at_Sunset_%2829560309357%29.jpg'

fail() {
  local message="$1"
  printf '\nRepair stopped: %s\n' "$message" >&2
  /usr/bin/osascript -e "display dialog \"Stormy wallpaper could not be repaired.\\n\\n$message\" buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null 2>&1 || true
  exit 1
}

printf '\nReplacing the broken wallpaper with a crisp full-resolution version…\n'
mkdir -p "$ROOT" "$HOME/Library/LaunchAgents"

# Stop every earlier version first. The old player was kept alive by launchd,
# so killing only its window was not enough.
for service in \
  "$OLD_LABEL" \
  "$OLD_LABEL.v2" \
  "$OLD_LABEL.v3" \
  "$OLD_LABEL.hd" \
  "$LABEL"
do
  /bin/launchctl bootout "gui/$UID_NUMBER/$service" >/dev/null 2>&1 || true
done

for plist in \
  "$OLD_PLIST" \
  "$HOME/Library/LaunchAgents/$OLD_LABEL.v2.plist" \
  "$HOME/Library/LaunchAgents/$OLD_LABEL.v3.plist" \
  "$HOME/Library/LaunchAgents/$OLD_LABEL.hd.plist" \
  "$PLIST"
do
  /bin/launchctl bootout "gui/$UID_NUMBER" "$plist" >/dev/null 2>&1 || true
  /bin/rm -f "$plist"
done

# Kill only processes that contain one of our wallpaper paths/names.
/usr/bin/pkill -9 -f 'StormyLakeWallpaper' >/dev/null 2>&1 || true
/usr/bin/pkill -9 -f 'wallpaper-crisp\.js' >/dev/null 2>&1 || true
/usr/bin/pkill -9 -f 'wallpaper\.js' >/dev/null 2>&1 || true
sleep 2

# Download the original 5712 x 2877 source image. No tiny embedded thumbnail.
printf 'Downloading the 5712-pixel background…\n'
TMP_IMAGE="$ROOT/stormy-lake.download"
/bin/rm -f "$TMP_IMAGE" "$IMAGE"
/usr/bin/curl -fL --retry 5 --retry-delay 2 --connect-timeout 25 \
  -A 'Mozilla/5.0' "$IMAGE_URL" -o "$TMP_IMAGE" \
  || fail "The full-resolution image could not be downloaded."

[[ -s "$TMP_IMAGE" ]] || fail "The full-resolution image download was empty."
WIDTH="$(/usr/bin/sips -g pixelWidth "$TMP_IMAGE" 2>/dev/null | /usr/bin/awk '/pixelWidth/ {print $2; exit}')"
HEIGHT="$(/usr/bin/sips -g pixelHeight "$TMP_IMAGE" 2>/dev/null | /usr/bin/awk '/pixelHeight/ {print $2; exit}')"
[[ "$WIDTH" =~ ^[0-9]+$ && "$HEIGHT" =~ ^[0-9]+$ ]] || fail "macOS could not read the downloaded image."
(( WIDTH >= 3000 && HEIGHT >= 1400 )) || fail "The image host returned a small preview (${WIDTH}x${HEIGHT}) instead of the original."
/bin/mv -f "$TMP_IMAGE" "$IMAGE"
printf 'Using a %sx%s source image.\n' "$WIDTH" "$HEIGHT"

cat > "$HTML" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<style>
  * { box-sizing: border-box; }
  html, body { margin:0; width:100%; height:100%; overflow:hidden; background:#06111a; }
  .image-layer {
    position:fixed;
    inset:-10px;
    background-image:url('stormy-lake-5712.jpg');
    background-position:center center;
    background-repeat:no-repeat;
    background-size:cover;
    image-rendering:auto;
    transform:translateZ(0) scale(1.006);
    backface-visibility:hidden;
  }
  #left-trees {
    pointer-events:none;
    transform-origin:14% 72%;
    clip-path:polygon(0 0,39% 0,36% 64%,30% 76%,0 76%);
    -webkit-mask-image:linear-gradient(to right,#000 0 75%,transparent 100%),linear-gradient(to bottom,#000 0 78%,transparent 100%);
    -webkit-mask-composite:source-in;
    animation:leftSway 8s ease-in-out infinite alternate;
  }
  #right-trees {
    pointer-events:none;
    transform-origin:84% 69%;
    clip-path:polygon(65% 6%,100% 6%,100% 73%,69% 73%);
    -webkit-mask-image:linear-gradient(to left,#000 0 78%,transparent 100%),linear-gradient(to bottom,#000 0 80%,transparent 100%);
    -webkit-mask-composite:source-in;
    animation:rightSway 9.4s ease-in-out infinite alternate;
  }
  @keyframes leftSway {
    0% { transform:translateX(-1.5px) rotate(-.045deg) scale(1.006); }
    50% { transform:translateX(.5px) rotate(.018deg) scale(1.006); }
    100% { transform:translateX(2.5px) rotate(.065deg) scale(1.006); }
  }
  @keyframes rightSway {
    0% { transform:translateX(1.5px) rotate(.04deg) scale(1.006); }
    100% { transform:translateX(-2px) rotate(-.055deg) scale(1.006); }
  }
  .mist {
    position:fixed;
    border-radius:50%;
    filter:blur(38px);
    mix-blend-mode:screen;
    pointer-events:none;
    background:radial-gradient(ellipse,rgba(197,216,226,.44),rgba(179,202,214,.14) 50%,transparent 74%);
    will-change:transform;
  }
  #mist-a { width:46vw;height:11vh;left:17vw;top:30vh;opacity:.12;animation:mistA 22s ease-in-out infinite alternate; }
  #mist-b { width:38vw;height:9vh;left:43vw;top:44vh;opacity:.085;animation:mistB 27s ease-in-out infinite alternate; }
  @keyframes mistA { from{transform:translateX(-4vw) translateY(1vh) scale(.96)} to{transform:translateX(5vw) translateY(-1vh) scale(1.07)} }
  @keyframes mistB { from{transform:translateX(4vw) scale(.96)} to{transform:translateX(-5vw) scale(1.08)} }
  #water-shimmer {
    position:fixed;left:0;right:0;top:59%;bottom:0;pointer-events:none;
    opacity:.11;mix-blend-mode:screen;
    background:repeating-linear-gradient(176deg,transparent 0 14px,rgba(177,214,234,.13) 16px,transparent 19px 34px);
    background-size:135% 135%;
    -webkit-mask-image:linear-gradient(to bottom,transparent,#000 23%);
    animation:waterShimmer 14s linear infinite;
  }
  @keyframes waterShimmer { from{background-position:0 0} to{background-position:90px 30px} }
  canvas { position:fixed;inset:0;width:100%;height:100%;pointer-events:none; }
  #finish {
    position:fixed;inset:0;pointer-events:none;
    background:radial-gradient(circle at 51% 46%,transparent 44%,rgba(0,6,13,.22) 100%),rgba(3,14,24,.025);
  }
</style>
</head>
<body>
  <div id="base" class="image-layer"></div>
  <div id="left-trees" class="image-layer"></div>
  <div id="right-trees" class="image-layer"></div>
  <div id="mist-a" class="mist"></div>
  <div id="mist-b" class="mist"></div>
  <div id="water-shimmer"></div>
  <canvas id="weather"></canvas>
  <div id="finish"></div>
<script>
'use strict';
const canvas=document.getElementById('weather');
const ctx=canvas.getContext('2d',{alpha:true,desynchronized:true});
let W=1,H=1,last=0,rain=[],rings=[];
function reset(){
  W=Math.max(1,innerWidth);H=Math.max(1,innerHeight);
  canvas.width=W;canvas.height=H;
  rain=[];rings=[];
  const count=Math.min(600,Math.round(330*W*H/(1920*1080)));
  for(let i=0;i<count;i++) rain.push({
    x:Math.random()*W,y:Math.random()*H,
    v:470+Math.random()*730,l:10+Math.random()*26,
    a:.10+Math.random()*.33,w:.55+Math.random()*.8
  });
  for(let i=0;i<24;i++) rings.push({
    x:W*(.25+Math.random()*.72),y:H*(.65+Math.random()*.32),
    p:Math.random(),v:.18+Math.random()*.24
  });
}
addEventListener('resize',reset);reset();
function frame(ms){
  if(ms-last<32){requestAnimationFrame(frame);return;}
  const dt=Math.min(.05,(ms-last)/1000||.033);last=ms;
  ctx.clearRect(0,0,W,H);ctx.lineCap='round';
  for(const p of rain){
    p.y+=p.v*dt;p.x-=p.v*.20*dt;
    if(p.y>H+40||p.x<-45){p.y=-40-Math.random()*H*.28;p.x=Math.random()*W+W*.06;}
    ctx.strokeStyle=`rgba(210,229,240,${p.a})`;ctx.lineWidth=p.w;
    ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(p.x-p.l*.27,p.y+p.l);ctx.stroke();
  }
  for(const r of rings){
    r.p+=r.v*dt;
    if(r.p>1){r.p=0;r.x=W*(.24+Math.random()*.74);r.y=H*(.65+Math.random()*.32);}
    const radius=3+r.p*36;
    ctx.strokeStyle=`rgba(221,235,243,${(1-r.p)*.30})`;ctx.lineWidth=.8;
    ctx.beginPath();ctx.ellipse(r.x,r.y,radius,radius*.24,0,0,Math.PI*2);ctx.stroke();
    if(r.p<.07){
      ctx.strokeStyle='rgba(231,241,247,.28)';ctx.beginPath();
      ctx.moveTo(r.x,r.y);ctx.lineTo(r.x-2,r.y-7);
      ctx.moveTo(r.x,r.y);ctx.lineTo(r.x+3,r.y-6);ctx.stroke();
    }
  }
  const t=ms*.001,pulse=Math.max(0,Math.sin(t*.29-1.15)),flash=Math.pow(pulse,52)*.055;
  if(flash>.001){ctx.fillStyle=`rgba(207,226,245,${flash})`;ctx.fillRect(0,0,W,H);}
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
</script>
</body>
</html>
HTML

cat > "$JXA" <<'JXA'
ObjC.import('Cocoa');
ObjC.import('WebKit');
ObjC.import('CoreGraphics');

const app=$.NSApplication.sharedApplication;
app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
const root=ObjC.unwrap($.NSProcessInfo.processInfo.environment.objectForKey('STORMY_ROOT'));
const htmlURL=$.NSURL.fileURLWithPath(root+'/wallpaper.html');
const rootURL=$.NSURL.fileURLWithPath(root);
const windows=[];
const webviews=[];
const screens=$.NSScreen.screens;
const desktopLevel=$.CGWindowLevelForKey($.kCGDesktopWindowLevelKey)+1;

for(let i=0;i<screens.count;i++){
  const screen=screens.objectAtIndex(i);
  const frame=screen.frame;
  const win=$.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
    frame,$.NSWindowStyleMaskBorderless,$.NSBackingStoreBuffered,false
  );
  win.opaque=true;
  win.backgroundColor=$.NSColor.blackColor;
  win.hasShadow=false;
  win.ignoresMouseEvents=true;
  win.hidesOnDeactivate=false;
  win.releasedWhenClosed=false;
  win.level=desktopLevel;
  win.collectionBehavior=$.NSWindowCollectionBehaviorCanJoinAllSpaces|$.NSWindowCollectionBehaviorStationary|$.NSWindowCollectionBehaviorIgnoresCycle;

  const config=$.WKWebViewConfiguration.alloc.init;
  const web=$.WKWebView.alloc.initWithFrameConfiguration(
    $.NSMakeRect(0,0,frame.size.width,frame.size.height),config
  );
  web.autoresizingMask=$.NSViewWidthSizable|$.NSViewHeightSizable;
  web.loadFileURLAllowingReadAccessToURL(htmlURL,rootURL);
  win.contentView=web;
  win.setFrameDisplay(frame,true);
  win.orderFrontRegardless;
  windows.push(win);webviews.push(web);
}
app.run;
JXA

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>/usr/bin/osascript</string><string>-l</string><string>JavaScript</string><string>$JXA</string>
  </array>
  <key>EnvironmentVariables</key><dict><key>STORMY_ROOT</key><string>$ROOT</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
  <key>ThrottleInterval</key><integer>5</integer>
  <key>StandardOutPath</key><string>$ROOT/wallpaper.log</string>
  <key>StandardErrorPath</key><string>$ROOT/wallpaper-error.log</string>
</dict></plist>
PLIST

/bin/launchctl enable "gui/$UID_NUMBER/$LABEL" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "gui/$UID_NUMBER" "$PLIST" || fail "macOS would not load the crisp wallpaper service."
/bin/launchctl kickstart -k "gui/$UID_NUMBER/$LABEL" >/dev/null 2>&1 || true
sleep 4

if /usr/bin/pgrep -f "$JXA" >/dev/null 2>&1; then
  printf '\nDone — the old blocky renderer is gone and the crisp animated wallpaper is running.\n'
  /usr/bin/osascript -e 'display notification "The crisp animated lake wallpaper is now running." with title "Wallpaper repaired"' >/dev/null 2>&1 || true
else
  ERR="$(/usr/bin/tail -n 12 "$ROOT/wallpaper-error.log" 2>/dev/null || true)"
  fail "The crisp wallpaper process did not stay running. ${ERR}"
fi
