import urllib.request, ssl, re

ctx = ssl._create_unverified_context()
u = "https://claude.site/artifacts/TySs1GvGkxtfVDWtd2Z4yv"
req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
with urllib.request.urlopen(req, context=ctx, timeout=10) as r:
    html = r.read().decode("utf-8", errors="ignore")

with open("scratch_artifact.html", "w", encoding="utf-8") as f:
    f.write(html)

print("Saved scratch_artifact.html, length:", len(html))

title = re.findall(r"<title>(.*?)</title>", html, re.I)
print("Title:", title)

# Extract plain text content
# Remove styles, scripts
clean = re.sub(r"<(script|style)[^>]*>.*?</\1>", "", html, flags=re.DOTALL | re.I)
text = re.sub(r"<[^>]+>", "\n", clean)
text = re.sub(r"\n\s*\n+", "\n\n", text).strip()

with open("scratch_artifact.txt", "w", encoding="utf-8") as f:
    f.write(text)

print("Saved scratch_artifact.txt, length:", len(text))
print("First 1500 chars:\n", text[:1500])

links = re.findall(r'href=[\'"](https?://[^\'"]+)[\'"]', html)
print("\n=== Found links ===")
for l in sorted(list(set(links))):
    print(" -", l)
