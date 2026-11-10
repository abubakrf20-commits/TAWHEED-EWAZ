#!/usr/bin/env python3
"""
convert_html_to_books.py
========================
Converts HTML books from المكتبة الشاملة (Al-Maktaba Al-Shamela) to the
Tawheed Flutter app's JSON format.

Input:  Directory containing book folders with .htm files (windows-1256 encoding)
Output: Compressed JSON files (book_*.json.gz) + books_index.json

Usage:
    python convert_html_to_books.py <input_dir> <output_dir>

The script handles:
- Two HTML formats: Shamela simple HTML and Word-export HTML
- Multi-volume books (merging multiple .htm files into one book)
- Footnote extraction and preservation
- Chapter/section detection for table of contents
- UTF-8 output with gzip compression
"""

import os
import sys
import re
import json
import gzip
import hashlib
from html.parser import HTMLParser
from pathlib import Path


# ============================================================================
# HTML Text Extractor
# ============================================================================

class ShamelaHTMLExtractor(HTMLParser):
    """Extracts structured text from Shamela HTML files."""

    def __init__(self):
        super().__init__()
        self.text_parts = []
        self.current_tag = None
        self.in_script = False
        self.in_style = False
        self.skip_content = False
        self.tag_stack = []
        self.footnotes = []
        self.current_footnote_id = None
        self.in_footnote = False
        self.chapters = []
        self.current_chapter = None

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        self.tag_stack.append(tag)

        if tag in ('script', 'style'):
            self.in_script = True
            return

        if tag == 'title':
            self.skip_content = True

        if tag in ('p', 'div', 'br'):
            if self.text_parts and self.text_parts[-1] != '\n':
                self.text_parts.append('\n')

        if tag == 'hr':
            self.text_parts.append('\n---\n')

        # Detect footnote markers (blue colored text in Word exports)
        if tag == 'span':
            style = attrs_dict.get('style', '')
            if 'color:blue' in style.lower() or 'color: blue' in style.lower():
                self.in_footnote = True

        # Detect superscript (footnote references)
        if tag == 'sup':
            pass  # Will be handled in content

    def handle_endtag(self, tag):
        if self.tag_stack and self.tag_stack[-1] == tag:
            self.tag_stack.pop()

        if tag in ('script', 'style'):
            self.in_script = False

        if tag == 'title':
            self.skip_content = False

        if tag == 'span' and self.in_footnote:
            self.in_footnote = False

    def handle_data(self, data):
        if self.in_script or self.skip_content:
            return

        text = data.strip()
        if not text:
            return

        self.text_parts.append(text)

    def get_text(self):
        raw = ' '.join(self.text_parts)
        # Clean up excessive whitespace
        raw = re.sub(r'\n\s*\n', '\n\n', raw)
        raw = re.sub(r' +', ' ', raw)
        return raw.strip()


def extract_text_from_html(html_content):
    """Extract plain text from HTML content, handling both Shamela formats."""
    # Remove Word XML comments
    html_content = re.sub(r'<!--.*?-->', '', html_content, flags=re.DOTALL)

    # Remove <head> section entirely
    html_content = re.sub(r'<head[^>]*>.*?</head>', '', html_content, flags=re.DOTALL | re.IGNORECASE)

    # Remove <style> blocks
    html_content = re.sub(r'<style[^>]*>.*?</style>', '', html_content, flags=re.DOTALL | re.IGNORECASE)

    # Remove <script> blocks
    html_content = re.sub(r'<script[^>]*>.*?</script>', '', html_content, flags=re.DOTALL | re.IGNORECASE)

    # Remove MSO conditional comments
    html_content = re.sub(r'<!--\[if.*?endif\]-->', '', html_content, flags=re.DOTALL)

    # Replace <br> and <br/> with newlines
    html_content = re.sub(r'<br\s*/?>', '\n', html_content, flags=re.IGNORECASE)

    # Replace <hr> with separator
    html_content = re.sub(r'<hr[^>]*>', '\n---\n', html_content, flags=re.IGNORECASE)

    # Replace block-level tags with newlines
    html_content = re.sub(r'</?(?:p|div|li|tr|td|th)[^>]*>', '\n', html_content, flags=re.IGNORECASE)

    # Remove all remaining HTML tags
    html_content = re.sub(r'<[^>]+>', '', html_content)

    # Decode HTML entities
    html_content = html_content.replace('&nbsp;', ' ')
    html_content = html_content.replace('&amp;', '&')
    html_content = html_content.replace('&lt;', '<')
    html_content = html_content.replace('&gt;', '>')
    html_content = html_content.replace('&quot;', '"')
    html_content = html_content.replace('&#39;', "'")
    html_content = html_content.replace('&ldquo;', '\u201c')
    html_content = html_content.replace('&rdquo;', '\u201d')
    html_content = html_content.replace('&lsquo;', '\u2018')
    html_content = html_content.replace('&rsquo;', '\u2019')

    # Remove Shamela header/footer
    html_content = re.sub(r'http://www\.shamela\.ws', '', html_content)
    html_content = re.sub(r'تم إعداد هذا الملف آليا بواسطة المكتبة الشاملة', '', html_content)

    # Clean up whitespace
    lines = html_content.split('\n')
    cleaned_lines = []
    for line in lines:
        line = line.strip()
        if line:
            cleaned_lines.append(line)

    return '\n'.join(cleaned_lines)


def extract_title_from_html(html_content, folder_name=''):
    """Extract book title from HTML content, with folder name fallback."""
    # First try to get a good title from the HTML
    html_title = None

    # Try the blue header table (Word export format) - look for specific book name
    # Pattern: "الكتاب: <book name>" in the blue header
    title_match = re.search(r'color:#00349C[^>]*>\s*(?:الكتاب\s*[:\s]\s*)?([^<]+)', html_content)
    if title_match:
        raw = re.sub(r'<[^>]+>', ' ', title_match.group(1)).strip()
        lines = [l.strip() for l in raw.split('\n') if l.strip()]
        for line in lines:
            # Skip generic labels
            if any(skip in line for skip in ['ترجمه فارسي', 'الكتاب :', 'الكتاب:', ' programme', 'shamela']):
                continue
            if line.startswith('الكتاب'):
                line = line.split(':', 1)[-1].strip() if ':' in line else line.replace('الكتاب', '').strip()
            if line and len(line) > 3:
                html_title = line
                break

    # Try the Shamela header format
    if not html_title:
        title_match = re.search(r'الكتاب[:\s]+([^\n<]+)', html_content)
        if title_match:
            raw = title_match.group(1).strip()
            if raw and 'ترجمه فارسي' not in raw:
                html_title = raw

    # Clean up HTML title
    if html_title:
        # Remove volume indicators like "جلد اول", "جلد اول" etc.
        html_title = re.sub(r'\s*جلد\s+(اوّل|اول|دوم|سوم|چهارم|خامس)\s*', '', html_title)
        html_title = html_title.strip()
        # Remove trailing numbers
        html_title = re.sub(r'_\d+$', '', html_title)

    # Use folder name as primary source (it's more reliable)
    folder_title = folder_name.strip() if folder_name else None

    # Manual overrides for books where HTML title extraction fails
    title_overrides = {
        'الؤلؤ و المرجان': 'الؤلؤ و المرجان',
        'الرحيق المختوم': 'الرحيق المختوم',
        'تصاويري از زندگی صحابه': 'تصاويري از زندگی صحابه',
        'شرح آسان عقیده طحاوی': 'شرح آسان عقیده طحاوی',
        'مختصر صحیح بخاری': 'مختصر صحیح بخاری',
        'كليله و دمنه': 'كليله و دمنه',
        'متن ابو شجاع': 'متن ابو شجاع',
        'ديوان مولوي و شمس': 'ديوان مولوي و شمس',
        'گلستان سعدي': 'گلستان سعدي',
        'بوستان سعدي': 'بوستان سعدي',
    }

    if folder_title and folder_title in title_overrides:
        return title_overrides[folder_title]

    # Prefer HTML title if it's more specific and not generic
    if html_title and len(html_title) > 5 and 'ترجمه' not in html_title:
        return html_title
    elif folder_title:
        return folder_title
    elif html_title:
        return html_title

    return None


def extract_author_from_html(html_content):
    """Extract author from HTML content."""
    # Try author patterns
    author_patterns = [
        r'مؤلف[:\s]+([^\n<]+)',
        r'تأليف[:\s]+([^\n<]+)',
        r'المؤلف[:\s]+([^\n<]+)',
        r'author["\s:>]+([^<"]+)',
    ]
    for pattern in author_patterns:
        match = re.search(pattern, html_content, re.IGNORECASE)
        if match:
            author = match.group(1).strip()
            # Clean up
            author = re.sub(r'<[^>]+>', '', author).strip()
            if author and len(author) < 200:
                return author
    return ''


def extract_chapters(text):
    """Extract chapter headings for table of contents."""
    chapters = []
    # Match patterns like "باب 1:" or "فصل 1:" or "حديث 1:"
    patterns = [
        r'(باب\s+\d+[:\s]+[^\n]+)',
        r'(فصل\s+(?:اوّل|دوم|سوم|چهارم|خامس|اول|دوم|سوم|چهارم|پنجم|[^\n]+))',
        r'(حديث\s+\d+[:\s]+[^\n]*)',
        r'(كتاب\s+[^\n:]+)',
    ]

    seen = set()
    for pattern in patterns:
        for match in re.finditer(pattern, text):
            chapter = match.group(1).strip()
            # Clean up
            chapter = re.sub(r'\s+', ' ', chapter)
            if chapter not in seen and len(chapter) > 5:
                seen.add(chapter)
                chapters.append(chapter)

    return chapters


def extract_footnotes(text):
    """Extract footnotes from text. Returns (cleaned_text, footnotes_dict)."""
    footnotes = {}

    # Pattern 1: (N) followed by ________ and footnote text
    fn_pattern1 = re.finditer(r'\((\d+)\)\s*_{5,}\s*\((\d+)\)\s*[-–]\s*(.*?)(?=\(\d+\)\s*_{5,}|$)', text, re.DOTALL)
    for match in fn_pattern1:
        fn_id = match.group(2)
        fn_text = match.group(3).strip()
        fn_text = re.sub(r'\s+', ' ', fn_text)
        footnotes[fn_id] = fn_text

    # Pattern 2: (N) at end of sentence, footnote text after separator
    fn_pattern2 = re.finditer(r'\((\d+)\)[.\s]*________\s*(.*?)(?=\((\d+)\)[.\s]*________|$)', text, re.DOTALL)
    for match in fn_pattern2:
        fn_id = match.group(1)
        fn_text = match.group(2).strip()
        fn_text = re.sub(r'\s+', ' ', fn_text)
        if fn_id not in footnotes and fn_text:
            footnotes[fn_id] = fn_text

    # Pattern 3: Simple (N) references with footnote text at end of section
    fn_pattern3 = re.finditer(r'\((\d+)\)\s*[-–]\s*([^\n(]+(?:\n[^\n(]+)*)', text)
    for match in fn_pattern3:
        fn_id = match.group(1)
        fn_text = match.group(2).strip()
        fn_text = re.sub(r'\s+', ' ', fn_text)
        if fn_id not in footnotes and fn_text and len(fn_text) > 10:
            footnotes[fn_id] = fn_text

    return footnotes


def split_into_pages(text, chars_per_page=800):
    """Split text into pages of approximately chars_per_page characters."""
    if not text:
        return []

    words = text.split()
    pages = []
    current_page = []
    current_len = 0

    for word in words:
        current_page.append(word)
        current_len += len(word) + 1

        if current_len >= chars_per_page:
            pages.append(' '.join(current_page))
            current_page = []
            current_len = 0

    if current_page:
        pages.append(' '.join(current_page))

    return pages


# ============================================================================
# Book Processor
# ============================================================================

def process_book_folder(folder_path):
    """Process a single book folder containing .htm files."""
    folder = Path(folder_path)
    book_name = folder.name

    # Find all HTM files
    htm_files = sorted(folder.glob('*.htm'))
    if not htm_files:
        print(f"  No .htm files found in {folder_path}")
        return None

    print(f"  Found {len(htm_files)} volume(s)")

    all_text_parts = []
    all_chapters = []
    all_footnotes = {}
    title = None
    author = ''

    for i, htm_file in enumerate(htm_files):
        print(f"    Processing volume {i+1}: {htm_file.name}")

        # Read with proper encoding
        try:
            with open(htm_file, 'r', encoding='windows-1256') as f:
                html_content = f.read()
        except Exception as e:
            print(f"    Error reading {htm_file}: {e}")
            try:
                with open(htm_file, 'r', encoding='utf-8', errors='replace') as f:
                    html_content = f.read()
            except Exception as e2:
                print(f"    Fatal error reading {htm_file}: {e2}")
                continue

        # Extract title from first volume only
        if title is None:
            title = extract_title_from_html(html_content, book_name)
            if title:
                title = re.sub(r'برنامج المكتبة الشاملة.*', '', title).strip()

        # Extract author from first volume only
        if not author:
            author = extract_author_from_html(html_content)

        # Extract text
        text = extract_text_from_html(html_content)
        if text:
            all_text_parts.append(text)

            # Extract chapters
            chapters = extract_chapters(text)
            all_chapters.extend(chapters)

            # Extract footnotes
            footnotes = extract_footnotes(text)
            all_footnotes.update(footnotes)

    # Use folder name as title if extraction failed
    if not title or len(title) < 3:
        title = book_name

    # Clean title
    title = title.strip()
    title = re.sub(r'\s+', ' ', title)

    # Combine all text
    full_text = '\n\n'.join(all_text_parts)

    # Split into pages
    pages = split_into_pages(full_text)

    # Generate a deterministic ID from the book name
    book_id = hashlib.md5(book_name.encode('utf-8')).hexdigest()[:8]
    # Convert to a numeric-ish ID
    book_id = str(int(book_id, 16) % 100000)

    # Build the book data
    book_data = {
        'id': book_id,
        'title': title,
        'author': author,
        'category': _detect_category(title, book_name),
        'volumes': len(htm_files),
        'pages': len(pages),
        'toc': all_chapters[:50],  # Limit TOC entries
        'content': pages,
        'footnotes': all_footnotes if all_footnotes else {},
    }

    return book_data


def _detect_category(title, folder_name):
    """Auto-detect book category from title/folder name."""
    combined = (title + ' ' + folder_name).lower()

    categories = {
        'فقه': ['فقه', 'نماز', 'وضو', 'طهارت', 'صوم', 'حج', 'زکاة', 'نيت', 'ابو شجاع', 'عمدة الأحكام'],
        'عقیده': ['عقیده', 'توحید', 'ایمان', '信仰', 'Names', 'صفات', 'اسلام', 'توحيد', 'طحاوي', 'طحاوی'],
        'حدیث': ['حدیث', 'بخاری', 'سنت', 'رياض', 'نووي', 'صحيح', 'التجريد'],
        'سیره': ['سیره', 'زندگی', 'صحابه', 'نبوت', 'علي', 'عمر', 'ابوبكر', 'عثمان', 'حسن', 'رحيق', 'تصوير', 'نوبي'],
        'اخلاق': ['اخلاق', 'آداب', 'ادب'],
        'ادعیه': ['ذکر', 'ادعیه', 'دعا', 'الأذكار', 'الأذکار'],
        'ادبیات': ['شعر', 'ادب', 'سعدي', 'مثنوی', 'ديوان', 'كليله', 'گلستان', 'بوستان', 'مولوي'],
        'ترجمه قرآن': ['ترجمه معاني', 'قرآن کريم'],
        'تجوید': ['تجوید'],
    }

    for cat, keywords in categories.items():
        for kw in keywords:
            if kw.lower() in combined:
                return cat

    return 'متفرقه'


def save_book_json(book_data, output_dir):
    """Save book data as gzipped JSON."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    book_id = book_data['id']
    filename = f'book_{book_id}.json.gz'
    filepath = output_dir / filename

    json_str = json.dumps(book_data, ensure_ascii=False, separators=(',', ':'))
    compressed = gzip.compress(json_str.encode('utf-8'))

    with open(filepath, 'wb') as f:
        f.write(compressed)

    return filepath, len(compressed)


def generate_books_index(books_data, output_dir):
    """Generate books_index.json file."""
    index = []
    for book in books_data:
        index.append({
            'id': book['id'],
            'title': book['title'],
            'author': book.get('author', ''),
            'category': book.get('category', ''),
            'pages': book['pages'],
            'volumes': book.get('volumes', 1),
            'tocCount': len(book.get('toc', [])),
            'readable': True,
            'compressed': True,
        })

    index_path = Path(output_dir) / 'books_index.json'
    with open(index_path, 'w', encoding='utf-8') as f:
        json.dump(index, f, ensure_ascii=False, indent=None)

    return index_path


# ============================================================================
# Main
# ============================================================================

def main():
    if len(sys.argv) < 3:
        print("Usage: python convert_html_to_books.py <input_dir> <output_dir>")
        print("  input_dir:  Directory containing book folders with .htm files")
        print("  output_dir: Directory to save converted .json.gz files")
        sys.exit(1)

    input_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])

    if not input_dir.exists():
        print(f"Error: Input directory not found: {input_dir}")
        sys.exit(1)

    # Find all book folders
    book_folders = sorted([
        d for d in input_dir.iterdir()
        if d.is_dir() and not d.name.startswith('.')
    ])

    print(f"Found {len(book_folders)} book folders in {input_dir}")
    print(f"Output directory: {output_dir}")
    print("=" * 60)

    all_books = []
    errors = []

    for folder in book_folders:
        print(f"\nProcessing: {folder.name}")
        try:
            book_data = process_book_folder(folder)
            if book_data:
                filepath, size = save_book_json(book_data, output_dir)
                all_books.append(book_data)
                print(f"  -> Saved: {filepath.name} ({size:,} bytes, {book_data['pages']} pages)")
            else:
                print(f"  -> Skipped (no content)")
        except Exception as e:
            print(f"  -> Error: {e}")
            errors.append((folder.name, str(e)))

    # Generate index
    if all_books:
        index_path = generate_books_index(all_books, output_dir)
        print(f"\n{'=' * 60}")
        print(f"Generated books_index.json with {len(all_books)} books")
        print(f"Index saved to: {index_path}")

    print(f"\n{'=' * 60}")
    print(f"Conversion complete!")
    print(f"  Books converted: {len(all_books)}")
    print(f"  Errors: {len(errors)}")

    if errors:
        print("\nErrors:")
        for name, err in errors:
            print(f"  - {name}: {err}")


if __name__ == '__main__':
    main()
