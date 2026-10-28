/// A species profile owns the heading, native save key and optionality together.
/datum/unit_test/sierra_background_social_catalog

/datum/unit_test/sierra_background_social_catalog/Run()
	var/list/data = get_sierra_social_data()
	var/list/kinds = data["species"]
	var/list/catalog = get_sierra_social_catalog()
	for(var/species_id in kinds)
		var/list/kind = kinds[species_id]
		var/species_type = GLOB.species_list[species_id]
		TEST_ASSERT(species_type, "Social profile [species_id] has no native species.")
		TEST_ASSERT(length(kind["label"]), "Social profile [species_id] has no heading.")
		var/datum/preference/preference = GLOB.preference_entries_by_key[kind["preference"]]
		TEST_ASSERT(preference, "Social profile [species_id] has no native save key.")
		TEST_ASSERT(preference.savefile_identifier == PREFERENCE_CHARACTER, "Social membership escaped character-slot storage.")
		var/list/choices = get_sierra_background_choices("social", species_type)
		TEST_ASSERT_EQUAL(("none" in choices), kind["can_omit"], "Social optionality disagrees with its species profile.")
		for(var/choice in choices)
			var/list/entry = catalog[choice]
			TEST_ASSERT(length(entry?["name"]), "Social choice [choice] has no readable name.")
			TEST_ASSERT(length(entry?["description"]), "Social choice [choice] has no description.")
			TEST_ASSERT(sierra_background_matches_species(entry, species_id), "Social choice [choice] belongs to another species.")
	var/list/vulp_choices = get_sierra_background_choices("social", /datum/species/vulpkanin)
	for(var/choice in list("vulp_ashtar", "vulp_rakh", "vulp_mzmanulin", "vulp_refugee", "none"))
		TEST_ASSERT(choice in vulp_choices, "Author-approved Vulpkanin membership [choice] is missing.")
	TEST_ASSERT_EQUAL(length(vulp_choices), 5, "Vulpkanin membership contains duplicate or unconfirmed options.")
	TEST_ASSERT_EQUAL(catalog["vulp_rakh"]["name"], "Рахт", "The clan name does not match the approved spelling.")
	TEST_ASSERT_EQUAL(length(get_sierra_background_choices("social", /datum/species/skrell)), 5, "Genetic Skrell castes changed during the social audit.")

/// Exercise the actual middleware after each native species change, including hidden fields.
/datum/unit_test/sierra_background_social_species_changes
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_social_species_changes/Run()
	var/datum/preferences/preferences = make_preferences()
	for(var/species_id in GLOB.species_list)
		var/species_type = GLOB.species_list[species_id]
		TEST_ASSERT(edit_background(preferences, /datum/preference/choiced/species, species_id), "Could not switch to native species [species_id].")
		var/list/kind = get_sierra_social_kind(species_type)
		var/list/row = background_row(preferences, "social")
		if(!kind)
			TEST_ASSERT_NULL(row, "[species_id] inherited another species' social field.")
			continue
		TEST_ASSERT(row, "[species_id] lost its social field after a species change.")
		TEST_ASSERT_EQUAL(row["label"], kind["label"], "Social heading is stale after selecting [species_id].")
		TEST_ASSERT_EQUAL(row["preference"], kind["preference"], "Social membership uses a stale save key for [species_id].")
		var/datum/preference/preference = GLOB.preference_entries_by_key[row["preference"]]
		TEST_ASSERT(preference.is_accessible(preferences), "The displayed social field is inaccessible for [species_id].")
		var/list/choices = row["choices"]
		for(var/choice in choices)
			TEST_ASSERT(preference.is_valid(choice, preferences), "The server rejects a displayed social choice for [species_id].")
		for(var/choice in list("vulp_rakh", "vulp_mzmanulin", "vulp_refugee"))
			TEST_ASSERT_EQUAL((choice in choices), species_id == "vulpkanin", "Vulpkanin membership [choice] crossed species boundaries.")
