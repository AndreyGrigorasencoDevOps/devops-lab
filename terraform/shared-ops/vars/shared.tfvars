location            = "uksouth"
resource_group_name = "taskapi-shared-ops-rg-uks"

monthly_budget_amount = 150
budget_contact_emails = [
  "platform-owner@example.com",
  "billing-owner@example.com",
]
budget_start_date = "2026-04-01T00:00:00Z"

runner_resource_group_name           = "taskapi-dev-rg-uks"
runner_vm_name                       = "taskapi-shared-cd-runner-01"
runner_schedule_timezone             = "Europe/Paris"
runner_weekday_start_time            = "07:00"
runner_weekday_stop_time             = "23:00"
runner_patch_day                     = "Wednesday"
runner_patch_time                    = "22:00"
runner_right_sizing_review_frequency = "monthly"

tags = {
  project = "taskapi"
  scope   = "shared-ops"
  owner   = "andrei"
}
