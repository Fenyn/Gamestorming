"""Read The Art of Game Design (Schell, 1st ed.) from docs/Art of Game Design.pdf.

The PDF is the user's own copy and is git-ignored. This script reads it on demand so no
book text has to live in the repo. All page numbers are PDF pages unless --book is given.
Book page N is PDF page N + 31.

  python book.py lens 18              the lens box for Lens #18 and the page it sits on
  python book.py pages 153 156        text of PDF pages 153 to 156
  python book.py pages 122 125 --book the same, given as printed book pages
  python book.py chapter 14           the whole chapter (capped; use --max to raise)
  python book.py find "interest curve"  pages that contain the phrase, with a snippet
  python book.py render 283 284       PNG of each page for figures; prints the paths
  python book.py toc                  chapter list with PDF page ranges
"""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
PDF = ROOT / "docs" / "Art of Game Design.pdf"
CACHE = Path(os.environ.get("TEMP", "/tmp")) / "agd"
TEXT = CACHE / "agd.txt"
PAGES = CACHE / "pages"
OFFSET = 31

POPPLER = Path(os.environ.get("LOCALAPPDATA", "")) / (
    "Microsoft/WinGet/Packages/oschwartz10612.Poppler_Microsoft.Winget.Source_8wekyb3d8bbwe/"
    "poppler-25.07.0/Library/bin"
)

CHAPTERS = [
    (1, 33, "In the Beginning, There Is the Designer"),
    (2, 41, "The Designer Creates an Experience"),
    (3, 55, "The Experience Rises Out of a Game"),
    (4, 71, "The Game Consists of Elements"),
    (5, 79, "The Elements Support a Theme"),
    (6, 89, "The Game Begins with an Idea"),
    (7, 107, "The Game Improves Through Iteration"),
    (8, 129, "The Game Is Made for a Player"),
    (9, 145, "The Experience Is in the Player's Mind"),
    (10, 161, "Some Elements Are Game Mechanics"),
    (11, 203, "Game Mechanics Must Be in Balance"),
    (12, 239, "Game Mechanics Support Puzzles"),
    (13, 253, "Players Play Games Through an Interface"),
    (14, 277, "Experiences Can Be Judged by Their Interest Curves"),
    (15, 293, "One Kind of Experience Is the Story"),
    (16, 315, "Story and Game Structures Can Be Artfully Merged with Indirect Control"),
    (17, 331, "Stories and Games Take Place in Worlds"),
    (18, 341, "Worlds Contain Characters"),
    (19, 361, "Worlds Contain Spaces"),
    (20, 377, "The Look and Feel of a World Is Defined by Its Aesthetics"),
    (21, 385, "Some Games Are Played with Other Players"),
    (22, 389, "Other Players Sometimes Form Communities"),
    (23, 403, "The Designer Usually Works with a Team"),
    (24, 413, "The Team Sometimes Communicates Through Documents"),
    (25, 421, "Good Games Are Created Through Playtesting"),
    (26, 435, "The Team Builds a Game with Technology"),
    (27, 447, "Your Game Will Probably Have a Client"),
    (28, 455, "The Designer Gives the Client a Pitch"),
    (29, 465, "The Designer and Client Want the Game to Make a Profit"),
    (30, 473, "Games Transform Their Players"),
    (31, 485, "Designers Have Certain Responsibilities"),
    (32, 491, "Each Designer Has a Motivation"),
    (33, 494, "Goodbye"),
]
LAST_PAGE = 520


def tool(name):
    exe = POPPLER / f"{name}.exe"
    return str(exe) if exe.exists() else name


def ensure_text():
    if not PDF.exists():
        sys.exit(f"PDF not found: {PDF}")
    CACHE.mkdir(parents=True, exist_ok=True)
    if TEXT.exists() and TEXT.stat().st_mtime >= PDF.stat().st_mtime:
        return
    try:
        subprocess.run([tool("pdftotext"), "-layout", str(PDF), str(TEXT)], check=True)
        return
    except (OSError, subprocess.CalledProcessError):
        pass
    from pypdf import PdfReader  # fallback when poppler is missing

    reader = PdfReader(str(PDF))
    TEXT.write_text("\f".join((p.extract_text() or "") for p in reader.pages), encoding="utf-8")


def load_pages():
    ensure_text()
    return TEXT.read_text(encoding="utf-8", errors="replace").split("\f")


def clean(text):
    lines = [re.sub(r"\s{2,}", " ", l.strip()) for l in text.splitlines()]
    return "\n".join(l for l in lines if l)


def unhyphenate(text):
    return re.sub(r"(\w)- (\w)", r"\1\2", text)


def print_pages(pages, first, last):
    for n in range(first, last + 1):
        if 1 <= n <= len(pages):
            print(f"\n===== PDF page {n} (book {n - OFFSET}) =====")
            print(clean(pages[n - 1]))


def cmd_pages(args):
    pages = load_pages()
    first, last = args.first, args.last or args.first
    if args.book:
        first, last = first + OFFSET, last + OFFSET
    print_pages(pages, first, last)


def chapter_range(num):
    for i, (n, start, _) in enumerate(CHAPTERS):
        if n == num:
            end = CHAPTERS[i + 1][1] - 1 if i + 1 < len(CHAPTERS) else LAST_PAGE
            return start, end
    sys.exit(f"no chapter {num}")


def cmd_chapter(args):
    pages = load_pages()
    start, end = chapter_range(args.num)
    out = []
    for n in range(start, end + 1):
        out.append(f"\n===== PDF page {n} (book {n - OFFSET}) =====\n{clean(pages[n - 1])}")
    text = "\n".join(out)
    if len(text) > args.max:
        text = text[: args.max] + f"\n\n[cut at {args.max} chars; use --max or pages for the rest]"
    print(text)


def cmd_lens(args):
    pages = load_pages()
    pat = re.compile(rf"^\s*Lens\s*#\s*{args.num}\s*:\s*The Lens of (.+)$", re.M)
    for n, page in enumerate(pages, 1):
        if n < 40:
            continue  # skip the table of contents
        m = pat.search(page)
        if not m:
            continue
        lines = page.splitlines()
        idx = next(i for i, l in enumerate(lines) if pat.search(l))
        box = []
        for l in lines[idx + 1 :]:
            s = re.sub(r"\s{2,}", " ", l.strip())
            if re.match(r"Lens\s*#", s):
                break
            box.append(s)
        text = unhyphenate(" ".join(x for x in box if x))
        cut = text.rfind("?")
        if cut > 0:
            text = text[: cut + 1]
        print(f"Lens #{args.num}: The Lens of {m.group(1).strip()}  (PDF page {n}, book {n - OFFSET})\n")
        print(text.replace("● ", "\n- ").strip())
        if args.context:
            print_pages(pages, n - 1, n + 1)
        return
    sys.exit(f"Lens #{args.num} not found")


def cmd_find(args):
    pages = load_pages()
    needle = args.phrase.lower()
    hits = 0
    for n, page in enumerate(pages, 1):
        flat = re.sub(r"\s+", " ", page)
        low = flat.lower()
        pos = low.find(needle)
        if pos < 0:
            continue
        hits += 1
        snippet = flat[max(0, pos - 90) : pos + len(needle) + 90].strip()
        print(f"PDF {n:3d} (book {n - OFFSET:3d}): ...{snippet}...")
    if not hits:
        print("no hits")


def cmd_render(args):
    PAGES.mkdir(parents=True, exist_ok=True)
    first, last = args.first, args.last or args.first
    if args.book:
        first, last = first + OFFSET, last + OFFSET
    prefix = PAGES / "p"
    subprocess.run(
        [tool("pdftoppm"), "-f", str(first), "-l", str(last), "-r", str(args.dpi), "-png", str(PDF), str(prefix)],
        check=True,
    )
    for n in range(first, last + 1):
        print(PAGES / f"p-{n:03d}.png")


def cmd_toc(args):
    for i, (n, start, title) in enumerate(CHAPTERS):
        end = CHAPTERS[i + 1][1] - 1 if i + 1 < len(CHAPTERS) else LAST_PAGE
        print(f"{n:2d}  pdf {start:3d}-{end:3d}  book {start - OFFSET:3d}-{end - OFFSET:3d}  {title}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("pages")
    p.add_argument("first", type=int)
    p.add_argument("last", type=int, nargs="?")
    p.add_argument("--book", action="store_true", help="numbers are printed book pages")
    p.set_defaults(fn=cmd_pages)

    p = sub.add_parser("chapter")
    p.add_argument("num", type=int)
    p.add_argument("--max", type=int, default=60000)
    p.set_defaults(fn=cmd_chapter)

    p = sub.add_parser("lens")
    p.add_argument("num", type=int)
    p.add_argument("--context", action="store_true", help="also print the page before and after")
    p.set_defaults(fn=cmd_lens)

    p = sub.add_parser("find")
    p.add_argument("phrase")
    p.set_defaults(fn=cmd_find)

    p = sub.add_parser("render")
    p.add_argument("first", type=int)
    p.add_argument("last", type=int, nargs="?")
    p.add_argument("--book", action="store_true")
    p.add_argument("--dpi", type=int, default=80)
    p.set_defaults(fn=cmd_render)

    p = sub.add_parser("toc")
    p.set_defaults(fn=cmd_toc)

    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    args.fn(args)


if __name__ == "__main__":
    main()
