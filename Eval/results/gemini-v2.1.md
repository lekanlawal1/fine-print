# Eval: Gemini (gemini-3-flash-preview)

Prompt v2.1 · context window 24000 tokens · 12 documents · run 2026-10-04T07:46:36Z

## Headline

| Metric | Result |
|---|---|
| **False reassurance** (violations not flagged) | **0** |
| **Wrong legal verdicts** | **0** |
| Verdict agreement (rule-backed) | 45/45 (100%) |
| Clause recall | 63/63 (100%) |
| Clause precision | 97% (2 unexpected) |
| Parameter accuracy | 39/39 (100%) |
| Document type accuracy | 12/12 |
| Quote drop rate (fabricated or mangled quotes) | 0/67 (0%) |
| Labels rejected by LabelGuard (wording said the opposite) | 0 |
| Labels downgraded to "check this yourself" | 1 |
| Out-of-scope clause types dropped | 0 |
| Sections the engine failed on | 0 |
| Total time | 32.9s |

## Per document

| Document | Type | Recall | Params | Verdicts | Unexpected | Dropped | Time |
|---|---|---|---|---|---|---|---|
| 01_lease_problems | ✓ residential_lease (1.00) | 9/9 | 7/7 | 9/9 | 0 | 0/9 | 3.0s |
| 02_lease_fair | ✓ residential_lease (1.00) | 4/4 | 7/7 | 5/5 | 0 | 0/4 | 2.8s |
| 03_lease_scan_ocr | ✓ residential_lease (1.00) | 3/3 | 2/2 | 3/3 | 2 | 0/4 | 3.2s |
| 04_employment_offer | ✓ employment (1.00) | 6/6 | 3/3 | 5/5 | 0 | 0/6 | 2.5s |
| 05_subscription_terms | ✓ subscription_terms (1.00) | 8/8 | 1/1 | 0/0 | 0 | 0/8 | 2.3s |
| 06_contractor_agreement | ✓ unknown (1.00) | 4/4 | 0/0 | 0/0 | 0 | 0/4 | 2.8s |
| 07_lease_long | ✓ residential_lease (1.00) | 12/12 | 9/9 | 10/10 | 0 | 0/15 | 4.1s |
| 08_lease_negations | ✓ residential_lease (1.00) | 1/1 | 1/1 | 1/1 | 0 | 0/1 | 3.0s |
| 09_offer_nonsolicit | ✓ employment (1.00) | 3/3 | 3/3 | 4/4 | 0 | 0/3 | 2.0s |
| 10_lease_pdf_messy | ✓ residential_lease (1.00) | 4/4 | 4/4 | 5/5 | 0 | 0/4 | 2.4s |
| 11_gym_membership | ✓ subscription_terms (1.00) | 6/6 | 1/1 | 0/0 | 0 | 0/6 | 3.3s |
| 12_lease_injection | ✓ residential_lease (1.00) | 3/3 | 1/1 | 3/3 | 0 | 0/3 | 1.7s |

## Details

### 03_lease_scan_ocr
- unexpected: rent_deposit: "The Tenant shaII pay rent of $1,450 per rnonth, due on the f"
- should be absent: rent_deposit
