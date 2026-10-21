"""Create a labelled demonstration document; never seed model replies."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.sax.saxutils import escape

out = Path('artifacts')
out.mkdir(exist_ok=True)
paragraphs = [
    '시연용 문의 처리 운영 가이드',
    '이 문서는 자료 등록 기능을 보여주기 위한 시연용 문서입니다.',
    '문의가 접수되면 제목, 내용, 프로젝트명과 접수 경로를 확인합니다.',
    '답변 초안을 생성한 뒤 원문 매뉴얼과 참고 자료를 대조합니다.',
    '확인한 내용으로 답변을 수정하고 승인한 뒤 업무 조치가 끝나면 처리 완료로 변경합니다.',
    '팀 공유가 필요하면 연결된 앱으로 문의와 답변을 전송합니다.',
    '문의와 지식 자료는 각각 내보내기 기능으로 백업합니다.',
]
with ZipFile(out / 'demo-guide.docx', 'w', ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml', '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')
    z.writestr('_rels/.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
    z.writestr('word/document.xml', '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' + ''.join('<w:p><w:r><w:t>'+escape(p)+'</w:t></w:r></w:p>' for p in paragraphs) + '</w:body></w:document>')
