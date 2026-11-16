import re

with open("scratch_artifact.html", "r", encoding="utf-8") as f:
    c = f.read()

next_data = re.findall(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', c)
if next_data:
    print("Found __NEXT_DATA__, len:", len(next_data[0]))
    with open("next_data.json", "w", encoding="utf-8") as out:
        out.write(next_data[0])

scripts = re.findall(r'<script[^>]*>(.*?)</script>', c, re.DOTALL)
print(f"Total scripts: {len(scripts)}")
for i, s in enumerate(scripts):
    print(f"Script {i}: len {len(s)}")
    if "content" in s.lower() or "artifact" in s.lower() or "nasa" in s.lower() or "title" in s.lower():
        print(f"  match in script {i}")
