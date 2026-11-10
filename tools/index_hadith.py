import json, os

src_dir = r'C:\Users\abubakr\Desktop\tawheeed\hadith-json-main\db\by_book\the_9_books'
dst_dir = r'C:\Users\abubakr\Desktop\tawheeed\assets\hadith_books'
os.makedirs(dst_dir, exist_ok=True)

# Arabic book names
book_names = {
    'bukhari': ('صحيح البخاري', 'الإمام محمد بن إسماعيل البخاري', 7277),
    'muslim': ('صحيح مسلم', 'الإمام مسلم بن الحجاج النيسابوري', 7500),
    'abudawud': ('سنن أبي داود', 'الإمام أبي داود سليمان بن الأشعث السجستاني', 5274),
    'tirmidhi': ('جامع الترمذي', 'الإمام محمد بن عيسى الترمذي', 3956),
    'nasai': ('سنن النسائي', 'الإمام أحمد بن شعيب النسائي', 5761),
    'ibnmajah': ('سنن ابن ماجه', 'الإمام محمد بن يزيد القزويني', 4341),
    'ahmed': ('مسند الإمام أحمد', 'الإمام أحمد بن محمد بن حنبل', 4305),
    'malik': ('موطأ الإمام مالك', 'الإمام مالك بن أنس الأصبحي', 1832),
    'darimi': ('سنن الدارمي', 'الإمام عبد الله بن عبد الرحمن الدارمي', 3553),
}

summary = []
for fname in sorted(os.listdir(src_dir)):
    if not fname.endswith('.json'): continue
    book_key = fname.replace('.json', '')
    fpath = os.path.join(src_dir, fname)
    
    with open(fpath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    meta = data.get('metadata', {})
    chapters = data.get('chapters', [])
    hadiths = data.get('hadiths', [])
    
    ar_info = meta.get('arabic', {})
    en_info = meta.get('english', {})
    
    # Create chapter index (title only, no hadiths)
    chapter_list = []
    for ch in chapters:
        chapter_list.append({
            'id': ch.get('id'),
            'arabic': ch.get('arabic', ''),
            'english': ch.get('english', ''),
            'hadithCount': sum(1 for h in hadiths if h.get('chapterId') == ch.get('id')),
        })
    
    # Save chapter index (small file)
    index_path = os.path.join(dst_dir, f'{book_key}_index.json')
    with open(index_path, 'w', encoding='utf-8') as f:
        json.dump({
            'id': meta.get('id'),
            'key': book_key,
            'arabicTitle': ar_info.get('title', book_names.get(book_key, ('', '', 0))[0]),
            'arabicAuthor': ar_info.get('author', book_names.get(book_key, ('', '', 0))[1]),
            'totalHadiths': meta.get('length', book_names.get(book_key, ('', '', 0))[2]),
            'chapterCount': len(chapters),
            'chapters': chapter_list,
        }, f, ensure_ascii=False, indent=2)
    
    size_kb = os.path.getsize(index_path) // 1024
    summary.append({
        'key': book_key,
        'title': ar_info.get('title', book_names.get(book_key, ('', '', 0))[0]),
        'author': ar_info.get('author', book_names.get(book_key, ('', '', 0))[1]),
        'totalHadiths': meta.get('length', book_names.get(book_key, ('', '', 0))[2]),
        'chapterCount': len(chapters),
        'indexSize': size_kb,
    })
    print(f'{book_key}: {len(chapters)} chapters, index {size_kb}KB')

# Save book list
with open(os.path.join(dst_dir, 'books_list.json'), 'w', encoding='utf-8') as f:
    json.dump(summary, f, ensure_ascii=False, indent=2)

print(f'\nDone! {len(summary)} books indexed')
print(f'Total index size: {sum(s["indexSize"] for s in summary)}KB')
