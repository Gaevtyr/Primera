// AI EDIT START - Dwarven language and the tongue that can speak it.
/**
 * # Дворфийский
 * Традиционный язык дворфов, наряду с общим входящий в их повседневную речь.
 */
/datum/language/dwarven
	name = "Дворфийский"
	desc = "Грубый язык шахтёров и горняков, полный коротких, раскатистых слов."
	key = "a"
	space_chance = 35
	syllables = list(
		"etag", "gekur", "tel", "gudos", "geth", "udiz", "zalud", "shoveth", "ver", "zilir",
		"eshobak", "sarumak", "asdobak", "fozak", "shovethak", "tangak", "dogak", "ashokak", "gethak", "slisak", "mulonak",
		"vadag", "vasag", "udosag", "longudosag", "vanag", "hivag", "vilkag", "nigag",
		"asdob", "nir", "nob", "mez", "vor", "fim", "gat", "zun", "att", "nag", "zez", "eshob", "asdob",
		"og", "get", "zal", "ud", "lok", "ad", "nat", "gat", "mit", "des", "shug", "kul", "git", "gad", "zis",
		"deb", "koshmot", "legon", "razmer", "lanzil", "gim", "gamil", "datlad", "tat", "gelut", "gakit", "tomus", "tizot", "rirnol",
		"med", "kulet", "ngalak", "kuthdeng", "cenath", "ustos", "oshnil", "nural", "nazush",
	)

/**
 * # Дворфийский язык
 * Дворфы понимают и говорят на общем и дворфийском языках.
 */
/datum/language_holder/dwarven
	understood_languages = list(
		/datum/language/common = list(LANGUAGE_ATOM),
		/datum/language/dwarven = list(LANGUAGE_ATOM),
	)
	spoken_languages = list(
		/datum/language/common = list(LANGUAGE_ATOM),
		/datum/language/dwarven = list(LANGUAGE_ATOM),
	)

/**
 * # Дворфийский язык
 * Добавляет дворфийский язык к обычным языкам человеческого языка.
 */
/obj/item/organ/tongue/dwarven
	name = "дворфийский язык"
	languages_native = list(/datum/language/dwarven)
	liked_foodtypes = JUNKFOOD | FRIED
	disliked_foodtypes = GROSS | RAW
// AI EDIT END
