/**
 * ECOFLOR 2027 — Registration & abstract submission pipeline
 * =============================================================================
 * Google Apps Script. Paste this file into a new project at
 * https://script.google.com, then run `setup()` once (see README.md).
 *
 * What `setup()` creates in your Google Drive:
 *   1. The Google Form (registration + abstract submission).
 *   2. A linked Google Sheet with these tabs:
 *        - "Form Responses 1"  raw form output (Google's own; never edit, it is the backup)
 *        - "Submissions"       one clean row per participant, filled automatically.
 *                              The review columns on the right are for the organisers.
 *        - "Sessions"          session names, day, start time and chair (for the programme)
 *        - "Keyword counts"    live count of keywords, to help build sessions
 *   3. A trigger that copies every new or edited response into "Submissions".
 *
 * The R/Quarto side (R/ecoflor_submissions.R) reads the "Submissions" and
 * "Sessions" tabs, so keep those column names unchanged.
 */

// ── CONFIGURATION ────────────────────────────────────────────────────────────

const CONFIG = {
  formTitle: 'ECOFLOR 2027 – Registration & Abstract Submission',
  sheetTitle: 'ECOFLOR 2027 – Submissions',
  idPrefix: 'EF27-',
  deadline: '30 November 2026',
  maxTitleChars: 200,
  maxAbstractWords: 200,
  // Keyword configuration: 1 primary (required) + up to 2 optional
  primaryKeywords: 1,
  optionalKeywords: 2,
  sendConfirmationEmail: true,
  replyTo: 'ecoflor2027@googlegroups.com',
};

// Up to 15 broad topics, each close to a possible session (cf. ECOFLOR 2026 sessions),
// so that grouping abstracts into sessions is mostly a matter of sorting by Keyword_1.
const KEYWORDS = [
  'Floral evolution & speciation',
  'Breeding systems & reproductive success',
  'Floral traits & plasticity',
  'Floral signals & rewards (scent, colour, nectar)',
  'Pollen transfer & pollination efficiency',
  'Pollinator behaviour & foraging',
  'Communities & plant–pollinator networks',
  'Mountain & alpine ecosystems',
  'Global change (climate, land use, pollution)',
  'Agriculture & applied pollination',
  'Urban ecology',
  'Conservation, restoration & rewilding',
  'Herbivores, microbes & pathogens',
  'Monitoring, citizen science & new methods (AI, imaging)',
  'Theory, modelling & macroecology',
];

const CONTRIBUTION = {
  oral: 'Oral presentation',
  poster: 'Poster',
  either: 'Oral or poster (organisers decide)',
  risingStar: 'Rising Stars talk (longer talk for early-career researchers)',
  none: 'No contribution (attending only)',
};

// Columns filled automatically from the form, in this order. Never type here:
// an author's edit would overwrite it (ask them to use their edit link instead).
const AUTO_HEADERS = [
  'Submission_ID', 'Submitted', 'Last_edited', 'Email',
  'First_name', 'Last_name', 'Affiliation', 'Country', 'Career_stage',
  'Contribution', 'Title', 'Authors', 'Affiliations', 'Abstract', 'Word_count',
  'Keyword_primary', 'Keyword_optional',
  'Workshop', 'Workshop_proposal', 'Excursion', 'Dinner', 'Diet', 'Diet_notes',
  'Invitation_letter', 'Comments', 'Response_ID', 'Edit_URL',
];

// Columns for the organisers. The script never writes into them.
const REVIEW_HEADERS = [
  'Status', 'Final_format', 'Session_ID', 'Order', 'Reviewer', 'Review_notes',
];

const STATUS_VALUES = ['Pending', 'Accepted', 'Rejected', 'Withdrawn'];
const FORMAT_VALUES = ['Oral', 'Rising Star', 'Poster'];

const SESSION_HEADERS = [
  'Session_ID', 'Session_Name', 'Type', 'Day', 'Start_time', 'Slot_minutes', 'Chair',
];

// ── SETUP (run once) ─────────────────────────────────────────────────────────

function setup() {
  const props = PropertiesService.getScriptProperties();
  if (props.getProperty('FORM_ID')) {
    throw new Error('Setup has already been run. Delete the script properties ' +
      '(Project Settings → Script Properties) if you really want a second form.');
  }

  const form = FormApp.create(CONFIG.formTitle);
  const items = buildForm_(form);

  // Set up our tabs first: linking the form adds Google's "Form Responses 1" tab.
  const ss = SpreadsheetApp.create(CONFIG.sheetTitle);
  setupSheets_(ss);
  form.setDestination(FormApp.DestinationType.SPREADSHEET, ss.getId());

  props.setProperties({
    FORM_ID: form.getId(),
    SHEET_ID: ss.getId(),
    ITEM_MAP: JSON.stringify(items),
  });

  ScriptApp.newTrigger('onFormSubmit').forForm(form).onFormSubmit().create();

  Logger.log('Form (edit):      ' + form.getEditUrl());
  Logger.log('Form (public):    ' + form.getPublishedUrl());
  Logger.log('Spreadsheet:      ' + ss.getUrl());
}

// ── FORM ─────────────────────────────────────────────────────────────────────

/** Builds all questions and returns {key: itemId} so answers are found by ID, not title. */
function buildForm_(form) {
  const items = {};
  const add = (key, item) => { items[key] = item.getId(); return item; };

  form.setDescription(
    'ECOFLOR 2027 – 24th Annual Meeting of the Floral Ecology and Evolution Working Group, ' +
    '3–6 February 2027, Faculty of Science, Charles University, Prague.\n\n' +
    'Participation is free of charge, but registration is mandatory. ' +
    'Deadline for registration and abstracts: ' + CONFIG.deadline + '.\n\n' +
    'One form per participant. Each participant may present one contribution as the main author. ' +
    'After submitting you will get a link to edit your response until the deadline.');
  form.setCollectEmail(true);
  form.setAllowResponseEdits(true);
  form.setProgressBar(true);
  form.setConfirmationMessage(
    'Thank you! Your registration has been received. You will get a confirmation email ' +
    'with a link to edit your response before the deadline.');

  // Page 1 — participant
  form.addSectionHeaderItem().setTitle('About you');
  add('First_name', form.addTextItem().setTitle('First name').setRequired(true));
  add('Last_name', form.addTextItem().setTitle('Last name').setRequired(true));
  add('Affiliation', form.addTextItem().setTitle('Your affiliation')
    .setHelpText('Department, Institution, City, Country — e.g. "Department of Zoology, Faculty of Science, Charles University, Prague, Czech Republic"')
    .setRequired(true));
  add('Country', form.addTextItem().setTitle('Country').setRequired(true));
  add('Career_stage', form.addMultipleChoiceItem().setTitle('Career stage')
    .setHelpText('Students are eligible for the best student presentation award.')
    .setChoiceValues(['Bachelor or Master student', 'PhD student', 'Postdoc',
      'Senior researcher / faculty', 'Other'])
    .setRequired(true));
  const contribution = add('Contribution', form.addMultipleChoiceItem()
    .setTitle('Do you want to present?').setRequired(true));

  // Page 2 — abstract (oral and poster share the same questions → one column each)
  const abstractPage = form.addPageBreakItem().setTitle('Your contribution')
    .setHelpText('Plain text only, in English. Please follow the formats exactly — ' +
      'they are used to typeset the Book of Abstracts automatically.');

  add('Title', form.addTextItem().setTitle('Title')
    .setHelpText('Sentence case, no full stop at the end. Use _underscores_ for species names in italics, e.g. "Pollen limitation in _Primula veris_".')
    .setRequired(true)
    .setValidation(FormApp.createTextValidation()
      .requireTextLengthLessThanOrEqualTo(CONFIG.maxTitleChars)
      .setHelpText('Maximum ' + CONFIG.maxTitleChars + ' characters.')
      .build()));

  add('Authors', form.addParagraphTextItem().setTitle('Authors')
    .setHelpText('All authors in order, separated by semicolons. After each name, the number(s) of their ' +
      'affiliation(s) in brackets. Mark the presenting author with an asterisk *.\n' +
      'Example:  Jana Nováková (1,2)*; John Smith (2); Ana García (3)')
    .setRequired(true)
    .setValidation(FormApp.createParagraphTextValidation()
      .requireTextMatchesPattern(
        '^\\s*[^;()*]+\\(\\s*\\d+(\\s*,\\s*\\d+)*\\s*\\)\\s*\\*?\\s*' +
        '(;\\s*[^;()*]+\\(\\s*\\d+(\\s*,\\s*\\d+)*\\s*\\)\\s*\\*?\\s*)*;?\\s*$')
      .setHelpText('Please use the format:  Name (1,2)*; Name (2)')
      .build()));

  add('Affiliations', form.addParagraphTextItem().setTitle('Affiliations')
    .setHelpText('One affiliation per line, each starting with its number and a full stop.\n' +
      'Example:\n1. Department of Botany, Faculty of Science, Charles University, Prague, Czech Republic\n' +
      '2. Institute of Botany, Czech Academy of Sciences, Průhonice, Czech Republic')
    .setRequired(true)
    .setValidation(FormApp.createParagraphTextValidation()
      .requireTextMatchesPattern('^\\s*\\d+\\.\\s*\\S[^\\n]*(\\n\\s*\\d+\\.\\s*\\S[^\\n]*)*\\s*$')
      .setHelpText('Please put each affiliation on its own line, starting with "1.", "2.", …')
      .build()));

  add('Abstract', form.addParagraphTextItem().setTitle('Abstract')
    .setHelpText('Maximum ' + CONFIG.maxAbstractWords + ' words, plain text, no references or figures. ' +
      'Use _underscores_ for species names in italics.')
    .setRequired(true)
    .setValidation(FormApp.createParagraphTextValidation()
      .requireTextMatchesPattern('^\\s*(\\S+\\s+){0,' + (CONFIG.maxAbstractWords - 1) + '}\\S+\\s*$')
      .setHelpText('The abstract must not exceed ' + CONFIG.maxAbstractWords + ' words.')
      .build()));

  // Primary keyword (required) — for dividing between reviewers
  add('Keyword_primary', form.addMultipleChoiceItem()
    .setTitle('Primary keyword')
    .setHelpText('Choose the ONE keyword that best describes your work. This helps us assign submissions to reviewers and organize main sessions.')
    .setChoiceValues(KEYWORDS.concat('Other'))
    .setRequired(true));

  // Optional keywords (0-2) — for session placement and context
  add('Keyword_optional', form.addCheckboxItem()
    .setTitle('Additional keywords (optional)')
    .setHelpText('Choose 0 to 2 additional keywords if your work spans multiple topics. These help with session placement and finding related work.')
    .setChoiceValues(KEYWORDS)
    .showOtherOption(true)
    .setValidation(FormApp.createCheckboxValidation()
      .requireSelectAtMost(CONFIG.optionalKeywords)
      .setHelpText('Select at most ' + CONFIG.optionalKeywords + ' keywords.')
      .build()));

  // Page 3 — logistics
  const logisticsPage = form.addPageBreakItem().setTitle('Logistics');
  add('Workshop', form.addMultipleChoiceItem().setTitle('Would you like to join a workshop on Wednesday 3 February?')
    .setHelpText('Topics will be announced. This helps us plan capacity.')
    .setChoiceValues(['Yes', 'Maybe', 'No']).setRequired(true));
  add('Workshop_proposal', form.addParagraphTextItem()
    .setTitle('Would you like to run a workshop? (optional)')
    .setHelpText('Workshops take place on Wednesday 3 February. Give a title, a short description, ' +
      'the expected length and the number of participants. We especially welcome skills workshops for ' +
      'early-career researchers.'));
  add('Excursion', form.addMultipleChoiceItem().setTitle('Excursion on Saturday 6 February')
    .setChoiceValues(['Milovice Nature Reserve (European bison)', 'Prague', 'Not attending', 'Not sure yet'])
    .setRequired(true));
  add('Dinner', form.addMultipleChoiceItem().setTitle('Will you attend the conference dinner?')
    .setChoiceValues(['Yes', 'No']).setRequired(true));
  add('Diet', form.addMultipleChoiceItem().setTitle('Dietary requirements')
    .setChoiceValues(['No restrictions', 'Vegetarian', 'Vegan'])
    .showOtherOption(true).setRequired(true));
  add('Diet_notes', form.addTextItem().setTitle('Allergies or other food notes (optional)'));
  add('Invitation_letter', form.addMultipleChoiceItem().setTitle('Do you need an invitation letter (e.g. for a visa)?')
    .setChoiceValues(['No', 'Yes']).setRequired(true));
  add('Comments', form.addParagraphTextItem().setTitle('Anything else we should know? (optional)'));
  form.addCheckboxItem().setTitle('Data processing')
    .setChoiceValues(['I agree that my name, affiliation and abstract will be published in the programme ' +
      'and Book of Abstracts, and that my data are used for organising ECOFLOR 2027.'])
    .setRequired(true);

  // Branching: presenters go to the abstract page, everyone else skips it.
  contribution.setChoices([
    contribution.createChoice(CONTRIBUTION.oral, abstractPage),
    contribution.createChoice(CONTRIBUTION.poster, abstractPage),
    contribution.createChoice(CONTRIBUTION.either, abstractPage),
    contribution.createChoice(CONTRIBUTION.risingStar, abstractPage),
    contribution.createChoice(CONTRIBUTION.none, logisticsPage),
  ]);

  return items;
}

// ── SHEETS ───────────────────────────────────────────────────────────────────

function setupSheets_(ss) {
  const sub = ss.getSheets()[0];
  sub.setName('Submissions');
  const headers = AUTO_HEADERS.concat(REVIEW_HEADERS);
  sub.getRange(1, 1, 1, headers.length).setValues([headers])
    .setFontWeight('bold').setBackground('#5B9E9E').setFontColor('white');
  sub.getRange(1, AUTO_HEADERS.length + 1, 1, REVIEW_HEADERS.length).setBackground('#E0A030');
  sub.setFrozenRows(1);
  sub.setFrozenColumns(1);

  const col = name => headers.indexOf(name) + 1;
  sub.setColumnWidth(col('Title'), 300);
  sub.setColumnWidth(col('Authors'), 250);
  sub.setColumnWidth(col('Affiliations'), 300);
  sub.setColumnWidth(col('Abstract'), 500);
  sub.setColumnWidth(col('Review_notes'), 250);
  sub.getRange(2, col('Title'), 999, 1).setWrap(true);
  sub.getRange(2, col('Abstract'), 999, 1).setWrap(true);

  const dropdown = values => SpreadsheetApp.newDataValidation()
    .requireValueInList(values, true).setAllowInvalid(false).build();
  sub.getRange(2, col('Status'), 999, 1).setDataValidation(dropdown(STATUS_VALUES));
  sub.getRange(2, col('Final_format'), 999, 1).setDataValidation(dropdown(FORMAT_VALUES));

  const statusRange = sub.getRange(2, 1, 999, headers.length);
  const statusCol = columnLetter_(col('Status'));
  const colour = (value, bg) => SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied('=$' + statusCol + '2="' + value + '"')
    .setBackground(bg).setRanges([statusRange]).build();
  sub.setConditionalFormatRules([
    colour('Accepted', '#E3F4E3'),
    colour('Rejected', '#F8DEDE'),
    colour('Withdrawn', '#EEEEEE'),
  ]);

  const sessions = ss.insertSheet('Sessions');
  sessions.getRange(1, 1, 1, SESSION_HEADERS.length).setValues([SESSION_HEADERS])
    .setFontWeight('bold').setBackground('#5B9E9E').setFontColor('white');
  sessions.getRange(2, 1, 2, SESSION_HEADERS.length).setValues([
    [1, 'Example session – replace me', 'Oral', 'Thursday 4 February', '09:00', 12, ''],
    [2, 'Poster session', 'Poster', 'Thursday 4 February', '15:00', '', ''],
  ]);
  sessions.getRange(2, 3, 999, 1).setDataValidation(dropdown(FORMAT_VALUES));
  sessions.setFrozenRows(1);

  const counts = ss.insertSheet('Keyword counts');
  const kwPrimary = columnLetter_(col('Keyword_primary'));
  const kwOptional = columnLetter_(col('Keyword_optional'));
  counts.getRange('A1').setFormula(
    '=QUERY(FLATTEN(Submissions!' + kwPrimary + '2:' + kwOptional + '), ' +
    '"select Col1, count(Col1) where Col1 is not null group by Col1 ' +
    'order by count(Col1) desc label Col1 \'Keyword\', count(Col1) \'Submissions\'", 0)');
}

// ── RESPONSES → "Submissions" ────────────────────────────────────────────────

/** Trigger: runs on every new or edited form response. */
function onFormSubmit(e) {
  const created = upsertResponse_(e.response);
  if (created && CONFIG.sendConfirmationEmail) sendConfirmation_(created);
}

/** Re-copies every form response. Run manually if the trigger ever missed something. */
function resyncAll() {
  const form = FormApp.openById(prop_('FORM_ID'));
  form.getResponses().forEach(r => upsertResponse_(r));
}

function upsertResponse_(response) {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const sheet = SpreadsheetApp.openById(prop_('SHEET_ID')).getSheetByName('Submissions');
    const record = responseToRecord_(response);

    const idCol = AUTO_HEADERS.indexOf('Response_ID') + 1;
    const lastRow = sheet.getLastRow();
    const ids = lastRow > 1 ? sheet.getRange(2, idCol, lastRow - 1, 1).getValues().flat() : [];
    const existing = ids.indexOf(record.Response_ID);

    let row;
    const isNew = existing < 0;
    if (!isNew) {
      row = existing + 2;
      const kept = sheet.getRange(row, 1, 1, 2).getValues()[0];
      record.Submission_ID = kept[0];
      record.Submitted = kept[1];
    } else {
      row = lastRow + 1;
      record.Submission_ID = CONFIG.idPrefix + String(row - 1).padStart(3, '0');
      record.Submitted = record.Last_edited;
      sheet.getRange(row, AUTO_HEADERS.length + 1).setValue('Pending');
    }

    sheet.getRange(row, 1, 1, AUTO_HEADERS.length)
      .setValues([AUTO_HEADERS.map(h => record[h] === undefined ? '' : record[h])]);
    return isNew ? record : null;
  } finally {
    lock.releaseLock();
  }
}

function sendConfirmation_(r) {
  if (!r.Email) return;
  const lines = [
    'Dear ' + r.First_name + ',',
    '',
    'thank you for registering for ECOFLOR 2027 (3–6 February 2027, Prague).',
    'Your submission ID is ' + r.Submission_ID + '.',
    '',
    'Contribution: ' + r.Contribution,
  ];
  if (r.Title) {
    lines.push('Title: ' + r.Title);
    const allKeywords = [r.Keyword_primary, r.Keyword_optional].filter(Boolean).join(', ');
    if (allKeywords) lines.push('Keywords: ' + allKeywords);
  }
  lines.push('',
    'You can change your registration or abstract until ' + CONFIG.deadline + ' using this link:',
    r.Edit_URL, '',
    'Best wishes,', 'the ECOFLOR 2027 organising team');
  MailApp.sendEmail({
    to: r.Email,
    replyTo: CONFIG.replyTo,
    name: 'ECOFLOR 2027',
    subject: 'ECOFLOR 2027 – registration received (' + r.Submission_ID + ')',
    body: lines.join('\n'),
  });
}

function responseToRecord_(response) {
  const itemMap = JSON.parse(prop_('ITEM_MAP'));
  const keyById = {};
  Object.keys(itemMap).forEach(k => { keyById[itemMap[k]] = k; });

  const answers = {};
  response.getItemResponses().forEach(ir => {
    const key = keyById[ir.getItem().getId()];
    if (key) answers[key] = ir.getResponse();
  });

  const presenting = answers.Contribution && answers.Contribution !== CONTRIBUTION.none;
  const abstract = presenting ? cleanParagraphs_(answers.Abstract) : '';

  // Handle both old (3 keywords) and new (primary + optional) formats
  let keyword_primary = '';
  let keyword_optional = '';
  if (presenting) {
    // New format: separate primary and optional fields
    if (answers.Keyword_primary) {
      keyword_primary = cleanLine_(answers.Keyword_primary);
    }
    if (answers.Keyword_optional) {
      const optional = Array.isArray(answers.Keyword_optional)
        ? answers.Keyword_optional
        : [answers.Keyword_optional];
      keyword_optional = optional.map(cleanLine_).join('; ');
    }
  }

  return {
    Response_ID: response.getId(),
    Edit_URL: response.getEditResponseUrl(),
    Last_edited: response.getTimestamp(),
    Email: response.getRespondentEmail(),
    First_name: cleanLine_(answers.First_name),
    Last_name: cleanLine_(answers.Last_name),
    Affiliation: cleanLine_(answers.Affiliation),
    Country: cleanLine_(answers.Country),
    Career_stage: answers.Career_stage || '',
    Contribution: answers.Contribution || '',
    Title: presenting ? cleanLine_(answers.Title).replace(/\.$/, '') : '',
    Authors: presenting ? cleanLine_(answers.Authors) : '',
    Affiliations: presenting ? cleanLines_(answers.Affiliations) : '',
    Abstract: abstract,
    Word_count: abstract ? abstract.split(/\s+/).length : '',
    Keyword_primary: keyword_primary,
    Keyword_optional: keyword_optional,
    Workshop: answers.Workshop || '',
    Workshop_proposal: cleanParagraphs_(answers.Workshop_proposal),
    Excursion: answers.Excursion || '',
    Dinner: answers.Dinner || '',
    Diet: answers.Diet || '',
    Diet_notes: cleanLine_(answers.Diet_notes),
    Invitation_letter: answers.Invitation_letter || '',
    Comments: cleanParagraphs_(answers.Comments),
  };
}

// ── TEXT CLEANING ────────────────────────────────────────────────────────────

/** One line: no line breaks, single spaces. */
function cleanLine_(s) {
  return String(s || '').replace(/\s+/g, ' ').trim();
}

/** Keeps line structure (affiliations): trims each line, drops empty lines. */
function cleanLines_(s) {
  return String(s || '').split(/\r?\n/).map(cleanLine_).filter(Boolean).join('\n');
}

/** Keeps paragraphs (blank line between them), joins hard-wrapped lines inside a paragraph. */
function cleanParagraphs_(s) {
  return String(s || '').replace(/\r\n?/g, '\n').split(/\n\s*\n/)
    .map(cleanLine_).filter(Boolean).join('\n\n');
}

/** "Other" answers may hold several keywords separated by ; or , */
function splitKeywords_(selected) {
  const out = [];
  selected.forEach(k => {
    if (KEYWORDS.indexOf(k) >= 0) out.push(k);
    else String(k).split(/[;,]/).map(cleanLine_).filter(Boolean).forEach(x => out.push(x));
  });
  return out;
}

// ── HELPERS ──────────────────────────────────────────────────────────────────

function prop_(name) {
  const value = PropertiesService.getScriptProperties().getProperty(name);
  if (!value) throw new Error('Missing script property ' + name + ' — run setup() first.');
  return value;
}

function columnLetter_(n) {
  let s = '';
  while (n > 0) { const m = (n - 1) % 26; s = String.fromCharCode(65 + m) + s; n = (n - m - 1) / 26; }
  return s;
}
