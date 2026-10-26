/// All values use the native character savefile and slot lifecycle.
/datum/preference/choiced/sierra_background
	abstract_type = /datum/preference/choiced/sierra_background
	savefile_identifier = PREFERENCE_CHARACTER
	category = "sierra_background"
	priority = PREFERENCE_PRIORITY_NAMES
	can_randomize = FALSE
	should_update_preview = FALSE
	var/background_category
	var/background_label

/datum/preference/choiced/sierra_background/init_possible_values()
	var/list/catalog = get_sierra_background_catalog()
	var/list/entries = catalog[background_category]
	var/list/choices = list()
	for(var/entry in entries)
		choices += entry
	return choices

/datum/preference/choiced/sierra_background/create_default_value()
	return get_sierra_background_default(background_category)

/datum/preference/choiced/sierra_background/create_informed_default_value(datum/preferences/preferences)
	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/value = get_sierra_background_default(background_category, species_type)
	var/list/choices = get_sierra_background_choices(background_category, species_type, preferences.sierra_background_context(background_category))
	return (value in choices) ? value : get_sierra_background_neutral(background_category)

/datum/preference/choiced/sierra_background/deserialize(input, datum/preferences/preferences)
	var/species_type = preferences?.read_preference(/datum/preference/choiced/species) || /datum/species/human
	var/value = normalize_sierra_background_value(background_category, input, species_type)
	if(preferences && !isnull(input) && value != input)
		preferences.recently_updated_keys |= type
	return value

/datum/preference/choiced/sierra_background/is_valid(value, datum/preferences/preferences)
	if(!istext(value))
		return FALSE
	var/species_type = preferences?.read_preference(/datum/preference/choiced/species) || /datum/species/human
	return value in get_sierra_background_choices(background_category, species_type, preferences?.sierra_background_context(background_category))

/datum/preference/choiced/sierra_background/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	// Unresolved historical choices remain in the slot, not as contradictory runtime facts.
	if(is_valid(value, preferences))
		target.dna.features[savefile_key] = value

/datum/preference/choiced/sierra_background/culture
	savefile_key = "sierra_culture"
	background_category = "culture"
	background_label = "Культура / воспитание"

/datum/preference/choiced/sierra_background/culture/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	..()
	target.apply_sierra_background_languages(target.dna.features[savefile_key] || "other")

/datum/preference/choiced/sierra_background/homeworld
	savefile_key = "sierra_homeworld"
	background_category = "homeworld"
	background_label = "Место жительства"

/datum/preference/choiced/sierra_background/faction
	savefile_key = "sierra_faction"
	background_category = "faction"
	background_label = "Фракция / текущая принадлежность"

/datum/preference/choiced/sierra_background/faction/deserialize(input, datum/preferences/preferences)
	var/list/dependencies = get_sierra_background_dependencies()
	var/list/rules = dependencies["factions"]
	var/list/rule = istext(input) ? rules[input] : null
	if(preferences && rule?["parent"] && !rule["private"])
		var/list/save_data = preferences.get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER)
		if(isnull(save_data?["sierra_subfaction"]))
			preferences.value_cache[/datum/preference/choiced/sierra_background/subfaction] = input
			preferences.recently_updated_keys |= /datum/preference/choiced/sierra_background/subfaction
		preferences.recently_updated_keys |= type
		return rule["parent"]
	return ..()

/datum/preference/choiced/sierra_background/subfaction
	savefile_key = "sierra_subfaction"
	background_category = "subfaction"
	background_label = "Подразделение / подфракция"

/datum/preference/choiced/sierra_background/religion
	savefile_key = "sierra_religion"
	background_category = "religion"
	background_label = "Вера"

/datum/preference/choiced/sierra_background/social
	savefile_key = "sierra_social"
	background_category = "social"
	background_label = "Социальная принадлежность"

/datum/preference/choiced/sierra_background/social/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	if(get_sierra_social_kind(target.dna.species.type) && !ispath(target.dna.species.type, /datum/species/skrell))
		return ..()

/// Only read earlier dependencies: faction -> residence -> social -> culture; faith has no parents.
/datum/preferences/proc/sierra_background_context(category)
	var/list/context = list()
	if(category in list("faction", "religion"))
		return context
	context["faction"] = read_preference(/datum/preference/choiced/sierra_background/faction)
	if(category in list("subfaction", "homeworld"))
		return context
	context["homeworld"] = read_preference(/datum/preference/choiced/sierra_background/homeworld)
	if(category == "culture")
		var/species_type = read_preference(/datum/preference/choiced/species)
		context["social"] = ispath(species_type, /datum/species/skrell) ? read_preference(/datum/preference/choiced/skrell_caste) : read_preference(/datum/preference/choiced/sierra_background/social)
	return context

/// Explicit edits reset only incompatible descendants. Passive reads never rewrite old biographies.
/datum/preferences/proc/sanitize_sierra_background(changed_preference)
	var/list/dependent_categories = list()
	switch(changed_preference)
		if("species")
			dependent_categories = list("faction", "subfaction", "homeworld", "social", "culture")
		if("sierra_faction")
			dependent_categories = list("subfaction", "homeworld", "social", "culture")
		if("sierra_homeworld")
			dependent_categories = list("social", "culture")
		if("sierra_subfaction", "sierra_social", "skrell_caste")
			dependent_categories = list("culture")
	var/list/preference_types = list(
		"faction" = /datum/preference/choiced/sierra_background/faction,
		"subfaction" = /datum/preference/choiced/sierra_background/subfaction,
		"homeworld" = /datum/preference/choiced/sierra_background/homeworld,
		"social" = /datum/preference/choiced/sierra_background/social,
		"culture" = /datum/preference/choiced/sierra_background/culture,
	)
	for(var/category in dependent_categories)
		var/preference_type = preference_types[category]
		var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_type]
		var/value = read_preference(preference_type)
		if(!preference.is_valid(value, src))
			var/neutral_value = get_sierra_background_neutral(preference.background_category)
			if(preference.is_valid(neutral_value, src))
				value_cache[preference_type] = neutral_value
				recently_updated_keys |= preference_type

/// Revalidate before native serialization, including direct updates outside the UI action.
/datum/preferences/proc/validate_sierra_background_for_save()
	var/valid = TRUE
	for(var/preference_type in subtypesof(/datum/preference/choiced/sierra_background))
		var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_type]
		if(!preference.is_valid(read_preference(preference_type), src))
			// Do not serialize an invalid edit or overwrite a historical value still on disk.
			recently_updated_keys -= preference_type
			valid = FALSE
	return valid

/datum/preference_middleware/sierra_background

/datum/preference_middleware/sierra_background/get_constant_data()
	var/list/catalog = get_sierra_background_catalog()
	var/list/ui_catalog = list()
	for(var/category in catalog)
		var/list/entries = catalog[category]
		var/list/ui_entries = list()
		for(var/id in entries)
			var/list/entry = entries[id]
			ui_entries[id] = list("name" = entry["name"], "description" = entry["description"], "extra" = entry["extra"])
		ui_catalog[category] = ui_entries
	return ui_catalog

/datum/preference_middleware/sierra_background/pre_set_preference(mob/user, preference, value)
	if(preference == "skrell_caste")
		var/datum/preference/choiced/caste = GLOB.preference_entries[/datum/preference/choiced/skrell_caste]
		return !caste.is_accessible(preferences) || !caste.is_valid(value, preferences)
	var/datum/preference/choiced/sierra_background/entry = GLOB.preference_entries_by_key[preference]
	if(!istype(entry))
		return FALSE
	return !entry.is_valid(value, preferences)

/datum/preference_middleware/sierra_background/post_set_preference(mob/user, preference, value)
	preferences.sanitize_sierra_background(preference)

/datum/preference_middleware/sierra_background/get_ui_data(mob/user)
	var/list/rows = list()
	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/list/catalog = get_sierra_background_catalog()
	var/list/preference_types = list(
		/datum/preference/choiced/sierra_background/faction,
		/datum/preference/choiced/sierra_background/subfaction,
		/datum/preference/choiced/sierra_background/homeworld,
		/datum/preference/choiced/sierra_background/social,
		/datum/preference/choiced/sierra_background/culture,
		/datum/preference/choiced/sierra_background/religion,
	)
	for(var/preference_type in preference_types)
		var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_type]
		var/category = preference.background_category
		var/list/choices = get_sierra_background_choices(category, species_type, preferences.sierra_background_context(category))
		if(category == "social")
			var/list/social_kind = get_sierra_social_kind(species_type)
			if(!social_kind)
				continue
			if(ispath(species_type, /datum/species/skrell))
				var/value = preferences.read_preference(/datum/preference/choiced/skrell_caste)
				rows += list(list("category" = "social", "preference" = "skrell_caste", "label" = social_kind["label"], "value" = value, "choices" = choices, "selected_name" = catalog["social"][value]?["name"]))
				continue
		var/value = preferences.read_preference(preference_type)
		var/list/entries = catalog[category]
		var/list/row = list("category" = category, "preference" = preference.savefile_key, "label" = preference.background_label, "value" = value, "choices" = choices, "selected_name" = entries[value]?["name"] || value)
		if(category == "social")
			var/list/social_kind = get_sierra_social_kind(species_type)
			row["label"] = social_kind["label"]
		if(!(value in choices))
			row["invalid_reason"] = "Сохранённый вариант больше недоступен для этой анкеты. Он сохранён для справки; выберите допустимый вариант. Личные подробности остаются без изменений."
		var/datum/preference/text/sierra_background_notes/notes_preference = GLOB.preference_entries_by_key["[preference.savefile_key]_notes"]
		if(notes_preference)
			row["notes"] = preferences.read_preference(notes_preference.type)
			row["notes_preference"] = notes_preference.savefile_key
			row["notes_max_length"] = notes_preference.maximum_value_length - 1
			row["notes_prompt"] = notes_preference.notes_prompt
		if(category == "culture")
			row["language_names"] = (value in choices) ? get_sierra_background_language_names(value) : list()
			row["name_generation"] = get_sierra_background_name_generation_label(preferences)
		rows += list(row)
	return list("sierra_background" = rows)
