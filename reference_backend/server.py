#!/usr/bin/env python3
"""Local REST service for the Flutter laboratory; Python standard library only."""
import argparse
import copy
import json
import os
import re
from decimal import Decimal, ROUND_HALF_UP
import threading
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


class ApiError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


def product_index(catalog):
    home = catalog['homePage']
    result = {}
    for product in home.get('featureProducts', []) + home.get('recommended', []):
        result.setdefault(product['id'], copy.deepcopy(product))
    detail = catalog.get('productPage', {}).get('product')
    if detail:
        result[detail['id']] = {**result.get(detail['id'], {}), **copy.deepcopy(detail)}
        for product in detail.get('similarProducts', []):
            result.setdefault(product['id'], copy.deepcopy(product))
    return result


class Store:
    def __init__(self, catalog_path, state_path):
        self.catalog = json.loads(Path(catalog_path).read_text(encoding='utf-8'))
        self.products = product_index(self.catalog)
        self.state_path = Path(state_path)
        self.lock = threading.RLock()
        self.state = {
            'favoriteIds': sorted(p['id'] for p in self.products.values()
                                  if p.get('isFavorite', p.get('actions', {}).get('isFavorite', False))),
            'reviews': {key: copy.deepcopy(value.get('reviews', [])) for key, value in self.products.items()},
            'profile': {'name': '', 'email': ''}, 'cart': [], 'orders': [],
        }
        if self.state_path.exists():
            persisted = json.loads(self.state_path.read_text(encoding='utf-8'))
            if not isinstance(persisted, dict) or not isinstance(persisted.get('favoriteIds'), list) or not isinstance(persisted.get('reviews'), dict):
                raise ValueError('Invalid saved server state; restore or remove the state file.')
            self.state['favoriteIds'] = sorted({p for p in persisted['favoriteIds'] if p in self.products})
            for field, kind in [('profile', dict), ('cart', list), ('orders', list)]:
                if field in persisted:
                    if not isinstance(persisted[field], kind):
                        raise ValueError(f'Invalid saved {field}.')
                    self.state[field] = persisted[field]
            for key in self.products:
                if key in persisted['reviews']:
                    if not isinstance(persisted['reviews'][key], list):
                        raise ValueError('Invalid saved reviews.')
                    # Catalog reviews are authoritative; keep user-created reviews.
                    reviews = {r['id']: r for r in self.state['reviews'][key]}
                    reviews.update({r['id']: r for r in persisted['reviews'][key]
                                    if r.get('isMine', False)})
                    self.state['reviews'][key] = list(reviews.values())

    def require_product(self, product_id):
        if not isinstance(product_id, str) or product_id not in self.products:
            raise ApiError(404, 'Product not found.')

    def commit(self, updated):
        """Publish memory only after the atomic disk write succeeds."""
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.state_path.with_suffix('.tmp')
        try:
            temporary.write_text(json.dumps(updated, ensure_ascii=False, indent=2), encoding='utf-8')
            os.replace(temporary, self.state_path)
        except OSError:
            temporary.unlink(missing_ok=True)
            raise ApiError(500, 'Could not save the change. Try again.')
        self.state = updated

    def snapshot(self):
        with self.lock:
            return {'catalog': copy.deepcopy(self.catalog), **copy.deepcopy(self.state), 'cart': self.cart()}

    def favorites(self, product_id=None, selected=None):
        with self.lock:
            if product_id is not None:
                self.require_product(product_id)
                updated = copy.deepcopy(self.state)
                favorites = set(updated['favoriteIds'])
                favorites.add(product_id) if selected else favorites.discard(product_id)
                updated['favoriteIds'] = sorted(favorites)
                self.commit(updated)
            return {'favoriteIds': list(self.state['favoriteIds'])}

    def reviews(self, product_id):
        with self.lock:
            self.require_product(product_id)
            return {'reviews': copy.deepcopy(self.state['reviews'][product_id])}

    def add_review(self, product_id, body):
        self.require_product(product_id)
        author, text, rating = body.get('author'), body.get('text'), body.get('rating')
        avatar = body.get('avatarUrl', '')
        if (not isinstance(author, str) or not author.strip() or len(author) > 120
                or not isinstance(text, str) or not text.strip() or len(text) > 2000
                or type(rating) is not int or not 1 <= rating <= 5
                or not isinstance(avatar, str) or len(avatar) > 2048):
            raise ApiError(422, 'A name, review text (1–2000 characters) and rating (1–5) are required.')
        review = {'id': uuid.uuid4().hex, 'author': author.strip(), 'text': text.strip(),
                  'rating': rating, 'avatarUrl': avatar, 'isMine': True,
                  'createdAtLabel': datetime.now(timezone.utc).isoformat(timespec='seconds')}
        with self.lock:
            updated = copy.deepcopy(self.state)
            updated['reviews'][product_id].insert(0, review)
            self.commit(updated)
        return {'review': review}

    def delete_review(self, product_id, review_id):
        with self.lock:
            self.require_product(product_id)
            reviews = self.state['reviews'][product_id]
            review = next((r for r in reviews if r['id'] == review_id), None)
            if review is None:
                raise ApiError(404, 'Review not found.')
            if not review.get('isMine', False):
                raise ApiError(403, 'Only reviews created in this demo can be deleted.')
            updated = copy.deepcopy(self.state)
            updated['reviews'][product_id] = [r for r in reviews if r['id'] != review_id]
            self.commit(updated)


    def cart(self):
        with self.lock:
            totals = {}
            for line in self.state['cart']:
                product = self.products[line['productId']]
                currency = product.get('currency', '')
                totals[currency] = totals.get(currency, Decimal('0')) + Decimal(str(product['price'])) * line['quantity']
            return {'items': copy.deepcopy(self.state['cart']),
                    'totals': {key: float(value.quantize(Decimal('.01'), rounding=ROUND_HALF_UP)) for key, value in totals.items()}}

    def add_cart_item(self, body):
        product_id = body.get('productId')
        self.require_product(product_id)
        product = self.products[product_id]
        quantity = body.get('quantity', 1)
        color, size = body.get('colorId', ''), body.get('size', '')
        if (type(quantity) is not int or not 1 <= quantity <= 99
                or not isinstance(color, str) or not isinstance(size, str)):
            raise ApiError(422, 'Invalid quantity or variant.')
        if not product.get('actions', {}).get('canAddToCart', True):
            raise ApiError(422, 'This product cannot be added to the cart.')
        colors, sizes = product.get('availableColors', []), product.get('availableSizes', [])
        if (colors and color not in [c['id'] for c in colors]) or (not colors and color):
            raise ApiError(422, 'Choose an available color.')
        if (sizes and size not in sizes) or (not sizes and size) or product.get('sizeAvailability', {}).get(size) is False:
            raise ApiError(422, 'Choose an available size.')
        with self.lock:
            updated = copy.deepcopy(self.state)
            line = next((item for item in updated['cart'] if item['productId'] == product_id and
                         item['colorId'] == color and item['size'] == size), None)
            if line:
                if line['quantity'] + quantity > 99:
                    raise ApiError(422, 'Maximum quantity is 99.')
                line['quantity'] += quantity
            else:
                updated['cart'].append({'id': uuid.uuid4().hex, 'productId': product_id,
                                        'quantity': quantity, 'colorId': color, 'size': size})
            self.commit(updated)
            return self.cart()

    def change_cart(self, line_id, quantity):
        if type(quantity) is not int or not 0 <= quantity <= 99:
            raise ApiError(422, 'Quantity must be between 0 and 99.')
        with self.lock:
            updated = copy.deepcopy(self.state)
            line = next((item for item in updated['cart'] if item['id'] == line_id), None)
            if line is None:
                raise ApiError(404, 'Cart item not found.')
            if quantity == 0:
                updated['cart'].remove(line)
            else:
                line['quantity'] = quantity
            self.commit(updated)
            return self.cart()

    def clear_cart(self):
        with self.lock:
            updated = copy.deepcopy(self.state)
            updated['cart'] = []
            self.commit(updated)
            return self.cart()

    def save_profile(self, body):
        name, email = body.get('name'), body.get('email')
        if (not isinstance(name, str) or not name.strip() or len(name) > 120
                or not isinstance(email, str) or len(email) > 254
                or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email.strip())):
            raise ApiError(422, 'Enter a name and a valid email address.')
        with self.lock:
            updated = copy.deepcopy(self.state)
            updated['profile'] = {'name': name.strip(), 'email': email.strip()}
            self.commit(updated)
            return copy.deepcopy(updated['profile'])

    def place_order(self, body):
        key = body.get('requestId')
        name, email = body.get('customerName'), body.get('email')
        phone, address, notes = body.get('phone'), body.get('address'), body.get('notes', '')
        if (not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9_-]{8,100}', key)
                or not isinstance(name, str) or not name.strip() or len(name) > 120
                or not isinstance(email, str) or len(email) > 254
                or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email.strip())
                or not isinstance(phone, str) or not re.fullmatch(r'\+?[0-9 ()-]{7,20}', phone.strip())
                or len(re.sub(r'\D', '', phone)) < 7
                or not isinstance(address, str) or not 10 <= len(address.strip()) <= 500
                or not isinstance(notes, str) or len(notes) > 1000):
            raise ApiError(422, 'Complete a valid name, email, phone and delivery address.')
        with self.lock:
            previous = next((order for order in self.state['orders'] if order['requestId'] == key), None)
            if previous:
                if previous['request'] != body:
                    raise ApiError(409, 'This request ID was already used with different details.')
                return copy.deepcopy(previous)
            cart = self.cart()
            if not cart['items']:
                raise ApiError(422, 'Your cart is empty.')
            if len(cart['totals']) != 1:
                raise ApiError(422, 'An order must use a single currency.')
            currency, total = next(iter(cart['totals'].items()))
            items = []
            for line in cart['items']:
                product = self.products[line['productId']]
                if not product.get('actions', {}).get('canAddToCart', True) or product.get('sizeAvailability', {}).get(line['size']) is False:
                    raise ApiError(422, 'A cart item is no longer available.')
                color = next((color['name'] for color in product.get('availableColors', []) if color['id'] == line['colorId']), '')
                items.append({'productId': product['id'], 'name': product['name'], 'unitPrice': product['price'],
                              'quantity': line['quantity'], 'colorName': color, 'size': line['size']})
            order = {'id': uuid.uuid4().hex, 'requestId': key, 'request': copy.deepcopy(body),
                     'status': 'placed', 'createdAt': datetime.now(timezone.utc).isoformat(timespec='seconds'),
                     'currency': currency, 'total': total, 'items': items, 'paymentMethod': 'pay_on_delivery',
                     'customerName': name.strip(), 'email': email.strip(), 'phone': phone.strip(),
                     'address': address.strip(), 'notes': notes.strip()}
            updated = copy.deepcopy(self.state)
            updated['orders'].insert(0, order)
            updated['cart'] = []
            self.commit(updated)
            return copy.deepcopy(order)

    def cancel_order(self, order_id):
        with self.lock:
            updated = copy.deepcopy(self.state)
            order = next((order for order in updated['orders'] if order['id'] == order_id), None)
            if order is None:
                raise ApiError(404, 'Order not found.')
            if order['status'] not in ('placed', 'cancelled'):
                raise ApiError(409, 'This order can no longer be cancelled.')
            order['status'] = 'cancelled'
            self.commit(updated)
            return copy.deepcopy(order)


class Handler(BaseHTTPRequestHandler):
    server_version = 'GemStoreLab/1.0'

    def log_message(self, fmt, *args):
        if not getattr(self.server, 'quiet', False):
            super().log_message(fmt, *args)

    def reply(self, status, payload=None):
        raw = b'' if payload is None else json.dumps(payload, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(raw)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Accept')
        self.end_headers()
        self.wfile.write(raw)

    def read_json(self):
        if self.headers.get_content_type() != 'application/json':
            raise ApiError(415, 'Send a JSON request body.')
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            raise ApiError(400, 'Invalid Content-Length.')
        if not 0 < length <= 65536:
            raise ApiError(413 if length > 65536 else 400, 'Invalid request body size.')
        try:
            body = json.loads(self.rfile.read(length).decode('utf-8'))
        except (ValueError, UnicodeDecodeError):
            raise ApiError(400, 'Invalid JSON.')
        if not isinstance(body, dict):
            raise ApiError(400, 'Expected a JSON object.')
        return body

    def dispatch(self):
        try:
            path = [unquote(p) for p in urlsplit(self.path).path.strip('/').split('/')]
            store = self.server.store
            if path == ['api', 'health'] and self.command == 'GET':
                return self.reply(200, {'status': 'ok'})
            if path == ['api', 'catalog'] and self.command == 'GET':
                return self.reply(200, store.snapshot())
            if path == ['api', 'favorites'] and self.command == 'GET':
                return self.reply(200, store.favorites())
            if len(path) == 3 and path[:2] == ['api', 'favorites'] and self.command in ('PUT', 'DELETE'):
                return self.reply(200, store.favorites(path[2], self.command == 'PUT'))
            if path == ['api', 'profile']:
                if self.command == 'GET':
                    return self.reply(200, {'profile': store.snapshot()['profile']})
                if self.command == 'PUT':
                    return self.reply(200, {'profile': store.save_profile(self.read_json())})
            if path == ['api', 'cart']:
                if self.command == 'GET':
                    return self.reply(200, {'cart': store.cart()})
                if self.command == 'DELETE':
                    return self.reply(200, {'cart': store.clear_cart()})
            if path == ['api', 'cart', 'items'] and self.command == 'POST':
                return self.reply(200, {'cart': store.add_cart_item(self.read_json())})
            if len(path) == 4 and path[:3] == ['api', 'cart', 'items']:
                if self.command == 'PUT':
                    return self.reply(200, {'cart': store.change_cart(path[3], self.read_json().get('quantity'))})
                if self.command == 'DELETE':
                    return self.reply(200, {'cart': store.change_cart(path[3], 0)})
            if path == ['api', 'orders']:
                if self.command == 'GET':
                    return self.reply(200, {'orders': store.snapshot()['orders']})
                if self.command == 'POST':
                    return self.reply(201, {'order': store.place_order(self.read_json())})
            if len(path) == 4 and path[:2] == ['api', 'orders'] and path[3] == 'cancel' and self.command == 'POST':
                return self.reply(200, {'order': store.cancel_order(path[2])})
            if len(path) >= 3 and path[:2] == ['api', 'products']:
                product_id = path[2]
                store.require_product(product_id)
                if len(path) == 3 and self.command == 'GET':
                    return self.reply(200, {'product': store.products[product_id]})
                if len(path) == 4 and path[3] == 'reviews':
                    if self.command == 'GET':
                        return self.reply(200, store.reviews(product_id))
                    if self.command == 'POST':
                        return self.reply(201, store.add_review(product_id, self.read_json()))
                if len(path) == 5 and path[3] == 'reviews' and self.command == 'DELETE':
                    store.delete_review(product_id, path[4])
                    return self.reply(204)
            raise ApiError(404, 'Endpoint not found.')
        except ApiError as error:
            self.reply(error.status, {'error': error.message})
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception:
            self.reply(500, {'error': 'Unexpected server error.'})

    do_GET = do_POST = do_PUT = do_DELETE = dispatch

    def do_OPTIONS(self):
        self.reply(204)


def create_server(host='127.0.0.1', port=8080, catalog_path=None, state_path=None, quiet=False):
    store = Store(catalog_path or ROOT / 'assets/data/gemstore_data.json',
                  state_path or ROOT / 'backend/.runtime/state.json')
    server = ThreadingHTTPServer((host, port), Handler)
    server.store = store
    server.quiet = quiet
    server.daemon_threads = True
    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--state-file', type=Path)
    args = parser.parse_args()
    with create_server(args.host, args.port, state_path=args.state_file) as server:
        print(f'GemStore REST API: http://{args.host}:{server.server_port}/api', flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
