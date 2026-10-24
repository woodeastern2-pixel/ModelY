import unittest

from fastapi.testclient import TestClient
import faiss_bridge_server as bridge


class VectorRegression(unittest.TestCase):
    def setUp(self):
        bridge._INDEX = None
        bridge._DIM = None
        bridge._IDS.clear()
        bridge._PAYLOADS.clear()
        bridge._VECTORS.clear()
        self.client = TestClient(bridge.app)

    def tearDown(self):
        self.client.close()

    def test_empty_search_and_replacement_do_not_duplicate_ids(self):
        self.assertEqual(self.client.post('/search', json={'vector': [1., 0.]}).json(),
                         {'results': []})
        for vector in ([1., 0.], [0., 1.]):
            result = self.client.post('/upsert', json={'id': 'one', 'vector': vector})
            self.assertEqual(result.json()['count'], 1)
        results = self.client.post('/search', json={'vector': [0., 1.]}).json()['results']
        self.assertEqual(len(results), 1)
        self.assertAlmostEqual(results[0]['score'], 1.)

    def test_invalid_top_k_is_rejected(self):
        self.assertEqual(self.client.post('/search',
            json={'vector': [1., 0.], 'top_k': -1}).status_code, 422)


if __name__ == '__main__':
    unittest.main()
