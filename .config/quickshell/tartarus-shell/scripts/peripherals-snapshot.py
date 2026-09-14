#!/usr/bin/env python3
import glob,json,os,re
def rd(p):
 try:
  with open(p,encoding="utf-8",errors="replace") as f:return f.read().strip()
 except OSError:return ""
def usb():
 out=[]
 for d in glob.glob("/sys/bus/usb/devices/*-*"):
  if not os.path.exists(d+"/idVendor"):continue
  vid=rd(d+"/idVendor");pid=rd(d+"/idProduct")
  if vid and pid:out.append({"kind":"USB","name":rd(d+"/product") or "USB device","vendor":rd(d+"/manufacturer") or "Unknown","id":vid+":"+pid,"path":os.path.basename(d)})
 return out
def inputs():
 out=[]
 for block in rd("/proc/bus/input/devices").split("\n\n"):
  n=re.search(r'N: Name="([^"]+)',block);h=re.search(r'H: Handlers=([^\n]+)',block)
  if not n or not h:continue
  handlers=h.group(1)
  if not any(x in handlers for x in ("event","kbd","mouse")):continue
  kind="Teclado" if "kbd" in handlers else "Mouse" if "mouse" in handlers else "Entrada"
  out.append({"kind":kind,"name":n.group(1),"detail":handlers.strip()})
 return out
def simple(cls,kind):
 return [{"kind":kind,"name":rd(d+"/name") or os.path.basename(d),"detail":os.path.basename(d)} for d in glob.glob(cls)]
raw_usb=usb()
raw_inputs=inputs()
dev=raw_usb+raw_inputs+simple("/sys/class/video4linux/video*","Webcam")+simple("/sys/class/sound/card*","Audio")
for x in dev:
 s=(x["name"]+" "+x.get("vendor","")).lower()
 x["controller"]=""
 if "vendor" in x and any(k in s for k in ("iphone","ipad","apple")):x["kind"]="iPhone"
 elif any(k in s for k in ("light","lamp","led","illum","rgb")):x["kind"]="Iluminación"
 elif "vendor" in x and any(k in s for k in ("yeti","microphone","mic")):x["kind"]="Micrófono"
 elif any(k in s for k in ("huntsman","keyboard","teclado")):x["kind"]="Teclado"
 elif any(k in s for k in ("g305","mouse","ratón")):
  x["kind"]="Mouse"
  if "g305" in s:x["controller"]="logitech-g"
 elif any(k in s for k in ("8bitdo","controller","gamepad","game pad")):x["kind"]="Control"
 elif "logitech" in s:x["kind"]="Logitech"

# Hide implementation details exposed by USB and evdev. They are useful for
# debugging, but make the sidebar show the same physical device several times.
hidden_usb=("hub","wireless_device","wireless device","receiver","root hub")
hidden_input=("consumer control","pc speaker","hda ati hdmi","hd-audio","front mic","rear mic","line out","headphone","power button","leds")
usb_names=[" ".join(x.get("name","").lower().split()) for x in raw_usb]
input_names=[" ".join(x.get("name","").lower().split()) for x in raw_inputs]
visible=[]
seen=set()
for x in dev:
 name=" ".join(x.get("name","").lower().split())
 kind=x.get("kind","")
 if kind == "USB" and any(k in name for k in hidden_usb):
  continue
 if "receiver" in name or "wireless_device" in name:
  continue
 if kind == "Logitech" and "yeti" in name:
  continue
 if kind == "Audio" and name.startswith("card"):
  continue
 if kind in ("Teclado","Mouse","Entrada","Logitech") and any(k in name for k in hidden_input):
  continue
 # USB already represents the physical device; evdev exposes its keyboard,
 # mouse and consumer-control interfaces separately.
 if kind in ("Teclado","Mouse","Entrada") and "detail" in x:
  words=[w for w in name.split() if len(w)>3 and w not in ("keyboard","mouse","consumer","control")]
  if words and any(all(w in other for w in words[:2]) for other in usb_names):
   continue
 if kind in ("Micrófono","Logitech") and any(k in name for k in ("consumer control","leds")):
   continue
 canonical=re.sub(r"\b(for pc|keyboard|mouse|consumer control)\b", "", name).strip()
 key=(kind,"lighting") if kind == "Iluminación" else (kind,canonical)
 if key in seen:
  continue
 seen.add(key)
 visible.append(x)
dev=visible
print(json.dumps({"ok":True,"devices":dev}))
