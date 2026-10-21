"""Build-time downloads only. End-user installation needs no internet."""
import argparse
import hashlib
import json
import shutil
import urllib.request
import zipfile
from pathlib import Path

MODEL_REV = '90862c4b9d2787eaed51d12237eafdfe7c5f6077'
MODEL_NAME = 'Qwen3-1.7B-Q8_0.gguf'
MODEL_SHA = '061b54daade076b5d3362dac252678d17da8c68f07560be70818cace6590cb1a'
RUNTIME_TAG = 'b9380'
RUNTIME_NAME = 'llama-b9380-bin-win-cpu-x64.zip'
RUNTIME_SHA = 'cd44b61422671f0565cae98d856a70d55ef10392197a49246671f85bacb50dc3'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def download(url, path, expected=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and expected and digest(path) == expected:
        return
    temp = path.with_suffix(path.suffix + '.partial')
    request = urllib.request.Request(url, headers={'User-Agent': 'VoC-Mate-build'})
    with urllib.request.urlopen(request, timeout=120) as source, temp.open('wb') as target:
        shutil.copyfileobj(source, target, 4 * 1024 * 1024)
    if expected and digest(temp) != expected:
        temp.unlink()
        raise RuntimeError('Download checksum mismatch: ' + path.name)
    temp.replace(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('destination', type=Path)
    parser.add_argument('--cache', type=Path, default=Path('.qwen-build-cache'))
    args = parser.parse_args()
    target = args.destination
    model = args.cache / MODEL_NAME
    runtime = args.cache / RUNTIME_NAME
    origin = f'https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/{MODEL_REV}'
    download(f'{origin}/{MODEL_NAME}', model, MODEL_SHA)
    download(f'https://github.com/ggml-org/llama.cpp/releases/download/{RUNTIME_TAG}/{RUNTIME_NAME}', runtime, RUNTIME_SHA)
    (target / 'models').mkdir(parents=True, exist_ok=True)
    shutil.copy2(model, target / 'models' / MODEL_NAME)
    runtime_dir = target / 'runtime'
    runtime_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(runtime) as archive:
        for item in archive.infolist():
            name = Path(item.filename).name
            if name == 'llama-server.exe' or name.lower().endswith('.dll'):
                with archive.open(item) as source, (runtime_dir / name).open('wb') as dest:
                    shutil.copyfileobj(source, dest)
    assert (runtime_dir / 'llama-server.exe').is_file()
    licenses = target / 'licenses'
    download(f'{origin}/LICENSE', licenses / 'Qwen-APACHE-2.0.txt')
    download(f'https://raw.githubusercontent.com/ggml-org/llama.cpp/{RUNTIME_TAG}/LICENSE', licenses / 'llama.cpp-MIT.txt')
    download(f'{origin}/README.md', licenses / 'Qwen-model-card.md')
    (target / 'manifest.json').write_text(json.dumps({
        'model': 'Qwen3-1.7B', 'model_file': MODEL_NAME,
        'model_revision': MODEL_REV, 'model_sha256': MODEL_SHA,
        'runtime': 'llama.cpp', 'runtime_tag': RUNTIME_TAG,
        'runtime_archive_sha256': RUNTIME_SHA,
        'model_size_bytes': model.stat().st_size,
        'offline': True,
    }, indent=2), encoding='utf-8')
    print('Prepared offline Qwen bundle:', target)


if __name__ == '__main__':
    main()
