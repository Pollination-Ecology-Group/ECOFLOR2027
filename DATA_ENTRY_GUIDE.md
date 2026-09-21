# ECOFLOR 2026: Abstract Book Data Entry Guide

This document explains how to populate the Google Sheet to generate the Book of Abstracts without errors. The automation script relies on specific column names and data formats.

**Google Sheet Link:** [EcoFlor 2026 Abstracts Sheet](https://docs.google.com/spreadsheets/d/1zsfhYz32GoeKz8qzaHgDKsc-InRxitIsdnc9JWG-4OU/edit?usp=sharing)

## ⚠️ Critical Rules

1.  **DO NOT Rename Columns:** The columns listed below must keep their exact names (case-sensitive). If you change "Session_ID" to "Session ID" or "id", **the script will break**.
2.  **DO NOT Delete Columns:** Even if a column is empty, simply leave it blank. Do not delete it.
3.  **Rows with no `Session_ID` are ignored:** If you are drafting a row, keep the Session_ID blank and it won't appear in the book.

## Required Columns

### 1. Sorting & Structure (Mandatory)

These columns control the order of the talks in the PDF.

*   **`Session_ID`**
    *   **Content:** A number (e.g., `1`, `2`, `3`).
    *   **Function:** Controls the order of the Sessions.
    *   *Example:* All talks in "Opening Session" should have Session_ID `1`. All talks in "Genetics" should have Session_ID `2`.
*   **`Session_Name`**
    *   **Content:** The title of the session (e.g., "Pollination Ecology", "Genetics").
    *   **Function:** This text appears as the main Chapter/Section Header in the book.
    *   *Tip:* Ensure this is spelled identically for all rows in the same session.
*   **`Talk_Order`**
    *   **Content:** A number (e.g., `1`, `2`, `3`).
    *   **Function:** Controls the order of talks *within* that session.

### 2. Talk Details (Content)

These columns provide the actual text displayed on the page.

*   **`Presentation_title`**
    *   The title of the talk.
*   **`Names`**
    *   The name of the presenter (e.g., "Jane Doe").
*   **`Affiliated Institution`**
    *   The affiliation of the presenter (e.g., "University of Barcelona").
*   **`Authors`**
    *   List of all authors (e.g., "Doe, J., Smith, A., & Jones, B.").
*   **`Abstract_presentations_text`**
    *   The full body text of the abstract.
    *   *Note:* Avoid special formatting characters if possible.

## Troubleshooting

*   **"Error: Can't find column `xyz`"**: Someone likely renamed a header. Check the exact names above.
*   **Talks appearing in wrong order**: Check the `Talk_Order` numbers.
*   **Session split into two**: Check `Session_Name`. If one row says "Genetics" and another says " Genetics" (with a space), they might be treated as different sessions.
