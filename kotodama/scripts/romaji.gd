class_name Romaji
extends RefCounted
## Converts wāpuro romaji to hiragana as it is typed.

const VOWELS := "aiueo"
const TABLE := {
	"a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
	"ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
	"kya": "きゃ", "kyu": "きゅ", "kyo": "きょ",
	"sa": "さ", "shi": "し", "si": "し", "su": "す", "se": "せ", "so": "そ",
	"sha": "しゃ", "shu": "しゅ", "sho": "しょ", "she": "しぇ",
	"sya": "しゃ", "syu": "しゅ", "syo": "しょ",
	"ta": "た", "chi": "ち", "ti": "ち", "tsu": "つ", "tu": "つ", "te": "て", "to": "と",
	"cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ", "che": "ちぇ",
	"tya": "ちゃ", "tyu": "ちゅ", "tyo": "ちょ",
	"na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
	"nya": "にゃ", "nyu": "にゅ", "nyo": "にょ",
	"ha": "は", "hi": "ひ", "fu": "ふ", "hu": "ふ", "he": "へ", "ho": "ほ",
	"hya": "ひゃ", "hyu": "ひゅ", "hyo": "ひょ",
	"fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
	"ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
	"mya": "みゃ", "myu": "みゅ", "myo": "みょ",
	"ya": "や", "yu": "ゆ", "yo": "よ",
	"ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
	"rya": "りゃ", "ryu": "りゅ", "ryo": "りょ",
	"wa": "わ", "wo": "を", "wi": "うぃ", "we": "うぇ",
	"ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
	"gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ",
	"za": "ざ", "ji": "じ", "zi": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
	"ja": "じゃ", "ju": "じゅ", "jo": "じょ", "je": "じぇ",
	"jya": "じゃ", "jyu": "じゅ", "jyo": "じょ",
	"zya": "じゃ", "zyu": "じゅ", "zyo": "じょ",
	"da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
	"dya": "ぢゃ", "dyu": "ぢゅ", "dyo": "ぢょ",
	"ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
	"bya": "びゃ", "byu": "びゅ", "byo": "びょ",
	"pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
	"pya": "ぴゃ", "pyu": "ぴゅ", "pyo": "ぴょ",
	"xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
	"la": "ぁ", "li": "ぃ", "lu": "ぅ", "le": "ぇ", "lo": "ぉ",
	"xya": "ゃ", "xyu": "ゅ", "xyo": "ょ", "lya": "ゃ", "lyu": "ゅ", "lyo": "ょ",
	"xtu": "っ", "ltu": "っ", "xtsu": "っ", "ltsu": "っ",
	"-": "ー",
}


## Converts as much of [param romaji] as possible. Unfinished latin stays at the end.
static func to_kana(romaji: String) -> String:
	var text: String = romaji.to_lower()
	var out: String = ""
	var i: int = 0
	while i < text.length():
		var c: String = text[i]
		var next: String = text[i + 1] if i + 1 < text.length() else ""
		if c == "n":
			if next == "n" or next == "'":
				out += "ん"
				i += 2
				continue
			if next != "" and not VOWELS.contains(next) and next != "y":
				out += "ん"
				i += 1
				continue
		elif next == c and _is_consonant(c):
			out += "っ"
			i += 1
			continue
		var matched: bool = false
		for length in [4, 3, 2, 1]:
			if i + length > text.length():
				continue
			var chunk: String = text.substr(i, length)
			if TABLE.has(chunk):
				out += TABLE[chunk]
				i += length
				matched = true
				break
		if not matched:
			out += c
			i += 1
	return out


## Converts for a final answer: a trailing lone "n" becomes ん.
static func to_kana_final(romaji: String) -> String:
	var text: String = romaji.to_lower().strip_edges()
	if text.ends_with("n") and not text.ends_with("nn"):
		text += "n"
	return to_kana(text)


static func is_kana(text: String) -> bool:
	for c in text:
		var code: int = c.unicode_at(0)
		var hira: bool = code >= 0x3041 and code <= 0x309F
		var kata: bool = code >= 0x30A1 and code <= 0x30FF
		if not (hira or kata or c == "ー"):
			return false
	return true


static func katakana_to_hiragana(text: String) -> String:
	var out: String = ""
	for c in text:
		var code: int = c.unicode_at(0)
		if code >= 0x30A1 and code <= 0x30F6:
			out += char(code - 0x60)
		else:
			out += c
	return out


static func _is_consonant(c: String) -> bool:
	return c.length() == 1 and c >= "a" and c <= "z" and not VOWELS.contains(c) and c != "n"
