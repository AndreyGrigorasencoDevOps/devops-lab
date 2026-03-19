# Stage 05 Test - Terraform Foundation

Stage name: `Stage 5 - Terraform Foundation`

Who it is for: the project owner after completing Stage 5 and again during final roadmap review

When to take it: immediately after Stage 5 completion, then again during final consolidation

Pass mark: `80/100`

## How To Run This Test In A Future Chat

- Revision mode: `Run Stage 5 test in revision mode from docs/revision/stage-05-test.md`
- Exam mode: `Run Stage 5 test in exam mode from docs/revision/stage-05-test.md`

## Examiner Instructions

- Ask one question at a time.
- In revision mode, allow notes and give short coaching feedback after each answer.
- In exam mode, do not give hints or reveal model answers until the end.
- Score every answer out of `20` using the rubric below.
- Finish with total score, pass/fail result, strengths, weak areas, and a short study prescription.

## Candidate Instructions

- Answer from this repo's Terraform structure, not from generic Terraform material.
- Use repo paths, backend files, tfvars, and resource ownership examples where useful.
- In revision mode, notes are allowed. In exam mode, answer unaided.

## Source References Before Taking This Test

- [docs/ROADMAP.md](../ROADMAP.md)
- [terraform/README.md](../../terraform/README.md)
- [docs/terraform.md](../terraform.md)
- [terraform/main.tf](../../terraform/main.tf)
- [terraform/variables.tf](../../terraform/variables.tf)
- [terraform/backend/dev.hcl](../../terraform/backend/dev.hcl)
- [terraform/backend/prod.hcl](../../terraform/backend/prod.hcl)

## Questions

### Q1 - Stage purpose and overview (20 points)
Prompt:
What problem does Stage 5 solve in this repo, and what outcomes prove the infrastructure is now being managed correctly?

Marking guide:

- Full credit: explains reproducibility, environment separation, Terraform-managed resources, and visibility through outputs
- Partial credit: understands infrastructure as code broadly but misses repo-specific outcomes
- Low credit: vague answer with no clear connection to this project

### Q2 - Implementation specifics in this repo (20 points)
Prompt:
Describe how Terraform is structured in this repo, including the root stack, backend split, tfvars split, and the main resources it manages.

Marking guide:

- Full credit: accurately explains the single root, backend files, env tfvars, and major managed resources
- Partial credit: gets the structure mostly right but misses key pieces
- Low credit: cannot describe the repo layout or resource ownership

### Q3 - Architecture decision or tradeoff (20 points)
Prompt:
Why is backend separation different from tfvars separation, and why do both matter in this platform?

Marking guide:

- Full credit: clearly distinguishes state location from variable inputs and explains why mixing them creates operational risk
- Partial credit: partially separates the concepts but not cleanly
- Low credit: confuses backend configuration with runtime/infrastructure inputs

### Q4 - Troubleshooting or failure scenario (20 points)
Prompt:
You accidentally initialize the wrong backend or use the wrong tfvars file. What could go wrong, and how would you detect and correct it?

Marking guide:

- Full credit: explains wrong-state risk, wrong-environment plans, drift confusion, and a sensible recovery path
- Partial credit: identifies one risk but misses the full impact
- Low credit: cannot reason about state confusion

### Q5 - Evidence, operations, or next-step reasoning (20 points)
Prompt:
What evidence would you show that Stage 5 is mature enough for delivery workflow work, and when would the optional module refactor become worth it?

Marking guide:

- Full credit: points to plan/apply outputs, resource ownership, env separation, and gives a sensible answer on when modularization is justified
- Partial credit: offers some evidence but weak reasoning on readiness or modularization
- Low credit: cannot explain how to prove the stage is working

## Pass / Fail Rules

- `80-100`: pass
- `60-79`: fail; revise weak areas and retake
- `<60`: fail; rebuild understanding of Terraform state and structure before retaking

## Weak-Area Follow-Up If Failed

- Re-read [terraform/README.md](../../terraform/README.md) and [docs/terraform.md](../terraform.md).
- Explain backend vs tfvars without looking at the docs.
- Review the list of Terraform-managed resources in the repo.
- Retake after you can describe the environment model cleanly.
