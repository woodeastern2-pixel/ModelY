"""Tighten the existing real recording and omit native file-picker shots."""
import argparse
import json
import re
import subprocess
from pathlib import Path
from compose_full_demo import overlay


def speech_end(path):
    text = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(path),
        '-af', 'silencedetect=noise=-35dB:d=0.15', '-f', 'null', '-'],
        capture_output=True, text=True, check=True).stderr
    return float(re.findall(r'silence_start: ([0-9.]+)', text)[-1])


def subtract(ranges, cut_start, cut_end):
    result = []
    for a, b, factor in ranges:
        if b <= cut_start or a >= cut_end:
            result.append((a,b,factor))
        else:
            if a < cut_start: result.append((a,cut_start,factor))
            if b > cut_end: result.append((cut_end,b,factor))
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument('audit', type=Path)
    p.add_argument('assets', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--scenes', type=int, nargs='*')
    args = p.parse_args()
    work = args.output.parent / 'edit_work'
    work.mkdir(parents=True, exist_ok=True)
    report = []
    for scene in json.loads(args.audit.read_text()):
        n = scene['scene']
        a,b = scene['source_start'],scene['source_end']
        ranges = [(a,b,1)]
        if scene['wait_interval']:
            x,y = scene['wait_interval']
            ranges = [(a,x,1),(x,y,1.5/(y-x)),(y,b,1)]
        cuts = {3:[(30.05,32.35)],11:[(184.15,186.65),(191.15,193.65)]}.get(n,[])
        for x,y in cuts: ranges = subtract(ranges,x,y)
        voice = args.assets / 'narration' / f'{n:02}.mp3'
        voiced_end = speech_end(voice)
        lead = 0.18
        tail = 2.0 if n in (5,6,7,9) else 1.2
        seconds = voiced_end + lead + tail
        compact = sum((y-x)*factor for x,y,factor in ranges)
        speed = min(1, seconds/compact)
        frame = work/f'{n:02}-overlay.png'
        overlay(frame,args.assets,n-1)
        filters = [f'[0:v]trim=start={x-a}:end={y-a},setpts=(PTS-STARTPTS)*{factor*speed}[s{i}]'
                   for i,(x,y,factor) in enumerate(ranges)]
        inputs=''.join(f'[s{i}]' for i in range(len(ranges)))
        # These two stages contain native export toasts with local file paths.
        # Crop only that transient bottom strip, preserving the app actions.
        hide_path = ',crop=1600:928:0:0,pad=1600:1000:0:0:color=0xF3F4FA' if n in (3,11) else ''
        filters += [inputs+f'concat=n={len(ranges)}:v=1:a=0,tpad=stop_mode=clone:stop_duration={seconds},trim=duration={seconds}{hide_path},fps=30,scale=1472:920[screen]',
                    '[1:v][screen]overlay=424:85:shortest=1[out]',
                    f'[2:a]atrim=end={voiced_end+0.08},asetpts=PTS-STARTPTS,adelay=180|180,apad,atrim=duration={seconds}[audio]']
        target=work/f'{n:02}.mp4'
        if not args.scenes or n in args.scenes:
            subprocess.run(['ffmpeg','-y','-v','error','-ss',str(a),'-i',scene['source'],
            '-framerate','30','-loop','1','-i',str(frame),'-i',str(voice),
            '-filter_complex_threads','2','-filter_complex',';'.join(filters),
            '-map','[out]','-map','[audio]','-t',str(seconds),'-c:v','libx264',
            '-preset','veryfast','-crf','19','-threads','6','-pix_fmt','yuv420p',
            '-c:a','aac','-b:a','160k','-ar','48000','-movflags','+faststart',str(target)],check=True)
        report.append({**scene,'duration':seconds,'voice_lead':lead,'voice_tail':tail,
            'excluded_native_dialogs':cuts,'ranges':ranges,'speed_factor':speed,
            'model_outputs':'Original actual model outputs retained; no substitution'})
        print(f'{n:02}: {seconds:.2f}s',flush=True)
    manifest=work/'segments.txt'
    manifest.write_text(''.join(f"file '{work/f'{n:02}.mp4'}'\n" for n in range(1,13)))
    subprocess.run(['ffmpeg','-y','-v','error','-f','concat','-safe','0','-i',str(manifest),
                    '-c','copy','-movflags','+faststart',str(args.output)],check=True)
    (work/'edit-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    print('Completed',sum(x['duration'] for x in report),flush=True)


if __name__ == '__main__': main()
