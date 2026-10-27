/// Medals use the same award prompt and delay on a bare chassis as on a uniform.
/datum/component/pinnable_accessory/ipc_medal/can_pin_to(mob/living/carbon/human/pinning_on, mob/pinner, feedback = FALSE)
	if(pinning_on.w_uniform || !is_species(pinning_on, /datum/species/ipc))
		return ..()
	var/obj/item/bodypart/chest = pinning_on.get_bodypart(BODY_ZONE_CHEST)
	var/datum/component/ipc_medals/mount = pinning_on.GetComponent(/datum/component/ipc_medals)
	if(!chest || !IS_ROBOTIC_LIMB(chest) || length(mount?.medals) >= /obj/item/clothing/under::max_number_of_accessories)
		if(feedback)
			pinning_on.balloon_alert(pinner, "нет места для медали!")
		return FALSE
	return TRUE

/datum/component/pinnable_accessory/ipc_medal/attach_to_target(obj/item/clothing/accessory/badge, mob/living/carbon/human/distinguished, mob/user)
	if(distinguished.w_uniform || !is_species(distinguished, /datum/species/ipc))
		return ..()
	if(!can_pin_to(distinguished, user))
		return FALSE
	var/datum/component/ipc_medals/mount = distinguished.LoadComponent(/datum/component/ipc_medals)
	return mount.attach_medal(badge, user)

/// Owns the physical medals on one chassis; no clothing or equipment slot is fabricated.
/datum/component/ipc_medals
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/obj/item/bodypart/chest
	var/list/medals = list()
	var/datum/bodypart_overlay/simple/ipc_medal/medal_overlay

/datum/component/ipc_medals/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/carbon/human/human = parent
	chest = human.get_bodypart(BODY_ZONE_CHEST)
	if(!is_species(human, /datum/species/ipc) || !chest || !IS_ROBOTIC_LIMB(chest))
		return COMPONENT_INCOMPATIBLE

/datum/component/ipc_medals/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
	RegisterSignal(parent, COMSIG_TOPIC, PROC_REF(on_topic))
	RegisterSignals(parent, list(COMSIG_SPECIES_LOSS, COMSIG_QDELETING), PROC_REF(drop_medals))
	RegisterSignals(chest, list(COMSIG_BODYPART_CHANGED_OWNER, COMSIG_QDELETING), PROC_REF(drop_medals))
	RegisterSignal(chest, COMSIG_ATOM_EXITED, PROC_REF(on_medal_exited))

/datum/component/ipc_medals/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_EXAMINE, COMSIG_TOPIC, COMSIG_SPECIES_LOSS, COMSIG_QDELETING))
	UnregisterSignal(chest, list(COMSIG_BODYPART_CHANGED_OWNER, COMSIG_QDELETING, COMSIG_ATOM_EXITED))

/datum/component/ipc_medals/Destroy(force)
	. = ..()
	if(medal_overlay)
		chest.remove_bodypart_overlay(medal_overlay, update = !QDELETED(chest) && !QDELETED(chest.owner))
		QDEL_NULL(medal_overlay)
	for(var/obj/item/clothing/accessory/medal/medal as anything in medals)
		if(!QDELETED(medal) && medal.loc == chest)
			medal.forceMove(chest.drop_location())
	medals = null
	chest = null

/datum/component/ipc_medals/proc/attach_medal(obj/item/clothing/accessory/medal/medal, mob/living/pinner)
	var/mob/living/carbon/human/human = parent
	if(QDELETED(medal) || QDELETED(pinner) || !istype(medal) || human.w_uniform || !is_species(human, /datum/species/ipc))
		return FALSE
	if(chest.owner != human || length(medals) >= /obj/item/clothing/under::max_number_of_accessories)
		return FALSE
	if(!pinner.is_holding(medal) || !pinner.Adjacent(human) || !pinner.temporarilyRemoveItemFromInventory(medal))
		return FALSE
	medals += medal
	medal.forceMove(chest)
	update_medal_overlay()
	medal.record_commendation(human, pinner)
	return TRUE

/datum/component/ipc_medals/proc/update_medal_overlay()
	if(medal_overlay)
		chest.remove_bodypart_overlay(medal_overlay, update = FALSE)
		QDEL_NULL(medal_overlay)
	// As on uniforms, the first accessory is visible; every medal is listed on examine.
	if(length(medals))
		var/obj/item/clothing/accessory/medal/medal = medals[1]
		medal_overlay = new
		medal_overlay.icon = medal.worn_icon
		medal_overlay.icon_state = medal.icon_state_is_worn ? medal.icon_state : medal.worn_icon_state
		medal_overlay.draw_color = medal.color
		chest.add_bodypart_overlay(medal_overlay)
	else
		chest.owner?.update_body_parts()

/datum/component/ipc_medals/proc/on_medal_exited(datum/source, atom/movable/gone)
	SIGNAL_HANDLER
	if(!(gone in medals))
		return
	medals -= gone
	update_medal_overlay()

/datum/component/ipc_medals/proc/drop_medals(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/component/ipc_medals/proc/on_examine(atom/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	for(var/obj/item/clothing/accessory/medal/medal as anything in medals)
		examine_list += span_notice("На корпусе закреплена [medal.declent_ru(NOMINATIVE)]. <a href='byond://?src=[REF(source)];ipc_medal=[REF(medal)]'>Снять медаль.</a>")

/datum/component/ipc_medals/proc/on_topic(atom/source, mob/user, list/href_list)
	SIGNAL_HANDLER
	if(!href_list["ipc_medal"])
		return
	var/obj/item/clothing/accessory/medal/medal = locate(href_list["ipc_medal"]) in medals
	if(medal)
		INVOKE_ASYNC(src, PROC_REF(remove_medal), medal, user)

/datum/component/ipc_medals/proc/can_remove(obj/item/clothing/accessory/medal/medal, mob/living/user)
	if(QDELETED(src) || QDELETED(user) || QDELETED(medal) || !(medal in medals) || medal.loc != chest || chest.owner != parent)
		return FALSE
	if(!user.Adjacent(parent) || !user.can_perform_action(parent, NEED_DEXTERITY | NEED_HANDS) || HAS_TRAIT(medal, TRAIT_NO_STRIP) || !medal.canStrip(user, parent))
		return FALSE
	return !(SEND_SIGNAL(user, COMSIG_TRY_STRIP, parent, medal) & COMPONENT_CANT_STRIP) && !(SEND_SIGNAL(parent, COMSIG_BEING_STRIPPED, user, medal) & COMPONENT_CANT_STRIP)

/datum/component/ipc_medals/proc/remove_medal(obj/item/clothing/accessory/medal/medal, mob/living/user)
	if(!can_remove(medal, user))
		return FALSE
	var/mob/living/carbon/human/human = parent
	human.visible_message(span_notice("[user] начинает снимать [medal.declent_ru(ACCUSATIVE)] с корпуса [human.declent_ru(GENITIVE)]."))
	if(!do_after(user, medal.strip_delay, human, extra_checks = CALLBACK(src, PROC_REF(can_remove), medal, user)) || !can_remove(medal, user))
		return FALSE
	user.log_message("removed [medal] from [key_name(human)]'s chassis.", LOG_ATTACK)
	medal.add_fingerprint(user)
	medal.forceMove(human.drop_location())
	user.put_in_hands(medal)
	return TRUE

/// The ordinary medal sprite stays above a captain's mantle without occupying its neck slot.
/datum/bodypart_overlay/simple/ipc_medal
	layers = list("" = BODY_FRONT_LAYER)
	overlay_flags = NONE
	blocks_emissive = EMISSIVE_BLOCK_NONE
	offset_location = UPPER_BODY

/datum/bodypart_overlay/simple/ipc_medal/icon_render_key(obj/item/bodypart/limb)
	. = ..()
	. += icon
	. += draw_color
