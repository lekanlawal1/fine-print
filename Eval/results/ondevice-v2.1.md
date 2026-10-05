# Eval: Apple on-device model

Prompt v2.1 · context window 8192 tokens · 12 documents · run 2026-10-04T07:47:33Z

## Headline

| Metric | Result |
|---|---|
| **False reassurance** (violations not flagged) | **15** |
| **Wrong legal verdicts** | **0** |
| Verdict agreement (rule-backed) | 19/45 (42%) |
| Clause recall | 31/63 (49%) |
| Clause precision | 94% (2 unexpected) |
| Parameter accuracy | 18/22 (82%) |
| Document type accuracy | 12/12 |
| Quote drop rate (fabricated or mangled quotes) | 0/35 (0%) |
| Labels rejected by LabelGuard (wording said the opposite) | 2 |
| Labels downgraded to "check this yourself" | 2 |
| Out-of-scope clause types dropped | 0 |
| Sections the engine failed on | 0 |
| Total time | 55.1s |

## Per document

| Document | Type | Recall | Params | Verdicts | Unexpected | Dropped | Time |
|---|---|---|---|---|---|---|---|
| 01_lease_problems | ✓ residential_lease (0.90) | 3/9 | 3/3 | 4/9 | 1 | 0/4 | 6.4s |
| 02_lease_fair | ✓ residential_lease (0.90) | 2/4 | 3/4 | 1/5 | 0 | 0/2 | 4.3s |
| 03_lease_scan_ocr | ✓ residential_lease (0.90) | 2/3 | 1/1 | 2/3 | 0 | 0/2 | 3.3s |
| 04_employment_offer | ✓ employment (0.90) | 2/6 | 1/3 | 2/5 | 0 | 0/2 | 3.6s |
| 05_subscription_terms | ✓ subscription_terms (0.95) | 5/8 | 1/1 | 0/0 | 0 | 0/5 | 6.0s |
| 06_contractor_agreement | ✓ unknown (0.60) | 2/4 | 0/0 | 0/0 | 0 | 0/2 | 3.5s |
| 07_lease_long | ✓ residential_lease (0.95) | 2/12 | 2/3 | 1/10 | 1 | 0/3 | 7.7s |
| 08_lease_negations | ✓ residential_lease (0.90) | 1/1 | 1/1 | 1/1 | 0 | 2/3 | 4.0s |
| 09_offer_nonsolicit | ✓ employment (0.90) | 2/3 | 3/3 | 3/4 | 0 | 0/2 | 3.7s |
| 10_lease_pdf_messy | ✓ residential_lease (0.90) | 2/4 | 1/1 | 2/5 | 0 | 0/2 | 3.7s |
| 11_gym_membership | ✓ subscription_terms (0.90) | 5/6 | 1/1 | 0/0 | 0 | 0/5 | 5.1s |
| 12_lease_injection | ✓ residential_lease (0.90) | 3/3 | 1/1 | 3/3 | 0 | 0/3 | 3.9s |

## Details

### 01_lease_problems
- ⚠️ false reassurance: Landlord entry notice (app said: nothing)
- ⚠️ false reassurance: Rent acceleration clause (app said: nothing)
- ⚠️ false reassurance: Required post-dated cheques or automatic payments (app said: nothing)
- ⚠️ false reassurance: Security or damage deposit (app said: needs_human)
- missed: rent_deposit ("rent deposit of $1,800")
- missed: security_deposit ("damage deposit of $600")
- missed: post_dated_cheques ("twelve post-dated cheques")
- missed: acceleration_clause ("remainder of the term becomes due")
- missed: guests ("Guests may not stay overnight")
- missed: landlord_entry ("at any time without notice")
- unexpected: security_deposit: "The Tenant shall pay a rent deposit of $1,800, to be applied"

### 02_lease_fair
- missed: landlord_entry ("at least 24 hours' written notice")
- missed: rent_increase ("more than once in any 12-month period")
- parameter: rent_deposit.monthly_rent: expected 2100.0, got nothing

### 03_lease_scan_ocr
- ⚠️ false reassurance: Landlord entry notice (app said: nothing)
- missed: landlord_entry ("12 hours notice")

### 04_employment_offer
- ⚠️ false reassurance: Non-compete clause (app said: nothing)
- ⚠️ false reassurance: Overtime rate (app said: needs_human)
- missed: non_compete ("competes with Northwind Analytics")
- missed: termination ("two weeks' notice or pay in lieu")
- missed: non_disparagement ("negative public statements")
- missed: content_license ("All work you create")
- parameter: overtime.overtime_multiplier: expected 1.0, got nothing
- parameter: vacation.vacation_weeks: expected 2.0, got 10.0

### 05_subscription_terms
- missed: unilateral_amendment ("modify these Terms at any time")
- missed: venue ("laws of the State of Delaware")
- missed: liability_waiver ("will not be liable")

### 06_contractor_agreement
- missed: indemnity ("indemnify the Client")
- missed: content_license ("assigns to the Client all rights")

### 07_lease_long
- ⚠️ false reassurance: Bounced cheque (NSF) fee (app said: nothing)
- ⚠️ false reassurance: Landlord entry notice (app said: nothing)
- ⚠️ false reassurance: No-pets clause (app said: nothing)
- ⚠️ false reassurance: Rent acceleration clause (app said: nothing)
- ⚠️ false reassurance: Required post-dated cheques or automatic payments (app said: nothing)
- missed: post_dated_cheques ("paid by pre-authorized debit")
- missed: nsf_fee ("administration fee of $35")
- missed: rent_increase ("once in any twelve-month period")
- missed: rent_deposit ("rent deposit of $2,450")
- missed: pets ("shall not keep any dogs, cats")
- missed: landlord_entry ("at least 6 hours' notice")
- missed: liability_waiver ("shall not be liable for any loss")
- missed: indemnity ("shall indemnify the Landlord")
- missed: acceleration_clause ("balance of the term shall immediately become due")
- missed: assignment ("may assign this Agreement")
- parameter: key_deposit.replacement_cost: expected 150.0, got nothing
- unexpected: security_deposit: "The Tenant shall pay a rent deposit of $2,450, to be applied"

### 08_lease_negations
- dropped quote (labelContradicted("the wording says \"pets are welcome\", which is the opposite of a pets restriction")): pets "Pets are welcome. The Tenant may keep cats and dogs in the unit."
- dropped quote (labelContradicted("the wording says \"no damage deposit\", which is the opposite of a security deposit restriction")): security_deposit "No damage deposit or security deposit will be required for this tenanc"

### 09_offer_nonsolicit
- missed: termination ("required by the Employment Standards Act")

### 10_lease_pdf_messy
- ⚠️ false reassurance: Landlord entry notice (app said: nothing)
- ⚠️ false reassurance: Rent increase frequency (app said: nothing)
- ⚠️ false reassurance: Rent increase notice (app said: nothing)
- missed: landlord_entry ("enter the unit without notice")
- missed: rent_increase ("increased every six months")

### 11_gym_membership
- missed: price_increase ("may increase dues once per year")
