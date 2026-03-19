# Stage 09 Test - Junior Readiness and Portfolio Evidence

Stage name: `Stage 9 - Junior Readiness and Portfolio Evidence`

Who it is for: the project owner while Stage 9 is in progress and again during final roadmap review

When to take it: after each major Stage 9 milestone and again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 9 test in revision mode from docs/revision/stage-09-test.md`
- Exam mode: `Run Stage 9 test in exam mode from docs/revision/stage-09-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.

## Candidate Instructions

- Answer as if you are explaining the project to an interviewer, lead, or mentor.
- Use evidence from this repo and be concrete.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [README.md](../../README.md)
- [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
- [.github/workflows/ci-push.yml](../../.github/workflows/ci-push.yml)
- [.github/workflows/cd.yml](../../.github/workflows/cd.yml)
- [docs/revision/revision-runbook.md](./revision-runbook.md)

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
What is Stage 9 trying to prove, and why is this stage about more than finishing technical tasks?

Marking guide:

- Full credit: explains junior-readiness, evidence, explanation skill, and safe platform operation as the goal
- Partial credit: understands “portfolio” but misses the operator-readiness side
- Low credit: treats the stage as superficial polish only

### Q2 - Implementation specifics in this repo (20 points)
Prompt:
If you had to demo the full release flow in this repo right now, what exact story would you tell from PR through running deployment?

Marking guide:

- Full credit: narrates the real repo flow clearly using PR CI, CI Push, image metadata, CD, Terraform, and health checks
- Partial credit: gives the broad flow but misses important handoff details
- Low credit: cannot explain the release path coherently

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
Why does this roadmap place explanation quality, digest tracing, and evidence gathering before later platform expansion work?

Marking guide:

- Full credit: defends the sequencing with learning, interview readiness, and operational maturity logic
- Partial credit: understands the priority but cannot defend it strongly
- Low credit: treats the ordering as arbitrary

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
An interviewer asks you how you would handle a failed deploy in this project and what proof you would show afterward. How do you answer?

Marking guide:

- Full credit: explains safe recovery thinking, workflow evidence, health validation, incident notes, and follow-up proof
- Partial credit: understands recovery but misses the evidence and communication angle
- Low credit: generic failure-handling answer with no repo-specific grounding

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What should your Stage 9 evidence pack contain, and how would you organize it so it is easy to present and defend?

Marking guide:

- Full credit: includes workflow links, Terraform outputs, digest trace, incident or recovery notes, and a sensible presentation order
- Partial credit: lists some useful evidence but lacks structure or completeness
- Low credit: cannot define a convincing evidence pack

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; rebuild your project narrative before retaking

## Weak-Area Follow-Up If Failed

- Practice a five-minute walkthrough of the project out loud.
- Build a draft evidence pack with links and screenshots or notes.
- Rehearse one digest trace and one failure-recovery story.
- Retake after you can explain the platform clearly without rambling.
