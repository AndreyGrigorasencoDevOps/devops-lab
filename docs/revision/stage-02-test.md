# Stage 02 Test - Quality Gates and CI Foundations

Stage name: `Stage 2 - Quality Gates and CI Foundations`

Who it is for: the project owner after completing Stage 2 and again during final roadmap review

When to take it: immediately after Stage 2 completion, then again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 2 test in revision mode from docs/revision/stage-02-test.md`
- Exam mode: `Run Stage 2 test in exam mode from docs/revision/stage-02-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.

## Candidate Instructions

- Answer from this repo and its workflows.
- Use workflow job names, commands, and failure conditions where relevant.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [README.md](../../README.md)
- [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
- [package.json](../../package.json)
- [test/app.test.js](../../test/app.test.js)

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
What is Stage 2 meant to protect in this project, and what checks make up the CI foundation?

Marking guide:

- Full credit: explains merge protection and names the main PR checks accurately
- Partial credit: knows the stage theme but misses several important checks
- Low credit: generic CI explanation without repo detail

### Q2 - Implementation specifics in this repo (20 points)
Prompt:
Walk through the PR workflow in this repo and explain what each major job is validating.

Marking guide:

- Full credit: covers PR title, dependency review, quality job, Trivy, smoke, and summary with the right purpose for each
- Partial credit: identifies some jobs correctly but misses the full workflow shape
- Low credit: cannot describe the actual PR workflow

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
Why is Sonar token-gated and fork-safe in this repo, and why do PR-only checks exist separately from push artifact generation?

Marking guide:

- Full credit: explains secure secret handling for forks and the different purpose of merge validation vs artifact creation
- Partial credit: understands one reason but not the full tradeoff
- Low credit: treats all CI events as interchangeable

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
A pull request fails in CI. How would you reason about whether the failure is lint, tests, dependency review, or workflow configuration?

Marking guide:

- Full credit: gives a structured triage path and ties each failure type to the correct job or command
- Partial credit: offers useful debugging ideas but without strong workflow mapping
- Low credit: generic “check the logs” answer with no deeper reasoning

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What evidence would you show that Stage 2 is doing its job, and why should container artifact work come after this stage?

Marking guide:

- Full credit: points to successful PR runs, blocked merges, coverage, and explains why artifact trust depends on stable CI foundations
- Partial credit: gives some evidence but weak sequencing logic
- Low credit: cannot justify the stage order

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; rebuild understanding of the PR workflow before retaking

## Weak-Area Follow-Up If Failed

- Re-read [.github/workflows/ci.yml](../../.github/workflows/ci.yml) line by line.
- Re-run `npm run lint` and `npm run test:coverage`.
- Explain which failures should block merge and why.
- Retake after you can narrate the PR workflow without opening the file.
