import sqlite3

conn = sqlite3.connect(r"tools\mushaf_build\mushaf.db")
rows = conn.execute(
    "SELECT page_number, sura_number, ayah_number, min_x, min_y, max_x, max_y "
    "FROM ayah_bounds WHERE page_number IN (603, 604) "
    "ORDER BY page_number, min_y, min_x"
).fetchall()
for page, sura, ayah, minx, miny, maxx, maxy in rows:
    print("p%d  %d:%d   x[%6.1f .. %6.1f]  y[%6.1f .. %6.1f]"
          % (page, sura, ayah, minx, maxx, miny, maxy))
