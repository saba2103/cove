# The Letter — `lib/features/today/letter/`

The paragraph at the foot of Today that describes the day in plain prose.

**It is rule-based, deterministic and on-device.** No language model, no network, nothing
leaves the phone — a model here would be the first thing in Cove to send your data off the
device, and the privacy page promises otherwise.

## Two parts, built separately

1. **`composeDayLetter(DayLetterInput) → List<LetterSpan>`** — a pure function. No
   widgets, no providers, no `DateTime.now()`. The clock and every fact arrive in the input.
   A `LetterSpan` is `{text, style: plain | link | italic, target?}`.
2. **`CoveLetter`** — a widget that renders spans. It knows nothing about the day.

This split is what makes the Letter testable: the prose is checked as data.

## The sentences, in fixed order. Each is omitted when it has nothing to say.

| # | Sentence | Rule |
|---|---|---|
| 1 | **The day** | "A clear {Weekday}." with 0 things · "A quiet {Weekday}." 1–2 · "A full {Weekday}." 3–6 · "A busy {Weekday}." 7+. *Things* = today's events + expenses + ticked tasks + habit check-ins. |
| 2 | **The calendar** | 0 → "Nothing on the calendar." · 1 → "One thing on the calendar — {event} at {time}." · 2+ → "{N} things on the calendar, the first at {time}." |
| 3 | **Habits** | Only habits scheduled today. Done by both: "{habit} is done for both of you." · Mixed: "{done} done; {waiting} still waiting." Name at most two, then "and {N} more". |
| 4 | **Money** | Omitted at ₹0. "{total} went out today" · if the top item is ≥50% of the total: ", most of it {item}" · if the top two are ≥75%: ", most of it {A} and {B}" · then "." |
| 5 | **Commitments** | Due tomorrow (or today): "{sum} of commitments goes out tomorrow." |
| 6 | **Lists** — *italic* | Open items: "{N} {line/lines} {is/are} still on the {list} list." Several lists: "…still on your lists." |

## Wording rules
- **Names are verbatim.** Use the record's own title exactly — "Call with Amma", never "Amma". The prototype's prose was hand-written; a rule that rewrites people's text will eventually get one badly wrong.
- One to nine as words, 10 and up as digits.
- Times on the hour as words ("at seven"); otherwise digits ("at 7:30").
- Money through `formatCoveCurrency()` — Indian grouping.
- The viewer is "you"; the partner by name; both is "both of you".
- At most six sentences.
- **Never a timestamp.** Never cached, never "written at". It is recomposed on every build.
- First run, with no data at all: "The letter writes itself once there is a day to read." in italic tertiary.

## Links
Every person, event, habit, figure and list in the Letter is a link to that record or
section. Links: underlined, `accent.fill` underline, same colour as the text. Italic spans in
`text.secondary`, Libre Bodoni Italic.

## Type
`CoveType.letter` — Libre Bodoni 400, 21sp, 36dp line box.
