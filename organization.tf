resource "github_organization_settings" "osac-project" {
  name                                         = "Open Sovereign AI Cloud"
  description                                  = "Self service deployment of OpenShift clusters, virtual machines, and bare metal hosts"
  billing_email                                = "lars@redhat.com"
  secret_scanning_enabled_for_new_repositories = true
  has_repository_projects                      = false

  members_can_create_private_repositories = false
  members_can_create_public_repositories  = false
  members_can_create_repositories         = false
}

# Lets managers manage self-hosted runners/runner groups at the org level
# (register/remove runners, create runner groups, control repo access to
# them) without granting full org-owner access. base_role defaults to
# "none", so this role carries only the permission listed below.
resource "github_organization_role" "runner_manager" {
  name        = "runner-manager"
  description = "Manage organization self-hosted runners and runner groups"

  permissions = [
    "write_organization_runners_and_runner_groups",
  ]
}

resource "github_organization_role_team" "runner_manager_managers" {
  role_id   = github_organization_role.runner_manager.role_id
  team_slug = github_team.all["managers"].slug
}

# Assign GitHub's predefined "CI/CD admin" organization role to the ci-duty
# team. It grants admin access to Actions policies, runners, runner groups, hosted
# compute network configs, secrets, variables, and usage metrics for the org -- a
# superset of the runner-manager role above -- without granting org-owner access.
data "github_organization_roles" "all" {}

locals {
  # Predefined roles are returned with source = "Predefined". The API's exact
  # spelling for this role's `name` isn't documented (GitHub's own docs example
  # for the analogous "security manager" role uses the slug "security_manager"),
  # so match the known spellings exactly rather than with a loose regex. If the
  # lookup comes back empty, get the real value and pin role_id directly:
  #   gh api /orgs/osac-project/organization-roles --jq '.roles[] | select(.source=="Predefined") | {id, name}'
  cicd_admin_role_names = ["CI/CD admin", "cicd_admin", "ci_cd_admin"]

  cicd_admin_role_id = one([
    for r in data.github_organization_roles.all.roles : r.role_id
    if r.source == "Predefined" && contains(local.cicd_admin_role_names, r.name)
  ])
}

resource "github_organization_role_team" "cicd_admin_ci_duty" {
  role_id   = local.cicd_admin_role_id
  team_slug = github_team.all["ci-duty"].slug
}

# Custom repository role for CI duty on the CI repositories (osac and
# osac-test-infra). The CI/CD admin role above covers only org-level Actions
# settings, so without this, repository secrets and variables (BUF_TOKEN,
# KONFLUX_SA_TOKEN, ...), environments, Actions settings and repository runners
# need repository admin. It also lets the team merge past the branch protection
# of a pull request (bypass_branch_protection), next to the ruleset and review
# bypass it already has (ruleset_bypass_team_ids, pull_request_bypassers), so the
# "Merge without waiting for requirements to be met" checkbox is offered to its
# members as it is to admins. Permission names come from
#   gh api /orgs/osac-project/repository-fine-grained-permissions
resource "github_organization_repository_role" "ci_maintainer" {
  name        = "ci-maintainer"
  description = "Write, plus Actions secrets, variables, environments, settings and runners, merge queue priority, and branch protection bypass"
  base_role   = "write"

  permissions = [
    "write_repository_actions_secrets",
    "write_repository_actions_variables",
    "write_repository_actions_environments",
    "write_repository_actions_settings",
    "write_repository_actions_runners",
    "jump_merge_queue",
    "create_solo_merge_queue_entry",
    "bypass_branch_protection",
  ]
}
