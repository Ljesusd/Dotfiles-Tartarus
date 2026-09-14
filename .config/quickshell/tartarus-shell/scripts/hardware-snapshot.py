#!/usr/bin/env python3
import glob,json,os,re,subprocess,time,shutil
def rd(p):
 try:
  with open(p,encoding="utf-8",errors="replace") as f:return f.read().strip()
 except OSError:return ""
def val(p,scale=1):
 try:return float(rd(p))/scale
 except (ValueError,TypeError):return None
def pct(a,b):
 if not a or not b or b[0]<=a[0]:return 0
 return round(max(0,min(100,(1-(b[1]-a[1])/(b[0]-a[0]))*100)),1)
def counters():
 r={}
 for l in rd("/proc/stat").splitlines():
  p=l.split()
  if p and (p[0]=="cpu" or re.fullmatch(r"cpu\d+",p[0])):
   x=list(map(int,p[1:8]));r[p[0]]=(sum(x),x[3]+x[4])
 return r
def cpu():
 a=counters();time.sleep(.12);b=counters()
 u=pct((a.get("cpu") or (0,0)),(b.get("cpu") or (0,0)))
 cores=[pct(a.get("cpu"+str(i)),b.get("cpu"+str(i))) for i in range(len([x for x in b if x!="cpu"]))]
 return u,cores
def gpu():
 for d in sorted(glob.glob("/sys/class/drm/card[0-9]*/device")):
  if rd(d+"/vendor")!="0x1002":continue
  t=None; power=None; power_limit=None; fan_value=None
  for h in glob.glob("/sys/class/hwmon/hwmon*"):
   if os.path.realpath(d) in os.path.realpath(h+"/device"):
    for f in glob.glob(h+"/temp*_input"):
     x=val(f,1000)
     if x is not None:t=x
    power=val(h+"/power1_average",1000000)
    power_limit=val(h+"/power1_cap",1000000)
    for f in glob.glob(h+"/fan*_input"):
     fan_value=val(f); break
  name="AMD GPU"
  try:
   for l in subprocess.run(["lspci","-mm"],capture_output=True,text=True,timeout=.5).stdout.splitlines():
    if "VGA compatible controller" in l or "3D controller" in l:
     q=re.findall(r'"([^"]+)"',l);name=q[2] if len(q)>2 else name;break
  except Exception:pass
  level=rd(d+"/power_dpm_force_performance_level") or rd(d+"/power1_average")
  clocks=rd(d+"/pp_dpm_sclk").replace("\n"," ")
  return {"detected":True,"vendor":"AMD","name":name,"usage":val(d+"/gpu_busy_percent"),"memoryUsed":val(d+"/mem_info_vram_used",1073741824),"memoryTotal":val(d+"/mem_info_vram_total",1073741824),"temperature":t,"power":power,"powerLimit":power_limit,"fan":fan_value,"powerMode":level,"clocks":clocks,"processes":gpu_processes(d)}
 # NVIDIA fallback when its driver is active.
 if os.path.exists('/proc/driver/nvidia/version') and shutil.which('nvidia-smi'):
  try:
   p=subprocess.run(['timeout','2','nvidia-smi','--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit','--format=csv,noheader,nounits'],capture_output=True,text=True,timeout=3).stdout.splitlines()[0].split(',')
   return {'detected':True,'vendor':'NVIDIA','name':p[0].strip(),'usage':float(p[1]),'memoryUsed':float(p[2])/1024,'memoryTotal':float(p[3])/1024,'temperature':float(p[4]),'power':float(p[5]),'powerLimit':float(p[6]),'processes':[]}
  except Exception: pass
 # Intel/other DRM devices still expose a device and can be identified even
 # when no privileged utilization counter is available.
 for d in sorted(glob.glob('/sys/class/drm/card[0-9]*/device')):
  vendor=rd(d+'/vendor')
  if vendor not in ('0x8086','0x1002'): continue
  return {'detected':True,'vendor':'Intel' if vendor=='0x8086' else 'AMD','name':'GPU','usage':val(d+'/gpu_busy_percent'),'processes':gpu_processes(d)}
 return {"detected":False,"name":"GPU"}
def gpu_processes(device):
    result=[]; prefix=os.path.realpath(device).split('/device')[0]
    card=os.path.basename(prefix)
    nodes=[os.path.realpath(x) for x in glob.glob('/sys/class/drm/'+card+'/renderD*')]
    for pid in os.listdir('/proc'):
        if not pid.isdigit(): continue
        fdroot='/proc/'+pid+'/fd'; found=False
        try:
            for fd in os.listdir(fdroot):
                target=os.path.realpath(fdroot+'/'+fd)
                if '/dev/dri/' in target and (not nodes or target in nodes):
                    found=True; break
        except OSError: continue
        if not found: continue
        name=rd('/proc/'+pid+'/comm') or '?'
        result.append({'name':name,'pid':pid})
        if len(result)>=8: break
    return result
def mem():
 x={}
 for l in rd("/proc/meminfo").splitlines():
  p=l.split()
  if p and p[0] in ("MemTotal:","MemAvailable:"):x[p[0]]=int(p[1])
 t=x.get("MemTotal:",0)/1048576;u=(x.get("MemTotal:",0)-x.get("MemAvailable:",0))/1048576
 return {"used":round(u,1),"total":round(t,1),"percent":round(u/t*100,1) if t else 0}
def disks():
 r=[]
 try:
  for l in subprocess.run(["df","-P","-x","tmpfs","-x","devtmpfs","-x","squashfs"],capture_output=True,text=True,timeout=1).stdout.splitlines()[1:]:
   p=l.split()
   if len(p)>=6 and p[0].startswith("/dev/"):r.append({"mount":p[5],"used":round(int(p[2])/1048576,1),"total":round(int(p[1])/1048576,1),"percent":int(p[4].strip("%"))})
 except Exception:pass
 return r
def disk_io():
    now=time.monotonic()
    reads=writes=0
    for line in rd('/proc/diskstats').splitlines():
        p=line.split()
        if len(p)<14 or p[2].startswith(('loop','ram','zram','dm-','sr')): continue
        if re.search(r'p\d+$',p[2]): continue
        try: reads += int(p[5]); writes += int(p[9])
        except ValueError: pass
    path='/tmp/tartarus-hardware-io'
    old=None
    try:
        q=rd(path).split(); old=(float(q[0]),int(q[1]),int(q[2]))
    except (ValueError,IndexError): pass
    try:
        with open(path,'w') as f: f.write(f'{now} {reads} {writes}\n')
    except OSError: pass
    if not old or now-old[0] <= 0: return {'read':None,'write':None}
    dt=now-old[0]
    return {'read':round(max(0,(reads-old[1])*512/1048576/dt),1),'write':round(max(0,(writes-old[2])*512/1048576/dt),1)}
def battery():
    for p in glob.glob('/sys/class/power_supply/BAT*'):
        x=val(p+'/capacity')
        if x is not None:return {'percent':round(x),'status':rd(p+'/status')}
    return {'percent':None,'status':''}
def fan():
    for p in glob.glob('/sys/class/hwmon/hwmon*/fan*_input'):
        x=val(p)
        if x is not None:return round(x)
    return None
def smart_one(mount):
    if not shutil.which('smartctl'): return 'No disponible'
    try:
        src=subprocess.run(['findmnt','-no','SOURCE',mount],capture_output=True,text=True,timeout=.5).stdout.strip()
        if not src:return 'No disponible'
        out=subprocess.run(['timeout','2','smartctl','-H',src],capture_output=True,text=True,timeout=3).stdout
        m=re.search(r'(?:SMART overall-health self-assessment test result|SMART Health Status):\s*(\w+)',out,re.I)
        return m.group(1).replace('_',' ') if m else 'No disponible'
    except Exception:return 'No disponible'
def processes():
 r=[]
 try:
  for l in subprocess.run(["ps","-eo","comm=,pid=,%cpu=,%mem=","--sort=-%cpu"],capture_output=True,text=True,timeout=1).stdout.splitlines()[:6]:
   p=l.split()
   if len(p)>=4:r.append({"name":p[0],"pid":p[1],"cpu":float(p[2]),"memory":float(p[3])})
 except Exception:pass
 return r
u,cu=cpu();freq=[round(val(p,1000000) or 0,2) for p in sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq"),key=lambda x:int(re.search(r"cpu(\d+)",x).group(1)))]
physical=[rd(p+"/topology/core_id") for p in sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*"),key=lambda x:int(re.search(r"cpu(\d+)",x).group(1)))]
try:threads=int(rd("/sys/devices/system/cpu/present").split("-")[-1])+1
except:threads=len(cu)
load=list(map(float,rd("/proc/loadavg").split()[:3]))
core_ids=set(rd(p+"/topology/core_id") for p in glob.glob("/sys/devices/system/cpu/cpu[0-9]*") if rd(p+"/topology/core_id"))
temps=[]
for p in glob.glob("/sys/class/hwmon/hwmon*/temp*_input"):
 x=val(p,1000);label=rd(p.replace("_input","_label"))
 if x is not None and any(k in label.lower() for k in ("tctl","tdie","package","coretemp")):temps.append((x,label))
ds=disks()
for disk in ds: disk['smart']=smart_one(disk['mount'])
print(json.dumps({"ok":True,"cpu":{"name":re.sub(r"\s+\d+-Core Processor.*|\s+CPU\s+@.*","",next((l.split(":",1)[1].strip() for l in rd("/proc/cpuinfo").splitlines() if l.startswith("model name")),"CPU")),"cores":len(core_ids) or threads,"threads":threads,"frequency":freq[0] if freq else 0,"usage":u,"coreUsage":cu,"coreFrequency":freq,"physical":physical},"load":load,"memory":mem(),"gpu":gpu(),"disks":ds,"processes":processes(),"thermal":{"cpu":temps[0][0] if temps else None,"cpuLabel":temps[0][1] if temps else "" ,"fan":fan()},"io":disk_io(),"battery":battery(),"smart":ds[0].get("smart","No disponible") if ds else "No disponible"}))
