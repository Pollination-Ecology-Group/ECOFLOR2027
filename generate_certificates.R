# =============================================================================
# ECOFLOR 2027 — Certificate Generator
# =============================================================================
# Generates three types of PDF certificates from the "Submissions" tab:
#   1. Certificate of Attendance     — rows with Attended == "YES"
#   2. Certificate of Presentation   — attended + Status "Accepted" + Final_format set
#   3. Certificate of Workshop       — attended + workshop title(s) in Workshop_attended
#
# After the meeting, add two columns at the right end of "Submissions":
#   Attended           YES for everyone who came
#   Workshop_attended  title(s) of the workshop(s) attended, separated by ";"
#                      (must match the titles in WORKSHOPS below)
#
# OUTPUT: documents/certificates/generated/
# REQUIRES: googlesheets4, dplyr, pagedown (Chrome must be installed)
# DATA: the sheet set in R/ecoflor_submissions.R (or example data without it)
# =============================================================================

# ── 0. INSTALL MISSING PACKAGES ──────────────────────────────────────────────
required_packages <- c("googlesheets4", "dplyr", "stringr", "pagedown", "htmltools", "base64enc")
missing <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  message("Installing missing packages: ", paste(missing, collapse = ", "))
  install.packages(missing)
}

library(googlesheets4)
library(dplyr)
library(stringr)
library(htmltools)

# ── 1. CONFIGURATION ─────────────────────────────────────────────────────────

# Paths (relative to project root — set working directory to project root first)
OUTPUT_DIR <- "documents/certificates/generated"
LOGO_ECOFLOR <- normalizePath("images/logos/logo2027.png", mustWork = FALSE)
LOGO_RIGHT <- normalizePath("images/logos/prf_logo.svg", mustWork = FALSE)
SIGNATURE <- normalizePath("documents/certificates/signature_2027.png", mustWork = FALSE)

# Texts
MEETING_NAME <- "24th ECOFLOR Meeting"
MEETING_SUB <- "24th Annual Meeting of the Floral Ecology and Evolution Working Group"
MEETING_DATES <- "3rd to 6th February 2027"
MEETING_PLACE <- "Prague, Czech Republic"
FOOTER_LINE <- "Faculty of Science, Charles University, Prague · 3–6 February 2027"
SIGNATORY <- "Jakub Štenc"
SIGNATORY_ROLE <- "On behalf of the Organising Committee"

# Workshops: exact titles (as typed in Workshop_attended) → length and date
WORKSHOPS <- list(
  # "Workshop title" = list(hours = 3, date = "Wednesday, February 3, 2027")
)

# Encode images as Base64 so they work in self-contained HTML (no path issues)
img_to_base64 <- function(path) {
  if (!file.exists(path)) {
    return("")
  }
  ext <- tolower(tools::file_ext(path))
  mime <- switch(ext,
    png = "image/png",
    jpg = ,
    jpeg = "image/jpeg",
    svg = "image/svg+xml",
    "image/png"
  )
  raw <- readBin(path, "raw", file.info(path)$size)
  paste0("data:", mime, ";base64,", base64enc::base64encode(raw))
}

# (base64enc is already listed in required_packages above)

# ── 2. AUTHENTICATE & READ DATA ──────────────────────────────────────────────

message("\n=== ECOFLOR 2027 Certificate Generator ===\n")
source("R/ecoflor_submissions.R")

message("Reading data from the Submissions tab...")
data_raw <- read_tab("Submissions") %>%
  mutate(across(everything(), ~ str_trim(tidyr::replace_na(.x, ""))))
message("  → ", nrow(data_raw), " rows read, ", ncol(data_raw), " columns.")

if (!"Attended" %in% names(data_raw)) {
  stop("Add a column 'Attended' (YES for participants who came) at the right end of the Submissions tab.", call. = FALSE)
}
if (!"Workshop_attended" %in% names(data_raw)) data_raw$Workshop_attended <- ""

attendees <- data_raw %>%
  filter(toupper(Attended) == "YES") %>%
  mutate(name = str_squish(paste(First_name, Last_name)))

# ── 4. CREATE OUTPUT DIRECTORY ───────────────────────────────────────────────
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
message("\nOutput directory: ", OUTPUT_DIR)

# ── 5. HTML CERTIFICATE TEMPLATE ─────────────────────────────────────────────
# Builds a full self-contained HTML page for one certificate

build_certificate_html <- function(body_html,
                                   logo_ecoflor_b64,
                                   logo_aeet_b64,
                                   signature_b64) {
  sig_html <- if (nchar(signature_b64) > 0) {
    paste0('<img src="', signature_b64, '" alt="Signature" style="height:60px; margin-bottom:2px;">')
  } else {
    ""
  }

  paste0('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<style>
  @import url("https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,600;1,400&family=Montserrat:wght@300;600;700&display=swap");

  * { box-sizing: border-box; margin: 0; padding: 0; }

  @page {
    size: A4 landscape;
    margin: 0;
  }

  body {
    width: 297mm;
    height: 210mm;
    font-family: "EB Garamond", Georgia, serif;
    background: #fff;
    color: #2c2c2c;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: space-between;
    padding: 0;
    overflow: hidden;
  }

  /* ── DECORATIVE BORDER ── */
  .border-outer {
    position: absolute;
    inset: 8mm;
    border: 2.5px solid #C8882A;
    pointer-events: none;
  }
  .border-inner {
    position: absolute;
    inset: 11mm;
    border: 0.8px solid #C8882A;
    pointer-events: none;
  }

  /* ── HEADER ── */
  .header {
    width: 100%;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8mm 20mm 3mm;
    border-bottom: 1px solid #e0cba0;
  }
  .header img {
    height: 30mm;
    max-width: 60mm;
    object-fit: contain;
  }
  .header-center {
    text-align: center;
    flex: 1;
    padding: 0 10mm;
  }
  .conference-label {
    font-family: "Montserrat", sans-serif;
    font-weight: 300;
    font-size: 9pt;
    letter-spacing: 3px;
    text-transform: uppercase;
    color: #888;
    margin-bottom: 3px;
  }
  .conference-name {
    font-family: "Montserrat", sans-serif;
    font-weight: 700;
    font-size: 14pt;
    color: #C8882A;
    letter-spacing: 1px;
  }
  .conference-sub {
    font-size: 8pt;
    color: #666;
    font-style: italic;
    margin-top: 2px;
  }

  /* ── MAIN BODY ── */
  .content {
    flex: 1;
    min-height: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 1mm 28mm;
    text-align: center;
    line-height: 1.45;
  }

  .cert-title {
    font-family: "Montserrat", sans-serif;
    font-weight: 600;
    font-size: 10.5pt;
    letter-spacing: 3px;
    text-transform: uppercase;
    color: #C8882A;
    margin-bottom: 2.5mm;
    border-bottom: 1px solid #e0cba0;
    padding-bottom: 1.5mm;
    width: 80%;
  }

  .cert-body {
    font-size: 10.5pt;
    color: #333;
    max-width: 90%;
  }

  .cert-name {
    font-size: 14pt;
    font-weight: 600;
    color: #1a1a1a;
    font-style: italic;
    display: block;
    margin: 2mm 0;
  }

  .cert-institution {
    font-size: 11pt;
    color: #555;
    font-style: italic;
  }

  .cert-pres-title {
    font-size: 10pt;
    font-style: italic;
    color: #2c2c2c;
    font-weight: 600;
  }

  .cert-type-badge {
    display: inline-block;
    background: #C8882A;
    color: #fff;
    font-family: "Montserrat", sans-serif;
    font-weight: 600;
    font-size: 7.5pt;
    letter-spacing: 2px;
    padding: 2px 9px;
    border-radius: 2px;
    margin: 1.5mm 0;
    text-transform: uppercase;
  }

  /* ── FOOTER ── */
  .footer {
    width: 100%;
    flex-shrink: 0;
    display: flex;
    align-items: flex-end;
    justify-content: center;
    padding: 2mm 22mm 9mm;
    border-top: 1px solid #e0cba0;
  }

  .signature-block {
    text-align: center;
  }
  .signature-block img {
    height: 60px;
    margin-bottom: 1mm;
    display: block;
    margin-left: auto;
    margin-right: auto;
  }
  .sig-name {
    font-weight: 600;
    font-size: 10pt;
    color: #1a1a1a;
  }
  .sig-role {
    font-size: 8.5pt;
    color: #666;
    font-style: italic;
  }

  .location-date {
    font-size: 8pt;
    color: #999;
    font-style: italic;
    margin-bottom: 3mm;
  }
</style>
</head>
<body>

<div class="border-outer"></div>
<div class="border-inner"></div>

<!-- HEADER -->
<div class="header">
  <img src="', logo_ecoflor_b64, '" alt="ECOFLOR 2027">
  <div class="header-center">
    <div class="conference-label">Certificate</div>
    <div class="conference-name">ECOFLOR 2027</div>
    <div class="conference-sub">', MEETING_SUB, '</div>
  </div>
  <img src="', logo_aeet_b64, '" alt="Faculty of Science, Charles University">
</div>

<!-- CONTENT -->
<div class="content">
', body_html, '
</div>

<!-- FOOTER -->
<div class="footer">
  <div class="signature-block">
    <div class="location-date">', FOOTER_LINE, '</div>
', sig_html, '
    <div class="sig-name">', SIGNATORY, '</div>
    <div class="sig-role">', SIGNATORY_ROLE, '</div>
  </div>
</div>

</body>
</html>')
}

# ── 6. GENERATE PDF FROM HTML ────────────────────────────────────────────────
generate_pdf <- function(html_content, output_path) {
  # Write HTML to a temp file, then convert to PDF with Chrome
  tmp_html <- tempfile(fileext = ".html")
  writeLines(html_content, tmp_html, useBytes = TRUE)
  tryCatch(
    {
      pagedown::chrome_print(
        input = tmp_html,
        output = output_path,
        wait = 3,
        options = list(
          printBackground = TRUE,
          landscape       = TRUE,
          paperWidth      = 11.69, # A4 landscape inches
          paperHeight     = 8.27,
          marginTop       = 0,
          marginBottom    = 0,
          marginLeft      = 0,
          marginRight     = 0
        )
      )
      message("  ✓ ", basename(output_path))
    },
    error = function(e) {
      message("  ✗ FAILED: ", basename(output_path), " — ", conditionMessage(e))
    }
  )
  unlink(tmp_html)
}

# Escapes HTML and turns _species name_ (form convention) into italics
italics_html <- function(x) {
  str_replace_all(htmltools::htmlEscape(x), "_([^_]+)_", "<i>\\1</i>")
}

# Safe filename: remove special characters
safe_name <- function(x) {
  x <- iconv(x, to = "ASCII//TRANSLIT")
  x <- str_replace_all(x, "[^A-Za-z0-9_-]", "_")
  x <- str_replace_all(x, "_+", "_")
  str_trim(x, "both")
}

# ── 7. LOAD IMAGES AS BASE64 ─────────────────────────────────────────────────
message("\nEncoding logos...")
logo_ecoflor_b64 <- img_to_base64(LOGO_ECOFLOR)
logo_aeet_b64 <- img_to_base64(LOGO_RIGHT)
signature_b64 <- img_to_base64(SIGNATURE)

if (nchar(logo_ecoflor_b64) == 0) warning("ECOFLOR logo not found at: ", LOGO_ECOFLOR)
if (nchar(logo_aeet_b64) == 0) warning("Right-hand logo not found at: ", LOGO_RIGHT)
if (nchar(signature_b64) == 0) warning("Signature not found at: ", SIGNATURE)

# ── 8. ATTENDANCE CERTIFICATES ───────────────────────────────────────────────
message("\n--- [1/3] Attendance Certificates ---")

attendance_data <- attendees %>%
  transmute(name, institution = Affiliation) %>%
  filter(nzchar(name))

message("  Generating ", nrow(attendance_data), " attendance certificates...")
att_dir <- file.path(OUTPUT_DIR, "1_attendance")
dir.create(att_dir, showWarnings = FALSE)

for (i in seq_len(nrow(attendance_data))) {
  row <- attendance_data[i, ]
  name <- row$name
  inst <- if (!is.na(row$institution) && nzchar(row$institution)) row$institution else "their institution"

  body <- paste0(
    '<div class="cert-title">Certificate of Attendance</div>
    <div class="cert-body">
      We hereby certify that,
      <span class="cert-name">', htmltools::htmlEscape(name), '</span>
      with affiliation in the
      <span class="cert-institution">', htmltools::htmlEscape(inst), "</span>
      <br><br>
      has attended the <strong>", MEETING_NAME, "</strong>,<br>
      held from <strong>", MEETING_DATES, "</strong>, in <strong>", MEETING_PLACE, "</strong>.
    </div>"
  )

  html <- build_certificate_html(body, logo_ecoflor_b64, logo_aeet_b64, signature_b64)
  out <- file.path(att_dir, paste0("attendance_", safe_name(name), ".pdf"))
  generate_pdf(html, out)
}

message("  Done. PDFs saved to: ", att_dir)

# ── 9. PRESENTATION CERTIFICATES ─────────────────────────────────────────────
message("\n--- [2/3] Presentation Certificates ---")

pres_data <- attendees %>%
  filter(Status == "Accepted", Final_format %in% c("Oral", "Rising Star", "Poster")) %>%
  transmute(
    name,
    pres_type = ifelse(Final_format == "Poster", "Poster", "Oral"),
    pres_title = Title,
    # plain author names, without affiliation numbers and the presenter mark
    authors = purrr::map_chr(Authors, ~ paste(parse_authors(.x)$name, collapse = ", "))
  ) %>%
  filter(nzchar(name))

message("  Generating ", nrow(pres_data), " presentation certificates...")
pres_dir <- file.path(OUTPUT_DIR, "2_presentations")
dir.create(pres_dir, showWarnings = FALSE)

for (i in seq_len(nrow(pres_data))) {
  row <- pres_data[i, ]
  name <- row$name
  ptype <- toupper(trimws(row$pres_type)) # "ORAL" or "POSTER"
  title <- if (!is.na(row$pres_title) && nzchar(row$pres_title)) row$pres_title else "(untitled)"
  auths <- if (!is.na(row$authors) && nzchar(row$authors)) row$authors else name

  body <- paste0(
    '<div class="cert-title">Certificate of Presentation</div>
    <div class="cert-body">
      For any purpose it deems appropriate, we hereby certify that,
      <span class="cert-name">', htmltools::htmlEscape(name), '</span>
      <span class="cert-type-badge">', htmltools::htmlEscape(ptype), '</span>
      <br>
      has presented a contribution entitled<br>
      <span class="cert-pres-title">&ldquo;', italics_html(title), "&rdquo;</span>
      <br><br>
      scheduled within the <strong>", MEETING_NAME, "</strong>,<br>
      held from <strong>", MEETING_DATES, "</strong>, in <strong>", MEETING_PLACE, "</strong>.
      <br><br>
      <small><em>Authors of the contribution:</em><br>", htmltools::htmlEscape(auths), "</small>
    </div>"
  )

  html <- build_certificate_html(body, logo_ecoflor_b64, logo_aeet_b64, signature_b64)
  out <- file.path(pres_dir, paste0(tolower(ptype), "_", safe_name(name), ".pdf"))
  generate_pdf(html, out)
}

message("  Done. PDFs saved to: ", pres_dir)

# ── 10. WORKSHOP CERTIFICATES ─────────────────────────────────────────────────
message("\n--- [3/3] Workshop Certificates ---")

workshop_rows <- attendees %>%
  filter(nzchar(Workshop_attended)) %>%
  mutate(ws = str_split(Workshop_attended, ";")) %>%
  tidyr::unnest(ws) %>%
  mutate(ws = str_trim(ws)) %>%
  filter(nzchar(ws))

unknown <- setdiff(unique(workshop_rows$ws), names(WORKSHOPS))
if (length(unknown)) {
  warning("Workshop titles not listed in WORKSHOPS (skipped): ", paste(unknown, collapse = " | "), call. = FALSE)
}
workshop_rows <- workshop_rows %>% filter(ws %in% names(WORKSHOPS))

if (nrow(workshop_rows) == 0) {
  message("  Skipping — nobody has a known workshop in Workshop_attended.")
} else {
  work_dir <- file.path(OUTPUT_DIR, "3_workshops")
  for (i in seq_len(nrow(workshop_rows))) {
    name <- workshop_rows$name[i]
    ws_name <- workshop_rows$ws[i]
    ws <- WORKSHOPS[[ws_name]]

    body <- paste0(
      '<div class="cert-title">Certificate of Attendance to Workshop</div>
      <div class="cert-body">
        We hereby certify that,
        <span class="cert-name">', htmltools::htmlEscape(name), '</span>
        has attended the Workshop<br>
        <span class="cert-pres-title">&ldquo;', htmltools::htmlEscape(ws_name), "&rdquo;</span>
        <br><br>
        with a total duration of <strong>", ws$hours, " teaching hours</strong>,<br>
        held on <strong>", ws$date, "</strong>,<br>
        as part of the Scientific program of the <strong>", MEETING_NAME, "</strong>,<br>
        held from <strong>", MEETING_DATES, "</strong>, in <strong>", MEETING_PLACE, "</strong>.
      </div>"
    )

    html <- build_certificate_html(body, logo_ecoflor_b64, logo_aeet_b64, signature_b64)
    ws_folder <- file.path(work_dir, safe_name(substr(ws_name, 1, 50)))
    dir.create(ws_folder, showWarnings = FALSE, recursive = TRUE)
    generate_pdf(html, file.path(ws_folder, paste0("workshop_", safe_name(name), ".pdf")))
  }
  message("  Done. ", nrow(workshop_rows), " workshop certificate(s) saved to: ", work_dir)
}

# ── 11. SUMMARY ───────────────────────────────────────────────────────────────
message("\n=== Certificate generation complete! ===")
message("Output folder: ", normalizePath(OUTPUT_DIR))
message("Contents:")
all_pdfs <- list.files(OUTPUT_DIR, pattern = "\\.pdf$", recursive = TRUE, full.names = FALSE)
message("  ", length(all_pdfs), " PDF(s) generated:")
for (f in all_pdfs) message("  • ", f)
