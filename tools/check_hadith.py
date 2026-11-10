import json

with open(r'C:\Users\abubakr\Desktop\tawheeed\hadith-json-main\db\by_book\the_9_books\bukhari.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print('Keys:', list(data.keys()))
print('\nMetadata:')
for k, v in data['metadata'].items():
    val = str(v)[:100]
    print(f'  {k}: {val}')

chapters = data.get('chapters', [])
hadiths = data.get('hadiths', [])
print(f'\nChapters count: {len(chapters)}')
print(f'Hadiths count: {len(hadiths)}')

if chapters:
    print('\nFirst chapter:')
    ch = chapters[0]
    for k, v in ch.items():
        val = str(v)[:100]
        print(f'  {k}: {val}')

if hadiths:
    print('\nFirst hadith:')
    h = hadiths[0]
    for k, v in h.items():
        val = str(v)[:150]
        print(f'  {k}: {val}')
