/// The roboticist's ordinary screwdriver, crowbar and multitool must customize a printed generic arm.
/datum/unit_test/ipc_customization_surgery/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_species(/datum/species/ipc)
	patient.set_resting(TRUE)
	ADD_TRAIT(patient, TRAIT_READY_TO_OPERATE, TRAIT_SOURCE_UNIT_TESTS)
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	var/obj/item/multitool/multitool = allocate(/obj/item/multitool)
	var/datum/design/arm_design = SSresearch.techweb_designs[/datum/design/borg_l_arm]
	var/obj/item/bodypart/arm/left/robot/arm = arm_design.create_result(patient.loc)
	allocated += arm
	allocated += patient.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT_EQUAL(arm.type, /obj/item/bodypart/arm/left/robot, "The customization fixture did not use robotics' ordinary printed arm.")
	TEST_ASSERT(arm.replace_limb(patient), "Could not attach the printed robotic arm.")
	ADD_TRAIT(arm, TRAIT_READY_TO_OPERATE, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/organ/cyberimp/arm/toolkit/toolset/implant = allocate(/obj/item/organ/cyberimp/arm/toolkit/toolset)
	implant.swap_zone(BODY_ZONE_L_ARM)
	TEST_ASSERT(implant.Insert(patient, special = TRUE), "Could not install the arm's existing toolkit.")
	arm.receive_damage(brute = 7, burn = 9, wound_bonus = CANT_WOUND)
	var/initial_brute = arm.brute_dam
	var/initial_burn = arm.burn_dam
	var/list/initial_materials = arm.custom_materials.Copy()
	var/obj/item/bodypart/other_arm = patient.get_bodypart(BODY_ZONE_R_ARM)
	var/other_icon = other_arm.icon
	var/list/initial_features = patient.dna.features.Copy()
	var/datum/surgery_operation/limb/ipc_customization/customization = GLOB.operations.operations_by_typepath[__IMPLIED_TYPE__]
	var/model = /datum/ipc_chassis/bishop::name
	var/datum/ipc_chassis/expected_chassis = GLOB.ipc_chassis[model]
	TEST_ASSERT(!customization.check_availability(patient, arm, surgeon, multitool, BODY_ZONE_L_ARM), "A closed robotic casing offered appearance customization.")
	TEST_ASSERT(perform_step(/datum/surgery_operation/limb/mechanical_incision, patient, surgeon, screwdriver, BODY_ZONE_L_ARM), "Could not unscrew the printed arm's casing.")
	TEST_ASSERT(perform_step(/datum/surgery_operation/limb/mechanical_open, patient, surgeon, crowbar, BODY_ZONE_L_ARM), "Could not open the printed arm's casing with a crowbar.")
	TEST_ASSERT(!customization.check_availability(patient, arm, surgeon, screwdriver, BODY_ZONE_L_ARM), "A screwdriver could reprogram a robotic casing.")
	TEST_ASSERT(!perform_step(customization.type, patient, surgeon, multitool, BODY_ZONE_L_ARM, "invalid model"), "An unknown casing model was accepted.")
	TEST_ASSERT(!perform_step(customization.type, patient, surgeon, multitool, BODY_ZONE_L_ARM, /datum/ipc_chassis/bishop_alt1::name), "A head-only model was accepted for a robotic arm.")
	TEST_ASSERT(perform_step(customization.type, patient, surgeon, multitool, BODY_ZONE_L_ARM, model), "The native multitool operation could not customize a printed robotic arm.")
	TEST_ASSERT_EQUAL(arm.icon, expected_chassis.icon, "The selected arm did not receive its requested casing.")
	TEST_ASSERT_EQUAL(other_arm.icon, other_icon, "Customizing one arm changed the other arm.")
	TEST_ASSERT_EQUAL(arm.brute_dam, initial_brute, "Cosmetic customization repaired or damaged the arm's structure.")
	TEST_ASSERT_EQUAL(arm.burn_dam, initial_burn, "Cosmetic customization repaired or damaged the arm's circuitry.")
	TEST_ASSERT_EQUAL(implant.owner, patient, "Cosmetic customization removed the arm's toolkit.")
	TEST_ASSERT_EQUAL(implant.bodypart_owner, arm, "Cosmetic customization replaced the physical arm containing its toolkit.")
	for(var/material in initial_materials)
		TEST_ASSERT_EQUAL(arm.custom_materials[material], initial_materials[material], "Cosmetic customization changed a printed arm's material value.")
	for(var/feature in initial_features)
		TEST_ASSERT_EQUAL(patient.dna.features[feature], initial_features[feature], "A one-limb cosmetic operation rewrote the patient's shared appearance preferences.")
	TEST_ASSERT(perform_step(/datum/surgery_operation/limb/mechanical_close, patient, surgeon, screwdriver, BODY_ZONE_L_ARM), "Could not close the customized arm's casing.")
	TEST_ASSERT(!customization.check_availability(patient, arm, surgeon, multitool, BODY_ZONE_L_ARM), "Closing the casing left appearance customization available.")
	var/obj/item/bodypart/organic_arm = allocate(/obj/item/bodypart/arm/left)
	organic_arm.add_surgical_state(SURGERY_SKIN_OPEN)
	TEST_ASSERT(!customization.check_availability(null, organic_arm, surgeon, multitool, BODY_ZONE_L_ARM), "An organic arm offered cybernetic casing customization.")

/// Execute the real operation with the selected tool and model, without replacing the surgical delay.
/datum/unit_test/ipc_customization_surgery/proc/perform_step(operation_path, atom/movable/patient, mob/living/carbon/human/surgeon, obj/item/tool, zone, model = "default")
	var/datum/surgery_operation/operation = GLOB.operations.operations_by_typepath[operation_path]
	var/atom/movable/operating_on = operation.get_operation_target(patient, zone)
	if(!operating_on)
		return FALSE
	var/obj/item/held = surgeon.get_active_held_item()
	if(held && held != tool)
		surgeon.dropItemToGround(held)
	if(surgeon.get_active_held_item() != tool && !surgeon.put_in_active_hand(tool))
		return FALSE
	return operation.try_perform(operating_on, surgeon, tool, list(OPERATION_TARGET_ZONE = zone, OPERATION_ACTION = model)) == ITEM_INTERACT_SUCCESS

/// A limb moved to another patient during the multitool delay must not inherit the stale operation.
/datum/unit_test/ipc_customization_surgery/interrupted/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_species(/datum/species/ipc)
	patient.set_resting(TRUE)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	recipient.set_species(/datum/species/ipc)
	recipient.set_resting(TRUE)
	allocated += recipient.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/arm = patient.get_bodypart(BODY_ZONE_L_ARM)
	allocated += arm
	arm.add_surgical_state(SURGERY_SKIN_OPEN)
	var/original_override = arm.ipc_chassis_override
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent/slow)
	var/obj/item/multitool/multitool = allocate(/obj/item/multitool)
	var/datum/surgery_operation/limb/ipc_customization/customization = GLOB.operations.operations_by_typepath[__IMPLIED_TYPE__]
	TEST_ASSERT_EQUAL(customization.try_perform(arm, surgeon, multitool, list(OPERATION_TARGET_ZONE = BODY_ZONE_L_ARM, OPERATION_ACTION = /datum/ipc_chassis/bishop::name)), ITEM_INTERACT_BLOCKING, "A multitool outside the surgeon's hands completed casing customization.")
	addtimer(CALLBACK(src, PROC_REF(transfer_limb), arm, recipient), 1 SECONDS)
	TEST_ASSERT(!perform_step(/datum/surgery_operation/limb/ipc_customization, patient, surgeon, multitool, BODY_ZONE_L_ARM, /datum/ipc_chassis/bishop::name), "A transferred limb completed its original patient's cosmetic operation.")
	TEST_ASSERT_EQUAL(arm.owner, recipient, "The interruption fixture did not move the limb to its new patient.")
	TEST_ASSERT_EQUAL(arm.ipc_chassis_override, original_override, "The old patient's operation changed a limb after transplantation.")

/datum/unit_test/ipc_customization_surgery/interrupted/proc/transfer_limb(obj/item/bodypart/limb, mob/living/carbon/human/recipient)
	limb.drop_limb(special = TRUE)
	limb.replace_limb(recipient)
