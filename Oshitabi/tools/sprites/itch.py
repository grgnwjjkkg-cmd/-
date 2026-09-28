import sys, re, json, urllib.parse, http.cookiejar, urllib.request
game, upload, out = sys.argv[1], sys.argv[2], sys.argv[3]
cj = http.cookiejar.CookieJar(); op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
op.addheaders = [('User-Agent', 'Mozilla/5.0'), ('X-Requested-With', 'XMLHttpRequest')]
tok = lambda h: re.search(r'name="csrf_token" value="([^"]+)"', h).group(1)
h = op.open(game).read().decode()
dl = json.loads(op.open(game + '/download_url', urllib.parse.urlencode({'csrf_token': tok(h)}).encode()).read())['url']
h2 = op.open(dl).read().decode()
key = urllib.parse.unquote(dl.split('/download/')[1])
q = urllib.parse.urlencode({'source': 'game_download', 'after_download_lightbox': 'true'})
r = json.loads(op.open(f"{game}/file/{upload}?{q}", urllib.parse.urlencode({'csrf_token': tok(h2)}).encode()).read())
print(r if 'url' not in r else 'ok')
if 'url' in r:
    with op.open(r['url']) as f, open(out, 'wb') as o:
        while (b := f.read(1 << 20)): o.write(b)
