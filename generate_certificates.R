# =============================================================================
# ECOFLOR 2026 — Certificate Generator
# =============================================================================
# Generates three types of PDF certificates:
#   1. Certificate of Attendance (for everyone with Attending == "YES")
#   2. Certificate of Presentation (for Oral and Poster presenters)
#   3. Certificate of Attendance to Workshop (for workshop attendees)
#
# OUTPUT: documents/certificates/generated/
# REQUIRES: googlesheets4, dplyr, pagedown (Chrome must be installed)
# AUTHENTICATION: Run gs4_auth() once to authenticate with Google.
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
SHEET_URL <- "https://docs.google.com/spreadsheets/d/1zsfhYz32GoeKz8qzaHgDKsc-InRxitIsdnc9JWG-4OU/edit?usp=sharing"
OUTPUT_DIR <- "documents/certificates/generated"
LOGO_ECOFLOR <- normalizePath("images/IMG_1108.jpg", mustWork = FALSE)
LOGO_AEET <- normalizePath("images/logos/AEET.png", mustWork = FALSE)
SIGNATURE <- normalizePath("documents/certificates/singature.png", mustWork = FALSE)

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
    "image/png"
  )
  raw <- readBin(path, "raw", file.info(path)$size)
  paste0("data:", mime, ";base64,", base64enc::base64encode(raw))
}

# (base64enc is already listed in required_packages above)

# ── 2. AUTHENTICATE & READ DATA ──────────────────────────────────────────────

message("\n=== ECOFLOR 2026 Certificate Generator ===\n")
message("Authenticating with Google Sheets...")
message("(If this is your first time, a browser window will open for OAuth.)")
gs4_auth() # Comment this out and use gs4_deauth() if sheet becomes public

message("Reading data from Google Sheet...")
data_raw <- read_sheet(SHEET_URL, col_types = "c")

message("  → ", nrow(data_raw), " rows read, ", ncol(data_raw), " columns.")

# ── 3. IDENTIFY WORKSHOP COLUMNS ─────────────────────────────────────────────
# Workshop columns are those whose header contains "Wednesday" or "workshop"
col_names <- names(data_raw)
workshop_cols <- col_names[
  str_detect(col_names, regex("workshop|Wednesday|ateli[e|è]r", ignore_case = TRUE))
]
message("Workshop columns detected (", length(workshop_cols), "): ")
for (wc in workshop_cols) message("  • ", wc)
if (length(workshop_cols) == 0) {
  message("  WARNING: No workshop columns found! Check column names in the sheet.")
}

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
  <img src="', logo_ecoflor_b64, '" alt="ECOFLOR 2026">
  <div class="header-center">
    <div class="conference-label">Certificate</div>
    <div class="conference-name">ECOFLOR 2026</div>
    <div class="conference-sub">23rd Meeting of the Spanish Society for Pollination Ecology</div>
  </div>
  <img src="', logo_aeet_b64, '" alt="AEET">
</div>

<!-- CONTENT -->
<div class="content">
', body_html, '
</div>

<!-- FOOTER -->
<div class="footer">
  <div class="signature-block">
    <div class="location-date">Tortosa, Catalonia, Spain · 11–14 February 2026</div>
', sig_html, '
    <div class="sig-name">Carlos Hernández-Castellano</div>
    <div class="sig-role">On behalf of the Scientific Committee</div>
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
logo_aeet_b64 <- img_to_base64(LOGO_AEET)
signature_b64 <- img_to_base64(SIGNATURE)

if (nchar(logo_ecoflor_b64) == 0) warning("ECOFLOR logo not found at: ", LOGO_ECOFLOR)
if (nchar(logo_aeet_b64) == 0) warning("AEET logo not found at: ", LOGO_AEET)
if (nchar(signature_b64) == 0) warning("Signature not found at: ", SIGNATURE)

# ── 8. ATTENDANCE CERTIFICATES ───────────────────────────────────────────────
message("\n--- [1/3] Attendance Certificates ---")

# Identify the actual column names present in the data
name_col <- intersect(c("Names", "Name"), names(data_raw))[1]
inst_col <- intersect(c("Affiliated Institution", "Institution"), names(data_raw))[1]

attendance_data <- data_raw %>%
  filter(Attending == "YES") %>%
  mutate(
    name        = if (!is.na(name_col)) .data[[name_col]] else NA_character_,
    institution = if (!is.na(inst_col)) .data[[inst_col]] else NA_character_
  ) %>%
  select(name, institution) %>%
  filter(!is.na(name), nzchar(name))

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
      has attended the <strong>23rd ECOFLOR Meeting</strong>,<br>
      held from <strong>11th to 14th February 2026</strong>, in <strong>Tortosa, Catalonia, Spain</strong>.
    </div>"
  )

  html <- build_certificate_html(body, logo_ecoflor_b64, logo_aeet_b64, signature_b64)
  out <- file.path(att_dir, paste0("attendance_", safe_name(name), ".pdf"))
  generate_pdf(html, out)
}

message("  Done. PDFs saved to: ", att_dir)

# ── 9. PRESENTATION CERTIFICATES ─────────────────────────────────────────────
message("\n--- [2/3] Presentation Certificates ---")

pres_type_col <- intersect(c("Presentation"), names(data_raw))[1]
title_col_oral <- intersect(c("Presentation_title", "Presentation title"), names(data_raw))[1]
title_col_poster <- intersect(c("Presentation title poster", "Presentation_title_poster"), names(data_raw))[1]
authors_col <- intersect(c("Authors", "Authors poster", "Authors  poster"), names(data_raw))[1]

pres_data <- data_raw %>%
  filter(
    !is.na(.data[[pres_type_col]]),
    nzchar(.data[[pres_type_col]]),
    str_detect(.data[[pres_type_col]], regex("oral|poster", ignore_case = TRUE))
  ) %>%
  mutate(
    name = if (!is.na(name_col)) .data[[name_col]] else NA_character_,
    pres_type = if (!is.na(pres_type_col)) .data[[pres_type_col]] else NA_character_,
    # For oral presentations use the oral-title column;
    # for posters use the poster-title column (falls back to oral-title if absent).
    pres_title = case_when(
      str_detect(
        ifelse(!is.na(pres_type_col), .data[[pres_type_col]], ""),
        regex("poster", ignore_case = TRUE)
      ) & !is.na(title_col_poster) ~ .data[[title_col_poster]],
      !is.na(title_col_oral) ~ .data[[title_col_oral]],
      TRUE ~ NA_character_
    ),
    authors = if (!is.na(authors_col)) .data[[authors_col]] else NA_character_
  ) %>%
  select(name, pres_type, pres_title, authors) %>%
  filter(!is.na(name), nzchar(name))

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
      <span class="cert-pres-title">&ldquo;', htmltools::htmlEscape(title), "&rdquo;</span>
      <br><br>
      scheduled within the <strong>23rd ECOFLOR Meeting</strong>,<br>
      held from <strong>11th to 14th February 2026</strong>, in <strong>Tortosa, Catalonia, Spain</strong>.
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

workshop_col <- "Workshops (Wednesday 11th February)"

if (!workshop_col %in% names(data_raw)) {
  message("  Skipping — '", workshop_col, "' column not detected.")
} else {
  work_dir <- file.path(OUTPUT_DIR, "3_workshops")
  dir.create(work_dir, showWarnings = FALSE)

  total_workshop <- 0

  ws1_clean <- "Nesting traps for cavity-nesting bees and wasps in ecological studies: biology, ecology, materials and methods"
  ws2_clean <- "Perspectives in plant-pollinator systems research in the new era of Nature Restoration"

  workshop_attendees <- data_raw %>%
    filter(
      Attending == "YES",
      !is.na(.data[[workshop_col]]),
      nzchar(.data[[workshop_col]])
    ) %>%
    mutate(
      name = if (!is.na(name_col)) .data[[name_col]] else NA_character_,
      ws_val = .data[[workshop_col]]
    ) %>%
    select(name, ws_val) %>%
    filter(!is.na(name), nzchar(name))

  message("  Generating certificates for workshop attendees...")

  dir.create(file.path(work_dir, safe_name(substr(ws1_clean, 1, 50))), showWarnings = FALSE)
  dir.create(file.path(work_dir, safe_name(substr(ws2_clean, 1, 50))), showWarnings = FALSE)

  for (i in seq_len(nrow(workshop_attendees))) {
    name <- workshop_attendees$name[i]
    val <- workshop_attendees$ws_val[i]

    attended_ws1 <- str_detect(val, "10-13h") || str_detect(val, regex("both", ignore_case = TRUE))
    attended_ws2 <- str_detect(val, "15-18h") || str_detect(val, regex("both", ignore_case = TRUE))

    gen_ws_cert <- function(ws_name) {
      body <- paste0(
        '<div class="cert-title">Certificate of Attendance to Workshop</div>
        <div class="cert-body">
          We hereby certify that,
          <span class="cert-name">', htmltools::htmlEscape(name), '</span>
          has attended the Workshop<br>
          <span class="cert-pres-title">&ldquo;', htmltools::htmlEscape(ws_name), "&rdquo;</span>
          <br><br>
          with a total duration of <strong>3 teaching hours</strong>,<br>
          held on <strong>Wednesday, February 11, 2026</strong>,<br>
          as part of the Scientific program of the <strong>23rd ECOFLOR Meeting</strong>,<br>
          held from <strong>11th to 14th February 2026</strong>, in <strong>Tortosa, Catalonia, Spain</strong>.
        </div>"
      )

      html <- build_certificate_html(body, logo_ecoflor_b64, logo_aeet_b64, signature_b64)
      ws_folder <- file.path(work_dir, safe_name(substr(ws_name, 1, 50)))
      out <- file.path(ws_folder, paste0("workshop_", safe_name(name), ".pdf"))
      generate_pdf(html, out)
    }

    if (attended_ws1) {
      gen_ws_cert(ws1_clean)
      total_workshop <- total_workshop + 1
    }
    if (attended_ws2) {
      gen_ws_cert(ws2_clean)
      total_workshop <- total_workshop + 1
    }
  }

  message("  Done. ", total_workshop, " workshop certificate(s) saved to: ", work_dir)
}

# ── 11. SUMMARY ───────────────────────────────────────────────────────────────
message("\n=== Certificate generation complete! ===")
message("Output folder: ", normalizePath(OUTPUT_DIR))
message("Contents:")
all_pdfs <- list.files(OUTPUT_DIR, pattern = "\\.pdf$", recursive = TRUE, full.names = FALSE)
message("  ", length(all_pdfs), " PDF(s) generated:")
for (f in all_pdfs) message("  • ", f)
