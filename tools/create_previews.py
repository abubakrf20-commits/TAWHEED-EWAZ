import json, os

src_dir = r'C:\Users\abubakr\Desktop\tawheeed\hadith-json-main\db\by_book\the_9_books'
dst_dir = r'C:\Users\abubakr\Desktop\tawheeed\assets\hadith_books'

# For each book, extract first 5 hadiths per chapter as preview
for fname in sorted(os.listdir(src_dir)):
    if not fname.endswith('.json'): continue
    book_key = fname.replace('.json', '')
    fpath = os.path.join(src_dir, fname)
    
    with open(fpath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    hadiths = data.get('hadiths', [])
    chapters = data.get('chapters', [])
    
    # Group hadiths by chapter, take first 3 per chapter
    preview = {}
    for h in hadiths:
        ch_id = h.get('chapterId', 0)
        if ch_id not in preview:
            preview[ch_id] = []
        if len(preview[ch_id]) < 3:
            arabic = h.get('arabic', '')[:200]
            english = h.get('english', '')
            if isinstance(english, dict):
                english = english.get('text', '')[:200]
            elif isinstance(english, str):
                english = english[:200]
            preview[ch_id].append({
                'id': h.get('id'),
                'arabic': arabic,
                'english': english,
            })
    
    # Save preview
    preview_path = os.path.join(dst_dir, f'{book_key}_preview.json')
    with open(preview_path, 'w', encoding='utf-8') as f:
        json.dump(preview, f, ensure_ascii=False)
    
    size_kb = os.path.getsize(preview_path) // 1024
    print(f'{book_key}: preview {size_kb}KB')

print('Done creating previews')
