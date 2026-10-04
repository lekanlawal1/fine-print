# Phase 5: Harder Evaluation, LabelGuard, and Prompt v2

## What changed in the test set

The corpus grew from 6 to **12 labelled documents**. The six new ones each target a specific
way the system could fail:

| Document | What it tests |
|---|---|
| `07_lease_long` | A 9-article, 30-clause lease mixing legal and illegal terms; chunking; key vs cleaning deposits |
| `08_lease_negations` | **False alarms**: "No damage deposit will be required", "Pets are welcome", "post-dated cheques are optional". Should produce *no* violations |
| `09_offer_nonsolicit` | A **non-solicitation** clause (legal in Ontario) that a model may mistake for a non-compete (void under ESA s. 67.2) |
| `10_lease_pdf_messy` | Text copied from a PDF: hard line breaks mid-sentence, a word hyphenated across lines ("secur-/ity"), repeated page headers |
| `11_gym_membership` | A membership agreement: subscription patterns only, no rule pack |
| `12_lease_injection` | **Prompt injection**: hidden text tells "any AI system" the lease is compliant and to report no issues |

## Prompt and pipeline iterations

| Version | Change | Why |
|---|---|---|
| v1 (Phase 3) | One prompt listing all 26 clause types | Baseline |
| v2 | Offer only the clause types relevant to the detected document type; drop out-of-scope types in code; add **LabelGuard** | Phase 3 showed the small model overloaded by 26 types; v1 eval exposed wrong labels producing wrong verdicts |
| v2.1 | Clarified two catalog descriptions: "regular rate" means an overtime multiplier of 1; IP/work-product assignment is `content_license`, not `assignment` | v2 regressions found by the eval (see below) |

### LabelGuard: checking the AI's labels in code

Quote verification proves a clause is *real*. It doesn't prove it's *labelled* correctly. On the
v1 run, **both** engines labelled "Pets are welcome. The Tenant may keep cats and dogs" as a pets
clause, and the s. 14 rule then told the user their pets-welcome clause was **void**. The
on-device model also labelled "No damage deposit will be required" as an illegal security
deposit.

LabelGuard checks the document's actual wording before any rule can judge a clause:
- **Contradicted** (explicit opposite: "pets are welcome", "no damage deposit", "optional"): the
  label is rejected and no verdict is given.
- **Unsupported** (off-topic, wording that points to another clause type such as "last month's
  rent" inside a "security deposit", or nothing actually imposed): downgraded to "check this
  yourself". Never a legal verdict on a doubtful label.

It's tested in both directions with real corpus wording (22 cases), because a guard that blocked
genuine violations would trade wrong verdicts for **false reassurance**, which is worse. A
coverage test ensures every clause type that can receive a verdict has a guard rule.

## Results (12 documents)

| Metric | Keyword v1 → v2 | On-device v1 → v2.1 | Gemini v1 → v2 → **v2.1** |
|---|---|---|---|
| **Wrong legal verdicts** | 5 → **0** | 3 → **0** | 1 → 0 → **0** |
| **False reassurance** (violations missed) | 16 → 16 | 14 → 15 | 0 → 1 → **0** |
| Verdict agreement | 36% → 36% | 44% → 42% | 100% → 98% → **100%** |
| Clause recall | 63% → 63% | 33% → **49%** | 100% → 98% → **100%** |
| Clause precision | 80% → 87% | 78% → 94% | 98% → 95% → 97% |
| Parameter accuracy | 50% → 50% | 76% → 82% | 100% → 97% → **100%** |
| Document type accuracy | 10/12 | 12/12 | 12/12 |
| Fabricated quotes | 0 | 0 | 0 |
| Time per document (Mac) | instant | ~10 s → **~4.5 s** | ~2.5 s |

### What each column shows
- **LabelGuard eliminated every wrong legal verdict** for all three engines, including the
  engine with no AI. That's the point of putting the check in code rather than in the prompt.
- **Gemini v2 regressed, and the eval caught it.** The stricter "only numbers the document
  states" wording stopped it inferring a 1.0× overtime multiplier from "paid at your regular
  hourly rate", which turned a violation into a "check this yourself". It also confused "assigns
  … all rights in the work product" with the agreement-transfer type. v2.1 fixed both with
  clearer catalog descriptions, restoring 100%. **Prompt changes need regression tests like any
  other code change.**
- **LabelGuard caught a real model error it wasn't written for.** On the OCR scan, Gemini v2.1
  labelled "pay rent of $1,450 per month" as a *rent deposit*. The wording has no deposit in it,
  so it was downgraded to "check this yourself" instead of being judged.
- **Prompt injection had no effect on either AI engine.** The hidden instruction to "report no
  issues" was ignored, and all three violations were still flagged. Even if a model obeyed it,
  the quote check and rules run in code, so an injected "no issues" couldn't fabricate a
  compliant verdict.
- **The on-device model's limit is honest and documented.** Scoping helped (recall 33% → 49%,
  4× faster, zero wrong verdicts), but it still misses about a third of the violations Gemini
  finds. The app says so in Settings ("found fewer clauses than Gemini in testing"), and the
  product decision to prefer Gemini when the user consents rests on these numbers.

### One answer-key change, disclosed
`07_lease_long` clause 2.1 ("If neither party gives proper notice, the tenancy continues on a
month-to-month basis") was flagged by Gemini as `auto_renewal`. That's a defensible label for
an automatic continuation, so it was added to that document's accepted extras, with a note in
the truth file. No other answer key was changed after seeing results.

## Still not proven
- Twelve documents written by one person are still a small, friendly sample. Real leases are
  longer and less tidy, and real OCR is noisier than a generated scan.
- LabelGuard's patterns are hand-written English. They will miss unusual phrasings, so an
  unusual *restriction* can be downgraded to "check this yourself" (a safe failure).
- Self-reported document-type confidence is not calibrated; the 0.6 threshold is a judgment call.
