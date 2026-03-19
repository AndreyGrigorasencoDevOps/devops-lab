# Stage 11 Test - Kubernetes and AKS Expansion

Stage name: `Stage 11 - Kubernetes and AKS Expansion`

Who it is for: the project owner before, during, and after Stage 11 implementation

When to take it: once as a design check before implementation, again after the stage is built, and again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 11 test in revision mode from docs/revision/stage-11-test.md`
- Exam mode: `Run Stage 11 test in exam mode from docs/revision/stage-11-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.
- Until Stage 11 is implemented, treat design-oriented answers as valid for Q2 and Q5.

## Candidate Instructions

- Be explicit about what is planned versus what already exists.
- For now, answer Q2 and Q5 as design questions unless the stage has been implemented.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [docs/cloud-architecture.md](../cloud-architecture.md)
- [terraform/README.md](../../terraform/README.md)
- [docs/terraform.md](../terraform.md)

Upgrade note:

- Replace Q2 and Q5 with repo-evidence prompts once Stage 11 is implemented.

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
Why is Stage 11 kept as later expansion work, and what new responsibilities does it add compared with the current Container Apps model?

Marking guide:

- Full credit: explains why AKS is later, what Kubernetes adds operationally, and why the sequence matters
- Partial credit: understands AKS is “more complex” but cannot explain the concrete responsibility shift
- Low credit: treats AKS as a default upgrade with no tradeoff reasoning

### Q2 - Implementation specifics in this repo or design intent (20 points)
Prompt:
If you implemented Stage 11 in this repo, what concrete manifests, Terraform changes, and identity/network decisions would need to appear?

Marking guide:

- Full credit: includes `k8s/` manifests, probes, resource controls, ingress, HPA, AKS Terraform, ACR pull identity, and network model choice
- Partial credit: identifies some major pieces but misses important platform concerns
- Low credit: cannot translate the idea into repo-level implementation work

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
When is Container Apps still enough, and when does AKS become justified for this project?

Marking guide:

- Full credit: explains the tradeoff in terms of operational needs, platform control, and complexity cost
- Partial credit: gives a broad answer but not a strong decision framework
- Low credit: generic platform preference with no project relevance

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
Imagine the future AKS deployment is unstable because probes, limits, or networking are wrong. What design and troubleshooting areas would you inspect first?

Marking guide:

- Full credit: focuses on liveness/readiness probes, requests/limits, ingress, scaling signals, and network model assumptions
- Partial credit: knows some likely causes but misses the operational structure
- Low credit: generic Kubernetes debugging with no tie to the planned stage

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What evidence would prove Stage 11 is complete once implemented, and how should this test evolve after real AKS work exists in the repo?

Marking guide:

- Full credit: names future manifests, Terraform plans, deployment proof, health validation, and explains the shift from design to evidence questions
- Partial credit: gives some completion signals but weak upgrade logic
- Low credit: cannot define proof of completion

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; revisit the Stage 11 design before retaking

## Weak-Area Follow-Up If Failed

- Re-read the Stage 11 section in [docs/ROADMAP.md](../ROADMAP.md).
- Write down what Kubernetes adds that Container Apps does not.
- Sketch the minimum AKS design you would need before implementation.
- Retake after you can defend why AKS is later in the roadmap.
