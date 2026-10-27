/// This accessory can be pinned onto someone else
/datum/component/pinnable_accessory
	/// Do we let people know what we're doing?
	var/silent
	/// How long does it take to pin this onto someone?
	var/pinning_time
	/// Optional callback invoked before pinning, will cancel if it returns FALSE
	var/datum/callback/on_pre_pin

/datum/component/pinnable_accessory/Initialize(silent = FALSE, pinning_time = 2 SECONDS, datum/callback/on_pre_pin = null)
	. = ..()
	if (!istype(parent, /obj/item/clothing/accessory))
		return COMPONENT_INCOMPATIBLE
	src.silent = silent
	src.pinning_time = pinning_time
	src.on_pre_pin = on_pre_pin

/datum/component/pinnable_accessory/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ITEM_INTERACTING_WITH_ATOM, PROC_REF(on_atom_interact))

/datum/component/pinnable_accessory/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ITEM_INTERACTING_WITH_ATOM)

/// Called when you whack someone with this accessory
/datum/component/pinnable_accessory/proc/on_atom_interact(obj/item/clothing/accessory/badge, mob/living/user, atom/target, modifiers)
	SIGNAL_HANDLER
	if (!ishuman(target) || target == user)
		return

	INVOKE_ASYNC(src, PROC_REF(try_to_pin), badge, target, user)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/// Actually try to pin it on
/datum/component/pinnable_accessory/proc/try_to_pin(obj/item/clothing/accessory/badge, mob/living/carbon/human/distinguished, mob/user)
	// BANDASTATION EDIT START - Allow medal-specific chassis attachment using the same pinning checks and delay.
	if(!can_pin_to(distinguished, user, feedback = TRUE))
		return
	// BANDASTATION EDIT END

	if (!silent)
		user.visible_message(
			span_notice("[user] tries to pin [badge] on [distinguished]'s chest."),
			span_notice("You try to pin [badge] on [distinguished]'s chest."),
		)

	if (on_pre_pin && !on_pre_pin.Invoke(distinguished, user))
		return
	if(!pin_checks(user, distinguished) || !do_after(user, pinning_time, distinguished, extra_checks = CALLBACK(src, PROC_REF(pin_checks), user, distinguished)))
		return

	var/pinned = attach_to_target(badge, distinguished, user) // BANDASTATION EDIT - Resolve the current target after the delay.
	if (silent)
		return

	if (pinned)
		user.visible_message(
			span_notice("[user] pins [badge] on [distinguished]'s chest."),
			span_notice("You pin [badge] on [distinguished]'s chest."),
		)
	else
		user.visible_message(
			span_warning("[user] fails to pin [badge] on [distinguished]'s chest, seemingly unable to part with it."),
			span_warning("You fail to pin [badge] on [distinguished]'s chest."),
		)

/// Callback for do_after to check if we can still be pinned
/datum/component/pinnable_accessory/proc/pin_checks(mob/living/pinner, mob/living/carbon/human/pinning_on)
	if(QDELETED(parent) || QDELETED(pinner) || QDELETED(pinning_on))
		return FALSE
	if(!pinner.is_holding(parent) || !pinner.Adjacent(pinning_on))
		return FALSE
	return can_pin_to(pinning_on, pinner) // BANDASTATION EDIT - Shared validation for uniform and chassis attachment.

// BANDASTATION ADDITION START - Attachment hooks keep the ordinary pinning flow reusable for medals on a chassis.
/datum/component/pinnable_accessory/proc/can_pin_to(mob/living/carbon/human/pinning_on, mob/pinner, feedback = FALSE)
	var/obj/item/clothing/accessory/badge = parent
	var/obj/item/clothing/under/pinning_on_uniform = pinning_on.w_uniform
	if(!istype(pinning_on_uniform))
		if(feedback)
			pinning_on.balloon_alert(pinner, "no uniform to pin on!")
		return FALSE
	return badge.can_attach_accessory(pinning_on_uniform, feedback ? pinner : null)

/datum/component/pinnable_accessory/proc/attach_to_target(obj/item/clothing/accessory/badge, mob/living/carbon/human/distinguished, mob/user)
	var/obj/item/clothing/under/uniform = distinguished.w_uniform
	return uniform?.attach_accessory(badge, user)
// BANDASTATION ADDITION END
