# Stage 07 Test - Identity, Secrets, and Secure Operations

Stage name: `Stage 7 - Identity, Secrets, and Secure Operations`

Who it is for: the project owner after completing Stage 7 and again during final roadmap review

When to take it: immediately after Stage 7 completion, then again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 7 test in revision mode from docs/revision/stage-07-test.md`
- Exam mode: `Run Stage 7 test in exam mode from docs/revision/stage-07-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.

## Candidate Instructions

- Answer from this repo's identity, Key Vault, and runner/network model.
- Use role names and security posture terms precisely.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [docs/security-operations.md](../security-operations.md)
- [docs/cloud-architecture.md](../cloud-architecture.md)
- [docs/azure.md](../azure.md)
- [docs/terraform.md](../terraform.md)

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
What does Stage 7 change about the platform, and why is this more than “just adding secrets”?

Marking guide:

- Full credit: explains identity hardening, private access paths, secret ownership, operations cadence, and steady-state posture
- Partial credit: understands security improvements broadly but misses key operational elements
- Low credit: treats the stage as a simple secret-storage task

### Q2 - Implementation specifics in this repo (20 points)
Prompt:
Explain the current deploy identity, runtime identity, Key Vault role model, and private access path in this repo.

Marking guide:

- Full credit: accurately explains OIDC deploy identity, managed runtime identity, `Key Vault Secrets Officer`, `Key Vault Secrets User`, and private endpoint/DNS path
- Partial credit: knows some roles or identities but not the full model
- Low credit: cannot explain how secure access works end to end

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
Why did the platform temporarily use `public_allow`, and why is `firewall` with `bypass = None` the correct steady-state target?

Marking guide:

- Full credit: explains the stabilization path, bootstrap realities, and the security reason for the final hardened posture
- Partial credit: understands the two modes but not the migration logic
- Low credit: cannot justify the move from temporary to hardened posture

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
You hit `ForbiddenByFirewall`, missing secret access, or a role-binding problem during deploy or runtime. How would you investigate in this project?

Marking guide:

- Full credit: checks Key Vault posture, private access path, secret existence, role assignments, and env-specific identity scope
- Partial credit: identifies some checks but misses the full security path
- Low credit: generic access debugging with no repo specificity

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What evidence would you show that Stage 7 is operationally mature, and what recurring checks should continue even after the rollout is “done”?

Marking guide:

- Full credit: points to rotation runbook, access review cadence, preflight enforcement, runner posture, and cost-control evidence
- Partial credit: gives some evidence but misses the recurring operations dimension
- Low credit: treats security hardening as one-time setup only

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; rebuild understanding of the security model before retaking

## Weak-Area Follow-Up If Failed

- Re-read [docs/security-operations.md](../security-operations.md).
- Explain the deploy identity vs runtime identity model without notes.
- Review the Key Vault posture and runner/network path.
- Retake after you can describe the steady-state security model clearly.
