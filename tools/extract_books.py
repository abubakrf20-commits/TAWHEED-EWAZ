import jpype, jpype.imports, os, json, re

lib_dir = r'C:\Users\abubakr\Desktop\tawheeed\tools\mdb_libs'
jars = ';'.join([os.path.join(lib_dir, f) for f in os.listdir(lib_dir) if f.endswith('.jar')])
jvm_path = r'C:\Program Files\Java\jdk-26.0.1\bin\server\jvm.dll'
jpype.startJVM(jvm_path, classpath=[jars])
from java.io import File
from java.nio.charset import Charset
from com.healthmarketscience.jackcess import DatabaseBuilder

book_dir = r'C:\Users\abubakr\Desktop\tawheeed\books'
out_dir = r'C:\Users\abubakr\Desktop\tawheeed\assets\books_data'
mirror_dir = r'C:\Users\abubakr\Desktop\tawheeed\tools\books_json'
os.makedirs(out_dir, exist_ok=True)
os.makedirs(mirror_dir, exist_ok=True)

def jval(v):
    if v is None:
        return ''
    return str(v)

# The source Access DB is stored in cp1256, which cannot represent the
# zero-width non-joiner (ZWNJ, U+200C). Those positions were saved as ASCII
# '?'. A genuine Persian question mark is '؟' (U+061F), so any ASCII '?'
# sandwiched directly between Arabic-script letters is a lost ZWNJ.
_AR = '\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF'
_ZWNJ_RE = re.compile(r'([' + _AR + r'])\?([' + _AR + r'])')
def restore_zwnj(s):
    return _ZWNJ_RE.sub(lambda m: m.group(1) + '\u200c' + m.group(2), s)

def detect_category(title):
    t = (title or '').lower()
    if 'نماز' in t or 'وضو' in t or 'طهارت' in t or 'فقه' in t:
        return 'فقه'
    if 'عقیده' in t or 'توحید' in t or 'ایمان' in t:
        return 'عقیده'
    if 'قرآن' in t or 'تفسیر' in t or 'تجوید' in t:
        return 'تفسیر'
    if 'حدیث' in t or 'بخاری' in t or 'سنت' in t:
        return 'حدیث'
    if 'سیرت' in t or 'زندگی' in t or 'صحابه' in t or 'نبوت' in t:
        return 'سیره'
    if 'اخلاق' in t or 'آداب' in t:
        return 'اخلاق'
    if 'ذکر' in t or 'ادعیه' in t or 'دعا' in t:
        return 'ادعیه'
    if 'زکات' in t or 'حج' in t or 'روزه' in t:
        return 'عبادات'
    if 'شعر' in t or 'ادب' in t or 'سعدي' in t or 'مثنوی' in t:
        return 'ادبیات'
    return 'متفرقه'

def read_table(db, name):
    try:
        tbl = db.getTable(name)
    except Exception:
        return []
    if tbl is None:
        return []
    cols = [str(c.getName()) for c in tbl.getColumns()]
    rows = []
    it = tbl.iterator()
    while it.hasNext():
        row = it.next()
        d = {}
        for c in cols:
            d[c] = restore_zwnj(jval(row.get(c)))
        rows.append(d)
    return rows

files = sorted([f for f in os.listdir(book_dir) if f.endswith('.bok')])
results = []

for fname in files:
    fpath = os.path.join(book_dir, fname)
    proper_title = fname.replace('.bok', '')
    try:
        builder = DatabaseBuilder()
        builder.setCharset(Charset.forName('windows-1256'))
        builder.setFile(File(fpath))
        db = builder.open()

        main_rows = read_table(db, 'Main')
        book_data = main_rows[0] if main_rows else {}
        bkid = jval(book_data.get('BkId', ''))
        content, toc = [], []
        if bkid:
            content = read_table(db, f'b{bkid}')
            toc = read_table(db, f't{bkid}')
        db.close()

        category = jval(book_data.get('cat', ''))
        if not category:
            category = detect_category(proper_title)

        book_out = {
            'id': bkid,
            'originalFile': fname,
            'title': proper_title,
            'description': jval(book_data.get('Betaka', '')),
            'author': jval(book_data.get('Auth', '')),
            'category': category,
            'language': jval(book_data.get('Lng', '')),
            'pages': len(content),
            'toc': toc,
            'content': content,
        }
        out_path = os.path.join(out_dir, f'book_{bkid}.json')
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(book_out, f, ensure_ascii=False, indent=2)
        # keep the tools mirror in sync
        with open(os.path.join(mirror_dir, f'book_{bkid}.json'), 'w', encoding='utf-8') as f:
            json.dump(book_out, f, ensure_ascii=False, indent=2)

        sample = content[0].get('nass', '')[:50] if content else ''
        has_ar = any('\u0600' <= c <= '\u06FF' for c in sample)
        results.append({
            'id': bkid,
            'title': proper_title,
            'pages': len(content),
            'tocCount': len(toc),
            'readable': has_ar,
        })
        s = 'OK' if has_ar else 'NO-ARABIC'
        print(f'{s}: {proper_title[:45]} | {len(content)}p {len(toc)}toc')
    except Exception as e:
        print(f'FAIL: {fname} -> {str(e)[:100]}')

with open(os.path.join(out_dir, 'books_index.json'), 'w', encoding='utf-8') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
with open(os.path.join(mirror_dir, 'books_index.json'), 'w', encoding='utf-8') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print(f'\n{len(results)} books extracted')
jpype.shutdownJVM()
