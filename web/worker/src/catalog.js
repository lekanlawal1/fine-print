// The clause vocabulary and prompts, ported from FinePrintCore (ClauseCatalog.swift, Prompts.swift,
// prompt v2.1) so the web demo asks Gemini exactly what the app asks. test/catalog.test.mjs checks
// the type list against the Swift source.

export const PROMPT_VERSION = "v2.1";

export const SPECS = [
  // Residential lease
  ["pets", "restricts or prohibits pets or animals", []],
  ["security_deposit", "a damage, security, pet or cleaning deposit (NOT a deposit applied to last month's rent)",
    [["amount", "deposit amount in dollars"]]],
  ["rent_deposit", "a rent deposit or last month's rent deposit",
    [["amount", "deposit amount in dollars"], ["monthly_rent", "monthly rent in dollars, if stated anywhere in the document"]]],
  ["key_deposit", "a deposit for keys, fobs, remotes or access cards",
    [["amount", "deposit amount in dollars"], ["replacement_cost", "stated cost to replace the key or card, in dollars"]]],
  ["nsf_fee", "a fee for a returned, bounced or NSF cheque or payment", [["amount", "fee in dollars"]]],
  ["acceleration_clause", "makes remaining or future rent (or a lump sum) due if the tenant defaults or breaks the lease", []],
  ["post_dated_cheques", "REQUIRES post-dated cheques or automatic payments for rent (NOT when they are only optional)", []],
  ["landlord_entry", "when or how the landlord may enter the unit",
    [["notice_hours", "advance notice required, in hours; 0 if entry is allowed without notice"]]],
  ["rent_increase", "how or when rent can be increased",
    [["notice_days", "advance notice of an increase, in days"], ["months_between_increases", "minimum months between increases"]]],
  ["guests", "limits on guests or visitors", []],
  // Employment
  ["non_compete", "stops someone working for a competitor or starting a competing business after leaving", []],
  ["vacation", "paid vacation entitlement",
    [["vacation_weeks", "vacation per year in weeks; convert working days on a 5-day week (10 days = 2)"]]],
  ["overtime", "overtime hours or overtime pay",
    [["overtime_threshold_hours", "weekly hours after which overtime starts"],
     ["overtime_multiplier", "overtime pay as a multiple of regular pay, e.g. 1.5; \"regular rate\" or \"straight time\" means 1"]]],
  ["termination", "how the agreement or employment can be ended, and any notice", []],
  // Universal
  ["auto_renewal", "renews automatically unless cancelled", []],
  ["unilateral_amendment", "lets one party change the terms on its own", []],
  ["liability_waiver", "limits or excludes a party's liability", []],
  ["arbitration", "requires arbitration or waives class actions or jury trials", []],
  ["indemnity", "requires one party to cover the other's losses or legal costs", []],
  ["content_license", "grants or assigns rights in content, work product or intellectual property "
    + "(\"all work you create belongs to the Company\", \"assigns all rights in the work\")", []],
  ["data_sharing", "shares personal data with third parties", []],
  ["cancellation_fee", "a fee for cancelling or ending early", [["amount", "fee in dollars"]]],
  ["price_increase", "allows the price to change during the agreement", []],
  ["venue", "chooses which law, courts or location govern disputes", []],
  ["non_disparagement", "restricts saying negative things about a party", []],
  ["assignment", "allows the AGREEMENT ITSELF to be transferred to another party (not rights in "
    + "work or IP; that is content_license)", []],
].map(([type, description, parameters]) => ({ type, description, parameters }));

export const DOCUMENT_TYPES = ["residential_lease", "employment", "subscription_terms", "unknown"];
const UNIVERSAL = ["auto_renewal", "unilateral_amendment", "liability_waiver", "arbitration", "indemnity", "content_license",
  "data_sharing", "cancellation_fee", "price_increase", "venue", "non_disparagement", "assignment", "termination"];
const LEASE = ["pets", "security_deposit", "rent_deposit", "key_deposit", "nsf_fee", "acceleration_clause",
  "post_dated_cheques", "landlord_entry", "rent_increase", "guests"];
const EMPLOYMENT = ["non_compete", "vacation", "overtime"];

/** Clause types worth looking for in a document type, in catalog order (prompt v2). */
export function typesFor(documentType) {
  const scoped = { residential_lease: [...LEASE, ...UNIVERSAL], employment: [...EMPLOYMENT, ...UNIVERSAL],
    subscription_terms: UNIVERSAL }[documentType] || ["non_compete", ...UNIVERSAL];
  return SPECS.map((s) => s.type).filter((t) => scoped.includes(t));
}

export const ALL_PARAMETER_NAMES = [...new Set(SPECS.flatMap((s) => s.parameters.map(([n]) => n)))].sort();

export function promptList(types) {
  return SPECS.filter((s) => types.includes(s.type)).map((s) => {
    let line = `- ${s.type}: ${s.description}`;
    if (s.parameters.length) line += ". Parameters: " + s.parameters.map(([n, m]) => `${n} (${m})`).join("; ");
    return line;
  }).join("\n");
}

export function extractionInstructions(documentType) {
  return `You read contracts and legal documents and extract clauses for a review app.

RULES
1. Only extract clauses whose type is in the list below. Skip everything else.
2. "quote" must be copied EXACTLY from the document, character for character, including its punctuation. Do not paraphrase, summarize, shorten mid-sentence, fix typos, or join separate sentences. Code checks every quote against the document and throws away any quote that doesn't match.
3. Quote at least one full sentence.
4. "parameters": include only numbers the document actually states. Never estimate or assume a number. Leave parameters out when the document doesn't state them.
5. You do not decide whether anything is legal or fair. Only tag and quote.
6. If the same clause fits two types, list it once for each type.

CLAUSE TYPES
${promptList(typesFor(documentType))}`;
}

export const DOCUMENT_TYPE_INSTRUCTIONS = `Classify the document. Types:
- residential_lease: a lease or tenancy agreement for a home or apartment
- employment: an employment contract or job offer for an employee
- subscription_terms: terms of service, terms of use, or a subscription or membership agreement
- unknown: anything else (for example a contractor agreement, a loan, or a purchase agreement), or when you can't tell
Report your genuine confidence from 0 to 1. Use a low value if the document is short, mixed, or unclear.`;
