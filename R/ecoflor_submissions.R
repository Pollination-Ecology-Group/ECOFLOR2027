# =============================================================================
# ECOFLOR 2027 — shared helpers for the programme and the Book of Abstracts
# =============================================================================
# Reads the "Submissions" and "Sessions" tabs that the Google Apps Script
# (submission_pipeline/Code.gs) maintains, checks them and formats the text.
#
# Data source:
#   - SHEET_URL below (or the env variable ECOFLOR_SHEET) → the live Google Sheet
#   - empty / "example" → submission_pipeline/example_*.csv (for testing offline)
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(purrr)
  library(tidyr)
  library(readr)
})

SHEET_URL <- "https://docs.google.com/spreadsheets/d/1Bteqfwar_brI1vX9S5TOdTiFa-sOn9uMuxG4dkG8Bco/edit"

TALK_FORMATS <- c("Oral", "Rising Star")

data_source <- function() {
  src <- Sys.getenv("ECOFLOR_SHEET", SHEET_URL)
  if (src == "" || src == "example") "example" else src
}

read_tab <- function(tab) {
  src <- data_source()
  if (src == "example") {
    file <- file.path("submission_pipeline", paste0("example_", tolower(tab), ".csv"))
    message("Using example data: ", file)
    return(read_csv(file, col_types = cols(.default = col_character()), na = ""))
  }
  googlesheets4::gs4_auth(email = TRUE, cache = ".secrets")
  googlesheets4::read_sheet(src, sheet = tab, col_types = "c", na = "")
}

# ── READING ───────────────────────────────────────────────────────────────────

#' Accepted contributions, joined with their session, in programme order.
read_contributions <- function() {
  subs <- read_tab("Submissions") %>%
    mutate(across(everything(), ~ str_trim(replace_na(.x, ""))))
  sessions <- read_sessions()

  accepted <- subs %>%
    filter(Status == "Accepted") %>%
    mutate(
      Session_ID = suppressWarnings(as.numeric(Session_ID)),
      Order = suppressWarnings(as.numeric(Order)),
      Presenter = str_squish(paste(First_name, Last_name)),
      Student = Career_stage %in% c("Bachelor or Master student", "PhD student")
    )

  check_contributions(accepted, sessions)

  accepted %>%
    left_join(sessions, by = "Session_ID", suffix = c("", "_session")) %>%
    arrange(Session_ID, Order)
}

read_sessions <- function() {
  read_tab("Sessions") %>%
    mutate(across(everything(), ~ str_trim(replace_na(.x, "")))) %>%
    filter(Session_ID != "") %>%
    mutate(
      Session_ID = as.numeric(Session_ID),
      Slot_minutes = suppressWarnings(as.numeric(Slot_minutes))
    ) %>%
    arrange(Session_ID)
}

#' Stops on problems that would silently break the book; warns about the rest.
check_contributions <- function(accepted, sessions) {
  problems <- c(
    sprintf("%s: accepted but no Final_format (Oral / Rising Star / Poster)",
            accepted$Submission_ID[!accepted$Final_format %in% c(TALK_FORMATS, "Poster")]),
    sprintf("%s: accepted but no Session_ID",
            accepted$Submission_ID[is.na(accepted$Session_ID)]),
    sprintf("%s: Session_ID %s is not in the Sessions tab",
            accepted$Submission_ID, accepted$Session_ID)[
      !is.na(accepted$Session_ID) & !accepted$Session_ID %in% sessions$Session_ID],
    sprintf("%s: authors not in the format 'Name (1,2)*; Name (2)'",
            accepted$Submission_ID[!map_lgl(accepted$Authors, authors_ok)])
  )
  if (length(problems)) stop("Fix these rows in the sheet:\n  ", paste(problems, collapse = "\n  "), call. = FALSE)

  no_order <- accepted$Submission_ID[accepted$Final_format %in% TALK_FORMATS & is.na(accepted$Order)]
  if (length(no_order)) warning("Oral talks without Order (listed last): ", paste(no_order, collapse = ", "), call. = FALSE)

  dup <- accepted %>% filter(!is.na(Order)) %>% count(Session_ID, Order) %>% filter(n > 1)
  if (nrow(dup)) warning("Duplicate Order within a session: ",
                         paste0("session ", dup$Session_ID, " order ", dup$Order, collapse = "; "), call. = FALSE)
}

# ── AUTHORS & AFFILIATIONS ────────────────────────────────────────────────────

AUTHOR_RE <- "^\\s*(.+?)\\s*\\(\\s*([0-9][0-9,\\s]*)\\)\\s*(\\*?)\\s*$"

parse_authors <- function(x) {
  parts <- str_split(x, ";")[[1]] %>% str_trim() %>% discard(~ .x == "")
  m <- str_match(parts, AUTHOR_RE)
  tibble(
    name = m[, 2],
    affils = str_replace_all(m[, 3], "\\s", "") %>% str_remove(",$"),
    presenting = m[, 4] == "*"
  )
}

authors_ok <- function(x) {
  a <- parse_authors(x)
  nrow(a) > 0 && !anyNA(a$name)
}

#' "Jana Nováková (1,2)*; John Smith (2)" → "__Jana Nováková__^1,2^, John Smith^2^"
#' The presenting author is underlined; if nobody has *, the presenter is matched by name.
format_authors <- function(x, presenter = "") {
  a <- parse_authors(x)
  if (!any(a$presenting)) a$presenting <- str_to_lower(a$name) == str_to_lower(presenter)
  name <- md_escape(a$name, italics = FALSE)
  name <- ifelse(a$presenting, paste0("[", name, "]{.underline}"), name)
  paste0(name, "^", a$affils, "^", collapse = ", ")
}

#' "1. Dept A\n2. Dept B" → "^1^ Dept A\\\n^2^ Dept B" (one per line)
format_affiliations <- function(x) {
  lines <- str_split(x, "\n")[[1]] %>% str_trim() %>% discard(~ .x == "")
  m <- str_match(lines, "^(\\d+)\\s*[.)]?\\s*(.*)$")
  num <- ifelse(is.na(m[, 2]), "", paste0("^", m[, 2], "^ "))
  txt <- ifelse(is.na(m[, 3]), lines, m[, 3])
  paste0(num, md_escape(txt, italics = FALSE), collapse = "\\\n")
}

# ── TEXT ──────────────────────────────────────────────────────────────────────

#' Escapes characters that Markdown/LaTeX would interpret ($ math, * emphasis, @ citations…).
#' With italics = TRUE, _underscores_ stay active so authors can italicise species names.
md_escape <- function(x, italics = TRUE) {
  special <- if (italics) "([\\\\`*{}\\[\\]<>#|$^~@])" else "([\\\\`*_{}\\[\\]<>#|$^~@])"
  str_replace_all(x, special, "\\\\\\1")
}

#' Abstract paragraphs separated by blank lines, escaped.
format_abstract <- function(x) {
  paras <- str_split(x, "\n\\s*\n")[[1]] %>% str_squish() %>% discard(~ .x == "")
  paste(md_escape(paras), collapse = "\n\n")
}

keywords_of <- function(row) {
  kw <- c(row$Keyword_1, row$Keyword_2, row$Keyword_3)
  kw[!is.na(kw) & kw != ""]
}

# ── PROGRAMME TIMES ───────────────────────────────────────────────────────────

#' Start time of each talk: session start + (position − 1) × slot length.
add_talk_times <- function(orals, default_slot = 12) {
  orals %>%
    group_by(Session_ID) %>%
    arrange(Order, .by_group = TRUE) %>%
    mutate(
      slot = coalesce(Slot_minutes, default_slot),
      start = as.POSIXct(paste("2000-01-01", Start_time), format = "%Y-%m-%d %H:%M", tz = "UTC") +
        (row_number() - 1) * slot * 60,
      Time = format(start, "%H:%M")
    ) %>%
    ungroup() %>%
    select(-slot, -start)
}
