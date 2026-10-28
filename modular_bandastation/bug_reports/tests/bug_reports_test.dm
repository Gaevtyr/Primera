/datum/unit_test/bug_report_validation/Run()
	var/datum/bug_report/report = allocate(/datum/bug_report)
	var/list/params = list(
		"title" = "Тестовый баг",
		"expected_behavior" = "Ожидаемое поведение",
		"description" = "if(a < b && c > d)\n\treturn TRUE",
		"consequences" = "Последствия",
		"steps" = "1. Сделать что-нибудь\n2. Проверить результат",
		"log" = "<test> & \"quoted\"",
		"unexpected" = "ignored",
	)
	var/list/validated = report.validate_data(params)
	TEST_ASSERT_NOTNULL(validated, "A complete report must be accepted")
	TEST_ASSERT_EQUAL(validated["description"], params["description"], "Code must not be stripped from reports")
	TEST_ASSERT_EQUAL(validated["log"], params["log"], "Logs must retain markup and quotes")
	TEST_ASSERT(!("unexpected" in validated), "Unknown fields must not enter the payload")
	for(var/field in list("title", "expected_behavior", "description", "consequences", "steps"))
		var/list/invalid = params.Copy()
		invalid[field] = " \n\t"
		TEST_ASSERT_NULL(report.validate_data(invalid), "Blank required field [field] must be rejected")
		invalid[field] = list("not text")
		TEST_ASSERT_NULL(report.validate_data(invalid), "Non-text field [field] must be rejected")
	for(var/field in list("title", "description", "log"))
		var/limit = field == "title" ? 256 : (field == "log" ? 8192 : 4096)
		var/list/bounded = params.Copy()
		bounded[field] = repeat_string(limit, "я")
		TEST_ASSERT_NOTNULL(report.validate_data(bounded), "The character limit must accept Cyrillic")
		bounded[field] += "x"
		TEST_ASSERT_NULL(report.validate_data(bounded), "Oversized [field] must be rejected")

/datum/unit_test/bug_report_repository/Run()
	TEST_ASSERT_EQUAL(bug_report_repository("https://github.com/mo0niverse/PrimeDream-"), "mo0niverse/PrimeDream-", "Use the configured repository")
	TEST_ASSERT_EQUAL(bug_report_repository("https://www.github.com/owner/repo/"), "owner/repo", "Accept the existing GITHUBURL format")
	for(var/invalid in list("http://github.com/a/b", "https://github.com.evil.test/a/b", "https://evil.test/a/b", "https://github.com/a/b/issues", "https://github.com/a/b?token=secret", "https://github.com/a/b\n"))
		TEST_ASSERT_NULL(bug_report_repository(invalid), "Unsafe or malformed repository URL must be rejected: [invalid]")

/datum/unit_test/bug_report_cooldown/Run()
	var/test_ckey = "bugreporttest"
	GLOB.bug_report_next_submission[test_ckey] = world.time + 5 MINUTES
	var/remaining = bug_report_cooldown_remaining(test_ckey)
	GLOB.bug_report_next_submission[test_ckey] = world.time - 1
	var/expired = bug_report_cooldown_remaining(test_ckey)
	GLOB.bug_report_next_submission -= test_ckey
	TEST_ASSERT_EQUAL(remaining, 5 MINUTES, "Cooldown must be keyed by ckey")
	TEST_ASSERT_EQUAL(expired, 0, "Expired cooldown must allow another report")
	TEST_ASSERT_EQUAL(bug_report_cooldown_remaining(test_ckey), 0, "First report must not be rate limited")

/datum/unit_test/bug_report_lifecycle/Run()
	var/datum/bug_report/report = allocate(/datum/bug_report)
	report.author_ckey = "bugreporttest"
	report.author_key = "BugReportTest"
	report.report_data = list("title" = "Retain on HTTP error", "description" = "A saved report")
	report.sending = TRUE
	GLOB.bug_report_drafts[report.author_ckey] = report
	report.ui_close(null)
	TEST_ASSERT(!QDELETED(report), "Closing a form must not cancel an in-flight report")
	var/datum/http_response/response = allocate(/datum/http_response)
	response.status_code = 403
	TEST_ASSERT(!report.handle_response(response), "GitHub errors must not be reported as success")
	TEST_ASSERT(!QDELETED(report) && GLOB.bug_report_drafts[report.author_ckey] == report, "Failed reports must remain available to their author")
	TEST_ASSERT_EQUAL(report.report_data["description"], "A saved report", "HTTP errors must not lose the report")
	TEST_ASSERT(!report.sending, "HTTP errors must permit another attempt after cooldown")
	var/mob/unauthorized = allocate(/mob)
	TEST_ASSERT_EQUAL(report.ui_status(unauthorized), UI_CLOSE, "Reports must be inaccessible without a client")
	response.status_code = 201
	TEST_ASSERT(report.handle_response(response), "HTTP 201 must resolve the report")
	TEST_ASSERT(QDELETED(report), "Published reports must be deleted")
	TEST_ASSERT_NULL(GLOB.bug_report_drafts["bugreporttest"], "Published reports must leave no global references")
	var/datum/bug_report/draft = allocate(/datum/bug_report)
	draft.author_ckey = "bugreporttest"
	GLOB.bug_report_drafts[draft.author_ckey] = draft
	draft.ui_close(unauthorized)
	TEST_ASSERT(QDELETED(draft), "Closing an unsubmitted draft must delete it")
	TEST_ASSERT_NULL(GLOB.bug_report_drafts["bugreporttest"], "Deleted drafts must leave no global references")

/// Exercise real submission and cooldown handling without a client or HTTP request.
/datum/bug_report/submission_test
	var/request_count = 0

/datum/bug_report/submission_test/ui_status(mob/user, datum/ui_state/state)
	return user?.ckey == author_ckey ? UI_INTERACTIVE : UI_CLOSE

/datum/bug_report/submission_test/send_request()
	request_count++

/// Omit browser registration while retaining native UI close and window lock handling.
/datum/tgui_window/bug_report_unit_test/New()
	id = "bug-report-unit-test"

/datum/unit_test/bug_report_submission/Run()
	var/mob/author = allocate(/mob)
	author.key = "@bugreportauthor" // Native fake keys avoid client checks and ghosting during cleanup.
	var/mob/other = allocate(/mob)
	other.key = "@bugreportother"
	var/datum/bug_report/submission_test/report = allocate(/datum/bug_report/submission_test, author)
	GLOB.bug_report_drafts[author.ckey] = report
	var/datum/tgui/ui = allocate(/datum/tgui, author, report, "BugReportForm")
	var/datum/tgui_window/window = allocate(/datum/tgui_window/bug_report_unit_test)
	ui.window = window
	ui.initialized = TRUE
	ui.opened_at = world.time
	window.acquire_lock(ui)
	SStgui.on_open(ui)
	var/list/params = list(
		"title" = "Direct submission",
		"expected_behavior" = "Publish immediately",
		"description" = "No staff approval",
		"consequences" = "Waiting for review",
		"steps" = "Submit the form",
	)
	ui.user = other
	report.ui_act("confirm", params, ui)
	TEST_ASSERT_EQUAL(report.request_count, 0, "Another player must not submit the author's form")
	ui.user = author
	report.ui_act("confirm", params, ui)
	TEST_ASSERT_EQUAL(report.request_count, 1, "A player submission must immediately start the GitHub request")
	TEST_ASSERT(report.sending, "The request must lock repeat submissions before yielding")
	TEST_ASSERT_EQUAL(report.report_data["title"], params["title"], "The submitted data must be retained")
	TEST_ASSERT_EQUAL(bug_report_cooldown_remaining(author.ckey), 5 MINUTES, "Direct submissions must retain the cooldown")
	report.ui_act("confirm", params, ui)
	report.ui_act("cancel", list(), ui)
	TEST_ASSERT_EQUAL(report.request_count, 1, "Repeated clicks must not send another request")
	TEST_ASSERT(!QDELETED(report), "Cancel must not delete an in-flight report")
	var/datum/http_response/response = allocate(/datum/http_response)
	response.status_code = 403
	report.handle_response(response)
	report.ui_act("confirm", params, ui)
	TEST_ASSERT_EQUAL(report.request_count, 1, "An HTTP error must not bypass the cooldown")
	GLOB.bug_report_next_submission -= author.ckey
	report.ui_act("confirm", params, ui)
	TEST_ASSERT_EQUAL(report.request_count, 2, "The author may retry after the cooldown")
	GLOB.bug_report_next_submission -= author.ckey
	ui.close()
	TEST_ASSERT(QDELETED(ui), "The native UI must close while a request is in flight")
	TEST_ASSERT(!(ui in SStgui.all_uis) && !(ui in author.tgui_open_uis) && !(ui in report.open_uis), "Closing must remove the UI from every native registry")
	TEST_ASSERT(!window.locked && isnull(window.locked_by), "Closing must release the window lock")
	report.handle_response(response)
	TEST_ASSERT(!QDELETED(report) && GLOB.bug_report_drafts[author.ckey] == report, "A failed request after closing must leave the saved report available")
	response.status_code = 201
	report.handle_response(response)
	TEST_ASSERT(QDELETED(report), "A successful request after closing must clean up the report")
	TEST_ASSERT_NULL(GLOB.bug_report_drafts[author.ckey], "Success must remove the saved draft")
