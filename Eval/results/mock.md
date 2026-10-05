# Eval: Keyword engine (no AI)

Prompt v1 · context window 8192 tokens · 6 documents · run 2026-10-04T06:38:07Z

## Headline

| Metric | Result |
|---|---|
| **False reassurance** (violations not flagged) | **7** |
| **Wrong legal verdicts** | **1** |
| Verdict agreement (rule-backed) | 9/22 (41%) |
| Clause recall | 24/34 (71%) |
| Clause precision | 73% (9 unexpected) |
| Parameter accuracy | 9/17 (53%) |
| Document type accuracy | 5/6 |
| Quote drop rate (fabricated or mangled quotes) | 0/34 (0%) |
| Sections the engine failed on | 0 |
| Total time | 0.0s |

## Per document

| Document | Type | Recall | Params | Verdicts | Unexpected | Dropped | Time |
|---|---|---|---|---|---|---|---|
| 01_lease_problems | ✓ residential_lease (1.00) | 9/9 | 4/7 | 6/9 | 1 | 0/10 | 0.0s |
| 02_lease_fair | ✓ residential_lease (1.00) | 2/4 | 3/4 | 1/5 | 1 | 0/3 | 0.0s |
| 03_lease_scan_ocr | ✓ residential_lease (1.00) | 3/3 | 1/2 | 2/3 | 0 | 0/3 | 0.0s |
| 04_employment_offer | ✓ employment (0.73) | 2/6 | 0/3 | 0/5 | 4 | 0/6 | 0.0s |
| 05_subscription_terms | ✓ subscription_terms (0.86) | 7/8 | 1/1 | 0/0 | 1 | 0/8 | 0.0s |
| 06_contractor_agreement | ✗ subscription_terms (0.75) | 1/4 | 0/0 | 0/0 | 2 | 0/4 | 0.0s |

## Details

### 01_lease_problems
- ⚠️ false reassurance: Landlord entry notice (app said: needs_human)
- ⚠️ false reassurance: Rent increase frequency (app said: needs_human)
- ⚠️ false reassurance: Rent increase notice (app said: needs_human)
- parameter: landlord_entry.notice_hours: expected 0.0, got nothing
- parameter: rent_increase.months_between_increases: expected 6.0, got nothing
- parameter: rent_increase.notice_days: expected 60.0, got nothing
- unexpected: pets: "(the "Landlord") and Jordan Ellis (the "Tenant") for Unit 4B"

### 02_lease_fair
- ⚠️ wrong legal verdict: Bounced cheque (NSF) fee → needs_human
- missed: landlord_entry ("at least 24 hours' written notice")
- missed: rent_increase ("more than once in any 12-month period")
- parameter: key_deposit.replacement_cost: expected 40.0, got nothing
- unexpected: nsf_fee: "The Tenant may pay rent by cheque, e-transfer or pre-authori"

### 03_lease_scan_ocr
- ⚠️ false reassurance: Landlord entry notice (app said: needs_human)
- parameter: landlord_entry.notice_hours: expected 12.0, got nothing

### 04_employment_offer
- ⚠️ false reassurance: Non-compete clause (app said: nothing)
- ⚠️ false reassurance: Overtime rate (app said: needs_human)
- ⚠️ false reassurance: Overtime threshold (app said: needs_human)
- missed: non_compete ("competes with Northwind Analytics")
- missed: termination ("two weeks' notice or pay in lieu")
- missed: non_disparagement ("negative public statements")
- missed: content_license ("All work you create")
- parameter: overtime.overtime_multiplier: expected 1.0, got nothing
- parameter: overtime.overtime_threshold_hours: expected 48.0, got nothing
- parameter: vacation.vacation_weeks: expected 2.0, got nothing
- unexpected: overtime: "Hours and Overtime."
- unexpected: pets: "Non-Competition."
- unexpected: pets: "For 12 months after your employment ends, you will not work "
- unexpected: non_disparagement: "Non-Disparagement."

### 05_subscription_terms
- missed: arbitration ("binding arbitration")
- unexpected: liability_waiver: "Any dispute will be resolved by binding arbitration, and you"

### 06_contractor_agreement
- missed: non_compete ("any direct competitor of the Client")
- missed: termination ("14 days' written notice")
- missed: content_license ("assigns to the Client all rights")
- unexpected: pets: "Non-Competition."
- unexpected: pets: "During this agreement and for 6 months afterward, the Contra"
