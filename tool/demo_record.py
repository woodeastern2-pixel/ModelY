import subprocess,time,re,xml.etree.ElementTree as ET,sys,os
PKG="com.example.ai_voc_assistant"
def adb(*a,check=False):
    return subprocess.run(["adb",*a],text=True,capture_output=True,check=check)
def dump():
    for _ in range(8):
        adb("shell","uiautomator","dump","/data/local/tmp/window.xml")
        x=adb("exec-out","cat","/data/local/tmp/window.xml").stdout.strip()
        if x.startswith("<?xml") or x.startswith("<hierarchy"):
            return x
        time.sleep(2)
    return ""
def tap_text(candidates):
    x=dump()
    if not x: return False
    try: root=ET.fromstring(x)
    except ET.ParseError: return False
    for want in candidates:
        for n in root.iter("node"):
            txt=(n.attrib.get("text","")+" "+n.attrib.get("content-desc","")).strip()
            if want.lower() in txt.lower():
                m=re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",n.attrib.get("bounds",""))
                if m:
                    x1,y1,x2,y2=map(int,m.groups())
                    adb("shell","input","tap",str((x1+x2)//2),str((y1+y2)//2)); time.sleep(2); return True
    return False
def record(name,llm=False):
    remote=f"/data/local/tmp/{name}.mp4"
    adb("shell","pm","clear",PKG)
    adb("shell","monkey","-p",PKG,"1")
    time.sleep(15)
    focus=adb("shell","dumpsys","window","windows").stdout
    if PKG not in focus:
        raise RuntimeError("VOC Mate is not visible before recording")
    os.makedirs("artifacts",exist_ok=True)
    adb("exec-out","screencap","-p",check=True)
    with open(f"artifacts/{name}-start.png","wb") as shot:
        shot.write(subprocess.run(["adb","exec-out","screencap","-p"],capture_output=True,check=True).stdout)
    p=subprocess.Popen(["adb","shell","screenrecord","--bit-rate","6000000","--time-limit","90",remote])
    time.sleep(3)
    for labels in [
        ["시작","확인","건너뛰기","다음"],
        ["VOC","문의"],
        ["첫 번째","로그인","메신저","메일","Drive","드라이브"],
        ["AI 답변","답변 초안","답변"],
    ]:
        tap_text(labels); time.sleep(3)
    time.sleep(18 if llm else 10)
    tap_text(["근거","출처"]); time.sleep(5)
    p.terminate()
    try: p.wait(timeout=8)
    except subprocess.TimeoutExpired: p.kill()
    time.sleep(2)
    os.makedirs("artifacts",exist_ok=True)
    adb("pull",remote,f"artifacts/{name}.mp4",check=True)
    if not os.path.exists(f"artifacts/{name}.mp4") or os.path.getsize(f"artifacts/{name}.mp4") < 10000:
        raise RuntimeError("recorded video is missing or too small")
if __name__=="__main__":
    record(sys.argv[1],"--llm" in sys.argv)
