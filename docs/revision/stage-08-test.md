# Stage 08 Test - Observability, Incident Response, and Release Readiness

Stage name: `Stage 8 - Observability, Incident Response, and Release Readiness`

Who it is for: the project owner while Stage 8 is in progress and again during final roadmap review

When to take it: after each major Stage 8 milestone and again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 8 test in revision mode from docs/revision/stage-08-test.md`
- Exam mode: `Run Stage 8 test in exam mode from docs/revision/stage-08-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.

## Candidate Instructions

- Answer from the current repo plus the intended Stage 8 design in the roadmap.
- Be honest about what is already implemented versus what is still planned.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [docs/cloud-architecture.md](../cloud-architecture.md)
- [src/utils/logger.js](../../src/utils/logger.js)
- [src/middlewares/httpLogger.js](../../src/middlewares/httpLogger.js)
- [src/services/readiness.service.js](../../src/services/readiness.service.js)

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
What problem is Stage 8 trying to solve, and why is observability and incident readiness essential before calling the platform job-ready?

Marking guide:

- Full credit: explains signals, alerting, drills, and recovery as the bridge from deployable to operable
- Partial credit: understands observability broadly but misses the incident-response angle
- Low credit: treats the stage as “just add some logs”

### Q2 - Implementation specifics in this repo (20 points)
Prompt:
What observability foundation already exists in this repo today, and what still needs to be added to complete Stage 8?

Marking guide:

- Full credit: identifies structured logging already present and correctly names the planned gaps: dashboards, alerts, drills, and recovery templates
- Partial credit: knows current logging exists but misses several planned additions
- Low credit: incorrectly claims features already exist or cannot identify the current baseline

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
Why are availability, errors, latency, and saturation the right first signals to focus on in this project?

Marking guide:

- Full credit: explains why these signals cover the core operator view and why they are a better first target than random metrics
- Partial credit: identifies the signals but cannot defend their priority clearly
- Low credit: generic observability answer with no design reasoning

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
Design an incident drill for this repo where a bad deploy or dependency problem causes service trouble. What should the drill test?

Marking guide:

- Full credit: includes detection, diagnosis, health validation, recovery steps, and evidence capture
- Partial credit: proposes a useful drill but misses either recovery or evidence
- Low credit: vague incident idea with no operational learning goal

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What evidence will prove Stage 8 is complete, and how should the test evolve once dashboards and alerts are really implemented?

Marking guide:

- Full credit: points to dashboards, alert-path validation, incident notes, and explains how future answers should become evidence-based instead of design-based
- Partial credit: gives some completion criteria but weak upgrade thinking
- Low credit: cannot explain how to prove Stage 8 is done

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; revisit the observability plan before retaking

## Weak-Area Follow-Up If Failed

- Re-read the Stage 8 section in [docs/ROADMAP.md](../ROADMAP.md).
- Review what the existing logger and readiness checks already provide.
- Draft one alert path and one incident drill on paper.
- Retake after you can clearly separate current implementation from planned work.
