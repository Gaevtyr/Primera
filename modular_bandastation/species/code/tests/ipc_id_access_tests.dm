/// A replacement command ID's door access and silo account binding are separate for every species.
/datum/unit_test/ipc_replacement_id_silo_access/Run()
	var/obj/machinery/rnd/production/techfab/department/science/fabricator = allocate(/obj/machinery/rnd/production/techfab/department/science)
	var/obj/machinery/ore_silo/silo = allocate(/obj/machinery/ore_silo)
	silo.ID_required = TRUE
	var/mob/living/carbon/human/technician = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/multitool/multitool = allocate(/obj/item/multitool)
	multitool.set_buffer(silo)
	TEST_ASSERT_EQUAL(fabricator.materials.OnMultitool(fabricator, technician, multitool), ITEM_INTERACT_SUCCESS, "Could not connect the techfab to the restricted silo.")
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock)
	door.req_access = list(ACCESS_RD)

	var/obj/item/card/id/advanced/silver/qm_card = allocate(/obj/item/card/id/advanced/silver)
	TEST_ASSERT(SSid_access.apply_trim_to_card(qm_card, /datum/id_trim/job/quartermaster), "Could not assign the control ID its real quartermaster access.")
	TEST_ASSERT(technician.put_in_active_hand(qm_card), "Could not hold the quartermaster control ID.")
	TEST_ASSERT_NULL(qm_card.registered_account.account_id, "The quartermaster control ID unexpectedly had a personal account.")
	TEST_ASSERT(fabricator.materials.can_use_resource(user_data = ID_DATA(technician)), "Quartermaster access no longer bypassed the silo's personal-account requirement.")

	for(var/species_type in list(/datum/species/human, /datum/species/ipc))
		var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
		user.set_species(species_type)
		var/obj/item/card/id/advanced/silver/card = allocate(/obj/item/card/id/advanced/silver)
		TEST_ASSERT(SSid_access.apply_trim_to_card(card, /datum/id_trim/job/research_director), "Could not assign the replacement silver ID its real command access.")
		card.registered_name = user.real_name
		card.assignment = "И. о. научного руководителя"
		card.update_label()
		TEST_ASSERT(user.put_in_active_hand(card), "Could not hold the replacement command ID.")
		TEST_ASSERT(door.allowed(user), "The replacement command ID did not grant its actual door access to [species_type].")
		TEST_ASSERT_NULL(card.registered_account.account_id, "A blank replacement ID unexpectedly had a personal bank account number.")
		TEST_ASSERT(!fabricator.materials.can_use_resource(user_data = ID_DATA(user)), "A replacement ID without a linked personal account bypassed the silo restriction for [species_type].")

		var/datum/bank_account/account = allocate(/datum/bank_account, user.real_name, SSjob.get_job_type(/datum/job/research_director))
		TEST_ASSERT(isnum(account.account_id), "The fixture did not create a personal bank account.")
		card.set_account(account)
		TEST_ASSERT(fabricator.materials.can_use_resource(user_data = ID_DATA(user)), "A valid personal account on the replacement ID could not use the techfab's silo materials for [species_type].")
		silo.banned_users += account.account_id
		TEST_ASSERT(!fabricator.materials.can_use_resource(user_data = ID_DATA(user)), "Command access bypassed a personal silo ban for [species_type].")
		silo.banned_users -= account.account_id
		card.clear_account()
		TEST_ASSERT(!fabricator.materials.can_use_resource(user_data = ID_DATA(user)), "Unlinking a personal account left techfab material access available for [species_type].")
		TEST_ASSERT(door.allowed(user), "Unlinking a bank account removed the replacement ID's independent door access.")
