"""Flag AI-writing patterns in user-facing text.

Patterns come from Wikipedia's "Signs of AI writing" (WP:AISIGNS) and the repo
CLAUDE.md. The skill at .claude/skills/no-ai-tells/SKILL.md explains each rule.

Hook mode (PostToolUse on Write|Edit): reads the tool call from stdin, scans only
the text that was just written, and hands any hits back to Claude as context.

CLI mode: python .claude/hooks/ai_tells.py FILE [FILE...]
Scans whole files, prints hits, exits 1 if there are any.
"""

import json
import os
import re
import sys

CODE_EXTS = {".json", ".gd", ".cs", ".tscn", ".tres", ".cfg", ".py", ".yaml", ".yml"}
PROSE_EXTS = {".md", ".txt", ".csv", ".html"}
COMMENT_MARKERS = {".gd": "#", ".py": "#", ".cs": "//", ".cfg": ";", ".yaml": "#", ".yml": "#"}

SKIP_DIRS = {".claude", "memory", "node_modules", ".godot", "addons", "tests", "test",
             "reference", "polyblocks", ".git", "dev"}
SKIP_FILES = {"claude.md", "agents.md"}

MAX_HITS = 25


def w(words):
    return r"\b(?:" + words + r")\b"


RULES = [
    # Punctuation and symbols
    ("em-dash", r"—", "em dash; use a comma, full stop, \"and\", \"but\" or \"because\""),
    ("en-dash-pause", r" – ", "spaced en dash used as a pause"),
    ("emoji", "[\U0001F300-\U0001FAFF]", "emoji"),

    # AI vocabulary (WP:AIVOCAB, every era)
    ("ai-word", w(r"tapestry|testament|underscor(?:e|es|ed|ing)|pivotal|"
                  r"intricac(?:y|ies)|intricate|interplay|meticulous(?:ly)?|bolster(?:s|ed|ing)?|"
                  r"garner(?:s|ed|ing)?|showcas(?:e|es|ed|ing)|foster(?:s|ed|ing)?|"
                  r"enhanc(?:e|es|ed|ing)|vibrant|robust|crucial|enduring|multifaceted|"
                  r"leverag(?:e|es|ed|ing)|seamless(?:ly)?|nestled|groundbreaking|renowned|"
                  r"boasts?|align(?:s|ed)? with|resonat(?:e|es|ed|ing)|"
                  r"palpable|unwavering|quietly|universally|ever-evolving"),
     "word LLMs overuse"),
    ("additionally", r"(?:^|[.!?]\s+)Additionally\b", "sentence opening with \"Additionally\""),

    # Puffery and significance (WP:AILEGACY, WP:AIPEACOCK)
    ("significance", w(r"plays? an? (?:crucial|vital|key|pivotal|significant|central|important) role|"
                       r"(?:pivotal|defining|key|turning) (?:moment|point)|a reminder (?:of|that)|"
                       r"(?:enduring|lasting) (?:legacy|impact|influence)|indelible|deeply rooted|"
                       r"evolving landscape|setting the stage|broader (?:trend|context|movement)"),
     "puffed-up significance"),
    ("promo", w(r"in the heart of|diverse array|rich (?:history|heritage|tapestry|culture)|"
                r"breathtaking|immersive|unforgettable|embark(?:s|ing)? (?:on|upon)|like never before|"
                r"whether you'?re|dive (?:into|in)|game-?changer|elevates? your|"
                r"something for everyone|a world where"),
     "advert or travel-guide wording"),
    ("copula-dodge", w(r"(?:serves?|served|stands?|stood|functions?|acts?) as (?:a|an|the)"),
     "\"serves as\" style verb where \"is\" would do"),

    # Sentence shapes (WP:AIPARALLEL, WP:SUPERFICIAL)
    ("not-x-but-y", r"\bnot (?:just|only|merely|simply)\b|\b(?:isn'?t|wasn'?t|aren'?t) (?:just|only|merely|about)\b|"
                    r"\b(?:it'?s|it is|this is|that'?s|that is) not (?:a |an |the )?[\w' ]{1,30}[,;] (?:it'?s|it is|but)\b",
     "negative parallelism (\"not X, but Y\")"),
    ("no-x-no-y", r"\bno \w+, no \w+, (?:just|only)\b", "\"no X, no Y, just Z\""),
    ("ing-tail", r",\s+(?:highlighting|underscoring|emphasi[sz]ing|reflecting|symboli[sz]ing|showcasing|"
                 r"ensuring|contributing to|fostering|cementing|solidifying|marking|creating a|offering a)\b",
     "trailing -ing clause that comments on the sentence"),
    ("challenges", w(r"despite (?:these|its|their|the) challenges|faces? (?:several|many|numerous|significant) challenges|"
                     r"future (?:outlook|prospects)"),
     "\"despite challenges\" formula"),
    ("vague-source", w(r"(?:experts|critics|observers|scholars|many|some) (?:say|argue|believe|note|have noted)|"
                       r"it is (?:widely|often|generally) (?:believed|said|considered|regarded)"),
     "vague attribution"),

    # Chatbot residue (WP:COLLABCOMM, WP:DIDACTIC, WP:AIDISCLAIMER)
    ("didactic", w(r"it'?s (?:important|worth|crucial|essential) to (?:note|remember|consider)|worth noting|"
                   r"in (?:summary|conclusion)|overall,"),
     "summary or \"important to note\" filler"),
    ("chatbot", w(r"I hope this helps|let me know|feel free to|great question|absolutely right|"
                  r"certainly!|of course!"),
     "chat reply leaking into the text"),
    ("hedge", w(r"based on (?:the )?available information|not widely (?:available|documented)|"
                r"specific details are (?:limited|scarce)"),
     "hedging disclaimer"),

    # Repo CLAUDE.md list
    ("house-banned", w(r"load-bearing|worth (?:stating plainly|naming|flagging)|full stop|carries the argument|"
                       r"the trap is|the (?:real|honest) (?:question|answer|problem|issue) is|to be clear|"
                       r"let me be direct|(?:a|the) (?:real|actual) (?:tension|problem|issue|question|point)"),
     "phrase banned in the repo CLAUDE.md"),
]
COMPILED = [(name, re.compile(rx, re.IGNORECASE if name not in ("additionally",) else 0), note)
            for name, rx, note in RULES]

STRING_RX = re.compile(r'"((?:[^"\\\n]|\\.)*)"|\'((?:[^\'\\\n]|\\.)*)\'')
INLINE_HEADER_RX = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+\*\*[^*]+\*\*\s*[:—-]")
WORD_RX = re.compile(r"[A-Za-z][A-Za-z'\-]*")
# Log and error strings are read by developers, not players.
LOG_CALL_RX = re.compile(r"\b(?:GD\.Print\w*|GD\.Push\w+|print(?:err|_debug|_rich)?|push_(?:error|warning)|"
                         r"Debug\.Log\w*|Console\.Write\w*|console\.\w+|logger\.\w+|logging\.\w+|"
                         r"assert|Fail|raise|throw)\s*[(\s]")


def skip_path(path):
    parts = re.split(r"[\\/]", path.lower())
    if parts and parts[-1] in SKIP_FILES:
        return True
    return any(p in SKIP_DIRS for p in parts[:-1])


def code_strings(line, ext):
    """Yield string literals that sit before any line comment."""
    marker = COMMENT_MARKERS.get(ext)
    cut = len(line)
    if marker:
        in_str = None
        i = 0
        while i < len(line):
            c = line[i]
            if in_str:
                if c == "\\":
                    i += 2
                    continue
                if c == in_str:
                    in_str = None
            elif c in "\"'":
                in_str = c
            elif line.startswith(marker, i):
                cut = i
                break
            i += 1
    for m in STRING_RX.finditer(line[:cut]):
        s = m.group(1) if m.group(1) is not None else m.group(2)
        if len(WORD_RX.findall(s)) >= 3:
            yield s


def prose_segments(text, ext):
    """Return (line_no, text) pairs worth scanning."""
    out = []
    in_fence = False
    for n, line in enumerate(text.splitlines(), 1):
        if ext in CODE_EXTS:
            if LOG_CALL_RX.search(line):
                continue
            for s in code_strings(line, ext):
                out.append((n, s))
            continue
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        line = re.sub(r"`[^`]*`", "CODE", line)
        if ext == ".html":
            line = re.sub(r"<[^>]*>", " ", line)
        if line.strip():
            out.append((n, line))
    return out


def staccato(s):
    """Three short flat statements in a row. Shouts, questions and trailing-off lines are speech, not this."""
    sentences = [x.strip() for x in re.split(r"(?<=[.!?])\s+", s) if x.strip()]
    run = 0
    for x in sentences:
        flat = x.endswith(".") and not x.endswith("...") and "…" not in x
        run = run + 1 if flat and len(WORD_RX.findall(x)) <= 4 else 0
        if run >= 3:
            return True
    return False


def scan(text, ext, base_line=1):
    hits = []
    segments = prose_segments(text, ext)
    for n, s in segments:
        for name, rx, note in COMPILED:
            for m in rx.finditer(s):
                start = max(0, m.start() - 30)
                snippet = s[start:m.end() + 30].strip()
                hits.append((n + base_line - 1, f"{name} '{m.group(0).strip()}'", note, snippet))
        if ext not in (".csv",) and staccato(s):
            hits.append((n + base_line - 1, "staccato", "run of three or more clipped sentences",
                         s.strip()[:90]))
    if ext == ".md":
        rows = [n for n, s in segments if INLINE_HEADER_RX.match(s)]
        if len(rows) >= 3:
            hits.append((rows[0] + base_line - 1, "bold-header-list",
                         "list items that each open with a bold label and a colon", ""))
    return hits


def format_hits(path, hits):
    lines = []
    for n, name, note, snippet in hits[:MAX_HITS]:
        lines.append(f"  {os.path.basename(path)}:{n} [{name}] {note}: \"{snippet}\"")
    if len(hits) > MAX_HITS:
        lines.append(f"  ...and {len(hits) - MAX_HITS} more")
    return "\n".join(lines)


def hook_main():
    data = json.loads(sys.stdin.buffer.read().decode("utf-8"))
    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {}) or {}
    path = tool_input.get("file_path", "")
    ext = os.path.splitext(path)[1].lower()
    if not path or skip_path(path) or ext not in CODE_EXTS | PROSE_EXTS:
        return 0

    base_line = 1
    if tool_name == "Edit":
        new = tool_input.get("new_string", "")
        old_lines = set(tool_input.get("old_string", "").splitlines())
        # Lines carried over from old_string are blanked so only new lines are scanned.
        text = "\n".join(l if l not in old_lines else "" for l in new.splitlines())
        try:
            with open(path, encoding="utf-8") as f:
                content = f.read()
            idx = content.find(new)
            if idx >= 0:
                base_line = content[:idx].count("\n") + 1
        except OSError:
            pass
    else:
        text = tool_input.get("content", "")

    hits = scan(text, ext, base_line)
    if not hits:
        return 0
    msg = (f"AI-writing check on {path}: {len(hits)} possible tell(s) in the text just written.\n"
           f"{format_hits(path, hits)}\n"
           "Rewrite each one in plain words unless it is deliberate (a character's voice, a literal "
           "meaning, a rule name). Rules: .claude/skills/no-ai-tells/SKILL.md")
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse",
                                             "additionalContext": msg}}))
    return 0


def cli_main(paths):
    total = 0
    for path in paths:
        ext = os.path.splitext(path)[1].lower()
        if ext not in CODE_EXTS | PROSE_EXTS:
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            hits = scan(f.read(), ext)
        if hits:
            total += len(hits)
            print(f"{path}: {len(hits)} hit(s)")
            print(format_hits(path, hits))
    return 1 if total else 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(cli_main(sys.argv[1:]) if len(sys.argv) > 1 else hook_main())
