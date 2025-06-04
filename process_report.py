import json
import sys
import base64
import io

try:
    import matplotlib.pyplot as plt
except Exception as e:
    print(f"matplotlib is required: {e}", file=sys.stderr)
    sys.exit(1)

json_file = sys.argv[1]
html_out = sys.argv[2]

data = []
with open(json_file, 'r') as f:
    for line in f:
        line = line.strip()
        if line:
            data.append(json.loads(line))

added = sum(len(d.get('added_urls', [])) for d in data)
changed = sum(len(d.get('changed_urls', [])) for d in data)
removed = sum(len(d.get('removed_urls', [])) for d in data)

plt.figure()
plt.bar(['Added', 'Changed', 'Removed'], [added, changed, removed])
plt.title('URL Changes')
plt.ylabel('Count')
img_buf = io.BytesIO()
plt.savefig(img_buf, format='png')
img_buf.seek(0)
img_b64 = base64.b64encode(img_buf.read()).decode('utf-8')
img_buf.close()

html = f"""<html><body>
<h1>Sitemap Report</h1>
<p>Total added URLs: {added}</p>
<p>Total changed URLs: {changed}</p>
<p>Total removed URLs: {removed}</p>
<img src='data:image/png;base64,{img_b64}'/>
</body></html>"""
with open(html_out, 'w') as f:
    f.write(html)

try:
    from weasyprint import HTML
    HTML(html_out).write_pdf(html_out.replace('.html', '.pdf'))
except Exception:
    pass
