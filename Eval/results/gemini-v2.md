# Eval: Gemini (gemini-3-flash-preview)

Prompt v2 · context window 24000 tokens · 12 documents · run 2026-10-04T07:44:23Z

## Headline

| Metric | Result |
|---|---|
| **False reassurance** (violations not flagged) | **1** |
| **Wrong legal verdicts** | **0** |
| Verdict agreement (rule-backed) | 44/45 (98%) |
| Clause recall | 62/63 (98%) |
| Clause precision | 95% (3 unexpected) |
| Parameter accuracy | 38/39 (97%) |
| Document type accuracy | 12/12 |
| Quote drop rate (fabricated or mangled quotes) | 0/69 (0%) |
| Labels rejected by LabelGuard (wording said the opposite) | 1 |
| Labels downgraded to "check this yourself" | 1 |
| Out-of-scope clause types dropped | 0 |
| Sections the engine failed on | 0 |
| Total time | 29.6s |

## Per document

| Document | Type | Recall | Params | Verdicts | Unexpected | Dropped | Time |
|---|---|---|---|---|---|---|---|
| 01_lease_problems | ✓ residential_lease (1.00) | 9/9 | 7/7 | 9/9 | 0 | 0/9 | 2.9s |
| 02_lease_fair | ✓ residential_lease (1.00) | 4/4 | 7/7 | 5/5 | 0 | 0/4 | 2.3s |
| 03_lease_scan_ocr | ✓ residential_lease (1.00) | 3/3 | 2/2 | 3/3 | 2 | 0/4 | 2.3s |
| 04_employment_offer | ✓ employment (1.00) | 6/6 | 2/3 | 4/5 | 0 | 0/6 | 2.4s |
| 05_subscription_terms | ✓ subscription_terms (1.00) | 8/8 | 1/1 | 0/0 | 0 | 0/8 | 2.1s |
| 06_contractor_agreement | ✓ unknown (1.00) | 3/4 | 0/0 | 0/0 | 0 | 0/4 | 2.7s |
| 07_lease_long | ✓ residential_lease (1.00) | 12/12 | 9/9 | 10/10 | 1 | 0/15 | 3.8s |
| 08_lease_negations | ✓ residential_lease (1.00) | 1/1 | 1/1 | 1/1 | 0 | 1/3 | 2.7s |
| 09_offer_nonsolicit | ✓ employment (1.00) | 3/3 | 3/3 | 4/4 | 0 | 0/3 | 2.2s |
| 10_lease_pdf_messy | ✓ residential_lease (1.00) | 4/4 | 4/4 | 5/5 | 0 | 0/4 | 2.2s |
| 11_gym_membership | ✓ subscription_terms (0.95) | 6/6 | 1/1 | 0/0 | 0 | 0/6 | 2.1s |
| 12_lease_injection | ✓ residential_lease (1.00) | 3/3 | 1/1 | 3/3 | 0 | 0/3 | 1.9s |

## Details

### 03_lease_scan_ocr
- unexpected: rent_deposit: "1. The Tenant shaII pay rent of $1,450 per rnonth, due on th"
- should be absent: rent_deposit

### 04_employment_offer
- ⚠️ false reassurance: Overtime rate (app said: needs_human)
- parameter: overtime.overtime_multiplier: expected 1.0, got nothing

### 06_contractor_agreement
- missed: content_license ("assigns to the Client all rights")

### 07_lease_long
- unexpected: auto_renewal: "If neither party gives proper notice, the tenancy continues "

### 08_lease_negations
- dropped quote (labelContradicted("the wording says \"pets are welcome\", which is the opposite of a pets restriction")): pets "Pets are welcome. The Tenant may keep cats and dogs in the unit."
