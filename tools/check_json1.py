import json, sys
sys.stdout.reconfigure(encoding='utf-8')
with open('hafs/kfqc/json/001.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
for item in data[:3]:
    print(f'sura={item["surahNumber"]} ayah={item["ayahNumber"]} x={item["x"]} y={item["y"]}')
    print(f'  polygon="{item["polygon"]}"')
    print()
