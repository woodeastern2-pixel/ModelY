# Manual images 1.1.7

The reported recall screen was the answer evidence panel. It rendered the stored answer as plain text, including machine transcription, without the image gallery that existed in the knowledge view.

- ManualContent separates authored explanation/source from the known bundled transcription block without deleting stored data or excluding it from retrieval.
- Knowledge entries and selected answer evidence share ManualContentView. Original images render inline with numbered previews and a fullscreen paged/zoomable reader. Transcription is collapsed and clearly marked as fallible. Missing connections and decode failures are explicit.
- Local answers no longer paste raw machine transcription into the response. The answer screen attaches original images from the evidence records actually used by the extractive answer.
- Newly imported Word documents retain embedded DrawingML/VML images (including table images), grouped with their original sections. Media is stored under application support storage, independently of the original file path. Unsupported image encodings remain subject to the platform image decoder; external linked images are not downloaded. PDF image extraction is still not implemented and is reported during import.
- Existing bundled data is unchanged: 532 entries, 911 unique lossless WebP images. Every connection and every image decode/dimension is checked, with indexed contact sheets for review. Recall question screenshots use the real bundled record, not synthetic illustration.
- Raw OCR recognition accuracy is not silently claimed to be corrected. Original images are authoritative; OCR remains a search aid and separately inspectable.

No user rows or settings are deleted. Existing local imports without retained images need reimport from an accessible Word original; the new image-capable source record has a separate identity to preserve previous user data.

Validation results and installer hashes are recorded in the delivered release report. Known pre-existing golden baseline mismatches must be reported separately from a successful CI job.
