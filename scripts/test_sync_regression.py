import concurrent.futures
import sqlite3
import tempfile
import unittest
from pathlib import Path

from fastapi.testclient import TestClient
from voc_sync_receiver import create_app


class SyncRegression(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'db.sqlite'
        self.client = TestClient(create_app(self.path, desktop_notify=False))

    def tearDown(self):
        self.client.close()
        self.temp.cleanup()

    def voc(self, identity='original'):
        return dict(id=identity, title='메일 문의', content='메일 등록',
                    customer='고객', project='메일', category='기타', status='OPEN',
                    created_at='2026-09-29T09:00:00', updated_at='2026-09-29T09:00:00')

    def post(self, row):
        return self.client.post('/webhook/voc', json={
            'event': 'voc.created', 'source_app': 'origin', 'voc': row})

    def test_concurrent_repeated_events_are_idempotent(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.post(self.voc()), range(24)))
        self.assertTrue(all(r.status_code == 200 for r in results))
        self.assertEqual(sum(r.json()['action'] == 'created' for r in results), 1)
        self.assertEqual(self.client.get('/health').json()['voc_count'], 1)

    def test_push_then_full_then_push_has_one_parent_and_preserves_response(self):
        self.assertEqual(self.post(self.voc()).status_code, 200)
        row = self.voc()
        response = dict(id='answer', voc_id='original', content='답변',
                        created_at=row['created_at'], updated_at=row['updated_at'])
        payload = dict(event='sync.full', source_app='origin',
                       snapshot=dict(vocs=[row], responses=[response]))
        for _ in range(2):
            result = self.client.post('/webhook/sync/full', json=payload)
            self.assertEqual(result.status_code, 200, result.text)
        self.assertEqual(self.post(row).json()['action'], 'duplicate')
        with sqlite3.connect(self.path) as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM vocs').fetchone()[0], 1)
            self.assertEqual(db.execute('SELECT voc_id,content FROM responses').fetchone(),
                             ('original', '답변'))

    def test_excel_filename_does_not_collapse_unrelated_rows(self):
        one, two = self.voc('one'), self.voc('two')
        two['customer'] = '다른 고객'
        for row in [one, two]:
            row.update(source='excel', source_ref='manual.xlsx')
            self.assertEqual(self.post(row).json()['action'], 'created')

    def test_stale_full_sync_preserves_newer_resolution(self):
        row = self.voc()
        row.update(status='RESOLVED', updated_at='2026-09-29T12:00:00')
        self.post(row)
        self.client.post('/webhook/sync/full', json={
            'event': 'sync.full', 'source_app': 'origin',
            'snapshot': {'vocs': [self.voc()]}})
        with sqlite3.connect(self.path) as db:
            self.assertEqual(db.execute('SELECT status FROM vocs').fetchone()[0], 'RESOLVED')


if __name__ == '__main__':
    unittest.main()
