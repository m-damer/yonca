# YONCA — Screen audit (26 Oct 2026)

**Status, end of 26 Oct:** every item in Priority 1, 2 and 3 now has a frame in English and Arabic, in light and in dark. The wording differences listed below were fixed in the frames, except the repeated frame numbers (see below). DESIGN.md and tokens.json now describe the glass style, the logo palette and dark mode.

Still open: frame numbers still repeat in the older flows (C1–C13 in Contacts and Contact details, A1–A8 in Home Arabic and About); rename before developer handoff. Items 7 and 8 of the differences list (Contacts row details, calendar first day and dot shapes) were not re-checked. High contrast, 130% text size, landing page and widgets are still not drawn.


Compared: DESIGN.md (S01–S41, flows D1–D26, shared states, G2 dialogs, G3 toasts, G4 errors, G6 empty states, G7 notifications, G8 prompts) against the 143 frames now on the Design page (about 130 per language; light mode only).

**Result in one line:** every screen *family* in the spec has at least one frame, but about 90 screens, states, dialogs and prompts from the spec are not drawn yet. Details below, in the order I suggest drawing them.

## Priority 1 — screens that exist in the spec and have no frame

| # | Spec | What is missing |
|---|---|---|
| 1 | S31 My profile | The whole screen: photo, name, title, company, phones, email, website, address, own QR code, Share. (The More tab shows the card but it opens nothing.) |
| 2 | S15 Note screen | Note in its own screen with Edit and Delete (title, text, voice, files). |
| 3 | S16 Task | Quick create (one line), task detail with Done and Snooze, the Snooze choices (1 hour, tomorrow, pick a date), repeat and priority choices. |
| 4 | S17 Meeting | Quick create, meeting detail, contacts picker (up to 10, first is main), custom duration, Video type (link field), Cancel meeting dialog, overlap as a dialog (G2 `dlgOverlap`). |
| 5 | S19 Deal | Quick create, Add document form (reference, amount, date, file), stage history log, deal custom fields, Reopen deal dialog, delete deal. |
| 6 | S21 Deals | Won and Lost pages with the month filter, empty stage with "Add deal", filter sheet (currency, role, custom fields), deal search, filtered-empty state. |
| 7 | S20 Calendar | Week view, Agenda view, the view switcher in the top bar, contact filter, empty day, Today button state. |
| 8 | S09 Share sheet | The real sheet: QR preview with field picker and scan-quality warning, and vCard with the "Include photo" switch. What I drew is a simplified list. |
| 9 | S08 Contact details | Edited status ("Edited", "Reset to automatic"), "Complete this contact" banner, Requirements "Show more", Upcoming block with several items (sheet), Call and Map choice list for several phones or addresses, Files "Add" menu (Attach file, Note, Voice note), image and PDF preview with zoom, read-only note sheet, collapsed header, deleted contact state. |
| 10 | S32 Backup and data | Google sign-in, sign-in failed, Drive not signed in, restore from Drive, file picker, restore progress with safety copy, errors (damaged file, not a YONCA backup), export CSV and vCard progress, the 14-day "no backup" reminder banner, backup failed. |
| 11 | S33 Settings | "Targets and stats" settings screen, settings search results, and the pickers: quiet hours, temporary-note reminder frequency, alarm sound, event alert time, first day of week, name order, default currency, deal sort. Reset dialog. |
| 12 | S12 Duplicates | Hidden pairs list, "No duplicates found", scanning state, merge confirmation dialog (`dlgMergeConfirm`), swap older record, Skip and Not a duplicate buttons on the pair cards, the first-merge backup prompt as a dialog (`promptFirstMerge`). |
| 13 | S24 Stats | Target history screen, empty period ("No data for this period"), the list sheet behind a tapped number. |
| 14 | S25 Reports | Saved presets, large-report progress with Cancel, Next disabled with zero clients, report error. |
| 15 | S26 Tags | Contacts with a tag, edit and rename, merge tags, empty state, the tag picker inside the contact form. |
| 16 | S28 Custom fields | Choice options editor (up to 20), archive versus delete (`dlgDeleteField`). |

## Priority 2 — missing states of screens that exist

- **S02 Home:** "All caught up" state, Snooze sheet on an overdue task, long-press menu on Recent contacts (WhatsApp, Call), loading skeleton.
- **S03 Search:** empty query with recent searches, no results with "Create contact".
- **S04 Bell:** filtered tabs, Mark all as read, Clear all with confirmation, swipe or x with Undo, empty state, Missed and Update items.
- **S05 Contacts:** swipe actions (Call, WhatsApp), long-press menu, top-bar menu (Scan QR, Import from phone), alphabet scroller when sorted by name, Hot, Warm, Cold tabs, "More filters" sheet for custom fields, loading skeleton.
- **S06 Quick add:** validation error, country code picker, label picker, name expanded to first and last.
- **S07 Contact form:** each "Add more info" chip expanded (Email, Address, Job title, Website, Nickname, Events, Tags, Requirements, Custom fields), photo add and crop sheet, validation errors, edit mode, **Discard changes?** dialog.
- **S10 Scan:** nothing found.
- **S11 Import:** "Already added" rows, empty phone book, progress bar screen, result notification, permission denied, role None.
- **S13 Log activity:** contact picker (recent, search, New contact), "Log this call?" bar after a phone call, the "Choose an outcome" hint on a disabled Save, attachments added, General note (no contact).
- **S23 Timeline:** empty, filtered with chips and result count, Jump to date, loading.
- **S30 QR generator:** manual entry source, phone-book source, "Save as contact" after manual entry.
- **S35 Updates:** checking, offline, permission denied.
- **Contact status editing (D11):** the sheet where the user types their own status.

## Priority 3 — prompts, dialogs, toasts, notifications

Dialogs in G2 with no frame: Discard changes, Delete this item, Delete this field, Clear all notifications, Reopen this deal, Reset all settings, Merge these contacts, Cancel this meeting, Overlap. (Drawn: Delete contact, Delete tag, Delete stage, Restore, Delete everything 1 and 2, Save a backup first, Keep this recording, Bulk edit.)

Prompts in G8 with no frame: Complete this contact, status Edited and Reset, first-merge backup prompt, "Log this call?" bar.

Toasts in G3: only the merge Undo bar is drawn. Missing: delete contact Undo, bell dismiss Undo, saved confirmations, "Lead became Client" after a Won deal, copied.

Notification shade (G7): only the missed alarm is drawn. Missing: task due (Done, Snooze), meeting soon, event today, "Did your meeting happen?", temporary-note reminder, inactivity alert, update available, backup reminder.

Shared states (page 112): loading skeletons, the generic error state ("Try again" and "Copy details"), and the offline banner are not drawn as frames.

## Differences between what I drew and the spec (to fix)

1. **Frame numbers repeat across flows** (for example C1–C13 appear in both Contacts and Contact details, A1–A8 in Home Arabic and About). Rename with the flow prefix before dev handoff.
2. **Crash prompt wording:** spec G8 says "YONCA closed unexpectedly" with buttons "Send report", "Don't send", "Copy details". I wrote "stopped unexpectedly" and "Send".
3. **Follow-up prompt:** spec choices end with "No"; I wrote "Not now".
4. **Reports step 3:** spec has "Create PDF" and "Create CSV" buttons; I drew format chips and one "Export and share" button.
5. **Share contact sheet:** simplified, see Priority 1 item 8.
6. **Pipeline header:** spec says the header uses the stage tint and shows a peek of the next page edge; I drew neither.
7. **Contacts row:** the spec asks for nickname in lighter text, rating icon on the photo corner (All tab only), a temporary-note dot and a role badge with "+1". Checked against the frames on 26 Oct 2026: nickname, rating icon, temporary-note dot and "+1" role badge are all present.
8. **Calendar:** first day of the week should default to Saturday in Arabic and Sunday in English; dot shapes should differ per type. Fixed on 26 Oct 2026: Saturday-first Arabic month and week views, distinct dot shapes.
9. **`DESIGN.md` and `tokens.json`** updated to the glass style, dark logo petals, calendar conventions and the dark checks.

## Not drawn on purpose (later)

High contrast, 130% text size, the landing page, widgets. (Dark mode is now drawn and checked.)

## Still open for Mahmoud

Review of every Arabic line (all of it is my draft); bio and links for About the developer (Q3); Syrian wording for dates and digits.

## Code vs canvas pass (27 Oct 2026)

The Flutter app was brought up to the canvases for these screens. Where the build differs on purpose, the canvas is the reference for look and the note below is the reference for behaviour.

**Done in code**
- Home (Hm family): leaf-logo header with spaced "YONCA", name greeting and summary line, four quick cards, red overdue block with Done and Snooze (snooze sheet: in 1 hour, tomorrow 9:00, pick date and time), "Did it happen?" cards, grouped Today and Upcoming lists, To complete, Needs attention, Recent contacts strip with long-press menu, pipeline bar with open value, targets, recent activity with View more, empty-app and caught-up cards.
- Onboarding (Onb A1–A7, EN E1–E6): six steps with progress bar. The main currency is stored and new deals start with it. The profile name feeds the Home greeting.
- Notifications (Hm_BE, BM, BR, BT and Nt_DClr): tabs All, Tasks, Meetings, Contacts; unread dots; Missed pill; menu with Mark all as read, Clear all, Notification settings; clear-all confirmation; Undo toasts.
- Crash prompt (Sys Y13): shows error code, app version and Android version, with Send report, Copy details and Don't send.
- Contact details (Con Detail): editable status line ("Automatic" or "Edited", with reset), red overdue card, counts on the Schedule and Deals tab chips.
- Contacts filter sheet: Stage filter added (with active chip and live count).
- Calendar (Cal): month or week label with arrows and a view menu (Agenda, Week, Month, Tasks), Tasks, Meetings, Events and Done toggle chips, "N overdue, Show" banner.
- Settings (G1–G9): hub with Appearance, Language and region, Notifications and alarms, Inactivity alerts, Deals, Home (section switches) and links to Targets, My profile, Custom fields, Data and privacy, About; Reset all settings. Inactivity days now drive Home, Needs attention.
- More (M1): profile card, Work, Organize, Tools and Data groups with icon rows, duplicates count badge, Settings row. The temporary alarm test moved to Settings, Notifications and alarms, Test alarm.
- Reports already has Create PDF and Create CSV (item 4 above is out of date).

**Differs on purpose (build wins, canvas should change)**
- Crash report opens the Android share sheet, not an email app (no developer address is set yet), so the "No email app" frame (Y14) does not apply. Phone model is not collected.
- Backup to Drive is replaced by the share sheet and a saved file.
- Onboarding step "Numbers and dates" (Arabic, OA2) is not a step; the same choices are in Settings, Arabic.
- Notifications have no filter icon yet, and no birthday or deal-moved entries because the app does not log those events.

**Differs on purpose (added):** My profile and Custom fields stay as extra rows in the Settings hub; Home sections can be switched but not yet dragged to reorder; Deals settings offer only USD, SYP and EUR (no custom currency, no sort options); Notifications settings have no permission status list, no lock-screen detail hiding and no target alerts.

**Still missing from the canvases:** Calendar Today button and per-type dot shapes; Stats "Custom" period and the Follow-up discipline title; Tags page and QR generator rows in More; Share button on the More profile card.

**Not yet compared screen by screen:** forms and quick add, Deals detail and sheets, Timeline, Tools and Backup pages, Alarm frames, Arabic frames. The Deals pager already has the stage header, counts and Go to stage sheet; the stage-tint header and next-page peek (item 6 above) are still open.
