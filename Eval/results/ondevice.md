# Eval: Apple on-device model

Prompt v1 · context window 8192 tokens · 6 documents · run 2026-10-04T06:38:53Z

## Headline

| Metric | Result |
|---|---|
| **False reassurance** (violations not flagged) | **7** |
| **Wrong legal verdicts** | **1** |
| Verdict agreement (rule-backed) | 10/22 (45%) |
| Clause recall | 10/34 (29%) |
| Clause precision | 71% (4 unexpected) |
| Parameter accuracy | 6/8 (75%) |
| Document type accuracy | 6/6 |
| Quote drop rate (fabricated or mangled quotes) | 0/13 (0%) |
| Sections the engine failed on | 0 |
| Total time | 37.7s |

## Per document

| Document | Type | Recall | Params | Verdicts | Unexpected | Dropped | Time |
|---|---|---|---|---|---|---|---|
| 01_lease_problems | ✓ residential_lease (0.90) | 5/9 | 3/4 | 5/9 | 1 | 0/6 | 11.8s |
| 02_lease_fair | ✓ residential_lease (0.90) | 1/4 | 2/2 | 2/5 | 2 | 0/2 | 6.4s |
| 03_lease_scan_ocr | ✓ residential_lease (0.90) | 2/3 | 1/1 | 2/3 | 0 | 0/2 | 5.3s |
| 04_employment_offer | ✓ employment (0.90) | 1/6 | 0/1 | 1/5 | 0 | 0/1 | 3.9s |
| 05_subscription_terms | ✓ subscription_terms (0.95) | 0/8 | 0/0 | 0/0 | 1 | 0/1 | 4.3s |
| 06_contractor_agreement | ✓ unknown (0.60) | 1/4 | 0/0 | 0/0 | 0 | 0/1 | 6.0s |

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
