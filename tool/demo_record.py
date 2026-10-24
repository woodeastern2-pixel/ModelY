import subprocess,time,re,xml.etree.ElementTree as ET,sys,os
PKG="com.example.ai_voc_assistant"
def adb(*a,check=False): return subprocess.run(["adb",*a],text=True,capture_output=True,check=check)
def dump():
    for _ in range(10):
        adb("shell","uiautomator","dump","/data/local/tmp/window.xml")
        x=adb("exec-out","cat","/data/local/tmp/window.xml").stdout.strip()
        if x.startswith("<?xml") or x.startswith("<hierarchy"): return x
        time.sleep(2)
    return ""
def nodes():
    x=dump()
    if not x: return []
    try: return list(ET.fromstring(x).iter("node"))
    except ET.ParseError: return []
def screen_text(): return " ".join((n.attrib.get("text","")+" "+n.attrib.get("content-desc","")).strip() for n in nodes())
def tap_text(labels,required=True,wait=2):
    for _ in range(8):
        for n in nodes():
            txt=(n.attrib.get("text","")+" "+n.attrib.get("content-desc","")).strip()
            if any(w.lower() in txt.lower() for w in labels):
                m=re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",n.attrib.get("bounds",""))
                if m:
                    x1,y1,x2,y2=map(int,m.groups()); adb("shell","input","tap",str((x1+x2)//2),str((y1+y2)//2)); time.sleep(wait); return True
        time.sleep(2)
    if required: raise RuntimeError("Could not find UI target: "+"/".join(labels)+" | screen="+screen_text()[:1000])
    return False
def assert_text(labels):
    txt=screen_text()
    if not any(x.lower() in txt.lower() for x in labels): raise RuntimeError("Expected screen not reached: "+"/".join(labels)+" | "+txt[:1200])
def shot(name):
    os.makedirs("artifacts",exist_ok=True)
    data=subprocess.run(["adb","exec-out","screencap","-p"],capture_output=True,check=True).stdout
    open("artifacts/"+name+".png","wb").write(data)
def scenario(name,llm=False):
    remote=f"/data/local/tmp/{name}.mp4"; adb("shell","pm","clear",PKG); adb("shell","monkey","-p",PKG,"1"); time.sleep(15)
    if PKG not in adb("shell","dumpsys","window","windows").stdout: raise RuntimeError("VOC Mate not foreground")
    shot(name+"-00-start")
    p=subprocess.Popen(["adb","shell","screenrecord","--bit-rate","6000000","--time-limit","150",remote]); time.sleep(3)
    # Dashboard -> demo data import.
    assert_text(["VOC 현황","오늘의 현황"])
    tap_text(["시연 데이터로 둘러보기","브리티웍스 시연 데이터"],required=False)
    # Tooltip text may not be exposed: dashboard action is near top-right; fallback tap.
    if "브리티웍스 시연 데이터" not in screen_text():
        adb("shell","input","tap","1450","95"); time.sleep(3)
    assert_text(["브리티웍스 시연 데이터"])
    tap_text(["시연 데이터 입력"]); time.sleep(20)
    assert_text(["건 추가","이미 등록된","현재 등록된 시연 문의"])
    shot(name+"-01-demo-imported")
    tap_text(["닫기"])
    tap_text(["전체 목록 보기"]); time.sleep(6)
    assert_text(["VOC","문의"])
    shot(name+"-02-voc-list")
    # Open a real list item. Prefer a Brity scenario; otherwise first visible card.
    if not tap_text(["로그인","메신저","메일","드라이브","Drive"],required=False):
        adb("shell","input","tap","800","520"); time.sleep(5)
    assert_text(["VOC 상세"])
    shot(name+"-03-detail")
    tap_text(["답변 초안 만들기"]); time.sleep(25 if llm else 12)
    assert_text(["자료 기반 답변 초안","답변 초안"])
    shot(name+"-04-answer")
    # Evidence/source inspection is mandatory.
    if not tap_text(["근거","출처","참고"],required=False):
        adb("shell","input","swipe","800","1250","800","500","600"); time.sleep(3)
        tap_text(["근거","출처","참고"])
    shot(name+"-05-evidence")
    time.sleep(5)
    p.terminate()
    try: p.wait(timeout=10)
    except subprocess.TimeoutExpired: p.kill()
    adb("pull",remote,f"artifacts/{name}.mp4",check=True)
    if os.path.getsize(f"artifacts/{name}.mp4") < 100000: raise RuntimeError("video too small")
if __name__=="__main__": scenario(sys.argv[1],"--llm" in sys.argv)
