import base64, re, sys
src = open('udada.src.html').read()
css = ''.join('.bg%d{background-image:url(data:image/jpeg;base64,%s)}\n' % (i, base64.b64encode(open('img/s%d.jpg' % i, 'rb').read()).decode()) for i in range(6))
out = src.replace('/*__BGCSS__*/', css)
open('udada.html', 'w').write(out)
m = re.search(r'<script>(.*)</script>', out, re.S); open('udada_check.js', 'w').write(m.group(1))
print('bytes', len(out))
