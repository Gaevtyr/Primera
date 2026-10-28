// AI EDIT START - Dwarven species, beard, and alcohol requirement adapted to current species hooks.
#define DWARF_ALCOHOL_RATE 0.1
#define DWARF_DRUNKNESS_MAX 100
#define DWARF_DRUNKNESS_DECAY 1
#define DWARF_DRUNKNESS_CRITICAL_MAX 20
#define DWARF_DRUNKNESS_DANGER_MIN 21
#define DWARF_DRUNKNESS_DANGER_MAX 35
#define DWARF_DRUNKNESS_WARNING_MIN 36
#define DWARF_DRUNKNESS_WARNING_MAX 50
#define DWARF_DRUNKNESS_THIRST_MIN 51
#define DWARF_DRUNKNESS_THIRST_MAX 65
#define DWARF_DRUNKNESS_ALERT_TIME 10 SECONDS
#define DWARF_ALCOHOL_MESSAGE_COOLDOWN 5 SECONDS
#define DWARF_MILD_TRAUMA_CHANCE 1
#define DWARF_ALCOHOL_TRAUMA_LIMIT 3
#define DWARF_DANGER_MESSAGE_CHANCE 30
#define DWARF_THIRST_MESSAGE_CHANCE 30
#define DWARF_WITHDRAWAL_TOX_DAMAGE 10
#define DWARF_WITHDRAWAL_CRITICAL_STAMINA 80
#define DWARF_WITHDRAWAL_DANGER_STAMINA 60
#define DWARF_WITHDRAWAL_WARNING_STAMINA 40

/**
 * # Дворф
 * Коренастый, выносливый гуманоид, привычный к тяжёлому труду, шахтёрским контрактам и бару после смены.
 * Дворфы дышат как люди, говорят на общем и дворфийском, а алкоголь поддерживает их характерный боевой дух.
 */
/datum/species/dwarf
	name = "Дворф"
	plural_form = "Дворфы"
	id = "dwarf"
	inherent_traits = list(TRAIT_DWARF)
	species_language_holder = /datum/language_holder/dwarven
	mutanttongue = /obj/item/organ/tongue/dwarven
	changesource_flags = MIRROR_BADMIN | WABBAJACK | MIRROR_MAGIC | MIRROR_PRIDE | ERT_SPAWN | RACE_SWAP | SLIME_EXTRACT

	/// Current alcohol level. Staying drunk prevents withdrawal penalties.
	var/dwarf_drunkness = DWARF_DRUNKNESS_MAX
	/// Next time the alcohol level decays, in world ticks.
	var/next_dwarf_drunkness_time = 0
	/// Next time an alcohol craving message may be shown.
	var/next_dwarf_alcohol_message_time = 0
	/// Number of mild traumas successfully caused by alcohol withdrawal.
	var/dwarf_alcohol_traumas = 0

/**
 * Sets a characteristic beard and begins the dwarf-only alcohol and withdrawal effects.
 *
 * Arguments:
 * * human - The human who gained this species.
 * * old_species - The species the human had before the change.
 * * pref_load - Whether this change is loading saved preferences.
 * * regenerate_icons - Whether the species change should regenerate icons.
 * * replace_missing - Whether missing organs should be replaced.
 */
/datum/species/dwarf/on_species_gain(mob/living/carbon/human/human, datum/species/old_species, pref_load, regenerate_icons = TRUE, replace_missing = TRUE)
	human.set_facial_hairstyle(pick("Beard (Full)", "Beard (Dwarf)", "Beard (Very Long)"), update = FALSE)
	. = ..()
	// TRAIT_DWARF also grants table traversal; keep the short stature without that movement effect.
	REMOVE_TRAIT(human, TRAIT_PASSTABLE, TRAIT_DWARF)
	next_dwarf_drunkness_time = world.time + DWARF_DRUNKNESS_ALERT_TIME + rand(0, DWARF_DRUNKNESS_ALERT_TIME / 2)
	next_dwarf_alcohol_message_time = world.time
	RegisterSignal(human, COMSIG_LIVING_LIFE, PROC_REF(spec_life))
	RegisterSignal(human, COMSIG_MOB_MINED, PROC_REF(on_mined))
	RegisterSignal(human, COMSIG_MOB_REAGENT_TICK, PROC_REF(handle_chemicals))

/**
 * Stops dwarf-specific effects when a human changes away from this species.
 *
 * Arguments:
 * * human - The human who lost this species.
 * * new_species - The species the human changed into.
 * * pref_load - Whether this change is loading saved preferences.
 */
/datum/species/dwarf/on_species_loss(mob/living/carbon/human/human, datum/species/new_species, pref_load)
	UnregisterSignal(human, list(COMSIG_LIVING_LIFE, COMSIG_MOB_MINED, COMSIG_MOB_REAGENT_TICK))
	. = ..()

/// Rewards successful mining with a brief mood boost when using a pickaxe or mining drill.
/datum/species/dwarf/proc/on_mined(mob/living/carbon/human/source, turf/closed/mineral/rock, exp_multiplier)
	SIGNAL_HANDLER
	if(!istype(source.get_active_held_item(), /obj/item/pickaxe))
		return

	source.add_mood_event("dwarf_mining", /datum/mood_event/dwarf_mining)

/// Adds metabolized ethanol to the dwarf's alcohol level.
/datum/species/dwarf/proc/handle_chemicals(mob/living/carbon/human/source, datum/reagent/chem, seconds_per_tick, metabolization_ratio)
	SIGNAL_HANDLER
	if(!istype(chem, /datum/reagent/consumable/ethanol))
		return NONE

	var/datum/reagent/consumable/ethanol/the_good_stuff = chem
	var/booze_power = sqrt(the_good_stuff.volume) * the_good_stuff.boozepwr * DWARF_ALCOHOL_RATE
	dwarf_drunkness = clamp(dwarf_drunkness + booze_power, 0, DWARF_DRUNKNESS_MAX)

/// Sends an alcohol craving message no more often than once every 5 seconds.
/datum/species/dwarf/proc/notify_alcohol_craving(mob/living/carbon/human/source, message)
	if(next_dwarf_alcohol_message_time > world.time)
		return

	next_dwarf_alcohol_message_time = world.time + DWARF_ALCOHOL_MESSAGE_COOLDOWN
	to_chat(source, message)

/// Applies withdrawal effects and periodically lowers the dwarf's alcohol level.
/datum/species/dwarf/proc/spec_life(mob/living/carbon/human/source, seconds_per_tick)
	SIGNAL_HANDLER
	if(source.stat == DEAD || HAS_TRAIT(source, TRAIT_STASIS))
		return

	if(next_dwarf_drunkness_time <= world.time)
		dwarf_drunkness = max(dwarf_drunkness - DWARF_DRUNKNESS_DECAY, 0)
		next_dwarf_drunkness_time = world.time + DWARF_DRUNKNESS_ALERT_TIME + rand(0, DWARF_DRUNKNESS_ALERT_TIME / 2)

	switch(dwarf_drunkness)
		if(0 to DWARF_DRUNKNESS_CRITICAL_MAX)
			source.adjust_tox_loss(DWARF_WITHDRAWAL_TOX_DAMAGE)
			source.adjust_stamina_loss(DWARF_WITHDRAWAL_CRITICAL_STAMINA)
			notify_alcohol_craving(source, span_userdanger("Вам срочно нужен алкоголь! Тело содрогается от жажды, и вы чувствуете, что долго так не протянете."))
		if(DWARF_DRUNKNESS_DANGER_MIN to DWARF_DRUNKNESS_DANGER_MAX)
			notify_alcohol_craving(source, span_danger("Тяга к выпивке становится болезненной."))
			if(dwarf_alcohol_traumas < DWARF_ALCOHOL_TRAUMA_LIMIT && prob(DWARF_MILD_TRAUMA_CHANCE))
				if(source.gain_trauma_type(BRAIN_TRAUMA_MILD))
					dwarf_alcohol_traumas++
			source.adjust_stamina_loss(DWARF_WITHDRAWAL_DANGER_STAMINA)
		if(DWARF_DRUNKNESS_WARNING_MIN to DWARF_DRUNKNESS_WARNING_MAX)
			source.adjust_stamina_loss(DWARF_WITHDRAWAL_WARNING_STAMINA)
			if(prob(DWARF_DANGER_MESSAGE_CHANCE))
				notify_alcohol_craving(source, span_danger("Вы могли бы выпить прямо сейчас."))
		if(DWARF_DRUNKNESS_THIRST_MIN to DWARF_DRUNKNESS_THIRST_MAX)
			if(prob(DWARF_THIRST_MESSAGE_CHANCE))
				notify_alcohol_craving(source, span_warning("Вы чувствуете жажду. Кружка добротного пива была бы кстати."))

/**
 * Returns a Deep Rock Galactic-inspired description of the dwarf people.
 */
/datum/species/dwarf/get_species_description()
	return "Коренастые и бородатые дворфы известны как лучшие шахтёры и самые надёжные напарники. \
		Их нанимают на опасные контракты в дальних мирах: пробиваться сквозь скалу, добывать редкие минералы и успеть к эвакуации. \
		Тяжёлая смена заслуживает крепкого пива, а ни один дворф не бросит товарища в беде."

/**
 * Returns short lore entries about dwarven mining culture.
 */
/datum/species/dwarf/get_species_lore()
	return list(
		"Дворфы поколениями работают в шахтах, где обычный экипаж предпочёл бы даже не высаживаться. \
		Они любят хорошую броню, исправные инструменты, честную оплату и тех, кто держит слово.",
		"После смены дворфы собираются в баре: вспоминают удачные вылазки, спорят о добыче и поднимают кружки за вернувшихся домой. \
		Слава о смелых горняках часто опережает их корабли.",
	)

/// A little pride from a successful shift underground.
/datum/mood_event/dwarf_mining
	description = "Хорошо поработал в шахте."
	mood_change = 1
	timeout = 2 MINUTES

/**
 * Returns the visible species perks for dwarves.
 */
/datum/species/dwarf/create_pref_unique_perks()
	var/list/to_add = list()

	to_add += list(
		list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "beer-mug-empty",
			SPECIES_PERK_NAME = "Крепкий дворфийский дух",
			SPECIES_PERK_DESC = "Дворфы добывают кирками и шахтёрскими дрелями вдвое быстрее, а успешная добыча ненадолго улучшает им настроение. Алкоголь пополняет шкалу опьянения и помогает избежать тяжёлой ломки.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "beer-mug-empty",
			SPECIES_PERK_NAME = "Похмелье без пива",
			SPECIES_PERK_DESC = "Без алкоголя дворф постепенно теряет опьянение; при низком уровне начинаются слабость и болезненная ломка.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
			SPECIES_PERK_ICON = "comments",
			SPECIES_PERK_NAME = "Два языка",
			SPECIES_PERK_DESC = "Дворфы понимают и говорят на общем и дворфийском языках.",
		),
	)
	return to_add

#undef DWARF_ALCOHOL_RATE
#undef DWARF_DRUNKNESS_MAX
#undef DWARF_DRUNKNESS_DECAY
#undef DWARF_DRUNKNESS_CRITICAL_MAX
#undef DWARF_DRUNKNESS_DANGER_MIN
#undef DWARF_DRUNKNESS_DANGER_MAX
#undef DWARF_DRUNKNESS_WARNING_MIN
#undef DWARF_DRUNKNESS_WARNING_MAX
#undef DWARF_DRUNKNESS_THIRST_MIN
#undef DWARF_DRUNKNESS_THIRST_MAX
#undef DWARF_DRUNKNESS_ALERT_TIME
#undef DWARF_ALCOHOL_MESSAGE_COOLDOWN
#undef DWARF_MILD_TRAUMA_CHANCE
#undef DWARF_ALCOHOL_TRAUMA_LIMIT
#undef DWARF_DANGER_MESSAGE_CHANCE
#undef DWARF_THIRST_MESSAGE_CHANCE
#undef DWARF_WITHDRAWAL_TOX_DAMAGE
#undef DWARF_WITHDRAWAL_CRITICAL_STAMINA
#undef DWARF_WITHDRAWAL_DANGER_STAMINA
#undef DWARF_WITHDRAWAL_WARNING_STAMINA
// AI EDIT END
