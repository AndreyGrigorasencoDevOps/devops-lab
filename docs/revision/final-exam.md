# Final Exam - Junior-Ready Platform Path

Stage coverage: all roadmap stages, with emphasis on implemented work and cross-stage reasoning.

Recommended mode: `exam mode` only

Pass mark: `80/100`

## How To Run This Exam In A Future Chat

Use this prompt:

- `Run the final exam from docs/revision/final-exam.md`

Examiner behavior:

- ask one question at a time
- do not reveal model answers until the exam is finished
- score each answer out of `10` using the rubric below
- finish with total score, pass/fail result, grade band, strengths, weak areas, and a short retake prescription

## Candidate Instructions

- Answer from this project, not from generic DevOps theory.
- Use repo-specific details, workflows, paths, commands, and design choices where possible.
- Treat this as a live oral exam on how the platform works and why it was designed this way.

## Exam Rules

- Total questions: `10`
- Total score: `100`
- Pass mark: `80/100`
- Notes are not allowed in exam mode
- If an answer is incomplete, the examiner may ask one short follow-up only when needed to clarify, not to coach

## Grade Bands

- `90-100`: distinction
- `80-89`: pass
- `70-79`: near pass
- `<70`: fail

## Source References Before Attempting The Exam

- [docs/ROADMAP.md](../ROADMAP.md)
- [README.md](../../README.md)
- [docs/cloud-architecture.md](../cloud-architecture.md)
- [docs/security-operations.md](../security-operations.md)
- [docs/revision/revision-runbook.md](./revision-runbook.md)

## Section 1 - Platform Foundations and Release Flow

### Q1 - End-to-end delivery path (10 points)
Prompt:
Explain the full path from a code change to a running deployment in this project, including PR validation, push artifact generation, CD, and runtime health checks.

Marking rubric:

- Full credit: connects `ci.yml`, `ci-push.yml`, `cd.yml`, image creation, Terraform deployment, and post-deploy health validation in the correct order
- Partial credit: explains most of the path but misses key handoff points or confuses PR vs push vs CD responsibilities
- Low credit: generic CI/CD explanation without repo-specific flow

### Q2 - Commit-to-runtime traceability (10 points)
Prompt:
Show how you would trace one image from commit SHA to the running environment by immutable tag and digest, and explain why that matters.

Marking rubric:

- Full credit: explains `sha-<short_sha>`, digest capture, DEV ACR source, prod digest promotion, and how runtime image identity is validated
- Partial credit: understands tags and digests but does not fully connect them to this repo's workflows
- Low credit: treats tags as sufficient or cannot explain where digest proof is found

### Q3 - Health model and service readiness (10 points)
Prompt:
Explain why this project has `/health`, `/ready`, and `/info`, and how those endpoints support both local development and deployment operations.

Marking rubric:

- Full credit: distinguishes liveness from readiness, ties readiness to DB dependency, and explains operational value in CI/CD/runtime
- Partial credit: knows the endpoints but gives only partial operational reasoning
- Low credit: treats the endpoints as redundant or interchangeable

## Section 2 - Infrastructure and Security Reasoning

### Q4 - Terraform environment model (10 points)
Prompt:
Explain how Terraform is organized in this repo, how backend and tfvars separation work, and what can go wrong if they are mixed up.

Marking rubric:

- Full credit: explains single root, env-specific backends, env-specific tfvars, state isolation, and state confusion/drift risk
- Partial credit: understands Terraform layout but cannot clearly explain the risk model
- Low credit: cannot distinguish backend configuration from variable inputs

### Q5 - Identity and secret access model (10 points)
Prompt:
Explain the full identity model for GitHub Actions, Container App runtime, ACR access, and Key Vault access in the current platform.

Marking rubric:

- Full credit: explains OIDC for deploy identity, managed identity for runtime, `AcrPull`, `Key Vault Secrets Officer`, and `Key Vault Secrets User`
- Partial credit: understands some roles but misses the identity boundaries or mixes deploy and runtime responsibilities
- Low credit: falls back to generic “secrets in CI” explanations with little repo accuracy

### Q6 - Network and runner design tradeoffs (10 points)
Prompt:
Explain why the shared CD runner lives in the network path, how Key Vault private access works, and why the platform moved away from looser temporary access patterns.

Marking rubric:

- Full credit: explains private endpoints, private DNS, runner/runtime VNet access path, and the move from `public_allow` to `firewall`
- Partial credit: understands the broad idea but misses why the runner location and network posture matter operationally
- Low credit: treats the network model as optional detail rather than part of secure deployment design

## Section 3 - Incident Response and Troubleshooting

### Q7 - Failed readiness after deploy (10 points)
Prompt:
After a deployment, `/health` is fine but `/ready` returns `503`. Walk through your investigation path and likely root causes in this project.

Marking rubric:

- Full credit: checks DB connectivity, Key Vault secret resolution, identity roles, firewall/private access path, and deployment/runtime config
- Partial credit: identifies some plausible causes but misses the repo-specific dependency chain
- Low credit: gives only generic app-debugging advice

### Q8 - Failed deploy or rollback drill (10 points)
Prompt:
Describe how you would handle a failed deploy or rollback exercise in this project, including what evidence you would capture before closing the incident.

Marking rubric:

- Full credit: references `plan` before `apply`, workflow evidence, health validation, recovery steps, and post-incident note capture
- Partial credit: understands rollback/recovery at a high level but misses evidence and repo workflow details
- Low credit: cannot translate failure handling into concrete operator steps

## Section 4 - Roadmap Evolution and Design Tradeoffs

### Q9 - Why this learning sequence makes sense (10 points)
Prompt:
Explain why the roadmap prioritizes observability and junior-readiness evidence before multi-service expansion and AKS.

Marking rubric:

- Full credit: connects learning load, operational maturity, explanation skill, and the current Container Apps baseline before adding new complexity
- Partial credit: understands ordering but cannot defend it with concrete project reasoning
- Low credit: treats roadmap order as arbitrary

### Q10 - Defend the platform (10 points)
Prompt:
Pick three major architecture decisions in this repo, defend why they were reasonable, and name one meaningful improvement that is still pending.

Marking rubric:

- Full credit: chooses strong examples from this repo, defends tradeoffs clearly, and names a realistic next improvement such as observability, drills, or portfolio proof
- Partial credit: picks valid decisions but the defense is shallow or too generic
- Low credit: cannot connect decisions to project constraints or future roadmap direction

## Pass / Fail Rules

- `80-100`: pass
- `70-79`: near pass; review weak areas and retake
- `<70`: fail; complete targeted revision before retake

## Retake Guidance

- Re-read the matching sections in [docs/revision/revision-runbook.md](./revision-runbook.md).
- Rebuild your weakest two explanations out loud without notes.
- Review one workflow path and one infrastructure path before trying again.
- Retake the exam only after you can explain the failed topics clearly in your own words.
