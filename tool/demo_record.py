import subprocess,time,re,xml.etree.ElementTree as ET,sys
PKG="com.example.ai_voc_assistant"
def adb(*a,check=False):
    return subprocess.run(["adb",*a],text=True,capture_output=True,check=check)
def dump():
    adb("shell","uiautomator","dump","/sdcard/window.xml")
    x=adb("exec-out","cat","/sdcard/window.xml").stdout
    return x
def tap_text(candidates):
    x=dump()
    root=ET.fromstring(x)
    for want in candidates:
        for n in root.iter("node"):
            txt=(n.attrib.get("text","")+" "+n.attrib.get("content-desc","")).strip()
            if want.lower() in txt.lower():
                m=re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",n.attrib.get("bounds",""))
                if m:
                    x1,y1,x2,y2=map(int,m.groups()); adb("shell","input","tap",str((x1+x2)//2),str((y1+y2)//2)); time.sleep(2); return True
    return False
def record(name, llm=False):
    adb("shell","pm","clear",PKG); adb("shell","monkey","-p",PKG,"1"); time.sleep(8)
    p=subprocess.Popen(["adb","shell","screenrecord","--bit-rate","8000000","--time-limit","90",f"/sdcard/{name}.mp4"])
    time.sleep(3)
    tap_text(["시작","확인","건너뛰기","다음"])
    tap_text(["VOC","문의"])
    time.sleep(3)
    tap_text(["첫 번째","로그인","메신저","메일","Drive","드라이브"])
    time.sleep(3)
    tap_text(["AI 답변","답변 초안","답변"])
    time.sleep(15 if llm else 8)
    tap_text(["근거","출처"])
    time.sleep(5)
    p.terminate(); time.sleep(2)
    adb("pull",f"/sdcard/{name}.mp4",f"artifacts/{name}.mp4",check=True)
if __name__=="__main__":
    import os; os.makedirs("artifacts",exist_ok=True)
    record(sys.argv[1], "--llm" in sys.argv)
