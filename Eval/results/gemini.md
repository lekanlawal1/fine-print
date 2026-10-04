# Eval: Gemini (gemini-3-flash-preview)

Prompt v1 · context window 24000 tokens · 6 documents · run 2026-10-04T07:00:32Z

## Headline

| Metric | Result |
|---|---|
| **False reassurance** (violations not flagged) | **0** |
| **Wrong legal verdicts** | **0** |
| Verdict agreement (rule-backed) | 22/22 (100%) |
| Clause recall | 34/34 (100%) |
| Clause precision | 100% (0 unexpected) |
| Parameter accuracy | 20/20 (100%) |
| Document type accuracy | 6/6 |
| Quote drop rate (fabricated or mangled quotes) | 0/35 (0%) |
| Sections the engine failed on | 0 |
| Total time | 14.0s |

## Per document

| Document | Type | Recall | Params | Verdicts | Unexpected | Dropped | Time |
|---|---|---|---|---|---|---|---|
| 01_lease_problems | ✓ residential_lease (1.00) | 9/9 | 7/7 | 9/9 | 0 | 0/9 | 2.8s |
| 02_lease_fair | ✓ residential_lease (1.00) | 4/4 | 7/7 | 5/5 | 0 | 0/4 | 2.2s |
| 03_lease_scan_ocr | ✓ residential_lease (1.00) | 3/3 | 2/2 | 3/3 | 0 | 0/3 | 1.9s |
| 04_employment_offer | ✓ employment (1.00) | 6/6 | 3/3 | 5/5 | 0 | 0/6 | 2.4s |
| 05_subscription_terms | ✓ subscription_terms (1.00) | 8/8 | 1/1 | 0/0 | 0 | 0/8 | 2.4s |
| 06_contractor_agreement | ✓ unknown (1.00) | 4/4 | 0/0 | 0/0 | 0 | 0/5 | 2.3s |

## Details
