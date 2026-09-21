import fs from 'node:fs';

const [desktopInput, mobileInput, output] = process.argv.slice(2);
if (!desktopInput || !mobileInput || !output) {
  throw new Error(
    'usage: node tool/generate_brity_messenger_seed.mjs DESKTOP_TXT MOBILE_TXT OUTPUT',
  );
}

const sources = [
  {
    input: desktopInput,
    platform: 'Desktop',
    prefix: 'brity-messenger-desktop',
    sourceName: 'Brity Messenger User Manual - Desktop (Samsung SDS, official PDF)',
    sourceUrl:
      'https://image.samsungsds.com/en/resources/__icsFiles/afieldfile/2020/08/21/BrityMessenger_UserManual_Desktop_EN.pdf',
    titles: [
      '설치', '제거', '로그인', '연락처', '연락처 검색', '채팅', '설정', '상세 프로필',
      '메시지·이모티콘·빠른 답장', '답장·회수·중요 메시지', '대화 상대 초대',
      '참여자·방장 위임·내보내기', '기타 채팅 기능', '영상 통화 시작', '영상 통화',
      '내 화면 공유', '공유 화면 보기', '기본 설정', '화면·스킨', '알림', '연락처 옵션',
      '메시지 옵션', '영상 통화 옵션', '장치', '공지', 'Q&A',
    ],
  },
  {
    input: mobileInput,
    platform: 'Mobile',
    prefix: 'brity-messenger-mobile',
    sourceName: 'Brity Messenger User Manual - Mobile (Samsung SDS, official PDF)',
    sourceUrl:
      'https://image.samsungsds.com/en/resources/__icsFiles/afieldfile/2020/08/21/BrityMessenger_UserManual_Mobile_EN.pdf',
    titles: [
      '모바일 앱 설치', '모바일 앱 실행', '메신저 데이터 초기화', '연락처', '빠른 검색',
      '채팅 목록', '접속 상태', '대화방 화면', '메시지 전송·회수·삭제·읽음 처리',
      '엑셀 표 메시지', '메시지 전달', '멤버 초대', '대화방 나가기', '이모티콘',
      '대화방 알림', '즐겨찾기', '비밀 대화방', '대화방 옵션', '영상 통화 시작',
      '영상 통화', '내 화면 공유', '공유 화면 보기', '설정 화면', '계정 관리',
      '참여자 정보', '채팅 설정', '메시지 알림 설정', '영상 통화 설정', '화면 잠금',
      '테마', '서비스 데스크',
    ],
  },
];

const cleanPage = (page) => page
  .replace(/\r/g, '')
  .replace(/^HELP\s*\nBrity Messenger \([^\n]+\)[\s\S]*?Copyright 2020 Samsung SDS Co\., Ltd\. All rights reserved\s*$/m, '')
  .replace(/^Brity Messenger \([^\n]+\).*?Chapter[^\n]*\n/, '')
  .replace(/Copyright 2020 Samsung SDS Co\., Ltd\. All rights reserved\s*\d*\s*$/m, '')
  .replace(/^[ \t]+$/gm, '')
  .replace(/\n{3,}/g, '\n\n')
  .trim();

const escapeDart = (value) => value
  .replace(/\\/g, '\\\\')
  .replace(/'/g, "\\'")
  .replace(/\r?\n/g, '\\n')
  .replace(/\$/g, '\\$');

const entries = [];
for (const source of sources) {
  const pages = fs.readFileSync(source.input, 'utf8').split('\f').slice(2);
  if (pages.length < source.titles.length) {
    throw new Error(
      `${source.platform}: expected ${source.titles.length} content pages, got ${pages.length}`,
    );
  }

  source.titles.forEach((title, index) => {
    const body = cleanPage(pages[index]);
    entries.push({
      id: `${source.prefix}-${String(index + 1).padStart(3, '0')}`,
      question: `Brity Messenger ${source.platform}에서 ${title} 기능은 어떻게 사용하나요?`,
      answer:
        `[${source.platform} · ${title}]\n${body}\n\n` +
        `[출처] ${source.sourceName}\n${source.sourceUrl}`,
      sourceName: source.sourceName,
      sourceUrl: source.sourceUrl,
      platform: source.platform,
      project: 'Brity Messenger',
    });
  });
}

const lines = [
  '// GENERATED FILE. DO NOT EDIT.',
  '// Source PDFs are listed in each entry.',
  'class BrityMessengerManualSeed {',
  '  BrityMessengerManualSeed._();',
  '',
  '  static const List<Map<String, String>> entries = [',
];
for (const entry of entries) {
  lines.push('    {');
  for (const [key, value] of Object.entries(entry)) {
    lines.push(`      '${key}': '${escapeDart(value)}',`);
  }
  lines.push('    },');
}
lines.push('  ];', '}', '');

fs.writeFileSync(output, lines.join('\n'));
console.log(`Generated ${entries.length} Brity Messenger entries`);
