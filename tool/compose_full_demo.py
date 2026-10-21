"""Edit recorded production app frames; do not synthesize app screens."""
import argparse
import json
import re
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

TITLES = ['운영 현황', '언어 모델 연결', '지식 자료 관리', '문의 접수', '답변 초안 생성', '근거 확인', '검토와 승인', '처리 이력', '코파일럿 질의', '내부망 공유', '데이터 보호']
CAPTIONS = [
 '접수 현황과 미처리 업무를 확인합니다.',
 '모델 설정과 실제 연결 결과를 확인합니다.',
 '문서를 등록하고 검색된 자료의 원문을 확인합니다.',
 '메신저 알림 문의를 붙여넣기로 등록합니다.',
 'Qwen3 Instruct가 실제 생성한 초안을 확인합니다.',
 '초안 내용과 매뉴얼 근거를 함께 검토합니다.',
 '매뉴얼과 대조한 실제 생성 초안을 승인하고 처리를 완료합니다.',
 '문의와 확정한 답변을 처리 이력으로 확인합니다.',
 '승인된 답변을 근거로 설정 위치와 확인사항을 요약합니다.',
 '수신 주소를 등록하고 문의와 매뉴얼을 전송합니다.',
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
    d.text((32,146),'Qwen3 · 4B Instruct',font=font(22),fill='#ABA3FF')
    d.text((32,179),'실제 모델 응답 · 근거 확인',font=font(14),fill='#9CA3BA')
    d.line((32,203,368,203),fill='#33384A',width=2)
    for i,title in enumerate(TITLES):
        y=232+i*60
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

