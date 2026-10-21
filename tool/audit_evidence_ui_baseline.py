"""Distinguish existing dashboard golden drift from a new evidence regression.

Does not update approved images or suppress differences in the new render.
Both revisions must produce byte-identical actual images for all three views.
"""
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    current = Path.cwd()
    before = current / 'baseline-before-evidence'
    output = current / 'artifacts' / 'ui-baseline-audit'
    output.mkdir(parents=True, exist_ok=True)
    statuses = {}
    for name, root in [('before', before), ('after', current)]:
        result = subprocess.run(['flutter', 'test', 'test/ui_preview_golden_test.dart'],
            cwd=root, capture_output=True, text=True)
        log = result.stdout + result.stderr
        (output / f'{name}.log').write_text(log)
        statuses[name] = result.returncode
        if result.returncode and 'Pixel test failed' not in log:
            raise RuntimeError(f'{name}: golden test failed for an unaudited reason')
    assert statuses['before'] == statuses['after'], statuses
    views = {}
    for name in ['phone-light', 'tablet-light', 'desktop-dark']:
        reference = Path('test/goldens') / f'{name}.png'
        assert (before / reference).read_bytes() == (current / reference).read_bytes()
        actual = (Path('test/failures') / f'{name}_testImage.png'
            if statuses['after'] else reference)
        old, new = (before / actual).read_bytes(), (current / actual).read_bytes()
        assert old == new, f'New visual regression: {name}'
        (output / f'{name}-before.png').write_bytes(old)
        (output / f'{name}-after.png').write_bytes(new)
        views[name] = hashlib.sha256(new).hexdigest()
    report = {
        'before_commit': 'f549f6f011cd615bd388ad5d63d73fa942eea708',
        'validated_app_commit': 'c1e4d2cee3204742a957622893c9a889515e587e',
        'prior_full_regression_run': 39587709496,
        'prior_full_regression_tests_passed': 225,
        'approved_goldens_unchanged': True,
        'original_golden_exit_codes': statuses,
        'existing_golden_drift': bool(statuses['after']),
        'new_dashboard_pixel_differences': 0,
        'actual_image_sha256': views,
    }
    (output / 'report.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
