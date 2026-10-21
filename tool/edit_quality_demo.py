"""Compose verified production-app recording, shortening waits and excluding file dialogs."""
import argparse
import json
import re
import subprocess
from pathlib import Path
from compose_full_demo import overlay, TITLES


def speech_end(path):
    r = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(path),
        '-af', 'silencedetect=noise=-35dB:d=0.15', '-f', 'null', '-'],
        capture_output=True, text=True, check=True)
    starts = re.findall(r'silence_start: ([0-9.]+)', r.stderr)
    if not starts:
        raise ValueError(f'No ending silence detected: {path}')
    return float(starts[-1])


def subtract(ranges, start, end):
    result = []
    for a, b, speed in ranges:
        if b <= start or a >= end:
            result.append((a, b, speed))
        else:
            if a < start:
                result.append((a, start, speed))
            if b > end:
                result.append((end, b, speed))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('assets', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--scenes', type=int, nargs='*')
    args = parser.parse_args()
    root = args.assets.resolve()
    output = args.output.resolve()
    work = output.parent / 'edit_work'
    work.mkdir(parents=True, exist_ok=True)
    source = root / 'VOC_Mate_LLM_Actual.mp4'
    verification = json.loads((root / 'llm-verification.json').read_text())
    assert verification['success'] and verification['is_ai_answer']
    assert verification['backup_chapter_removed']
    assert verification['answer'].strip() == verification['reviewed_answer'].strip()
    assert verification['model'] == 'qwen3:4b-instruct-2507-q4_K_M'
    marks = json.loads((root / 'llm-steps.json').read_text())
    stamp = {m['step']: m['seconds'] for m in marks}
    chapters = [m for m in marks if re.match(r'^\d{2} ', m['step'])]
    assert len(chapters) == 12
    assert len(TITLES) == 11 and not any('백업' in t for t in TITLES)
    chapters[4] = {**chapters[4], 'seconds': stamp['문의 등록 및 분류 결과'] + 0.2}
    dialogs = json.loads((root / 'file-dialogs.json').read_text())
    audit = []
    for i, title in enumerate(TITLES):
        n = i + 1
        start, end = chapters[i]['seconds'], chapters[i+1]['seconds']
        if n == 9:
            end = min(end, stamp['코파일럿 실제 응답 확인'] + 6.0)
        wait = None
        if n == 4:
            wait = (stamp['새 문의 입력'] + 2.0, stamp['문의 등록 및 분류 결과'] - 1.0)
        elif n == 5:
            wait = (stamp['05 LLM 답변 생성'] + 1.0, stamp['실제 모델이 생성한 답변'] - 1.0)
        elif n == 9:
            wait = (stamp['코파일럿 질문 전송'] + 1.5, stamp['코파일럿 실제 응답 확인'] - 0.8)
        if wait and wait[1] - wait[0] > 5:
            a, b = wait
            ranges = [(start, a, 1), (a, b, 1.3 / (b-a)), (b, end, 1)]
        else:
            wait = None
            ranges = [(start, end, 1)]
        cuts = []
        for dialog in dialogs:
            a, b = dialog['start'] - 0.12, dialog['end'] + 0.15
            if b > start and a < end:
                ranges = subtract(ranges, a, b)
                cuts.append((a, b))
        ranges = [(a,b,s) for a,b,s in ranges if b-a > 0.01]
        voice = root / 'narration' / f'{n:02}.mp3'
        speech = speech_end(voice)
        lead, tail = 0.18, (1.5 if n in (5,6,7,9) else 0.9)
        seconds = speech + lead + tail
        compact = sum((b-a)*s for a,b,s in ranges)
        speed = min(1.0, seconds / compact)
        frame = work / f'{n:02}-overlay.png'
        overlay(frame, root, i)
        target = work / f'{n:02}.mp4'
        if not args.scenes or n in args.scenes:
            # Render each range separately: parallel trim branches retain
            # minutes of full-size frames while concat waits for earlier ranges.
            parts = []
            for j, (a, b, factor) in enumerate(ranges):
                part = work / f'{n:02}-part-{j:02}.mp4'
                hide_paths = ',crop=1600:928:0:0,pad=1600:1000:0:0:color=0xF3F4FA' if n == 3 else ''
                subprocess.run(['ffmpeg', '-y', '-v', 'error', '-ss', str(a),
                    '-t', str(b-a), '-i', str(source), '-an',
                    '-vf', f'setpts=(PTS-STARTPTS)*{factor*speed},fps=30{hide_paths},scale=1472:920',
                    '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '18',
                    '-threads', '2', '-pix_fmt', 'yuv420p', str(part)], check=True)
                parts.append(part)
            part_list = work / f'{n:02}-parts.txt'
            part_list.write_text(''.join(f"file '{part}'\n" for part in parts))
            filters = [
                f'[0:v]tpad=stop_mode=clone:stop_duration={seconds},trim=duration={seconds}[screen]',
                '[1:v][screen]overlay=424:85:shortest=1[out]',
                f'[2:a]atrim=end={speech+0.08},asetpts=PTS-STARTPTS,adelay=180|180,apad,atrim=duration={seconds}[audio]']
            subprocess.run(['ffmpeg', '-y', '-v', 'error', '-f', 'concat', '-safe', '0',
                '-i', str(part_list), '-framerate', '30', '-loop', '1', '-i', str(frame),
                '-i', str(voice), '-filter_complex_threads', '2',
                '-filter_complex', ';'.join(filters), '-map', '[out]', '-map', '[audio]',
                '-t', str(seconds), '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '19',
                '-threads', '4', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '160k',
                '-ar', '48000', '-movflags', '+faststart', str(target)], check=True)
        audit.append({'scene': n, 'title': title, 'source': str(source),
            'source_start': start, 'source_end': end, 'duration': seconds,
            'voice_lead': lead, 'voice_tail': tail, 'wait_interval': wait,
            'excluded_native_dialogs': cuts, 'ranges': ranges, 'speed_factor': speed,
            'model': verification['model'], 'model_outputs': 'Actual outputs, no substitution'})
        print(f'{n:02}: {seconds:.2f}s', flush=True)
    manifest = work / 'segments.txt'
    manifest.write_text(''.join(f"file '{work / f'{n:02}.mp4'}'\n" for n in range(1,12)))
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', str(manifest),
        '-c', 'copy', '-movflags', '+faststart', str(output)], check=True)
    (work / 'edit-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2))
    print('Completed', sum(a['duration'] for a in audit), flush=True)


if __name__ == '__main__':
    main()
