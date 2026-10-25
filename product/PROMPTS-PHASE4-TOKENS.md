# Phase 4.1 — the undesigned screens take the tokens

Every file still on `tool/style_allowlist.txt` gets the design system's colour, type, radius
and spacing, **with its layout unchanged**. This is the decision from 22 Oct: undesigned
screens "must just exist and work". They get a proper design later.

When this phase ends, the allow-list is empty except `cove_web_sidebar.dart`, which belongs
to the web pass.

## The rule for every batch

````
Do batch <4.1x> from product/PROMPTS-PHASE4-TOKENS.md.

For each file in the batch:
1. **Before.** If the file has no golden yet, add one *before changing anything* (a screen,
   sheet or dialog in its usual state, 3 widths × 2 modes, built from fixtures with the fixed
   clock) and commit those goldens alone first, as
   `test(golden): before-goldens for batch <4.1x>`.
2. **Convert, tokens only.** Every raw colour, font size, font family, radius and spacing
   literal becomes the matching token from CoveTokens / CoveType / CoveSpace / CoveRadius /
   CoveSize. **Same widgets, same order, same layout.** No restructuring, no new components,
   no copy changes (except 4.1g). Where a primitive already does exactly what a hand-rolled
   piece does (a row, a header, a button), you may swap it in, but list each swap.
3. **No token fits?** If the literal is within 2 of a token, use the token. Otherwise leave
   the literal with a `// (literal) <why>` comment and report it. Don't invent tokens in this
   phase.
4. Delete the file's line from tool/style_allowlist.txt. Never lower a number; delete the line.
5. Regenerate the goldens. Make a before → after contact sheet for the batch
   (build/token_batches/<4.1x>.png) and describe every visible change. Each one must be
   explained by a token value. Anything that moved for another reason is a bug: fix it.
6. tool/check.sh must exit 0. Commit as `style(tokens): <batch name> take the tokens (<4.1x>)`.
````

## The batches, in order

Each one is a separate prompt. The numbers are the allow-list budgets.

| Batch | Name | Files | Literals |
|---|---|---|---|
| **4.1a** | core widgets | cove_checkbox 5 · cove_tab_row 4 · cove_pill_button 4 · cove_undo_toast 3 · cove_toggle_switch 3 · cove_pill_input 3 · cove_activity_row 3 · cove_streak_badge 2 · cove_splash_screen 2 · cove_error_state 2 · cove_empty_state 2 · cove_loading 1 | 34 |
| **4.1b** | home, auth, profile | onboarding_choice_screen 5 · join_home_screen 10 · create_home_screen 3 · home_switcher_sheet 5 · sign_in_screen 4 · edit_profile_dialog 8 · edit_home_dialog 4 · edit_partner_profile_dialog 2 · delete_data_dialog 2 · currency_selector_sheet 3 · drive_backup_sheets 4 · drive_backup_section 1 | 51 |
| **4.1c** | about and changelog | about_cove_screen 15 · changelog_screen 17 · whats_fresh_modal 18 · changelog_preview_mockup 19 | 69 |
| **4.1d** | small sheets and screens | monthly_budget_sheet 10 · month_commitments_sheet 15 · reminders_screen 10 · roadmap_screen 8 · weather_detail_sheet 7 · dashboard_weather_badge 7 · calendar_month_view 7 · create_list_dialog 5 | 69 |
| **4.1e** | routines and habits | routine_models 9 · routine_event_form_sheet 8 · routine_form_sheet 2 · habits_screen 12 · habit_form_sheet 16 | 47 |
| **4.1f** | the Edit forms | calendar_event_form_sheet 6 · expense_form_sheet 28 · subscription_form_sheet 51 | 85 |
| **4.1g** | Lists, then the wording | lists_screen 29, then the sweep below | 29 |

**4.1a goes first** because every later batch uses those widgets. Its goldens will move in
many places at once. That's expected, but every screen that moves must be listed.

**4.1f is the riskiest.** These forms are what Edit opens on real records. In addition to the
rule above, add a widget test per form that opens it with an existing record, saves without
changing anything, and asserts the controller received exactly the record's original values.

**4.1g, after lists_screen — Rhythm becomes Habit.** Find every user-visible "Rhythm" /
"rhythm" (labels, empty states, toasts, notification copy, Activity strings) and say "Habit"
/ "habit", matching the surrounding case. Code identifiers and stored event types stay as
they are. List every string changed.

## When the last batch is green

1. `General Sans` is still bundled. If nothing references it, remove the font files and their
   pubspec entries, and confirm no golden changes.
2. The allow-list holds only `cove_web_sidebar.dart`.
3. Report the totals: literals at the start of 4.1 (406), and now.
