#define OPERATION_IPC_PATIENT "ipc_original_patient"

/// Uses the ordinary hatch-opening operations; only the selected limb's casing changes.
/datum/surgery_operation/limb/ipc_customization
	name = "настроить внешний вид кибернетической конечности"
	desc = "Изменить модель корпуса выбранной конечности с помощью мультитула."
	implements = list(TOOL_MULTITOOL = 1)
	time = 4.8 SECONDS
	operation_flags = OPERATION_MECHANIC | OPERATION_SELF_OPERABLE
	required_bodytype = BODYTYPE_ROBOTIC
	all_surgery_states_required = SURGERY_SKIN_OPEN
	preop_sound = 'sound/items/taperecorder/tape_flip.ogg'
	success_sound = 'sound/items/taperecorder/taperecorder_close.ogg'

/datum/surgery_operation/limb/ipc_customization/get_default_radial_image()
	return image(/obj/item/multitool)

/datum/surgery_operation/limb/ipc_customization/state_check(obj/item/bodypart/limb)
	return !IS_STUMP(limb) && length(limb.get_ipc_customization_choices()) > 0

/datum/surgery_operation/limb/ipc_customization/pre_preop(obj/item/bodypart/limb, mob/living/surgeon, obj/item/tool, list/operation_args)
	operation_args[OPERATION_IPC_PATIENT] = limb.owner
	var/list/choices = limb.get_ipc_customization_choices()
	var/chosen_model = operation_args[OPERATION_ACTION]
	if(isnull(chosen_model) || chosen_model == "default")
		chosen_model = tgui_input_list(surgeon, "Выберите модель корпуса этой конечности.", "Настройка кибернетической конечности", choices)
	operation_args[OPERATION_ACTION] = chosen_model
	var/mob/living/original_patient = operation_args[OPERATION_IPC_PATIENT]
	if(QDELETED(limb) || QDELETED(surgeon) || QDELETED(tool) || QDELETED(original_patient))
		return FALSE
	return limb.owner == original_patient && (chosen_model in limb.get_ipc_customization_choices())

/datum/surgery_operation/limb/ipc_customization/operate_check(mob/living/patient, obj/item/bodypart/limb, mob/living/surgeon, tool, list/operation_args)
	if(QDELETED(limb) || limb.owner != patient || limb.owner != operation_args[OPERATION_IPC_PATIENT])
		return FALSE
	if(!..())
		return FALSE
	return operation_args[OPERATION_ACTION] in limb.get_ipc_customization_choices()

/datum/surgery_operation/limb/ipc_customization/on_preop(obj/item/bodypart/limb, mob/living/surgeon, obj/item/tool, list/operation_args)
	display_results(
		surgeon,
		limb.owner,
		span_notice("Вы начинаете настраивать внешний вид [limb.ru_plaintext_zone[GENITIVE]]..."),
		span_notice("[surgeon] начинает настраивать внешний вид [limb.ru_plaintext_zone[GENITIVE]]."),
		span_notice("[surgeon] подключает мультитул к открытой панели корпуса."),
	)

/datum/surgery_operation/limb/ipc_customization/on_success(obj/item/bodypart/limb, mob/living/surgeon, obj/item/tool, list/operation_args)
	if(!operate_check(operation_args[OPERATION_IPC_PATIENT], limb, surgeon, tool, operation_args))
		return
	if(!limb.set_ipc_chassis(operation_args[OPERATION_ACTION]))
		return
	display_results(
		surgeon,
		limb.owner,
		span_notice("Вы меняете внешний вид [limb.ru_plaintext_zone[GENITIVE]] на [operation_args[OPERATION_ACTION]]."),
		span_notice("[surgeon] меняет внешний вид [limb.ru_plaintext_zone[GENITIVE]] на [operation_args[OPERATION_ACTION]]."),
		span_notice("[surgeon] завершает настройку корпуса."),
	)

#undef OPERATION_IPC_PATIENT
