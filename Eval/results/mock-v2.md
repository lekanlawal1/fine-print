# Eval: Keyword engine (no AI)

Prompt v2 · context window 8192 tokens · 12 documents · run 2026-10-04T07:43:53Z

## Headline

| Metric | Result |
|---|---|
| **False reassurance** (violations not flagged) | **16** |
| **Wrong legal verdicts** | **0** |
| Verdict agreement (rule-backed) | 16/45 (36%) |
| Clause recall | 40/63 (63%) |
| Clause precision | 87% (6 unexpected) |
| Parameter accuracy | 13/26 (50%) |
| Document type accuracy | 10/12 |
| Quote drop rate (fabricated or mangled quotes) | 0/59 (0%) |
| Labels rejected by LabelGuard (wording said the opposite) | 4 |
| Labels downgraded to "check this yourself" | 3 |
| Out-of-scope clause types dropped | 4 |
| Sections the engine failed on | 0 |
| Total time | 0.1s |

## Per document

| Document | Type | Recall | Params | Verdicts | Unexpected | Dropped | Time |
|---|---|---|---|---|---|---|---|
| 01_lease_problems | ✓ residential_lease (1.00) | 9/9 | 4/7 | 6/9 | 1 | 0/10 | 0.0s |
| 02_lease_fair | ✓ residential_lease (1.00) | 2/4 | 3/4 | 1/5 | 1 | 0/3 | 0.0s |
| 03_lease_scan_ocr | ✓ residential_lease (1.00) | 3/3 | 1/2 | 2/3 | 0 | 0/3 | 0.0s |
| 04_employment_offer | ✓ employment (0.73) | 2/6 | 0/3 | 0/5 | 2 | 2/6 | 0.0s |
| 05_subscription_terms | ✓ subscription_terms (0.86) | 7/8 | 1/1 | 0/0 | 1 | 0/8 | 0.0s |
| 06_contractor_agreement | ✗ subscription_terms (0.75) | 1/4 | 0/0 | 0/0 | 0 | 2/4 | 0.0s |
| 07_lease_long | ✓ residential_lease (0.98) | 7/12 | 2/5 | 2/10 | 1 | 0/10 | 0.0s |
| 08_lease_negations | ✓ residential_lease (1.00) | 0/1 | 0/0 | 0/1 | 0 | 4/6 | 0.0s |
| 09_offer_nonsolicit | ✓ employment (0.89) | 2/3 | 0/1 | 1/4 | 0 | 0/2 | 0.0s |
| 10_lease_pdf_messy | ✓ residential_lease (1.00) | 2/4 | 0/1 | 1/5 | 0 | 0/2 | 0.0s |
| 11_gym_membership | ✗ unknown (0.00) | 2/6 | 1/1 | 0/0 | 0 | 0/2 | 0.0s |
| 12_lease_injection | ✓ residential_lease (1.00) | 3/3 | 1/1 | 3/3 | 0 | 0/3 | 0.0s |

## Details

### 01_lease_problems
- ⚠️ false reassurance: Landlord entry notice (app said: needs_human)
- ⚠️ false reassurance: Rent increase frequency (app said: needs_human)
- ⚠️ false reassurance: Rent increase notice (app said: needs_human)
- parameter: landlord_entry.notice_hours: expected 0.0, got nothing
- parameter: rent_increase.notice_days: expected 60.0, got nothing
- parameter: rent_increase.months_between_increases: expected 6.0, got nothing
- unexpected: pets: "(the "Landlord") and Jordan Ellis (the "Tenant") for Unit 4B"

### 02_lease_fair
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
- unexpected: non_disparagement: "Non-Disparagement."
- dropped quote (outOfScope(FinePrintCore.DocumentType.employment)): pets "Non-Competition."
- dropped quote (outOfScope(FinePrintCore.DocumentType.employment)): pets "For 12 months after your employment ends, you will not work for or pro"

### 05_subscription_terms
- missed: arbitration ("binding arbitration")
- unexpected: liability_waiver: "Any dispute will be resolved by binding arbitration, and you"

### 06_contractor_agreement
- missed: non_compete ("any direct competitor of the Client")
- missed: termination ("14 days' written notice")
- missed: content_license ("assigns to the Client all rights")
- dropped quote (outOfScope(FinePrintCore.DocumentType.subscriptionTerms)): pets "Non-Competition."
- dropped quote (outOfScope(FinePrintCore.DocumentType.subscriptionTerms)): pets "During this agreement and for 6 months afterward, the Contractor will "

### 07_lease_long
- ⚠️ false reassurance: Bounced cheque (NSF) fee (app said: nothing)
- ⚠️ false reassurance: Landlord entry notice (app said: needs_human)
- ⚠️ false reassurance: Rent acceleration clause (app said: nothing)
- ⚠️ false reassurance: Required post-dated cheques or automatic payments (app said: nothing)
- ⚠️ false reassurance: Security or damage deposit (app said: nothing)
- missed: post_dated_cheques ("paid by pre-authorized debit")
- missed: nsf_fee ("administration fee of $35")
- missed: key_deposit ("refundable deposit of $150 for two key fobs")
- missed: security_deposit ("cleaning deposit of $400")
- missed: acceleration_clause ("balance of the term shall immediately become due")
- parameter: rent_increase.notice_days: expected 90.0, got nothing
- parameter: rent_increase.months_between_increases: expected 12.0, got nothing
- parameter: landlord_entry.notice_hours: expected 6.0, got nothing
- unexpected: assignment: "1 In this Agreement, "Premises" means the residential unit d"

### 08_lease_negations
- missed: landlord_entry ("at least 24 hours' written notice")
- dropped quote (labelContradicted("the wording says \"no damage deposit\", which is the opposite of a security deposit restriction")): security_deposit "No damage deposit or security deposit will be required for this tenanc"
- dropped quote (labelContradicted("the wording says \"pets are welcome\", which is the opposite of a pets restriction")): pets "Pets are welcome."
- dropped quote (labelContradicted("the wording says \"optional\", which is the opposite of a post dated cheques restriction")): post_dated_cheques "Post-dated cheques are optional."
- dropped quote (labelContradicted("the wording says \"will not charge\", which is the opposite of a nsf fee restriction")): nsf_fee "The Landlord will not charge any fee for a returned or NSF cheque beyo"

### 09_offer_nonsolicit
- missed: overtime ("Hours worked over 44")
- parameter: vacation.vacation_weeks: expected 3.0, got nothing

### 10_lease_pdf_messy
- ⚠️ false reassurance: Landlord entry notice (app said: needs_human)
- ⚠️ false reassurance: Rent increase frequency (app said: nothing)
- ⚠️ false reassurance: Rent increase notice (app said: nothing)
- ⚠️ false reassurance: Security or damage deposit (app said: nothing)
- missed: security_deposit ("ity deposit of $500")
- missed: rent_increase ("increased every six months")
- parameter: landlord_entry.notice_hours: expected 0.0, got nothing

### 11_gym_membership
- missed: auto_renewal ("renews automatically each month")
- missed: price_increase ("may increase dues once per year")
- missed: liability_waiver ("not responsible for any injury")
- missed: arbitration ("not as part of a class action")
