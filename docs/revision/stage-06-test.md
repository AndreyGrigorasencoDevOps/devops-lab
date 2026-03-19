# Stage 06 Test - Delivery Workflow

Stage name: `Stage 6 - Delivery Workflow`

Who it is for: the project owner after completing Stage 6 and again during final roadmap review

When to take it: immediately after Stage 6 completion, then again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 6 test in revision mode from docs/revision/stage-06-test.md`
- Exam mode: `Run Stage 6 test in exam mode from docs/revision/stage-06-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.

## Candidate Instructions

- Answer from this repo's delivery model, especially `cd.yml` and the preflight path.
- Focus on safe operations, not just mechanical workflow steps.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [README.md](../../README.md)
- [.github/workflows/cd.yml](../../.github/workflows/cd.yml)
- [scripts/check-post-refactor-prereqs.sh](../../scripts/check-post-refactor-prereqs.sh)
- [docs/post-refactor-runbook.md](../post-refactor-runbook.md)

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
What does Stage 6 add on top of Terraform and artifact delivery, and what makes the delivery path “controlled” in this project?

Marking guide:

- Full credit: explains the manual gated CD model, validated inputs, Terraform-driven deployment, preflight checks, and operator safety
- Partial credit: understands manual CD but misses some key safety mechanisms
- Low credit: treats the stage as generic deployment automation

### Q2 - Implementation specifics in this repo (20 points)
Prompt:
Walk through the high-level flow of `cd.yml` for a normal `plan` or `apply` run, including how prod differs from dev.

Marking guide:

- Full credit: covers input validation, prod digest resolution/import, runner preparation, preflight, Terraform, and env differences
- Partial credit: gets the broad flow right but misses critical prod-specific behavior
- Low credit: cannot narrate the CD workflow accurately

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
Why is `plan` before `apply` so important in this repo, and why does prod promote by digest instead of deploying directly from a mutable tag?

Marking guide:

- Full credit: explains change visibility, safer reconciliation, traceability, and supply-chain integrity with repo context
- Partial credit: understands one concept but not the full operational reasoning
- Low credit: generic deployment advice with little project relevance

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
CD fails before Terraform even starts because the runner is offline or preflight fails. How would you reason about each failure?

Marking guide:

- Full credit: distinguishes runner lifecycle problems from unmet security/network prerequisites and suggests sensible checks
- Partial credit: recognizes the failures but cannot clearly separate the causes
- Low credit: treats both as generic workflow noise

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What evidence would you show that Stage 6 is operating safely, and why does Stage 7 naturally follow from it?

Marking guide:

- Full credit: points to safe CD runs, summaries, preflight behavior, and explains why deeper identity/secret hardening is the next step
- Partial credit: gives some evidence but weak sequencing logic
- Low credit: cannot justify the stage transition

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; rebuild understanding of the CD control flow before retaking

## Weak-Area Follow-Up If Failed

- Re-read [.github/workflows/cd.yml](../../.github/workflows/cd.yml).
- Revisit the preflight script and its purpose.
- Explain dev vs prod CD behavior without notes.
- Retake after you can narrate a safe release path from memory.
