import fs from 'node:fs';
import vm from 'node:vm';

const input = process.argv[2];
const output = process.argv[3];
if (!input || !output) {
  throw new Error('usage: node tool/generate_brity_manual_seed.mjs INPUT OUTPUT');
}

const calls = [];
vm.runInNewContext(fs.readFileSync(input, 'utf8'), {
  Http: { set: (url, data) => calls.push([url, data]) },
});

const stripHtml = (html) =>
  html
    .replace(/<img[^>]*>/g, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>|<\/li>|<\/tr>|<\/h\d>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n\s*\n+/g, '\n')
    .trim();

const escapeDart = (value) =>
  value
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\r?\n/g, '\\n')
    .replace(/\$/g, '\\$');

const entries = [];
let sequence = 1;
for (const [url, chapter] of calls) {
  if (!url.includes('/viewer/content/') || !chapter?.elements) continue;

  const chapterTitle = stripHtml(chapter.title || '매뉴얼');
  let sectionTitle = `${chapterTitle} 개요`;
  let paragraphs = [];

  const flush = () => {
    const body = paragraphs.join('\n').trim();
    paragraphs = [];
    if (!body) return;
    const chunks = body.match(/[\s\S]{1,1800}(?=\s|$)/g) || [body];
    chunks.forEach((chunk, index) => {
      const suffix = chunks.length > 1 ? ` (${index + 1}/${chunks.length})` : '';
      entries.push({
        id: `brity-full-${String(sequence++).padStart(4, '0')}`,
        question: `${sectionTitle}${suffix}에 대해 알려주세요.`,
        answer:
          `${chunk.trim()}\n\n[출처] New Brity Mail 사용자매뉴얼 · ${sectionTitle}`,
      });
    });
  };

  for (const element of chapter.elements) {
    if (String(element.type).startsWith('heading')) {
      flush();
      sectionTitle = stripHtml(element.html || '') || chapterTitle;
      continue;
    }
    if (element.type === 'image') continue;
    const text = stripHtml(element.html || '');
    if (text) paragraphs.push(text);
  }
  flush();
}

const lines = [
  '// GENERATED FILE. DO NOT EDIT.',
  '// Source: https://manual.brityworks.com/user/ko/index.html',
  'class BrityManualFullSeed {',
  '  BrityManualFullSeed._();',
  '',
  '  static const List<Map<String, String>> entries = [',
];
for (const entry of entries) {
  lines.push('    {');
  lines.push(`      'id': '${entry.id}',`);
  lines.push(`      'question': '${escapeDart(entry.question)}',`);
  lines.push(`      'answer': '${escapeDart(entry.answer)}',`);
  lines.push('    },');
}
lines.push('  ];', '}', '');
fs.writeFileSync(output, lines.join('\n'));
console.log(`Generated ${entries.length} knowledge entries`);
