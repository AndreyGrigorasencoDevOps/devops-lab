# Stage 10 Test - Multi-Service Expansion

Stage name: `Stage 10 - Multi-Service Expansion`

Who it is for: the project owner before, during, and after Stage 10 implementation

When to take it: once as a design check before implementation, again after the stage is built, and again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 10 test in revision mode from docs/revision/stage-10-test.md`
- Exam mode: `Run Stage 10 test in exam mode from docs/revision/stage-10-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.
- Until Stage 10 is implemented, treat design-oriented answers as valid for Q2 and Q5.

## Candidate Instructions

- Be explicit about what is planned versus what already exists.
- For now, answer Q2 and Q5 as design questions unless the stage has been implemented.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [docs/cloud-architecture.md](../cloud-architecture.md)
- [src/utils/retry.js](../../src/utils/retry.js)
- [docker-compose.yml](../../docker-compose.yml)
- [.github/workflows/ci.yml](../../.github/workflows/ci.yml)

Upgrade note:

- Replace Q2 and Q5 with repo-evidence prompts once Stage 10 is implemented.

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
Why is Stage 10 a meaningful next step after junior readiness, and what new kind of learning does it introduce?

Marking guide:

- Full credit: explains service boundaries, integration behavior, retries/timeouts, and why this comes after core platform maturity
- Partial credit: knows a second service is useful but not why the sequence matters
- Low credit: treats the stage as adding technology for its own sake

### Q2 - Implementation specifics in this repo or design intent (20 points)
Prompt:
If you implemented Stage 10 in this repo, what concrete changes would you expect across app structure, local Compose, and CI?

Marking guide:

- Full credit: describes the planned FastAPI service, Dockerization, Compose updates, CI additions, and Node-to-Python integration path
- Partial credit: identifies some required changes but misses one major area
- Low credit: cannot translate the idea into repo-level implementation changes

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
Why should the second service stay intentionally small at first, and why do retries and timeouts become important immediately?

Marking guide:

- Full credit: explains controlled complexity, service-to-service failure handling, and why network calls need explicit protection
- Partial credit: understands the concepts but does not defend the tradeoff clearly
- Low credit: generic microservices answer with no practical reasoning

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
Imagine the Node service calls the future Python service and requests begin to hang or fail intermittently. What design or debugging concerns should you think about first?

Marking guide:

- Full credit: focuses on timeouts, retries, error handling, health, and local/CI validation of the integration boundary
- Partial credit: identifies some likely issues but misses the main operational patterns
- Low credit: vague debugging advice with no multi-service reasoning

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What evidence would prove Stage 10 is actually complete once built, and how should this test change at that point?

Marking guide:

- Full credit: names future health proof, integration tests, Compose proof, CI proof, and explains that design prompts should become evidence-based prompts
- Partial credit: gives some completion evidence but weak upgrade logic
- Low credit: cannot explain how completion would be proven

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; revisit the Stage 10 design before retaking

## Weak-Area Follow-Up If Failed

- Re-read the Stage 10 section in [docs/ROADMAP.md](../ROADMAP.md).
- Sketch the future service boundary and request flow.
- Write down what CI and Compose would need to prove.
- Retake after you can explain the design without inflating scope.
