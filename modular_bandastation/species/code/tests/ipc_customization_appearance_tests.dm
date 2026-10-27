/// A selected shell changes the real icon cache and follows only its physical limb.
/datum/unit_test/ipc_customization_persistent_shell/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	ipc.dna.features[FEATURE_IPC_CHASSIS] = /datum/ipc_chassis/morpheus::name
	ipc.update_body_parts(update_limb_data = TRUE)
	var/obj/item/bodypart/arm = ipc.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/other_arm = ipc.get_bodypart(BODY_ZONE_R_ARM)
	var/original_key = arm.get_cache_key()
	var/other_key = other_arm.get_cache_key()
	var/datum/ipc_chassis/bishop/model = GLOB.ipc_chassis[/datum/ipc_chassis/bishop::name]
	TEST_ASSERT(arm.set_ipc_chassis(model.name), "A native IPC arm rejected a compatible shell.")
	TEST_ASSERT_NOTEQUAL(arm.get_cache_key(), original_key, "Different IPC models collided in the limb icon cache.")
	TEST_ASSERT_EQUAL(ipc.icon_render_keys[BODY_ZONE_L_ARM], arm.get_cache_key(), "Customization left the old arm cache entry displayed.")
	var/list/images = ipc.limb_icon_cache[arm.get_cache_key()]
	var/list/states = list()
	for(var/image/limb_image as anything in images)
		if(limb_image.icon == model.icon)
			states += limb_image.icon_state
	TEST_ASSERT(("ipc_l_arm" in states) && ("ipc_l_hand" in states), "The cache did not contain the selected model's arm and hand.")
	ipc.update_body_parts(update_limb_data = TRUE)
	TEST_ASSERT(ipc_customization_has_shell(arm, model.icon), "A forced appearance update reset the chosen shell.")
	TEST_ASSERT_EQUAL(other_arm.get_cache_key(), other_key, "Customizing the left arm changed the right arm.")
	TEST_ASSERT_EQUAL(ipc.dna.features[FEATURE_IPC_CHASSIS], /datum/ipc_chassis/morpheus::name, "A physical shell rewrote the wearer's body preference.")
	allocated += arm
	arm.drop_limb(special = TRUE)
	TEST_ASSERT(ipc_customization_has_shell(arm, model.icon), "Detaching the customized arm reset its shell.")
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	recipient.set_species(/datum/species/ipc)
	recipient.dna.features[FEATURE_IPC_CHASSIS] = /datum/ipc_chassis/hephaestus::name
	allocated += recipient.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(arm.replace_limb(recipient), "The customized arm could not be transplanted.")
	recipient.update_body_parts(update_limb_data = TRUE)
	TEST_ASSERT_EQUAL(arm.owner, recipient, "The transplanted arm retained its old owner.")
	TEST_ASSERT(ipc_customization_has_shell(arm, model.icon), "The recipient's preferences replaced the transplanted shell.")
	TEST_ASSERT_EQUAL(arm.ipc_chassis_override, model.name, "Transplantation lost the selected manufacturer.")

/// An ordinary printed prosthesis keeps its hardware and mechanics while using IPC arm and hand sprites.
/datum/unit_test/ipc_customization_printed_arm_appearance/Run()
	var/datum/design/design = SSresearch.techweb_designs[/datum/design/borg_l_arm]
	var/obj/item/bodypart/arm/left/robot/arm = design.create_result(run_loc_floor_bottom_left)
	allocated += arm
	TEST_ASSERT_EQUAL(arm.type, /obj/item/bodypart/arm/left/robot, "The fixture did not use the ordinary robotics arm.")
	var/obj/item/organ/cyberimp/arm/toolkit/toolset/implant = allocate(/obj/item/organ/cyberimp/arm/toolkit/toolset)
	implant.swap_zone(BODY_ZONE_L_ARM)
	implant.bodypart_insert(arm)
	arm.receive_damage(brute = 7, burn = 9, wound_bonus = CANT_WOUND)
	var/initial_brute = arm.brute_dam
	var/initial_burn = arm.burn_dam
	var/initial_max_damage = arm.max_damage
	var/list/materials = arm.custom_materials.Copy()
	TEST_ASSERT(arm.set_ipc_chassis(/datum/ipc_chassis/bishop::name), "An ordinary robotic arm rejected IPC customization.")
	var/first_key = arm.get_cache_key()
	TEST_ASSERT(arm.set_ipc_chassis(/datum/ipc_chassis/hephaestus::name), "A customized prosthesis could not select another manufacturer.")
	TEST_ASSERT_NOTEQUAL(arm.get_cache_key(), first_key, "Generic prosthesis manufacturers shared an icon cache key.")
	TEST_ASSERT_EQUAL(arm.type, /obj/item/bodypart/arm/left/robot, "Cosmetic customization replaced the physical prosthesis.")
	TEST_ASSERT_EQUAL(arm.bodytype, BODYTYPE_ROBOTIC, "Customization changed the prosthesis' body type.")
	TEST_ASSERT_EQUAL(arm.brute_modifier, initial(arm.brute_modifier), "Customization changed structural damage resistance.")
	TEST_ASSERT_EQUAL(arm.burn_modifier, initial(arm.burn_modifier), "Customization changed circuitry damage resistance.")
	TEST_ASSERT_EQUAL(arm.max_damage, initial_max_damage, "Customization changed the prosthesis' health limit.")
	TEST_ASSERT_EQUAL(arm.brute_dam, initial_brute, "Customization changed existing structural damage.")
	TEST_ASSERT_EQUAL(arm.burn_dam, initial_burn, "Customization changed existing circuitry damage.")
	TEST_ASSERT_EQUAL(implant.bodypart_owner, arm, "Customization disconnected the installed toolkit.")
	TEST_ASSERT_EQUAL(implant.loc, arm, "Customization removed hardware from the physical arm.")
	for(var/material in materials)
		TEST_ASSERT_EQUAL(arm.custom_materials[material], materials[material], "Customization changed the prosthesis' material value.")
	var/datum/ipc_chassis/model = GLOB.ipc_chassis[/datum/ipc_chassis/hephaestus::name]
	var/list/states = list()
	for(var/image/limb_image as anything in arm.get_limb_icon(dropped = TRUE))
		if(limb_image.icon == model.icon)
			states += limb_image.icon_state
	TEST_ASSERT(("ipc_l_arm" in states) && ("ipc_l_hand" in states), "The customized prosthesis did not render IPC arm and hand sprites.")

/// Head models sanitize incompatible displays while preserving the physical head's accessories and colors.
/datum/unit_test/ipc_customization_head_appearance/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/obj/item/bodypart/head/robot/ipc/head = ipc.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(head.set_ipc_chassis(/datum/ipc_chassis/morpheus::name), "The head fixture could not select a monitor model.")
	head.ipc_display_name = /datum/sprite_accessory/ipc_display/ipc_screen_blue::name
	head.ipc_display_color = "#123456"
	head.ipc_display_color_secondary = "#abcdef"
	head.ipc_antenna_name = /datum/sprite_accessory/ipc_antenna/ipc_horns::name
	head.ipc_antenna_color = "#654321"
	var/datum/ipc_chassis/model = GLOB.ipc_chassis[/datum/ipc_chassis/bishop::name]
	TEST_ASSERT(head.set_ipc_chassis(model.name), "A monitor head could not select its compatible non-monitor shell.")
	TEST_ASSERT_NOTEQUAL(head.ipc_display_name, /datum/sprite_accessory/ipc_display/ipc_screen_blue::name, "A non-monitor head retained its incompatible monitor screen.")
	TEST_ASSERT(head.ipc_display_name in get_ipc_display_choices(model.name), "The replacement head selected an unsupported display.")
	ipc.update_body_parts(update_limb_data = TRUE)
	TEST_ASSERT(ipc_customization_has_shell(head, model.icon), "A forced refresh reset the selected head model.")
	TEST_ASSERT_EQUAL(head.ipc_head_name, model.name, "A forced refresh reset the head's physical manufacturer.")
	TEST_ASSERT_EQUAL(head.ipc_display_color, "#123456", "Changing head models rewrote the display's primary color.")
	TEST_ASSERT_EQUAL(head.ipc_display_color_secondary, "#abcdef", "Changing head models rewrote the display's secondary color.")
	TEST_ASSERT_EQUAL(head.ipc_antenna_name, /datum/sprite_accessory/ipc_antenna/ipc_horns::name, "Changing head models replaced the physical antenna.")
	TEST_ASSERT_EQUAL(head.ipc_antenna_color, "#654321", "Changing head models rewrote the antenna's color.")
	TEST_ASSERT(!head.set_ipc_chassis(/datum/ipc_chassis/cybersun_cybersun_redheavy::name), "A body-only model was accepted for a head.")
	TEST_ASSERT(ipc_customization_has_shell(head, model.icon), "Rejecting a body-only model changed the head's shell.")
	var/obj/item/bodypart/head/robot/generic_head = allocate(/obj/item/bodypart/head/robot)
	TEST_ASSERT(!generic_head.set_ipc_chassis(model.name), "A generic robotic head accepted unsupported IPC head customization.")

/// Observe the rendered shell without reaching into the bodypart's protected icon configuration.
/datum/unit_test/proc/ipc_customization_has_shell(obj/item/bodypart/limb, expected_icon)
	for(var/image/limb_image as anything in limb.get_limb_icon(dropped = isnull(limb.owner)))
		if(limb_image.icon == expected_icon && limb_image.icon_state == "[SPECIES_IPC]_[limb.body_zone]")
			return TRUE
	return FALSE
