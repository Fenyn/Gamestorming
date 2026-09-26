extends RefCounted
## Fills a duel's CardFaceCache with placeholder textures under every key the duel can ask for, so
## a headless test never waits on a real face render. Personalities get each seat's deck colour and
## the default; Strikes get every Strike Table base. One texture per card, so checks that compare
## faces can still tell cards apart.

const STRIKE_TABLE_BASES: int = 32   # more than any Strike Table base a matchup can resolve to


static func fill(cache: CardFaceCache, library: CardLibrary, decks: Array[DeckList]) -> void:
	cache._back = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	var backdrops: Array[Color] = [CardFace.NO_BACKDROP]
	for deck in decks:
		backdrops.append(CardFace.mastery_backdrop(deck, library))
	for value in library.defs.values():
		var def: CardDef = value
		var placeholder: ImageTexture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
		if def.is_personality():
			for aspect in def.aspects:
				for backdrop in backdrops:
					cache._cache[CardFaceCache.key_for(def, int(aspect.get("aspect", 1)), backdrop)] = placeholder
		else:
			cache._cache[CardFaceCache.key_for(def)] = placeholder
			for table in range(STRIKE_TABLE_BASES):
				cache._cache[CardFaceCache.key_for(def, 0, CardFace.NO_BACKDROP, table)] = placeholder
