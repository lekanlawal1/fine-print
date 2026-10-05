# Case Study: Fine Print

**The problem.** Tenants and new hires sign documents full of clauses that Ontario law has already made void: "no pets" rules, damage deposits, non-competes. An AI model can read a contract in seconds, but one that confidently calls a legal clause illegal does real harm.

**The build.** Fine Print is a SwiftUI iOS app that reads a lease, job offer or terms of service from pasted text, a PDF, or a photo read on the device. An AI model only extracts clauses and must quote each one word for word. Code then checks that the quote exists, checks that the document's wording supports the AI's label, and only then applies cited rules from the Residential Tenancies Act and Employment Standards Act, each verified against the official statute text.

**What testing found.** A 12-document evaluation set, built to break the system, showed that both AI engines labelled "Pets are welcome" as a pet ban, which the rules then called void. Quote checking couldn't catch it because the quote was real. A deterministic label check brought wrong legal verdicts to zero for every engine. The evaluation also caught a regression caused by a prompt fix.

**The result.** Gemini finds 100% of the labelled clauses with no missed violations and no wrong verdicts, and the app asks consent before any document leaves the phone. The lesson: verify the AI's claims in code, including the labels it puts on real text.
