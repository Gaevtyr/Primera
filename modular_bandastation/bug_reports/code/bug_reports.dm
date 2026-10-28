// Adapted from https://github.com/ParadiseSS13/Paradise/pull/30376 (originally CM-SS13).
#define BUG_REPORT_COOLDOWN (5 MINUTES)
#define BUG_REPORT_TITLE_LIMIT 256
#define BUG_REPORT_TEXT_LIMIT 4096
#define BUG_REPORT_LOG_LIMIT 8192
#define BUG_REPORT_CREATED 201

GLOBAL_LIST_EMPTY(bug_report_drafts)
GLOBAL_LIST_EMPTY(bug_report_next_submission)

/datum/config_entry/string/github_api_token
	protection = CONFIG_ENTRY_LOCKED | CONFIG_ENTRY_HIDDEN

/// Restrict authenticated requests to the public GitHub API, using the existing repository setting.
/proc/bug_report_repository(repo_url)
	if(!istext(repo_url))
		return null
	var/static/regex/repository = regex("^https://(www\\.)?github\\.com/(\[A-Za-z0-9_.-\]+/\[A-Za-z0-9_.-\]+)/?$")
	if(repository.Find(repo_url) && repository.match == repo_url)
		return repository.group[2]
	return null

/proc/bug_report_cooldown_remaining(author_ckey)
	return max(0, GLOB.bug_report_next_submission[author_ckey] - world.time)

/client/proc/open_bug_report()
	if(!mob || !bug_report_repository(CONFIG_GET(string/githuburl)))
		to_chat(src, span_warning("Багрепорты не настроены: требуется адрес репозитория GitHub в GITHUBURL."))
		return
	var/datum/bug_report/report = GLOB.bug_report_drafts[ckey]
	if(QDELETED(report))
		var/remaining = bug_report_cooldown_remaining(ckey)
		if(remaining)
			to_chat(src, span_warning("Следующий багрепорт можно отправить через [DisplayTimeText(remaining)]."))
			return
		report = new(mob)
		GLOB.bug_report_drafts[ckey] = report
	report.ui_interact(mob)

/datum/bug_report
	/// Keep the report alive and prevent duplicate submissions while HTTP yields.
	var/sending = FALSE
	var/author_ckey
	var/author_key
	var/list/report_data = list()
	var/client_version
	var/server_commit
	var/origin_commit
	var/round_id
	var/test_merges

/datum/bug_report/New(mob/user)
	. = ..()
	author_ckey = user?.ckey
	author_key = user?.key
	if(user?.client)
		client_version = "[user.client.byond_version].[user.client.byond_build]"
	server_commit = GLOB.revdata.commit
	origin_commit = GLOB.revdata.originmastercommit
	round_id = GLOB.round_id
	var/list/merges = list()
	for(var/datum/tgs_revision_information/test_merge/merge as anything in GLOB.revdata.testmerge)
		merges += "#[merge.number] at [merge.head_commit]"
	test_merges = merges.Join("\n")

/datum/bug_report/Destroy()
	if(author_ckey && GLOB.bug_report_drafts[author_ckey] == src)
		GLOB.bug_report_drafts -= author_ckey
	SStgui.close_uis(src)
	report_data = null
	return ..()

/datum/bug_report/ui_status(mob/user, datum/ui_state/state)
	if(!user?.client)
		return UI_CLOSE
	return user.ckey == author_ckey ? UI_INTERACTIVE : UI_CLOSE

/datum/bug_report/ui_interact(mob/user, datum/tgui/ui)
	if(ui_status(user) != UI_INTERACTIVE)
		ui?.close()
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BugReportForm")
		ui.open()

/datum/bug_report/ui_close(mob/user)
	. = ..()
	if(!sending && !QDELETED(src))
		qdel(src)

/datum/bug_report/ui_data(mob/user)
	return list(
		"report_details" = report_data,
		"sending" = sending,
		"title_limit" = BUG_REPORT_TITLE_LIMIT,
		"text_limit" = BUG_REPORT_TEXT_LIMIT,
		"log_limit" = BUG_REPORT_LOG_LIMIT,
	)

/// Whitelist, type-check and bound fields on the server; keep code/log text intact.
/datum/bug_report/proc/validate_data(list/params)
	if(!islist(params))
		return null
	var/list/validated = list()
	for(var/field in list("title", "expected_behavior", "description", "consequences", "steps", "log"))
		var/optional = field == "log"
		var/value = params[field]
		if(isnull(value) && optional)
			value = ""
		var/limit = field == "title" ? BUG_REPORT_TITLE_LIMIT : (field == "log" ? BUG_REPORT_LOG_LIMIT : BUG_REPORT_TEXT_LIMIT)
		if(!istext(value) || length_char(value) > limit || (!optional && !length(trim(value))))
			return null
		validated[field] = value
	return validated

/datum/bug_report/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || sending || ui_status(ui?.user) != UI_INTERACTIVE)
		return
	var/mob/user = ui.user
	switch(action)
		if("confirm")
			var/list/validated = validate_data(params)
			if(!validated)
				to_chat(user, span_warning("Заполните все обязательные поля и соблюдайте ограничения длины."))
				return
			if(bug_report_cooldown_remaining(author_ckey))
				to_chat(user, span_warning("Между отправками багрепортов должно пройти 5 минут."))
				return
			report_data = validated
			sending = TRUE
			GLOB.bug_report_next_submission[author_ckey] = world.time + BUG_REPORT_COOLDOWN
			INVOKE_ASYNC(src, PROC_REF(send_request))
		if("cancel")
			qdel(src)
	return TRUE

/datum/bug_report/proc/create_body()
	return {"## Ожидаемое поведение
[report_data["expected_behavior"]]

## Что произошло
[report_data["description"]]

## Последствия
[report_data["consequences"]]

## Шаги воспроизведения
[report_data["steps"]]

## Логи
```
[report_data["log"] || "Нет"]
```

## Дополнительные сведения
- Автор: [author_key]
- Раунд: [round_id || "Не задан"]
- BYOND клиента: [client_version]
- BYOND сервера: [world.byond_version].[world.byond_build]
- Коммит сервера: [server_commit]
- Коммит origin/master: [origin_commit]
- Активные test merges:
[test_merges || "Нет"]
"}

/datum/bug_report/proc/send_request()
	if(IsAdminAdvancedProcCall() || !sending)
		return
	var/repository = bug_report_repository(CONFIG_GET(string/githuburl))
	var/token = CONFIG_GET(string/github_api_token)
	if(!repository || !length(token))
		sending = FALSE
		to_chat(GLOB.directory[author_ckey], span_warning("Багрепорт не отправлен: не настроены GITHUBURL или GITHUB_API_TOKEN. Данные сохранены в форме."))
		return
	var/datum/http_request/request = new()
	request.prepare(RUSTG_HTTP_METHOD_POST, "https://api.github.com/repos/[repository]/issues", json_encode(list(
		"title" = report_data["title"],
		"body" = create_body(),
		"labels" = list("bug"),
	)), list(
		"Authorization" = "Bearer [token]",
		"Accept" = "application/vnd.github+json",
		"Content-Type" = "application/json; charset=utf-8",
		"User-Agent" = "PrimeDream-BugReports",
	), timeout_seconds = 15)
	var/datum/http_response/response
	try
		request.begin_async()
		UNTIL(request.is_complete())
		response = request.into_response()
	catch
		response = new()
		response.errored = TRUE
	request.headers = null
	qdel(request)
	handle_response(response)
	qdel(response)

/datum/bug_report/proc/handle_response(datum/http_response/response)
	if(response.errored || response.status_code != BUG_REPORT_CREATED)
		sending = FALSE
		to_chat(GLOB.directory[author_ckey], span_warning("GitHub не подтвердил создание issue (HTTP [response.status_code || "нет ответа"]). Данные сохранены в форме. Проверьте Issues перед повторной отправкой: запрос мог дойти до GitHub."))
		return FALSE
	log_admin("[author_ckey] submitted a bug report to GitHub: [report_data["title"]]")
	var/client/author = GLOB.directory[author_ckey]
	if(author)
		to_chat(author, span_notice("Ваш багрепорт «[html_encode(report_data["title"])]» опубликован на GitHub. Спасибо!"))
	qdel(src)
	return TRUE

#undef BUG_REPORT_COOLDOWN
#undef BUG_REPORT_TITLE_LIMIT
#undef BUG_REPORT_TEXT_LIMIT
#undef BUG_REPORT_LOG_LIMIT
#undef BUG_REPORT_CREATED
