"""Replace only chapter 06 with a verified production-app pickup.

Other chapters are byte-for-byte copies except the first 2.4 seconds of chapter
07, which still showed the old English expansion. Its audio remains unchanged.
Actual model generation and Copilot footage are not substituted.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

from compose_full_demo import overlay, CAPTIONS
from edit_quality_demo import speech_end


def duration(path):
    return float(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
        '-of', 'default=nw=1:nk=1', str(path)], text=True))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('previous', type=Path)
    parser.add_argument('pickup', type=Path)
    parser.add_argument('fonts', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    previous = args.previous.resolve() / 'edit_work'
    pickup = args.pickup.resolve()
    output = args.output.resolve()
    work = output.parent / 'edit_work'
    work.mkdir(parents=True, exist_ok=True)
    verification = json.loads((pickup / 'evidence-verification.json').read_text())
    for key in ['success', 'source_matches_recorded_citation', 'korean_default',
                'original_collapsed', 'detached_labels_absent', 'original_retained']:
        assert verification[key], key
    assert verification['new_model_inference'] is False
    audit = json.loads((previous / 'edit-audit.json').read_text())
    assert len(audit) == 11
    hashes = {}
    for number in range(1, 12):
        if number in (6, 7):
            continue
        filename = f'{number:02}.mp4'
        shutil.copy2(previous / filename, work / filename)
        assert digest(previous / filename) == digest(work / filename)
        hashes[filename] = digest(work / filename)

    voice = pickup / '06.mp3'
    speech = speech_end(voice)
    seconds = speech + 0.18 + 1.2
    source = pickup / 'evidence-pickup.mp4'
    source_seconds = duration(source)
    assert source_seconds > verification['ready_at'] + 10
    CAPTIONS[5] = '인용한 매뉴얼의 한국어 안내와 원문 출처를 확인합니다.'
    frame = work / '06-overlay.png'
    overlay(frame, args.fonts.resolve(), 5)
    filters = [
        f'[0:v]setpts=PTS-STARTPTS,fps=30,scale=1472:920,tpad=stop_mode=clone:stop_duration={seconds},trim=duration={seconds}[screen]',
        '[1:v][screen]overlay=424:85:shortest=1[out]',
        f'[2:a]atrim=end={speech+0.08},asetpts=PTS-STARTPTS,adelay=180|180,apad,atrim=duration={seconds}[audio]',
    ]
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(source),
        '-framerate', '30', '-loop', '1', '-i', str(frame), '-i', str(voice),
        '-filter_complex_threads', '2', '-filter_complex', ';'.join(filters),
        '-map', '[out]', '-map', '[audio]', '-t', str(seconds),
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '19', '-threads', '4',
        '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '160k', '-ar', '48000',
        '-movflags', '+faststart', str(work / '06.mp4')], check=True)
    # The original next chapter began with the still-expanded English source.
    # Remove that visual carry-over; preserve the approved narration verbatim.
    previous07 = previous / '07.mp4'
    seconds07 = duration(previous07)
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-ss', '2.4', '-i', str(previous07),
        '-i', str(previous07), '-map', '0:v:0', '-map', '1:a:0',
        '-vf', f'setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=2.4,trim=duration={seconds07}',
        '-t', str(seconds07), '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '19',
        '-threads', '4', '-pix_fmt', 'yuv420p', '-c:a', 'copy',
        '-movflags', '+faststart', str(work / '07.mp4')], check=True)
    audit[6]['removed_old_english_carryover_seconds'] = 2.4
    audit[6]['audio'] = 'Original chapter audio copied without re-encoding'
    audit[5] = {
        'scene': 6, 'title': '근거 확인', 'source': str(source),
        'source_start': 0, 'source_end': min(seconds, source_seconds),
        'duration': seconds, 'voice_lead': .18, 'voice_tail': 1.2,
        'pickup': verification,
        'model_outputs': 'Previously generated actual answer retained; no new inference in pickup',
    }
    for scene in audit:
        scene['duration'] = duration(work / f"{scene['scene']:02}.mp4")
    manifest = work / 'segments.txt'
    manifest.write_text(''.join(f"file '{work / f'{n:02}.mp4'}'\n" for n in range(1, 12)))
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-f', 'concat', '-safe', '0',
        '-i', str(manifest), '-c', 'copy', '-movflags', '+faststart', str(output)], check=True)
    (work / 'edit-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2))
    (work / 'unchanged-chapter-sha256.json').write_text(json.dumps(hashes, indent=2))
    print(json.dumps({'video': str(output), 'duration': duration(output),
        'unchanged_chapters': list(hashes), 'chapter06_seconds': seconds,
        'bytes': output.stat().st_size, 'sha256': digest(output)}))


if __name__ == '__main__':
    main()
