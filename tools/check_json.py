import json, sys
sys.stdout.reconfigure(encoding='utf-8')
with open('hafs/kfqc/json/003.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
for item in data[:3]:
    print(f'sura={item["surahNumber"]} ayah={item["ayahNumber"]}')
    print(f'  polygon="{item["polygon"]}"')
    print()
