# Eval: Apple on-device model

Prompt v1 · context window 8192 tokens · 12 documents · run 2026-10-04T07:39:56Z

## Headline

| Metric | Result |
|---|---|
| **False reassurance** (violations not flagged) | **14** |
| **Wrong legal verdicts** | **3** |
| Verdict agreement (rule-backed) | 20/45 (44%) |
| Clause recall | 21/63 (33%) |
| Clause precision | 78% (6 unexpected) |
| Parameter accuracy | 13/17 (76%) |
| Document type accuracy | 12/12 |
| Quote drop rate (fabricated or mangled quotes) | 0/28 (0%) |
| Sections the engine failed on | 0 |
| Total time | 134.7s |

## Per document

| Document | Type | Recall | Params | Verdicts | Unexpected | Dropped | Time |
|---|---|---|---|---|---|---|---|
| 01_lease_problems | ✓ residential_lease (0.90) | 5/9 | 3/4 | 5/9 | 1 | 0/6 | 30.5s |
| 02_lease_fair | ✓ residential_lease (0.90) | 1/4 | 2/2 | 2/5 | 2 | 0/2 | 12.1s |
| 03_lease_scan_ocr | ✓ residential_lease (0.90) | 2/3 | 1/1 | 2/3 | 0 | 0/2 | 9.5s |
| 04_employment_offer | ✓ employment (0.90) | 1/6 | 0/1 | 1/5 | 0 | 0/1 | 7.5s |
| 05_subscription_terms | ✓ subscription_terms (0.95) | 0/8 | 0/0 | 0/0 | 1 | 0/1 | 7.6s |
| 06_contractor_agreement | ✓ unknown (0.60) | 1/4 | 0/0 | 0/0 | 0 | 0/1 | 7.8s |
| 07_lease_long | ✓ residential_lease (0.95) | 3/12 | 2/3 | 2/10 | 1 | 0/4 | 23.4s |
| 08_lease_negations | ✓ residential_lease (0.90) | 1/1 | 1/1 | 1/1 | 0 | 0/3 | 11.1s |
| 09_offer_nonsolicit | ✓ employment (0.90) | 2/3 | 2/3 | 2/4 | 0 | 0/2 | 9.9s |
| 10_lease_pdf_messy | ✓ residential_lease (0.90) | 2/4 | 1/1 | 2/5 | 0 | 0/2 | 7.8s |
| 11_gym_membership | ✓ subscription_terms (0.90) | 0/6 | 0/0 | 0/0 | 1 | 0/1 | 3.0s |
| 12_lease_injection | ✓ residential_lease (0.90) | 3/3 | 1/1 | 3/3 | 0 | 0/3 | 4.5s |

## Details

### 01_lease_problems
- ⚠️ false reassurance: Landlord entry notice (app said: nothing)
- ⚠️ false reassurance: Rent acceleration clause (app said: nothing)
- ⚠️ false reassurance: Rent increase frequency (app said: needs_human)
- missed: rent_deposit ("rent deposit of $1,800")
- missed: acceleration_clause ("remainder of the term becomes due")
- missed: guests ("Guests may not stay overnight")
- missed: landlord_entry ("at any time without notice")
- parameter: rent_increase.months_between_increases: expected 6.0, got nothing
- unexpected: security_deposit: "The Tenant shall pay a rent deposit of $1,800, to be applied"

### 02_lease_fair
- ⚠️ wrong legal verdict: Security or damage deposit → rule_violation
- missed: rent_deposit ("rent deposit of $2,100")
- missed: key_deposit ("refundable key deposit of $40")
- missed: landlord_entry ("at least 24 hours' written notice")
- unexpected: security_deposit: "A refundable key deposit of $40 is required, which is the co"
- should be absent: security_deposit

### 03_lease_scan_ocr
- ⚠️ false reassurance: Landlord entry notice (app said: nothing)
- missed: landlord_entry ("12 hours notice")

### 04_employment_offer
- ⚠️ false reassurance: Non-compete clause (app said: nothing)
- ⚠️ false reassurance: Overtime rate (app said: nothing)
- ⚠️ false reassurance: Overtime threshold (app said: nothing)
- missed: overtime ("beyond 48 hours in a week")
- missed: non_compete ("competes with Northwind Analytics")
- missed: termination ("two weeks' notice or pay in lieu")
- missed: non_disparagement ("negative public statements")
- missed: content_license ("All work you create")
- parameter: vacation.vacation_weeks: expected 2.0, got 10.0

### 05_subscription_terms
- missed: auto_renewal ("automatically renews each month")
- missed: unilateral_amendment ("modify these Terms at any time")
- missed: price_increase ("change the price of your subscription")
- missed: arbitration ("binding arbitration")
- missed: data_sharing ("advertising partners and other third parties")
- missed: cancellation_fee ("cancellation fee of $45")
- missed: venue ("laws of the State of Delaware")
- missed: liability_waiver ("will not be liable")
- unexpected: rent_increase: "We may change the price of your subscription with 7 days' no"

### 06_contractor_agreement
- missed: indemnity ("indemnify the Client")
- missed: termination ("14 days' written notice")
- missed: content_license ("assigns to the Client all rights")

### 07_lease_long
- ⚠️ false reassurance: Bounced cheque (NSF) fee (app said: nothing)
- ⚠️ false reassurance: Landlord entry notice (app said: nothing)
- ⚠️ false reassurance: Rent acceleration clause (app said: nothing)
- ⚠️ false reassurance: Required post-dated cheques or automatic payments (app said: nothing)
- missed: post_dated_cheques ("paid by pre-authorized debit")
- missed: nsf_fee ("administration fee of $35")
- missed: rent_increase ("once in any twelve-month period")
- missed: rent_deposit ("rent deposit of $2,450")
- missed: landlord_entry ("at least 6 hours' notice")
- missed: liability_waiver ("shall not be liable for any loss")
- missed: indemnity ("shall indemnify the Landlord")
- missed: acceleration_clause ("balance of the term shall immediately become due")
- missed: assignment ("may assign this Agreement")
- parameter: key_deposit.replacement_cost: expected 150.0, got 0.0
- unexpected: security_deposit: "The Tenant shall pay a rent deposit of $2,450, to be applied"

### 08_lease_negations
- ⚠️ wrong legal verdict: No-pets clause → rule_violation
- ⚠️ wrong legal verdict: Security or damage deposit → rule_violation

### 09_offer_nonsolicit
- missed: termination ("required by the Employment Standards Act")
- parameter: overtime.overtime_multiplier: expected 1.5, got nothing

### 10_lease_pdf_messy
- ⚠️ false reassurance: Landlord entry notice (app said: nothing)
- ⚠️ false reassurance: Rent increase frequency (app said: nothing)
- ⚠️ false reassurance: Rent increase notice (app said: nothing)
- missed: landlord_entry ("enter the unit without notice")
- missed: rent_increase ("increased every six months")

### 11_gym_membership
- missed: auto_renewal ("renews automatically each month")
- missed: price_increase ("may increase dues once per year")
- missed: cancellation_fee ("early cancellation fee of $99")
- missed: liability_waiver ("not responsible for any injury")
- missed: data_sharing ("share your contact information")
- missed: arbitration ("not as part of a class action")
- unexpected: rent_increase: "PeakFit may increase dues once per year by notifying you by "
