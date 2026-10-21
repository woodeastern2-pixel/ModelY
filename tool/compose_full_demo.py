"""Edit recorded production app frames; do not synthesize app screens."""
import argparse
import json
import re
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

TITLES = ['운영 현황', '언어 모델 연결', '지식 자료 관리', '문의 접수', '답변 초안 생성', '근거 확인', '검토와 승인', '처리 이력', '코파일럿 질의', '내부망 공유', '중복 점검과 백업', '데이터 보호']
CAPTIONS = [
 '접수 현황과 미처리 업무를 확인합니다.',
 '모델 설정과 실제 연결 결과를 확인합니다.',
 '문서를 등록하고 검색된 자료의 원문을 확인합니다.',
 '메신저 알림 문의를 붙여넣기로 등록합니다.',
 '검색한 자료를 바탕으로 연결된 언어 모델이 초안을 생성합니다.',
 '초안 내용과 매뉴얼 근거를 함께 검토합니다.',
 '담당자가 답변을 수정·승인하고 처리 상태를 변경합니다.',
 '문의와 확정한 답변을 처리 이력으로 확인합니다.',
 '저장된 문의에 대해 질문하고 실제 모델의 답변을 확인합니다.',
 '수신 주소를 등록하고 문의와 매뉴얼을 전송합니다.',
 '중복 문의를 점검하고 지식과 문의 데이터를 각각 백업합니다.',
 '데이터 처리 범위와 담당자의 확인 사항을 살펴봅니다.',
]
MIN_SECONDS = [19,21,28,23,20,20,28,13,25,27,25,21]

def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)

def duration(p):
    return float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(p)],text=True))

def overlay(out, root, stage):
    font_path = root/'Pretendard-Regular.otf'
    bold_path = root/'Pretendard-Bold.otf'
    def font(size,bold=False): return ImageFont.truetype(str(bold_path if bold else font_path),size)
    im=Image.new('RGB',(1920,1080),'#F3F4FA')
    d=ImageDraw.Draw(im)
    d.rectangle((0,0,399,1080),fill='#111522')
    d.text((30,38),'VoC Mate',font=font(39,True),fill='#F7F8FF')
    d.text((32,103),'전체 시스템 시연',font=font(27,True),fill='#E1E4F3')
    d.text((32,146),'언어 모델 연결',font=font(22),fill='#ABA3FF')
    d.text((32,179),'Large Language Model · 대규모 언어 모델',font=font(14),fill='#9CA3BA')
    d.line((32,203,368,203),fill='#33384A',width=2)
    for i,title in enumerate(TITLES):
        y=232+i*55
        active=i==stage
        if active: d.rounded_rectangle((23,y-7,377,y+43),radius=12,fill='#5645C8')
        d.text((39,y),f'{i+1:02}',font=font(22,True),fill='#FFFFFF' if active else '#8C93AD')
        d.text((84,y),title,font=font(24,active),fill='#FFFFFF' if active else '#C0C5D8')
    d.line((32,939,368,939),fill='#33384A',width=2)
    d.text((32,961),'실제 앱 조작 화면',font=font(23,True),fill='#E5E7F2')
    d.text((32,1001),'시연용 데이터 · 대기 구간 단축',font=font(18),fill='#9CA3BA')
    d.text((424,26),TITLES[stage],font=font(31,True),fill='#252B3D')
    text='LLM 연결 전체 시연'
    d.text((1632,32),text,font=font(22,True),fill='#6652BB')
    d.rectangle((422,83,1898,1007),outline='#D3D7E5',width=2)
    caption=CAPTIONS[stage]
    bbox=d.textbbox((0,0),caption,font=font(25,True))
    d.text((424+(1472-(bbox[2]-bbox[0]))/2,1031),caption,font=font(25,True),fill='#3C445C')
    im.save(out)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('source_dir',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    root=args.source_dir
    work=args.output.parent/'edit_work'
    work.mkdir(parents=True,exist_ok=True)
    raw=root/'VOC_Mate_LLM_Actual.mp4'
    marks=json.loads((root/'llm-steps.json').read_text())
    boundaries=[m for m in marks if re.match(r'^\d{2} ',m['step'])]
    assert len(boundaries)==13, boundaries
    verification=json.loads((root/'llm-verification.json').read_text())
    assert verification['success'] and verification['is_ai_answer']
    segments=[]
    audit=[]
    for i in range(12):
        start,end=boundaries[i]['seconds'],boundaries[i+1]['seconds']
        source_seconds=end-start
        voice=root/'narration'/f'{i+1:02}.mp3'
        speech=duration(voice)
        minimum=max(MIN_SECONDS[i],speech+1.8)
        # Keep every action. Accelerate only when source is longer than narration.
        # Long model waits use a separate interval so clicks remain readable.
        wait_interval=None
        if i==3:
            a=next(m['seconds'] for m in marks if m['step']=='새 문의 입력')+2
            b=next(m['seconds'] for m in marks if m['step']=='문의 등록 및 분류 결과')-1
            if b-a>5: wait_interval=(a,b)
        if i==4:
            a=start+2
            b=next(m['seconds'] for m in marks if m['step']=='실제 모델이 생성한 답변')-1
            if b-a>5: wait_interval=(a,b)
        if i==8:
            pastes=[p for p in verification['paste_events'] if start<=p['start']<end]
            if pastes:
                a=pastes[-1]['end']+2
                b=end-9
                if b-a>5: wait_interval=(a,b)
        ranges=[(start,end,1)]
        if wait_interval:
            a,b=wait_interval
            ranges=[(start,a,1),(a,b,2.5/(b-a)),(b,end,1)]
        compact=sum((b-a)*speed for a,b,speed in ranges)
        out_seconds=max(minimum,min(compact,minimum+5))
        speed=min(1,out_seconds/compact)
        edited=work/f'{i+1:02}-screen.mp4'
        pieces=[]
        for j,(a,b,sp) in enumerate(ranges):
            pieces.append(f'[0:v]trim=start={a-start}:end={b-start},setpts=(PTS-STARTPTS)*{sp*speed}[p{j}]')
        joined=''.join(f'[p{j}]' for j in range(len(ranges)))
        pieces.append(joined+f'concat=n={len(ranges)}:v=1:a=0,tpad=stop_mode=clone:stop_duration={out_seconds},trim=duration={out_seconds},fps=30,scale=1472:920[screen]')
        frame=work/f'{i+1:02}-overlay.png'
        overlay(frame,root,i)
        pieces.append('[1:v][screen]overlay=424:85:shortest=1[out]')
        final=work/f'{i+1:02}.mp4'
        run(['ffmpeg','-y','-v','error','-ss',str(start),'-i',str(raw),'-framerate','30','-loop','1','-i',str(frame),'-i',str(voice),
             '-filter_complex_threads','2','-filter_complex',';'.join(pieces)+';[2:a]adelay=700|700,apad,atrim=duration='+str(out_seconds)+'[audio]',
             '-map','[out]','-map','[audio]','-t',str(out_seconds),'-c:v','libx264','-preset','veryfast','-crf','19','-threads','6',
             '-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-ar','48000','-movflags','+faststart',str(final)])
        segments.append(final)
        audit.append({'scene':i+1,'title':TITLES[i],'source_start':start,'source_end':end,'duration':out_seconds,'narration_seconds':speech,'wait_interval':wait_interval})
        print(f'{i+1}/12 {TITLES[i]} {out_seconds:.1f}s',flush=True)
    manifest=work/'segments.txt'
    manifest.write_text(''.join("file '"+str(p)+"'\n" for p in segments))
    run(['ffmpeg','-y','-v','error','-f','concat','-safe','0','-i',str(manifest),'-c','copy','-movflags','+faststart',str(args.output)])
    (work/'edit-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2))
    print('Completed',args.output,'seconds',duration(args.output),flush=True)

if __name__=='__main__': main()
