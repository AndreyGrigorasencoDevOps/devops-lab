# Stage 03 Test - Container Artifact Delivery

Stage name: `Stage 3 - Container Artifact Delivery`

Who it is for: the project owner after completing Stage 3 and again during final roadmap review

When to take it: immediately after Stage 3 completion, then again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 3 test in revision mode from docs/revision/stage-03-test.md`
- Exam mode: `Run Stage 3 test in exam mode from docs/revision/stage-03-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.

## Candidate Instructions

- Answer from this repo's image pipeline, not from generic Docker theory.
- Refer to workflow steps, image metadata, and ACR behavior where useful.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [README.md](../../README.md)
- [.github/workflows/ci-push.yml](../../.github/workflows/ci-push.yml)
- [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
- [Dockerfile](../../Dockerfile)

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
What makes Stage 3 more than “just build a Docker image,” and what outcomes prove the stage is complete?

Marking guide:

- Full credit: explains validated release artifact creation, security scanning, smoke testing, ACR push, and digest handoff
- Partial credit: understands image building but misses the trust model around it
- Low credit: treats the stage as a basic Docker tutorial

### Q2 - Implementation specifics in this repo (20 points)
Prompt:
Walk through the push workflow from commit on `main` to a verified image in DEV ACR.

Marking guide:

- Full credit: describes quality gates, Trivy, smoke test, immutable tag resolution, build/push, and digest verification
- Partial credit: remembers the broad flow but misses important handoff details
- Low credit: cannot accurately describe the push workflow

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
Why does this project use immutable tags and digest verification instead of relying on a mutable tag like `latest`?

Marking guide:

- Full credit: explains traceability, reproducibility, and supply-chain confidence with direct repo relevance
- Partial credit: understands immutability in general but not how this repo uses it
- Low credit: cannot justify digest-aware delivery

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
The Docker smoke test or Trivy scan fails in CI. How would you interpret each failure, and what do they tell you about the artifact?

Marking guide:

- Full credit: distinguishes runtime-startup/health issues from security/config findings and ties each to release readiness
- Partial credit: understands one failure type well but not the other
- Low credit: treats both failures as generic CI noise

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What evidence would you show to prove the image is ready for CD, and why is Azure runtime work the logical next stage?

Marking guide:

- Full credit: points to workflow summary, image tag/ref/digest, ACR proof, and explains why a real runtime target comes next
- Partial credit: gives some evidence but weakly connects it to the next stage
- Low credit: cannot show proof of deployable artifact readiness

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; rebuild understanding of the image pipeline before retaking

## Weak-Area Follow-Up If Failed

- Re-read [.github/workflows/ci-push.yml](../../.github/workflows/ci-push.yml).
- Explain `image_tag`, `image_ref`, and `image_digest` out loud.
- Review how smoke tests and Trivy protect the artifact.
- Retake after you can narrate the full artifact path from memory.
