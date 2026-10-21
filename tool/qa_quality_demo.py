"""Decode the final deliverable, check silence, and make internal review frames."""
import json
import re
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

video = Path(sys.argv[1]).resolve()
audit = json.loads((video.parent/'edit_work/edit-audit.json').read_text())
work = video.parent/'review'
work.mkdir(exist_ok=True)
probe = json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(video)], text=True))
subprocess.run(['ffmpeg','-v','error','-xerror','-i',str(video),'-f','null','-'],check=True)
silence = subprocess.run(['ffmpeg','-hide_banner','-i',str(video),'-af','silencedetect=noise=-35dB:d=2.5','-f','null','-'],capture_output=True,text=True,check=True).stderr
assert 'silence_start:' not in silence, silence
sheet = Image.new('RGB',(1920,1440),'#111522')
offset = 0.0
for i,scene in enumerate(audit):
    frame = work/f"scene-{scene['scene']:02}.png"
    stamp = offset + scene['duration'] - 0.35
    subprocess.run(['ffmpeg','-y','-v','error','-ss',str(stamp),'-i',str(video),'-frames:v','1',str(frame)],check=True)
    im=Image.open(frame); im.thumbnail((640,360))
    sheet.paste(im,((i%3)*640,(i//3)*360))
    offset += scene['duration']
sheet.save(work/'contact-sheet.jpg',quality=95)
result={'decoded':True,'long_silence_seconds_threshold':2.5,'long_silences':0,
        'duration':probe['format']['duration'],'bytes':probe['format']['size'],
        'streams':[{'type':s['codec_type'],'codec':s['codec_name'],'width':s.get('width'),'height':s.get('height')} for s in probe['streams']],
        'chapters':len(audit),'backup_chapter_present':any('백업' in x['title'] for x in audit)}
(work/'technical-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps(result,ensure_ascii=False,indent=2))
