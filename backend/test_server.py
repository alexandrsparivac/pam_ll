import copy
import http.client
import io
from types import SimpleNamespace
import json
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch
from server import ROOT, Store, Handler, create_server


class MemorySocket:
    def __init__(self, incoming):
        self.incoming = io.BytesIO(incoming)
        self.outgoing = bytearray()
    def makefile(self, *args, **kwargs):
        return self.incoming
    def sendall(self, data):
        self.outgoing.extend(data)


class HandlerApiTests(unittest.TestCase):
    """Actual HTTP parser, routes and JSON responses; no network sockets."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state_path = Path(self.temp.name) / 'state.json'
        self.server = SimpleNamespace(
            store=Store(ROOT / 'assets/data/gemstore_data.json', self.state_path), quiet=True)

    def request(self, method, path, body=None, raw=None, content_type='application/json'):
        payload = json.dumps(body).encode('utf-8') if body is not None else raw
        headers = f'{method} /api/{path} HTTP/1.0\r\nHost: localhost\r\n'
        if payload is not None:
            headers += f'Content-Type: {content_type}\r\nContent-Length: {len(payload)}\r\n'
        connection = MemorySocket(headers.encode() + b'\r\n' + (payload or b''))
        Handler(connection, ('127.0.0.1', 12345), self.server)
        response = http.client.HTTPResponse(MemorySocket(bytes(connection.outgoing)))
        response.begin()
        encoded = response.read()
        return response.status, json.loads(encoded) if encoded else None, dict(response.getheaders())

    def test_catalog_is_exactly_the_supplied_json(self):
        status, body, _ = self.request('GET', 'catalog')
        self.assertEqual(status, 200)
        self.assertEqual(body['catalog'], json.loads((ROOT / 'assets/data/gemstore_data.json').read_text()))
        self.assertEqual(len(self.server.store.products), 8)

    def test_health_and_cors(self):
        status, body, headers = self.request('GET', 'health')
        self.assertEqual((status, body['status']), (200, 'ok'))
        self.assertEqual(headers['Access-Control-Allow-Origin'], '*')
        self.assertEqual(self.request('OPTIONS', 'catalog')[0], 204)

    def test_favorite_put_delete_and_persistence(self):
        self.assertEqual(self.request('PUT', 'favorites/p001')[0], 200)
        self.assertIn('p001', self.request('GET', 'favorites')[1]['favoriteIds'])
        self.assertIn('p001', Store(ROOT / 'assets/data/gemstore_data.json', self.state_path).state['favoriteIds'])
        self.request('DELETE', 'favorites/p001')
        self.assertNotIn('p001', self.request('GET', 'favorites')[1]['favoriteIds'])

    def test_favorite_put_is_idempotent(self):
        self.request('PUT', 'favorites/p001')
        self.request('PUT', 'favorites/p001')
        self.assertEqual(self.request('GET', 'favorites')[1]['favoriteIds'].count('p001'), 1)

    def test_review_post_get_delete_and_persistence(self):
        status, body, _ = self.request('POST', 'products/p001/reviews',
            {'author': 'Valentin', 'text': 'Produs bun, mulțumesc!', 'rating': 5})
        self.assertEqual(status, 201)
        review_id = body['review']['id']
        self.assertTrue(body['review']['isMine'])
        restored = Store(ROOT / 'assets/data/gemstore_data.json', self.state_path)
        self.assertEqual(restored.state['reviews']['p001'][0]['text'], 'Produs bun, mulțumesc!')
        self.assertEqual(self.request('GET', 'products/p001/reviews')[1]['reviews'][0]['id'], review_id)
        self.assertEqual(self.request('DELETE', f'products/p001/reviews/{review_id}')[0], 204)
        self.assertEqual(self.request('GET', 'products/p001/reviews')[1]['reviews'], [])

    def test_reviews_are_in_catalog_snapshot(self):
        self.request('POST', 'products/p001/reviews', {'author': 'Test', 'text': 'Review', 'rating': 4})
        self.assertEqual(self.request('GET', 'catalog')[1]['reviews']['p001'][0]['rating'], 4)

    def test_catalog_reviews_survive_old_empty_saved_reviews(self):
        old_state = copy.deepcopy(self.server.store.state)
        old_state['reviews']['p003'] = []
        self.state_path.write_text(json.dumps(old_state))
        restored = Store(ROOT / 'assets/data/gemstore_data.json', self.state_path)
        self.assertEqual([r['id'] for r in restored.state['reviews']['p003']],
                         ['r001', 'r002'])

    def test_unknown_product_and_route_return_404(self):
        for method, path in [('GET', 'products/missing'), ('PUT', 'favorites/missing'), ('GET', 'unknown')]:
            self.assertEqual(self.request(method, path)[0], 404)

    def test_invalid_review_validation(self):
        for rating in [0, 6, True, '5']:
            self.assertEqual(self.request('POST', 'products/p001/reviews',
                {'author': 'Test', 'text': 'Review', 'rating': rating})[0], 422)
        for body in [{'author': '', 'text': 'Review', 'rating': 5},
                     {'author': 'Test', 'text': ' ', 'rating': 5},
                     {'author': 'Test', 'text': 'a' * 2001, 'rating': 5}]:
            self.assertEqual(self.request('POST', 'products/p001/reviews', body)[0], 422)

    def test_invalid_json_and_content_type(self):
        self.assertEqual(self.request('POST', 'products/p001/reviews', raw=b'{')[0], 400)
        self.assertEqual(self.request('POST', 'products/p001/reviews', raw=b'[]')[0], 400)
        self.assertEqual(self.request('POST', 'products/p001/reviews', raw=b'{}', content_type='text/plain')[0], 415)
        self.assertEqual(self.request('POST', 'products/p001/reviews', raw=b'x' * 65537)[0], 413)

    def test_cannot_delete_seed_review(self):
        self.server.store.state['reviews']['p001'] = [{'id': 'seed', 'isMine': False}]
        self.assertEqual(self.request('DELETE', 'products/p001/reviews/seed')[0], 403)
        self.assertEqual(self.request('DELETE', 'products/p001/reviews/missing')[0], 404)

    def test_failed_disk_write_keeps_memory_unchanged(self):
        previous = copy.deepcopy(self.server.store.state)
        with patch('server.os.replace', side_effect=OSError('Disk unavailable')):
            self.assertEqual(self.request('PUT', 'favorites/p001')[0], 500)
        self.assertEqual(self.server.store.state, previous)

    def test_parallel_writes_do_not_lose_favorites(self):
        ids = ['p001', 'p004', 'p006', 'p007', 'p008']
        with ThreadPoolExecutor(max_workers=5) as executor:
            statuses = list(executor.map(lambda key: self.request('PUT', f'favorites/{key}')[0], ids))
        self.assertTrue(all(status == 200 for status in statuses))
        self.assertTrue(set(ids).issubset(self.request('GET', 'favorites')[1]['favoriteIds']))

    def test_product_details_are_merged_by_id(self):
        status, body, _ = self.request('GET', 'products/p003')
        self.assertEqual(status, 200)
        self.assertEqual(body['product']['name'], 'Sportwear Set')
        self.assertEqual(len(body['product']['galleryImageUrls']), 2)
        self.assertEqual(body['product']['availableSizes'], ['S', 'M', 'L'])
        self.assertFalse(body['product']['sizeAvailability']['S'])

    def cart_item(self, product='p001', **options):
        return self.request('POST', 'cart/items', {'productId': product, 'quantity': 1, **options})

    def draft(self):
        return {'requestId': 'checkout-request-001', 'customerName': 'Valentin',
                'email': 'test@example.com', 'phone': '+37369123456',
                'address': 'Chisinau, strada Exemplu 10', 'notes': ''}

    def test_cart_variants_quantities_and_totals(self):
        self.assertEqual(self.cart_item('p003', colorId='black', size='S')[0], 422)
        self.assertEqual(self.cart_item('p003', colorId='unknown', size='L')[0], 422)
        status, body, _ = self.cart_item('p003', colorId='black', size='L', quantity=2)
        self.assertEqual(status, 200)
        self.assertEqual(body['cart']['totals']['USD'], 160)
        line_id = body['cart']['items'][0]['id']
        self.cart_item('p003', colorId='coral', size='L')
        self.assertEqual(len(self.request('GET', 'cart')[1]['cart']['items']), 2)
        self.request('PUT', f'cart/items/{line_id}', {'quantity': 3})
        self.assertEqual(self.request('GET', 'cart')[1]['cart']['totals']['USD'], 320)
        self.request('DELETE', f'cart/items/{line_id}')
        self.assertEqual(self.request('GET', 'cart')[1]['cart']['totals']['USD'], 80)
        self.request('DELETE', 'cart')
        self.assertEqual(self.request('GET', 'cart')[1]['cart']['items'], [])

    def test_profile_and_cart_persist(self):
        self.assertEqual(self.request('PUT', 'profile', {'name': 'Valentin', 'email': 'test@example.com'})[0], 200)
        self.cart_item()
        restored = Store(ROOT / 'assets/data/gemstore_data.json', self.state_path)
        self.assertEqual(restored.state['profile']['name'], 'Valentin')
        self.assertEqual(restored.cart()['items'][0]['productId'], 'p001')
        self.assertEqual(self.request('PUT', 'profile', {'name': 'V', 'email': 'invalid'})[0], 422)

    def test_checkout_uses_server_prices_and_clears_cart(self):
        self.cart_item(quantity=3)
        status, body, _ = self.request('POST', 'orders', {**self.draft(), 'total': 0.01})
        self.assertEqual(status, 201)
        self.assertEqual(body['order']['total'], 119.97)
        self.assertEqual(body['order']['status'], 'placed')
        self.assertEqual(self.request('GET', 'cart')[1]['cart']['items'], [])
        self.assertEqual(self.request('GET', 'orders')[1]['orders'][0]['id'], body['order']['id'])
        self.assertEqual(Store(ROOT / 'assets/data/gemstore_data.json', self.state_path).state['orders'][0]['total'], 119.97)

    def test_checkout_retry_does_not_duplicate_orders(self):
        self.cart_item()
        first = self.request('POST', 'orders', self.draft())[1]['order']
        second = self.request('POST', 'orders', self.draft())[1]['order']
        self.assertEqual(first['id'], second['id'])
        self.assertEqual(len(self.request('GET', 'orders')[1]['orders']), 1)
        self.assertEqual(self.request('POST', 'orders', {**self.draft(), 'address': 'Different complete address'})[0], 409)

    def test_checkout_validation_and_empty_cart(self):
        self.assertEqual(self.request('POST', 'orders', self.draft())[0], 422)
        self.cart_item()
        for field, value in [('email', 'bad'), ('phone', '12'), ('address', 'short')]:
            self.assertEqual(self.request('POST', 'orders', {**self.draft(), field: value})[0], 422)
        self.assertEqual(len(self.request('GET', 'cart')[1]['cart']['items']), 1)

    def test_order_cancellation(self):
        self.cart_item()
        order_id = self.request('POST', 'orders', self.draft())[1]['order']['id']
        self.assertEqual(self.request('POST', f'orders/{order_id}/cancel', {})[1]['order']['status'], 'cancelled')
        self.assertEqual(self.request('POST', 'orders/missing/cancel', {})[0], 404)

    def test_checkout_disk_failure_is_atomic(self):
        self.cart_item()
        with patch('server.os.replace', side_effect=OSError('Disk full')):
            self.assertEqual(self.request('POST', 'orders', self.draft())[0], 500)
        self.assertEqual(self.request('GET', 'orders')[1]['orders'], [])
        self.assertEqual(len(self.request('GET', 'cart')[1]['cart']['items']), 1)


class SocketApiTests(HandlerApiTests):
    """Same contract over real HTTP when local port binding is permitted."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state_path = Path(self.temp.name) / 'state.json'
        try:
            self.server = create_server(port=0, state_path=self.state_path, quiet=True)
        except PermissionError:
            self.skipTest('Local port binding is not permitted in this environment.')
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.thread.join, 3)
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)

    def request(self, method, path, body=None, raw=None, content_type='application/json'):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=3)
        payload = json.dumps(body).encode('utf-8') if body is not None else raw
        headers = {'Content-Type': content_type} if payload is not None else {}
        try:
            connection.request(method, '/api/' + path, body=payload, headers=headers)
            response = connection.getresponse()
            encoded = response.read()
            return response.status, json.loads(encoded) if encoded else None, dict(response.getheaders())
        finally:
            connection.close()


if __name__ == '__main__':
    unittest.main()
