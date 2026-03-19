# Stage 01 Test - Product Build and Local Runtime

Stage name: `Stage 1 - Product Build and Local Runtime`

Who it is for: the project owner after completing Stage 1 and again during final roadmap review

When to take it: immediately after Stage 1 completion, then again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 1 test in revision mode from docs/revision/stage-01-test.md`
- Exam mode: `Run Stage 1 test in exam mode from docs/revision/stage-01-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.

## Candidate Instructions

- Answer from this repo, not from generic Node or DevOps theory.
- Refer to local flows, docs, commands, and endpoints where useful.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [docs/local-development.md](../local-development.md)
- [src/app.js](../../src/app.js)
- [src/index.mjs](../../src/index.mjs)
- [src/config/env.js](../../src/config/env.js)

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
What problem does Stage 1 solve in this project, and what concrete outcomes prove the stage is complete?

Marking guide:

- Full credit: explains the local-service baseline, names the main deliverables, and connects them to later DevOps work
- Partial credit: identifies the stage theme but misses key deliverables or why they matter later
- Low credit: generic description with little repo-specific detail

### Q2 - Implementation specifics in this repo (20 points)
Prompt:
Walk through the two supported local development flows in this repo and explain when you would choose each one.

Marking guide:

- Full credit: explains host-run Node + Docker Postgres, full Docker Compose, and their different use cases
- Partial credit: remembers both flows but cannot clearly explain the tradeoff
- Low credit: cannot describe how to run the app locally in this repo

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
Why does this project expose `/health`, `/ready`, and `/info` separately instead of using a single status endpoint?

Marking guide:

- Full credit: clearly separates liveness, readiness, and informational behavior and ties readiness to dependencies
- Partial credit: understands the endpoints but treats some of them as overlapping
- Low credit: cannot justify the separate endpoints

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
You start the app locally and see `ECONNREFUSED 127.0.0.1:5432` or `client password must be a string`. What do those usually mean, and what would you check first?

Marking guide:

- Full credit: ties the errors to Postgres availability, port mapping, env loading, or missing `DB_PASSWORD`, and suggests sensible first checks
- Partial credit: finds one likely cause but misses the full diagnostic path
- Low credit: gives generic debugging steps with no repo awareness

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What evidence would you show to prove Stage 1 is genuinely complete, and what stage naturally comes next?

Marking guide:

- Full credit: gives concrete evidence such as local commands, health checks, and docs, then connects naturally to CI foundations
- Partial credit: gives vague evidence or weak sequencing logic
- Low credit: cannot explain how to prove the stage exists

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; revisit the stage from scratch before retaking

## Weak-Area Follow-Up If Failed

- Re-run both local development flows.
- Revisit [docs/local-development.md](../local-development.md).
- Explain the three core endpoints out loud without notes.
- Retake the test after you can describe the local bootstrap path clearly.
