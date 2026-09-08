# Ehitab korrutaja.src.html -> index.html (iseseisev PWA) + sw.js. Käivita: python3 build.py (vajab Pillow: pip install pillow)
from PIL import Image, ImageDraw
import base64, io, json, os
root=os.path.dirname(os.path.abspath(__file__))
def icon(sz):
    im=Image.new('RGB',(sz,sz),'#2F49D1'); d=ImageDraw.Draw(im)
    m=sz*0.28; w=int(sz*0.11)
    d.line([(m,m),(sz-m,sz-m)],fill='#FBF7EE',width=w); d.line([(sz-m,m),(m,sz-m)],fill='#FBF7EE',width=w)
    r=w//2
    for (x,y) in [(m,m),(sz-m,sz-m),(sz-m,m),(m,sz-m)]: d.ellipse([x-r,y-r,x+r,y+r],fill='#FBF7EE')
    b=io.BytesIO(); im.save(b,'PNG',optimize=True); return base64.b64encode(b.getvalue()).decode()
i180=icon(180); i192=icon(192); i512=icon(512)
manifest={"name":"Korrutaja","short_name":"Korrutaja","start_url":"./index.html","display":"standalone","background_color":"#FBF7EE","theme_color":"#FBF7EE","lang":"et",
 "icons":[{"src":"data:image/png;base64,"+i192,"sizes":"192x192","type":"image/png"},{"src":"data:image/png;base64,"+i512,"sizes":"512x512","type":"image/png"}]}
mjson=json.dumps(manifest,separators=(',',':'))
frag=open(os.path.join(root,'korrutaja.src.html'),encoding='utf-8').read()
# Supabase config (ainult index.html-i; artefakti fragment jääb tühjaks)
cfg_path=os.path.join(root,'config.json')
if os.path.exists(cfg_path):
    cfg=json.load(open(cfg_path,encoding='utf-8'))
    frag=frag.replace("var SB={url:'',key:''};","var SB={url:'%s',key:'%s'};"%(cfg.get('url',''),cfg.get('key','')),1)
head_extra=('<link rel="manifest" href="data:application/manifest+json;charset=utf-8,'+mjson.replace('"','%22').replace('#','%23')+'">\n'
 '<link rel="apple-touch-icon" href="data:image/png;base64,'+i180+'">\n'
 '<link rel="icon" href="data:image/png;base64,'+i192+'">\n')
cut=frag.index('</style>')+len('</style>')
sw='<script>if("serviceWorker" in navigator&&location.protocol==="https:"){navigator.serviceWorker.register("./sw.js").catch(function(){});}</script>\n'
html='<!doctype html>\n<html lang="et">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no">\n'+head_extra+frag[:cut]+'\n</head>\n<body>\n'+frag[cut:]+'\n'+sw+'</body>\n</html>\n'
open(os.path.join(root,'index.html'),'w',encoding='utf-8').write(html)
open(os.path.join(root,'sw.js'),'w',encoding='utf-8').write('''const C='korrutaja-v3';
self.addEventListener('install',e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(['./','./index.html'])).then(()=>self.skipWaiting()));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==C).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET')return;
  const u=new URL(e.request.url);
  if(u.pathname.indexOf('/rest/')>=0)return;
  if(u.origin===location.origin){e.respondWith(fetch(e.request).then(r=>{const cp=r.clone();caches.open(C).then(c=>c.put(e.request,cp));return r;}).catch(()=>caches.match(e.request).then(r=>r||caches.match('./index.html'))));}
  else{e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(x=>{const cp=x.clone();caches.open(C).then(c=>c.put(e.request,cp));return x;})));}
});
''')
print('index.html', os.path.getsize(os.path.join(root,'index.html'))//1024,'KB')
