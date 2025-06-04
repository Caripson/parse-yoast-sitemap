import json
import sys
import base64
import io
import datetime
from collections import defaultdict

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

daily = defaultdict(lambda: {'added': 0, 'changed': 0, 'removed': 0})
for entry in data:
    ts = entry.get('timestamp')
    if isinstance(ts, (int, float)):
        day = datetime.datetime.utcfromtimestamp(ts).date()
    elif isinstance(ts, str):
        try:
            day = datetime.date.fromisoformat(ts.split('T')[0])
        except Exception:
            continue
    else:
        continue
    daily[str(day)]['added'] += len(entry.get('added_urls', []))
    daily[str(day)]['changed'] += len(entry.get('changed_urls', []))
    daily[str(day)]['removed'] += len(entry.get('removed_urls', []))

days = sorted(daily.keys())
added_series = [daily[d]['added'] for d in days]
changed_series = [daily[d]['changed'] for d in days]
removed_series = [daily[d]['removed'] for d in days]
plt.figure(figsize=(6, 4))
plt.bar(['Added', 'Changed', 'Removed'], [added, changed, removed])
plt.title('Total URL Changes')
plt.ylabel('Count')
img_buf = io.BytesIO()
plt.savefig(img_buf, format='png')
img_buf.seek(0)
img_b64 = base64.b64encode(img_buf.read()).decode('utf-8')
img_buf.close()

plt.figure(figsize=(8, 4))
plt.plot(days, added_series, label='Added', marker='o')
plt.plot(days, changed_series, label='Changed', marker='o')
plt.plot(days, removed_series, label='Removed', marker='o')
plt.legend()
plt.title('Daily URL Changes')
plt.xlabel('Day')
plt.ylabel('Count')
plt.xticks(rotation=45, ha='right')
plt.tight_layout()
trend_buf = io.BytesIO()
plt.savefig(trend_buf, format='png')
trend_buf.seek(0)
trend_b64 = base64.b64encode(trend_buf.read()).decode('utf-8')
trend_buf.close()

html = f"""<html><body>
<h1>Sitemap Report</h1>
<p>Total added URLs: {added}</p>
<p>Total changed URLs: {changed}</p>
<p>Total removed URLs: {removed}</p>
<img src='data:image/png;base64,{img_b64}'/>
<h2>Trend</h2>
<img src='data:image/png;base64,{trend_b64}'/>
</body></html>"""
with open(html_out, 'w') as f:
    f.write(html)

try:
    from weasyprint import HTML
    HTML(html_out).write_pdf(html_out.replace('.html', '.pdf'))
except Exception:
    pass
