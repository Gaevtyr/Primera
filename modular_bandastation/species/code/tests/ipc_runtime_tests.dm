/// Empty immune holders do no work, but zero-volume entries still end their active effects.
/datum/unit_test/ipc_runtime_chemical_cleanup
	var/holder_updates = 0

/datum/unit_test/ipc_runtime_chemical_cleanup/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	RegisterSignal(ipc.reagents, COMSIG_REAGENTS_HOLDER_UPDATED, PROC_REF(on_holder_updated))
	ipc.reagents.metabolize(ipc, SSMOBS_DT)
	ipc.reagents.handle_stasis_chems(ipc, SSMOBS_DT)
	TEST_ASSERT_EQUAL(holder_updates, 0, "An empty immune holder still emitted chemical change notifications.")

	for(var/entrypoint in list("metabolize", "direct", "stasis"))
		REMOVE_TRAIT(ipc, TRAIT_REAGENT_IMMUNE, SPECIES_TRAIT)
		ipc.reagents.add_reagent(/datum/reagent/medicine/stimulants, 10)
		ipc.reagents.metabolize(ipc, SSMOBS_DT)
		var/datum/reagent/stimulant = ipc.reagents.has_reagent(/datum/reagent/medicine/stimulants)
		TEST_ASSERT(stimulant && HAS_TRAIT(ipc, TRAIT_STIMULATED), "The [entrypoint] fixture did not activate its legacy reagent.")
		TEST_ASSERT(ipc.has_movespeed_modifier(/datum/movespeed_modifier/reagent/stimulants), "The [entrypoint] fixture did not activate its reagent speed modifier.")
		ADD_TRAIT(ipc, TRAIT_REAGENT_IMMUNE, SPECIES_TRAIT)
		// A pending zero-volume entry can still own traits until update_total() ends metabolism.
		stimulant.volume = 0
		ipc.reagents.total_volume = 0
		holder_updates = 0
		switch(entrypoint)
			if("metabolize")
				ipc.reagents.metabolize(ipc, SSMOBS_DT)
			if("direct")
				ipc.reagents.metabolize_reagent(ipc, stimulant, SSMOBS_DT)
			if("stasis")
				ipc.reagents.handle_stasis_chems(ipc, SSMOBS_DT)
		TEST_ASSERT_EQUAL(length(ipc.reagents.reagent_list), 0, "The [entrypoint] path skipped a zero-volume reagent entry.")
		TEST_ASSERT(QDELETED(stimulant), "The [entrypoint] path retained its discarded reagent.")
		TEST_ASSERT(!HAS_TRAIT(ipc, TRAIT_STIMULATED), "The [entrypoint] path skipped the reagent's effect cleanup.")
		TEST_ASSERT(!ipc.has_movespeed_modifier(/datum/movespeed_modifier/reagent/stimulants), "The [entrypoint] path retained a reagent speed modifier.")
		TEST_ASSERT(holder_updates > 0, "The [entrypoint] path did not notify listeners after actual reagent cleanup.")

/datum/unit_test/ipc_runtime_chemical_cleanup/proc/on_holder_updated(datum/reagents/source)
	SIGNAL_HANDLER
	holder_updates += 1

/// Charge-only updates retain the same native states and HUD positioning across health changes.
/datum/unit_test/ipc_runtime_nutrition_hud/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/image/health_bar = ipc.hud_list[DIAG_HUD]
	var/image/status_icon = ipc.hud_list[DIAG_STAT_HUD]
	var/image/battery_bar = ipc.hud_list[DIAG_BATT_HUD]
	TEST_ASSERT(health_bar && status_icon && battery_bar, "The IPC fixture did not initialize its diagnostic HUD.")
	TEST_ASSERT_EQUAL(health_bar.icon_state, "huddiagmax", "A healthy chassis did not show its normal diagnostic bar.")
	TEST_ASSERT_EQUAL(status_icon.icon_state, "hudstat", "An awake chassis did not show its normal diagnostic status.")
	var/original_battery_x = battery_bar.pixel_x
	ipc.set_nutrition(NUTRITION_LEVEL_FULL / 2, forced = TRUE)
	TEST_ASSERT_EQUAL(battery_bar.icon_state, "hudbattmed", "A real nutrition update did not refresh the battery diagnostic.")
	TEST_ASSERT_EQUAL(health_bar.icon_state, "huddiagmax", "A charge update changed a healthy chassis' diagnostic state.")
	TEST_ASSERT_EQUAL(status_icon.icon_state, "hudstat", "A charge update changed an awake chassis' diagnostic status.")
	ipc.readjust_atom_huds()
	TEST_ASSERT_EQUAL(battery_bar.pixel_x, original_battery_x, "A charge update lost the diagnostic bar's persistent horizontal offset.")
	TEST_ASSERT_EQUAL(battery_bar.pixel_w, health_bar.pixel_w, "Charge and health diagnostics lost their common HUD anchor.")
	TEST_ASSERT_EQUAL(battery_bar.pixel_z, health_bar.pixel_z, "Charge and health diagnostics lost their common height adjustment.")

	ipc.adjust_brute_loss(25)
	TEST_ASSERT_EQUAL(health_bar.icon_state, "huddiaghigh", "A real damage update stopped refreshing the chassis diagnostic.")
	TEST_ASSERT_EQUAL(battery_bar.icon_state, "hudbattmed", "A damage update changed the battery diagnostic.")
	ipc.set_stat(HARD_CRIT)
	TEST_ASSERT_EQUAL(status_icon.icon_state, "hudoffline", "An unconscious chassis retained its awake diagnostic status.")
	ipc.set_stat(STABLE)
	TEST_ASSERT_EQUAL(status_icon.icon_state, "hudstat", "An awakened chassis retained its offline diagnostic status.")
	ipc.death()
	TEST_ASSERT_EQUAL(health_bar.icon_state, "huddiagdead", "Death stopped refreshing the chassis diagnostic.")
	TEST_ASSERT_EQUAL(status_icon.icon_state, "huddead2", "Death stopped refreshing the chassis diagnostic status.")
	TEST_ASSERT(ipc.revive(), "The diagnostic fixture could not be revived.")
	TEST_ASSERT_EQUAL(health_bar.icon_state, "huddiaghigh", "Revival did not restore the damaged chassis diagnostic.")
	TEST_ASSERT_EQUAL(status_icon.icon_state, "hudstat", "Revival did not restore the awake chassis diagnostic status.")
	TEST_ASSERT_EQUAL(battery_bar.icon_state, "hudbattmed", "Revival changed the battery diagnostic.")
