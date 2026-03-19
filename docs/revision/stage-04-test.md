# Stage 04 Test - Azure Runtime Platform

Stage name: `Stage 4 - Azure Runtime Platform`

Who it is for: the project owner after completing Stage 4 and again during final roadmap review

When to take it: immediately after Stage 4 completion, then again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 4 test in revision mode from docs/revision/stage-04-test.md`
- Exam mode: `Run Stage 4 test in exam mode from docs/revision/stage-04-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.

## Candidate Instructions

- Answer from this repo's Azure design, not from generic Azure documentation.
- Use the terms Container Apps, managed identity, ACR, Key Vault, and readiness checks precisely.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [docs/cloud-architecture.md](../cloud-architecture.md)
- [docs/azure.md](../azure.md)
- [src/app.js](../../src/app.js)
- [terraform/main.tf](../../terraform/main.tf)

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
What does Stage 4 add to the platform, and why is getting the service running in Azure a meaningful step after artifact delivery?

Marking guide:

- Full credit: explains the move from artifact trust to real runtime operation, identity-based access, and operational relevance
- Partial credit: understands cloud deployment in general but misses why this stage matters in sequence
- Low credit: generic “deploy to Azure” explanation

### Q2 - Implementation specifics in this repo (20 points)
Prompt:
Describe how this repo runs on Azure Container Apps and how the runtime gets both image and secret access.

Marking guide:

- Full credit: explains Container Apps, managed identity, `AcrPull`, Key Vault integration, and runtime checks accurately
- Partial credit: describes the runtime but misses one major access path or role
- Low credit: cannot explain how the runtime actually works

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
Why was an identity-based runtime model important here, and why was Container Apps a reasonable choice at this stage?

Marking guide:

- Full credit: defends managed identity over app-owned secrets and Container Apps over heavier orchestration for this stage
- Partial credit: knows the choices but cannot justify them well
- Low credit: offers generic cloud opinions without repo-specific tradeoffs

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
The app deploys, but it cannot pull the image or cannot become ready. What are your most likely causes and first checks in this project?

Marking guide:

- Full credit: checks ACR access, managed identity, Key Vault access, DB dependency, and readiness path in a structured way
- Partial credit: identifies some causes but misses the access model or dependency chain
- Low credit: vague debugging with no platform reasoning

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What evidence would you show that Stage 4 is genuinely working, and why is Terraform the correct next step?

Marking guide:

- Full credit: points to running app evidence, health checks, identity-based access, and explains why reproducibility becomes the next priority
- Partial credit: gives some evidence but weak reasoning about the next stage
- Low credit: cannot connect runtime proof to infrastructure-as-code motivation

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; rebuild understanding of the Azure runtime model before retaking

## Weak-Area Follow-Up If Failed

- Re-read [docs/cloud-architecture.md](../cloud-architecture.md) and [docs/azure.md](../azure.md).
- Explain how the runtime identity gets image and secret access.
- Revisit the role of `/ready` after deployment.
- Retake after you can describe the Azure runtime path clearly from memory.
