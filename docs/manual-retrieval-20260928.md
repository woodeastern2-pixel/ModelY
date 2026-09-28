# Manual retrieval 1.1.6

Problem: title-only eligibility discarded body matches; a single stored answer was copied in full. Import could retain only AI-generated Q&A, lose headings/numbered steps and flatten Word tables. File counts excluded earlier bundled manuals.

Changes:
- Every stored body participates in query-dependent retrieval. Adjacent paragraphs are searched together, concepts are weighted by corpus document frequency, Korean/English terminology and spacing are normalized. Product mismatch is rejected where product identity is known. Product/title-only matches cannot establish answer evidence.
- Conservative answer threshold is separate from related-result threshold. Up to three sufficiently relevant sections from the same source/product are quoted separately; sources/versions are not spliced into a fabricated procedure. Longer extracts preserve nearby context, restrictions and source/OCR notices. Search score is not confidence probability.
- Imports persist raw source sections before optional AI callbacks; UI import requires no AI. Word paragraphs and table cells retain boundaries, PDF text keeps page labels, content-based identifiers avoid duplicating the same file when moved. No existing user row is overwritten or deleted by this change.
- Counts include all system-manual entries and say knowledge items, not answerable questions.
- Copilot still requires an actual AI connection; unanswered VOCs remain excluded from offline answer evidence.

Corpus inventory at source revision 2538a93:
- Earlier bundled entries: 476 (Mail 268, English Messenger Desktop/Mobile 57, suite topics 151).
- Six added Word documents: 532 sections, 81 tables, 911 unique images (921 references), 548 OCR images.
- Combined default corpus: 1008 entries; installed user databases may differ after additions/deletions. No claim of inspecting a user's device.
- Uploaded Brity Messenger User Guide v8.5.5-1.pdf (16863940 bytes) and Brity Messenger 사용자 매뉴얼 v8.5.5.pdf (15286708 bytes) both start with NASCA DRM FILE. Their body is unavailable, and they must not be counted as successfully registered. Earlier English seeds cite 2020 official Desktop/Mobile PDFs, not these v8.5.5 files.

Limits:
- Offline retrieval quotes source evidence; it is not general semantic reasoning or translation. Unknown synonyms or poor OCR can still miss evidence.
- New on-device imports do not OCR embedded/scanned images and report that limitation. The previously bundled six-document pack already includes its OCR/media links.
- Previous imports that retained only generated Q&A cannot have lost raw source reconstructed automatically. Reimport an accessible original to preserve its body.
- File identity includes filename + full bytes + section index. Revised files coexist; different names count as different sources.

Validation: local environment has no Dart/Flutter/Windows SDK. GitHub Actions runs static analysis, full regression and responsive tests, golden comparisons, Android release and Windows installer builds. See release report for actual outcomes; golden steps have existing continue-on-error settings and must not be described as passing just because the job is green.
