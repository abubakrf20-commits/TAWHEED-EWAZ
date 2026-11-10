import json, os

src_dir = r'C:\Users\abubakr\Desktop\tawheeed\hadith-json-main\db\by_book\the_9_books'
dst_dir = r'C:\Users\abubakr\Desktop\tawheeed\assets\hadith_books'

for fname in sorted(os.listdir(src_dir)):
    if not fname.endswith('.json'): continue
    book_key = fname.replace('.json', '')
    fpath = os.path.join(src_dir, fname)
    
    with open(fpath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    hadiths = data.get('hadiths', [])
    chapters = data.get('chapters', [])
    
    # Group hadiths by chapter
    by_chapter = {}
    for h in hadiths:
        ch_id = h.get('chapterId', 0)
        if ch_id not in by_chapter:
            by_chapter[ch_id] = []
        by_chapter[ch_id].append({
            'id': h.get('id'),
            'idInBook': h.get('idInBook'),
            'arabic': h.get('arabic', ''),
            'english': h.get('english', '') if isinstance(h.get('english'), str) else h.get('english', {}).get('text', ''),
        })
    
    # Save per-chapter files
    book_dir = os.path.join(dst_dir, book_key)
    os.makedirs(book_dir, exist_ok=True)
    
    for ch in chapters:
        ch_id = ch.get('id')
        ch_hadiths = by_chapter.get(ch_id, [])
        ch_path = os.path.join(book_dir, f'ch_{ch_id}.json')
        with open(ch_path, 'w', encoding='utf-8') as f:
            json.dump(ch_hadiths, f, ensure_ascii=False)
    
    print(f'{book_key}: {len(chapters)} chapters, {len(hadiths)} hadiths')

print('Done splitting hadiths into per-chapter files')
