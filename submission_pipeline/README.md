# ECOFLOR 2027 — submissions → programme & Book of Abstracts

```
Google Form ──(trigger)──▶ Sheet "Submissions" ──▶ R/ecoflor_submissions.R ──▶ Ecoflor_2027_programme.qmd
   (Code.gs)                  + review columns                                └▶ Ecoflor_2027_Book_of_abstracts.qmd
                              + "Sessions" tab
```

## 1. Create the form and sheet (once)

1. Log in to the Google account that should own the form (e.g. the ECOFLOR account).
2. Open <https://script.google.com> → **New project**, name it "ECOFLOR 2027 pipeline".
3. Delete the default code, paste the whole of `Code.gs`, save.
4. Select the function **`setup`** in the toolbar and click **Run**. Allow the permissions
   (Forms, Sheets, Drive, sending email, triggers).
5. Open **Execution log**: it prints the form edit link, the public form link and the sheet link.
6. Check the form in preview, then paste the public link into the Registration section of `index.qmd`.
7. Paste the sheet URL into `SHEET_URL` in `R/ecoflor_submissions.R`.

Adjust the keyword list, questions or texts in `CONFIG` / `KEYWORDS` / `buildForm_()` **before** running
`setup()`. Small text changes later can be done directly in the Forms editor — the script finds answers
by question ID, not by title, so retitling questions is safe. Do not delete questions.

## 2. While submissions come in

- Every new or edited response appears in **Submissions** within seconds, with an ID (`EF27-001`, …),
  cleaned text and a word count. The participant gets an email with their edit link.
- **Teal columns are automatic — don't type in them.** If an author edits their response,
  these columns are overwritten. Ask authors to fix typos via their edit link.
- **Amber columns are yours** and are never touched by the script:

| Column | Values | Used for |
|---|---|---|
| `Status` | Pending / Accepted / Rejected / Withdrawn | only *Accepted* rows go into the documents |
| `Final_format` | Oral / Rising Star / Poster | talk or poster section |
| `Session_ID` | number from the **Sessions** tab | grouping |
| `Order` | 1, 2, 3 … within the session | order of talks (and poster numbering) |
| `Reviewer`, `Review_notes` | free text | your notes only |

- Use **Data → Create a filter** to read abstracts by keyword or status; **Keyword counts** shows
  which topics are popular, to help build sessions.
- Google's own "Form Responses 1" tab is the raw backup. Leave it as is.

## 3. Build sessions

In the **Sessions** tab, one row per session:

| Session_ID | Session_Name | Type | Day | Start_time | Slot_minutes | Chair |
|---|---|---|---|---|---|---|
| 1 | Pollen and pollen transfer | Oral | Thursday 4 February | 09:00 | 12 | … |
| 5 | Poster session I | Poster | Thursday 4 February | 15:00 | | |

Talk times are calculated as `Start_time + (position − 1) × Slot_minutes` (default 12 min:
10 min talk + 2 min questions). Put Rising Stars talks in their own session with a longer
`Slot_minutes` (e.g. 20). Then fill `Session_ID` and `Order` in **Submissions**.

## 4. Generate the documents

From the project root:

```bash
quarto render Ecoflor_2027_programme.qmd --to pdf
quarto render Ecoflor_2027_Book_of_abstracts.qmd --to pdf
```

The first run opens a browser to log in to Google (the token is cached in `.secrets/`, which is git-ignored).
Rendering stops with a clear list of rows to fix if, for example, an accepted contribution has no
session or the authors are not in the expected format.

Without `SHEET_URL` the documents use `example_submissions.csv` / `example_sessions.csv`, which is
handy for testing layout changes. `ECOFLOR_SHEET=example quarto render …` forces the example data.

## Formats the form enforces

- **Authors:** `Jana Nováková (1,2)*; John Smith (2)` — `*` marks the presenter (underlined in the book).
- **Affiliations:** one per line, `1. Department, Institution, City, Country`.
- **Abstract:** ≤ 200 words, blank line between paragraphs, `_species name_` for italics.
- **Keywords:** exactly 3, from a list of 15 session-like topics or "Other" (several own keywords can be
  separated by `;`). Sorting **Submissions** by `Keyword_1` gives a first draft of the sessions.

## Maintenance

- **`resyncAll()`** (run from the script editor) re-copies every response into Submissions — use it if
  a trigger ever failed. Review columns are kept.
- To stop accepting submissions: in the form, switch off **Accepting responses**.
