import sqlite3, sys, os
sys.stdout.reconfigure(encoding='utf-8')
conn = sqlite3.connect('tools/mushaf_build/mushaf.db')
cur = conn.cursor()
cur.execute('SELECT count(*) FROM ayah_bounds')
print(f'Rows: {cur.fetchone()[0]}')
cur.execute('SELECT page_number, sura_number, ayah_number, min_x, min_y, max_x, max_y FROM ayah_bounds ORDER BY page_number, sura_number, ayah_number LIMIT 10')
for r in cur.fetchall():
    print(f'  page={r[0]} sura={r[1]} ayah={r[2]} bbox=({r[3]:.1f},{r[4]:.1f})-({r[5]:.1f},{r[6]:.1f})')
cur.execute('SELECT page_number, count(*) as cnt FROM ayah_bounds GROUP BY page_number ORDER BY page_number LIMIT 10')
print('\nAyahs per page (first 10):')
for r in cur.fetchall():
    print(f'  page {r[0]:3d}: {r[1]} ayahs')
db_size = os.path.getsize('tools/mushaf_build/mushaf.db')
print(f'\nDB size: {db_size:,} bytes')
conn.close()
