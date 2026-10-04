# Rule Verification Log

Every rule-backed verdict in Fine Print comes from this table. Each rule was checked against
the official consolidated text on Ontario's e-Laws site (ontario.ca/laws) on **2026-10-04**,
read in a browser because the pages render their text with JavaScript. Short excerpts are
quoted below so each rule can be audited against its source. Every rule has at least one
unit test in `FinePrintCore/Tests/FinePrintCoreTests/ShippingPacksTests.swift`, and a
coverage test fails if a rule is added without one.

**Not legal advice.** The app reports where a clause conflicts with a cited provision. It
does not tell anyone what to do.

## Residential Tenancies Act, 2006 (S.O. 2006, c. 17)
Source: https://www.ontario.ca/laws/statute/06r17

| Rule | Section | Statute text (excerpt) | Check | Tier when it fires |
|---|---|---|---|---|
| `no-pets-void` | s. 14 | "A provision in a tenancy agreement prohibiting the presence of animals in or about the residential complex is void." | present | violation |
| `acceleration-void` | s. 15 | "...all or part of the remaining rent ... becomes due upon a default of the tenant ... is void." | present | violation |
| `security-deposit` | s. 105(1), s. 4(1) | "The only security deposit that a landlord may collect is a rent deposit collected in accordance with section 106." s. 4(1): a provision "inconsistent with this Act or the regulations is void." | present | violation |
| `rent-deposit-cap` | s. 106(2) | "...shall not be more than the lesser of the amount of rent for one rent period and the amount of rent for one month." | amount ÷ monthly rent ≤ 1 | violation / compliant / needs a human if numbers are missing |
| `required-postdated-cheques` | s. 108 | "Neither a landlord nor a tenancy agreement shall require a tenant ... to (a) provide post-dated cheques ...; or (b) permit automatic debiting ..." | present (only when the lease *requires* it) | violation |
| `entry-notice` | s. 27(1), 27(3) | "...written notice given to the tenant at least 24 hours before the time of entry..." Notice must state the reason, the day, and a time "between the hours of 8 a.m. and 8 p.m." | notice hours ≥ 24 | violation / compliant |
| `rent-increase-notice` | s. 116(1), 116(4) | "...without first giving the tenant at least 90 days written notice..." An increase without notice "is void". | notice days ≥ 90 | violation / compliant |
| `rent-increase-frequency` | s. 119(1) | "...only if at least 12 months have elapsed..." since the last increase or first rental. | months between increases ≥ 12 | violation / compliant |

## O. Reg. 516/06 (General), under the RTA
Source: https://www.ontario.ca/laws/regulation/060516

RTA s. 134(1)(a) prohibits a "fee, premium, commission, bonus, penalty, key deposit or other
like amount" **"unless otherwise prescribed"**. The regulation prescribes the exceptions:

| Rule | Provision | Text (excerpt) | Check |
|---|---|---|---|
| `key-deposit-limit` | s. 17, item 3 | "Payment of a refundable key, remote entry device or card deposit, not greater than the expected direct replacement costs." | amount ÷ replacement cost ≤ 1. Usually lands on **needs a human**, because leases rarely state the replacement cost. |
| `nsf-admin-fee` | s. 17, items 4–5 | Item 4: NSF charges "charged by a financial institution to the landlord". Item 5: "an administration charge, not greater than $20, for an NSF cheque." | amount ≤ $20 |

## Employment Standards Act, 2000 (S.O. 2000, c. 41)
Source: https://www.ontario.ca/laws/statute/00e41

| Rule | Section | Statute text (excerpt) | Check | Tier |
|---|---|---|---|---|
| `non-compete-void` | s. 67.2 | "No employer shall enter into an employment contract or other agreement with an employee that is, or that includes, a non-compete agreement." 67.2(2): the agreement "is void". | present | violation, with exceptions noted: sale of business (67.2(3)) and executives (67.2(4)–(5)) |
| `vacation-minimum` | s. 33(1), s. 5(1) | "...at least two weeks after each vacation entitlement year ... if the employee's period of employment is less than five years" (three weeks at five years or more). s. 5(1): no contracting out. | vacation weeks ≥ 2 | violation / compliant |
| `overtime-threshold` | s. 22(1) | "...for each hour of work in excess of 44 hours in each work week or, if another threshold is prescribed, that prescribed threshold." | threshold hours ≤ 44 | violation / compliant |
| `overtime-rate` | s. 22(1) | "...overtime pay of at least one and one-half times his or her regular rate..." | multiplier ≥ 1.5 | violation / compliant |
| `termination-notice-review` | s. 57, s. 5(1) | Notice from "at least one week" (under one year) rising to "at least eight weeks" (eight years or more). | **review**: always routed to a person | needs a human |

## Deliberately NOT turned into rules

| Topic | Why not |
|---|---|
| Termination notice verdicts | The minimum depends on length of service, and on probation and contracting-out nuances the document can't show. It's a `review` rule instead: it cites s. 57 and sets out the schedule, but never issues a verdict. |
| Limits on guests | No RTA section addresses guests directly. It stays an amber "worth a look" flag. |
| Standard form lease (s. 12.1) | This is a property of the whole document, not of a clause. A future document-level check. |
| Rent increase guideline (s. 120) | Many units are exempt, and the annual amount changes. Mentioned in the exception note only. |
| Overtime exemptions by job | Exemptions live in regulations I haven't verified. The exception note says some jobs are exempt, without naming them. |
| Non-competes signed before the 2021 amendment | Courts have treated these differently. Mentioned in the exception note, not decided. |

## Re-verification

Statutes change. Before any release: re-read each provision above on e-Laws, update
`last_verified` in the pack, and re-run `swift test`. The app shows `last_verified` next to
every verdict, so a stale date is visible to users.
