#!/bin/bash
set -Eeuo pipefail

LABEL="com.openai.stormylakewallpaper"
ROOT="$HOME/Library/Application Support/StormyLakeWallpaper"
HTML="$ROOT/wallpaper.html"
JXA="$ROOT/wallpaper.js"
IMAGE="$ROOT/stormy-lake.jpg"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
B64_URL="https://raw.githubusercontent.com/CryptoJym/Overseer/stormy-wallpaper/wallpaper-installer/stormy-lake.jpg.b64"
EXPECTED_SHA="c563c55da3cbfb5e833a794c6232833ea1d6068a8561674349322777df1eff1b"
UID_NUMBER="$(id -u)"

fail() {
  printf '\nInstallation stopped: %s\n' "$1" >&2
  /usr/bin/osascript -e "display dialog \"Stormy wallpaper could not be installed.\\n\\n$1\" buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null 2>&1 || true
  exit 1
}

printf '\nInstalling your animated storm-lake wallpaper…\n'
mkdir -p "$ROOT" "$HOME/Library/LaunchAgents"

TMP_B64="$ROOT/stormy-lake.jpg.b64.download"
rm -f "$TMP_B64" "$IMAGE"
/usr/bin/curl -fsSL --retry 4 --retry-delay 1 --connect-timeout 20 "$B64_URL" -o "$TMP_B64" \
  || fail "The wallpaper image could not be retrieved. Check the internet connection and run the same command again."
/usr/bin/base64 -D -i "$TMP_B64" -o "$IMAGE" \
  || fail "The wallpaper image could not be decoded."
rm -f "$TMP_B64"

ACTUAL_SHA="$(/usr/bin/shasum -a 256 "$IMAGE" | /usr/bin/awk '{print $1}')"
[[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]] || fail "The wallpaper image failed its integrity check."

cat > "$HTML" <<'HTML'
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<style>
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#07111a}
canvas{display:block;width:100vw;height:100vh}
</style>
</head>
<body>
<canvas id="scene"></canvas>
<script>
'use strict';
const canvas=document.getElementById('scene');
const ctx=canvas.getContext('2d',{alpha:false,desynchronized:true});
const img=new Image();
img.src='stormy-lake.jpg';
let W=1280,H=720,last=0;
const rain=[];
const rings=[];
const mist=[];

function resize(){
  const scale=Math.min(1,1600/Math.max(innerWidth,1),900/Math.max(innerHeight,1));
  W=Math.max(640,Math.round(innerWidth*scale));
  H=Math.max(360,Math.round(innerHeight*scale));
  canvas.width=W; canvas.height=H;
  rain.length=0;
  const count=Math.round(Math.min(500,220*(W*H)/(1280*720)));
  for(let i=0;i<count;i++) rain.push({
    x:Math.random()*W,y:Math.random()*H,
    v:340+Math.random()*520,l:10+Math.random()*24,
    a:.12+Math.random()*.38,w:.55+Math.random()*.9
  });
  rings.length=0;
  for(let i=0;i<18;i++) rings.push({
    x:W*(.34+Math.random()*.60),y:H*(.66+Math.random()*.29),
    r:Math.random()*30,life:Math.random(),speed:.18+Math.random()*.22
  });
  mist.length=0;
  for(let i=0;i<5;i++) mist.push({
    x:W*(.20+Math.random()*.65),y:H*(.25+Math.random()*.30),
    rx:W*(.10+Math.random()*.13),ry:H*(.025+Math.random()*.035),
    speed:.000018+Math.random()*.000025,phase:Math.random()*Math.PI*2,a:.025+Math.random()*.035
  });
}
addEventListener('resize',resize); resize();

function geometry(extra=1,ox=0,oy=0){
  const s=Math.max(W/img.width,H/img.height)*extra;
  const dw=img.width*s,dh=img.height*s;
  return {x:(W-dw)/2+ox,y:(H-dh)/2+oy,w:dw,h:dh};
}
function drawCover(g){ctx.drawImage(img,g.x,g.y,g.w,g.h)}

function drawScene(ms,dt){
  const t=ms*.001;
  ctx.fillStyle='#07111a';ctx.fillRect(0,0,W,H);
  const g=geometry(1.018,Math.sin(t*.12)*2.0,Math.cos(t*.10)*1.2);
  drawCover(g);

  // Left and right tree groups move in opposite wind phases.
  const sway=Math.sin(t*.78)*3.2+Math.sin(t*1.37)*1.1;
  ctx.save();ctx.beginPath();ctx.rect(0,0,W*.35,H*.67);ctx.clip();ctx.translate(sway,0);drawCover(g);ctx.restore();
  ctx.save();ctx.beginPath();ctx.rect(W*.69,0,W*.31,H*.64);ctx.clip();ctx.translate(-sway*.55,0);drawCover(g);ctx.restore();

  // The lower lake is redrawn as thin moving strips to create water movement.
  const waterTop=Math.floor(H*.585);
  for(let y=waterTop;y<H;y+=5){
    const amp=1.2+5.5*((y-waterTop)/(H-waterTop));
    const dx=Math.sin(y*.075+t*1.65)*amp+Math.sin(y*.031-t*.88)*1.5;
    ctx.save();ctx.beginPath();ctx.rect(0,y,W,6);ctx.clip();ctx.translate(dx,0);drawCover(g);ctx.restore();
  }

  // Low fog moves across the mountain and tree line.
  ctx.save();ctx.globalCompositeOperation='screen';
  for(const m of mist){
    const x=m.x+Math.sin(ms*m.speed+m.phase)*W*.08;
    const grad=ctx.createRadialGradient(x,m.y,0,x,m.y,m.rx);
    grad.addColorStop(0,`rgba(200,216,225,${m.a})`);
    grad.addColorStop(.55,`rgba(185,205,215,${m.a*.55})`);
    grad.addColorStop(1,'rgba(180,200,210,0)');
    ctx.save();ctx.translate(x,m.y);ctx.scale(1,m.ry/m.rx);ctx.translate(-x,-m.y);
    ctx.fillStyle=grad;ctx.beginPath();ctx.arc(x,m.y,m.rx,0,Math.PI*2);ctx.fill();ctx.restore();
  }
  ctx.restore();

  // Falling wind-driven rain.
  ctx.lineCap='round';
  for(const p of rain){
    p.y+=p.v*dt;p.x-=p.v*.22*dt;
    if(p.y>H+35||p.x<-35){p.y=-35-Math.random()*H*.25;p.x=Math.random()*W+W*.05;}
    ctx.strokeStyle=`rgba(205,225,238,${p.a})`;ctx.lineWidth=p.w;
    ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(p.x-p.l*.30,p.y+p.l);ctx.stroke();
  }

  // Rain rings and tiny splashes on the lake.
  for(const r of rings){
    r.life+=r.speed*dt;
    if(r.life>1){r.life=0;r.x=W*(.30+Math.random()*.66);r.y=H*(.65+Math.random()*.31);}
    const radius=3+r.life*32;
    ctx.strokeStyle=`rgba(218,232,240,${(1-r.life)*.32})`;ctx.lineWidth=.8;
    ctx.beginPath();ctx.ellipse(r.x,r.y,radius,radius*.25,0,0,Math.PI*2);ctx.stroke();
    if(r.life<.10){
      ctx.strokeStyle=`rgba(230,240,245,${(.10-r.life)*2.1})`;
      ctx.beginPath();ctx.moveTo(r.x,r.y);ctx.lineTo(r.x-2,r.y-5);ctx.moveTo(r.x,r.y);ctx.lineTo(r.x+2,r.y-4);ctx.stroke();
    }
  }

  // Occasional soft lightning behind the clouds.
  const pulse=Math.max(0,Math.sin(t*.43-1.4));
  const flash=Math.pow(pulse,34)*.12;
  if(flash>.001){ctx.fillStyle=`rgba(205,225,245,${flash})`;ctx.fillRect(0,0,W,H);}

  // Slight storm tint and vignette.
  ctx.fillStyle='rgba(2,14,25,.07)';ctx.fillRect(0,0,W,H);
  const vg=ctx.createRadialGradient(W*.53,H*.48,H*.16,W*.53,H*.48,W*.72);
  vg.addColorStop(.45,'rgba(0,0,0,0)');vg.addColorStop(1,'rgba(0,5,12,.30)');
  ctx.fillStyle=vg;ctx.fillRect(0,0,W,H);
}

function frame(ms){
  if(!img.complete||!img.naturalWidth){requestAnimationFrame(frame);return;}
  if(ms-last<31){requestAnimationFrame(frame);return;}
  const dt=Math.min(.05,(ms-last)/1000||.033);last=ms;
  drawScene(ms,dt);requestAnimationFrame(frame);
}
img.onload=()=>requestAnimationFrame(frame);
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
  const win=$.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(frame,$.NSWindowStyleMaskBorderless,$.NSBackingStoreBuffered,false);
  win.opaque=true;
  win.backgroundColor=$.NSColor.blackColor;
  win.hasShadow=false;
  win.ignoresMouseEvents=true;
  win.hidesOnDeactivate=false;
  win.releasedWhenClosed=false;
  win.level=desktopLevel;
  win.collectionBehavior=$.NSWindowCollectionBehaviorCanJoinAllSpaces|$.NSWindowCollectionBehaviorStationary|$.NSWindowCollectionBehaviorIgnoresCycle;

  const config=$.WKWebViewConfiguration.alloc.init;
  const web=$.WKWebView.alloc.initWithFrameConfiguration($.NSMakeRect(0,0,frame.size.width,frame.size.height),config);
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
<key>ProgramArguments</key><array><string>/usr/bin/osascript</string><string>-l</string><string>JavaScript</string><string>$JXA</string></array>
<key>EnvironmentVariables</key><dict><key>STORMY_ROOT</key><string>$ROOT</string></dict>
<key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
<key>ProcessType</key><string>Interactive</string>
<key>LimitLoadToSessionType</key><string>Aqua</string>
<key>StandardOutPath</key><string>$ROOT/wallpaper.log</string>
<key>StandardErrorPath</key><string>$ROOT/wallpaper-error.log</string>
</dict></plist>
PLIST

/bin/launchctl bootout "gui/$UID_NUMBER" "$PLIST" >/dev/null 2>&1 || true
/usr/bin/pkill -f "$JXA" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "gui/$UID_NUMBER" "$PLIST" || fail "macOS would not register the wallpaper player."
/bin/launchctl kickstart -k "gui/$UID_NUMBER/$LABEL" >/dev/null 2>&1 || true
sleep 3

if /usr/bin/pgrep -f "$JXA" >/dev/null 2>&1; then
  printf '\nDone — your storm-lake wallpaper is animated and will restart automatically at login.\n'
  /usr/bin/osascript -e 'display notification "Rain, trees, mist, and lake motion are now running." with title "Stormy wallpaper installed"' >/dev/null 2>&1 || true
else
  ERR="$(tail -n 8 "$ROOT/wallpaper-error.log" 2>/dev/null || true)"
  fail "The wallpaper player did not stay running. ${ERR}"
fi
