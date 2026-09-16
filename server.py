import http.server
import json
import os
import urllib.error
import urllib.request

HOST = ''
PORT = 8000
ROOT = os.path.dirname(os.path.abspath(__file__))
TOKEN_FILE = os.path.join(ROOT, 'lichess_token.txt')
PROXY_PATH = '/explorer/lichess'
EXPLORER_URL = 'https://explorer.lichess.org/lichess'


def read_token():
    try:
        with open(TOKEN_FILE, encoding='utf-8-sig') as file:
            return file.read().strip()
    except OSError:
        return ''


def http_error_text(code, has_token):
    if code == 401 and not has_token:
        return 'lichess требует токен — положи его в файл lichess_token.txt'
    if code == 401:
        return 'lichess не принял токен из lichess_token.txt'
    if code == 429:
        return 'lichess просит подождать — слишком много запросов'
    return 'lichess ответил ошибкой ' + str(code)


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.js': 'application/javascript',
        '.css': 'text/css',
        '.json': 'application/json',
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_GET(self):
        path, _, query = self.path.partition('?')
        if path == PROXY_PATH:
            self.proxy_explorer(query)
        else:
            super().do_GET()

    def proxy_explorer(self, query):
        token = read_token()
        headers = {'Accept': 'application/json', 'User-Agent': 'chess-debut-trainer'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = urllib.request.Request(EXPLORER_URL + '?' + query, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                status = response.status
                body = response.read()
        except urllib.error.HTTPError as error:
            self.send_error_json(error.code, http_error_text(error.code, bool(token)))
            return
        except Exception as error:
            self.send_error_json(502, 'нет связи с lichess: ' + str(getattr(error, 'reason', error)))
            return
        self.send_json_body(status, body)

    def send_error_json(self, status, message):
        self.send_json_body(status, json.dumps({'error': message}, ensure_ascii=False).encode('utf-8'))

    def send_json_body(self, status, body):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)


def main():
    server = http.server.ThreadingHTTPServer((HOST, PORT), Handler)
    if not read_token():
        print('Внимание: нет файла lichess_token.txt — статистика lichess работать не будет.')
    print('Сервер запущен: http://localhost:%d/index.html' % PORT)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
