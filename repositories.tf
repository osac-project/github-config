locals {
  # Teams flagged "contributor" in teams.csv get push access on every
  # repository that uses this list. Iterating github_team.all (rather than
  # the CSV) makes the repositories wait for the teams to exist.
  contributor_teams = [
    for name, team in github_team.all : team.name
    if local.teams_csv[name].contributor == "true"
  ]
  teams_csv = { for team in csvdecode(file("teams.csv")) : team.name => team }
}

module "repo_issues" {
  source                 = "./modules/common_repository"
  name                   = "issues"
  visibility             = "public"
  description            = "Issues related to AI in a Box project"
  use_public_template    = false
  all_members_permission = "push"
}

module "repo_docs" {
  source                 = "./modules/common_repository"
  name                   = "docs"
  description            = "General documentation for the AI in a Box project"
  use_public_template    = false
  all_members_permission = "push"
  # Merged into osac mono-repo docs/, with full commit history preserved;
  # archived.
  archived    = true
  lock_branch = true

  teams = [
    {
      team_id    = "documentation-wg"
      permission = "push"
    }
  ]
}

module "repo_dotgithub" {
  source              = "./modules/common_repository"
  name                = ".github"
  description         = "Profile README for osac-project organization"
  use_public_template = false
}

module "repo_github_config" {
  source              = "./modules/common_repository"
  name                = "github-config"
  description         = "Repository for managing osac-project github organization"
  use_public_template = false
  required_approvals  = 1
  required_status_checks = [
    { context = "pre-commit", integration_id = 15368 },
  ]
  ruleset_bypass_team_ids = [github_team.all["managers"].id]

  # An approval of a code owner is needed where CODEOWNERS names one (a team file needs its team, see CODEOWNERS), and every
  # pull request needs the owner (the ruleset below). Pull requests merge by themselves once approved (see
  # .github/workflows/auto-merge.yaml), so a new commit must drop the approvals: nothing reviewed may change afterwards.
  require_code_owner_reviews = true
  dismiss_stale_reviews      = true

  contributor_teams = local.contributor_teams
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    },
    {
      team_id    = github_team.all["github-config-owners"].name
      permission = "push"
    }
  ]
}

# Every pull request to github-config needs an approval of github-config-owners, whatever files it changes. CODEOWNERS cannot
# say "this team AND that team" (one owner per path is enough), so the team files get their own team from CODEOWNERS and this
# ruleset adds the owners on top. The author of a pull request cannot approve it, so a pull request of an owner is approved by
# someone else, or merged by an organization admin, who may bypass the ruleset like the status checks one. Required
# reviewers is a beta feature of GitHub rulesets.
resource "github_repository_ruleset" "github_config_owner_review" {
  name        = "owner-review"
  repository  = "github-config"
  target      = "branch"
  enforcement = "active"

  bypass_actors {
    actor_id    = 1
    actor_type  = "OrganizationAdmin"
    bypass_mode = "always"
  }

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    pull_request {
      required_approving_review_count = 0
      dismiss_stale_reviews_on_push   = true

      required_reviewers {
        minimum_approvals = 1
        file_patterns     = ["**"]

        reviewer {
          id   = tonumber(github_team.all["github-config-owners"].id)
          type = "Team"
        }
      }
    }
  }

  depends_on = [module.repo_github_config]
}

module "repo_dotgithub_private" {
  source      = "./modules/common_repository"
  visibility  = "private"
  name        = ".github-private"
  description = "Member-only README for osac-project organization"
}

module "repo_public_template" {
  source              = "./modules/common_repository"
  visibility          = "public"
  name                = "public_template"
  description         = "Use this repository as the template for public-facing repositories"
  use_public_template = false
  is_template         = true
}

module "repo_managed_cluster_config" {
  source              = "./modules/common_repository"
  visibility          = "public"
  name                = "managed-cluster-config"
  use_public_template = false
  description         = "Configuration for OpenShift cluster running ACM w/ Hosted Control Planes"
  contributor_teams   = local.contributor_teams
}

module "repo_managed_cluster_apps" {
  source            = "./modules/common_repository"
  visibility        = "public"
  name              = "managed-cluster-apps"
  description       = "Argocd apps to deploy resources on the innabox cluster"
  contributor_teams = local.contributor_teams
}

module "repo_fulfillment_service" {
  source      = "./modules/common_repository"
  visibility  = "public"
  name        = "fulfillment-service"
  description = "Cloud-in-a-box fulfillment service"
  # Merged into osac mono-repo (OSAC-1732/OSAC-1733); archived (OSAC-1737).
  archived          = true
  lock_branch       = true
  contributor_teams = local.contributor_teams
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    }
  ]
  required_approvals = null
  required_status_checks = [
    { context = "e2e-vmaas-full-install / e2e", integration_id = 15368 },
  ]
  ruleset_bypass_team_ids = [github_team.all["managers"].id]
  push_allowances         = ["/openshift-merge-robot", "osac-project/${github_team.all["managers"].name}", "osac-project/org-admins"]
  environments            = [{ name = "e2e-test" }]
  pages = {
    build_type = "workflow"
    source = {
      branch = "main"
      path   = "/"
    }
  }
}

module "repo_osac" {
  source      = "./modules/common_repository"
  visibility  = "public"
  name        = "osac"
  description = "OSAC mono-repo: consolidates fulfillment-service, osac-operator, osac-aap, and osac-installer"
  # Always show "Update branch" (merge or rebase). The merge queue does not
  # require up-to-date branches, so GitHub otherwise hides the button.
  allow_update_branch = true
  # The contributor teams, and "maintainers" (the parent of the wg-* teams): the owner of every path in CODEOWNERS that no
  # other rule names.
  contributor_teams = concat(local.contributor_teams, [github_team.maintainers.name])
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    },
    {
      team_id    = github_team.all["ci-duty"].name
      permission = github_organization_repository_role.ci_maintainer.name
    }
  ]
  # Native GitHub review: one approval, dropped when a new commit is pushed. Prow stays only for the Jira reference, the
  # Jira lifecycle and cherry-picks.
  required_approvals    = 1
  dismiss_stale_reviews = true
  # A path listed in CODEOWNERS needs approval from its owner team (today the CI definition under .github/; a team adds
  # its own folders by a pull request to CODEOWNERS), and a path with no owner needs nobody in particular.
  require_code_owner_reviews = true
  # ci-duty can force-merge ("Merge without waiting for requirements to be met"): that needs a bypass of these review
  # requirements as well as of the ci-status-checks ruleset below. Admins (managers) bypass them already.
  pull_request_bypassers = ["osac-project/${github_team.all["ci-duty"].name}"]
  # Three required checks. `CI` is the one job that adds up every cheap check that applies to the change (ci.yml; a part
  # that does not apply is skipped inside it) and `jira-reference` says the title names a Jira issue or NO-ISSUE (the
  # Prow-set label jira/valid-reference); both are posted by GitHub Actions. `E2E` is the full-install suites on a real
  # cluster (e2e-pr.yml for a pull request, e2e-queue.yml for a merge queue entry). It is required from the OSAC CI
  # app only (integration id 4966101, the app that writes it), so a workflow that is not that app cannot satisfy it.
  required_status_checks = [
    { context = "CI", integration_id = 15368 },
    { context = "jira-reference", integration_id = 15368 },
    { context = "E2E", integration_id = 4966101 },
  ]
  ruleset_bypass_team_ids = [
    github_team.all["managers"].id,
    github_team.all["ci-duty"].id,
  ]

  # osac-release/* tags trigger a Konflux staging release (see
  # .tekton/*-release.yaml and the trigger-konflux-staging-release job in
  # osac-build-and-publish.yaml) -- only the osac-ci app may create them,
  # and nobody may move or delete one once pushed.
  tag_rulesets = [
    {
      name                    = "osac-release-tag"
      ref_patterns            = ["refs/tags/osac-release/*"]
      creation_bypass_app_ids = [4966101] # osac-ci
    }
  ]

  # Full-install E2E gates can take over two hours; leave room for slow runs.
  merge_queue = {
    merge_method                      = "SQUASH"
    max_entries_to_build              = 4
    max_entries_to_merge              = 5
    min_entries_to_merge              = 1
    min_entries_to_merge_wait_minutes = 5
    check_response_timeout_minutes    = 180
    grouping_strategy                 = "ALLGREEN"
  }
}

# Branch protection for any release-X.Y stabilization branch (e.g.
# release-0.4, cut per docs/RELEASING.md in osac-project/osac), mirroring
# repo_osac's own ci-status-checks ruleset above: same three required
# checks, same review requirements (real approving-review-count embedded
# directly in the ruleset's own pull_request rule, not left to classic
# branch protection -- github_branch_protection can't target a branch
# that doesn't exist yet, so there's no equivalent of main's "real review
# enforcement happens at the classic-protection level" split here), same
# bypass actors as repo_osac's own ruleset_bypass_team_ids (managers,
# ci-duty) plus the GitHub Merge Queue app (262318) -- that one specific
# bypass actor matches the module's own dynamic bypass_actors block
# (modules/common_repository/main.tf): it exists so the queue bot can
# push a rebased commit past deletion/non_fast_forward after queue checks
# pass, needed here because non_fast_forward (unlike repo_osac's
# merge_queue-bundled ruleset, which has no such rule to bypass at all)
# is part of this ruleset. Also blocks deletion/force-push, since a
# release branch has none of main's own reasons to allow force-push.
#
# NOT generated by the shared module: release-* is an osac-specific
# pattern, not something every repo this module manages needs, so this
# is a standalone resource rather than a new module variable (unlike
# tag_rulesets above, which genuinely is generic across repos).
#
# Created out-of-band via the GitHub API on 2026-11-04 when release-0.4
# was actually cut (before this repo's own plan/apply cycle could run);
# codified here afterward so it's reviewable and reproducible like
# everything else in this file, via the `import` block below.
resource "github_repository_ruleset" "release_branch_protection" {
  name        = "release-branch-protection"
  repository  = "osac"
  target      = "branch"
  enforcement = "active"

  bypass_actors {
    actor_id    = 1
    actor_type  = "OrganizationAdmin"
    bypass_mode = "always"
  }
  bypass_actors {
    actor_id    = 262318
    actor_type  = "Integration"
    bypass_mode = "always"
  }
  bypass_actors {
    actor_id    = github_team.all["managers"].id
    actor_type  = "Team"
    bypass_mode = "always"
  }
  bypass_actors {
    actor_id    = github_team.all["ci-duty"].id
    actor_type  = "Team"
    bypass_mode = "always"
  }

  conditions {
    ref_name {
      include = ["refs/heads/release-*"]
      exclude = []
    }
  }

  rules {
    required_status_checks {
      # Matches repo_osac's own merge_queue-enabled branches: the queue
      # already re-tests against latest before merging, so requiring
      # checks to be re-run up to date here would be redundant.
      strict_required_status_checks_policy = false

      required_check {
        context        = "CI"
        integration_id = 15368
      }
      required_check {
        context        = "jira-reference"
        integration_id = 15368
      }
      required_check {
        context        = "E2E"
        integration_id = 4966101
      }
    }

    pull_request {
      required_approving_review_count   = 1
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = true
      require_last_push_approval        = false
      required_review_thread_resolution = false
      allowed_merge_methods             = ["merge", "squash", "rebase"]
    }

    deletion         = true
    non_fast_forward = true
  }

  depends_on = [module.repo_osac]
}

import {
  to = github_repository_ruleset.release_branch_protection
  id = "osac:26559405"
}

# Merge queue for release-0.4 specifically. GitHub rejects a wildcard
# ref_name pattern when a merge_queue rule is present ("Wildcard ref
# names are not supported when merge queue is enabled" -- confirmed
# live), so this can't be folded into release_branch_protection above.
# A sibling resource like this one is needed per release branch going
# forward (0.5, 0.6, ...), unlike that wildcard ruleset which only had
# to be created once.
#
# Matches the live ruleset's actual bypass_actors exactly (it has no
# restrictive rule for them to bypass -- merge_queue alone doesn't
# restrict direct pushes, that's release_branch_protection's job -- but
# they were set on creation and this codifies what's live rather than
# narrowing it as a drive-by cleanup under this change's scope).
resource "github_repository_ruleset" "release_0_4_merge_queue" {
  name        = "release-0.4-merge-queue"
  repository  = "osac"
  target      = "branch"
  enforcement = "active"

  bypass_actors {
    actor_id    = 1
    actor_type  = "OrganizationAdmin"
    bypass_mode = "always"
  }
  bypass_actors {
    actor_id    = 262318
    actor_type  = "Integration"
    bypass_mode = "always"
  }
  bypass_actors {
    actor_id    = github_team.all["managers"].id
    actor_type  = "Team"
    bypass_mode = "always"
  }
  bypass_actors {
    actor_id    = github_team.all["ci-duty"].id
    actor_type  = "Team"
    bypass_mode = "always"
  }

  conditions {
    ref_name {
      include = ["refs/heads/release-0.4"]
      exclude = []
    }
  }

  rules {
    merge_queue {
      merge_method                      = "SQUASH"
      max_entries_to_build              = 4
      max_entries_to_merge              = 5
      min_entries_to_merge              = 1
      min_entries_to_merge_wait_minutes = 5
      check_response_timeout_minutes    = 180
      grouping_strategy                 = "ALLGREEN"
    }
  }

  depends_on = [module.repo_osac]
}

import {
  to = github_repository_ruleset.release_0_4_merge_queue
  id = "osac:26569686"
}

module "repo_cloudkit_operator" {
  source      = "./modules/common_repository"
  visibility  = "public"
  name        = "osac-operator"
  description = "OSAC kubernetes operator"
  # Merged into osac mono-repo (OSAC-1732/OSAC-1733); archived (OSAC-1737).
  archived          = true
  lock_branch       = true
  contributor_teams = local.contributor_teams
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    }
  ]
  required_approvals = null
  required_status_checks = [
    { context = "e2e-vmaas-full-install / e2e", integration_id = 15368 },
  ]
  ruleset_bypass_team_ids = [github_team.all["managers"].id]
  push_allowances         = ["/openshift-merge-robot", "osac-project/${github_team.all["managers"].name}", "osac-project/org-admins"]
  environments            = [{ name = "e2e-test" }]
}

module "repo_cloudkit_aap" {
  source      = "./modules/common_repository"
  visibility  = "public"
  name        = "osac-aap"
  description = "OSAC AAP configuration and playbooks"
  # Merged into osac mono-repo (OSAC-1732/OSAC-1733); archived (OSAC-1737).
  archived          = true
  lock_branch       = true
  contributor_teams = local.contributor_teams
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    }
  ]
  required_approvals = null
  required_status_checks = [
    { context = "e2e-vmaas-full-install / e2e", integration_id = 15368 },
  ]
  ruleset_bypass_team_ids = [github_team.all["managers"].id]
  push_allowances         = ["/openshift-merge-robot", "osac-project/${github_team.all["managers"].name}", "osac-project/org-admins"]
  environments            = [{ name = "e2e-test" }]
}

module "repo_cloudkit_aap_ee" {
  source            = "./modules/common_repository"
  visibility        = "public"
  name              = "osac-aap-ee"
  description       = "OSAC execution environment for AAP"
  contributor_teams = local.contributor_teams
}

module "repo_cloudkit_operator_config" {
  source            = "./modules/common_repository"
  visibility        = "public"
  name              = "osac-operator-config"
  description       = "Configuration for our deployment of the OSAC operator"
  contributor_teams = local.contributor_teams
}

module "repo_osac_installer" {
  source      = "./modules/common_repository"
  visibility  = "public"
  name        = "osac-installer"
  description = "Integration repository for installing all OSAC components"
  # Merged into osac mono-repo (OSAC-1732/OSAC-1733); archived (OSAC-1737).
  archived          = true
  lock_branch       = true
  contributor_teams = local.contributor_teams
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    }
  ]

  required_status_checks = [
    { context = "e2e-vmaas-full-install / e2e", integration_id = 15368 },
  ]

  required_approvals      = null
  ruleset_bypass_team_ids = [github_team.all["managers"].id]
  push_allowances         = ["/openshift-merge-robot", "osac-project/${github_team.all["managers"].name}", "osac-project/org-admins"]
  environments            = [{ name = "e2e-test" }]
}

module "repo_enhancement_proposals" {
  source                 = "./modules/common_repository"
  visibility             = "public"
  name                   = "enhancement-proposals"
  description            = "A repository for proposing enhancements to the osac project"
  all_members_permission = "push"
  # Prow plugins handle approval via OWNERS (lgtm/approved labels), not native
  # GitHub reviews.
  required_approvals = null
  # Enhancement proposals are documentation-only; requiring branches to be
  # up-to-date before merging adds unnecessary friction without safety benefit.
  strict_required_status_checks = false
  required_status_checks = [
    # Job id in enhancement-proposals/.github/workflows/review-gate.yml.
    { context = "check-human-reviews", integration_id = 15368 },
    # Job id in enhancement-proposals/.github/workflows/pre-commit.yaml.
    { context = "pre-commit", integration_id = 15368 },
  ]
  ruleset_bypass_team_ids = [
    github_team.all["managers"].id,
    github_team.all["ci-duty"].id,
  ]
}

module "repo_osac_test_infra" {
  source            = "./modules/common_repository"
  visibility        = "public"
  name              = "osac-test-infra"
  description       = "Ansible-based test infrastructure for OSAC end-to-end testing"
  contributor_teams = local.contributor_teams
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    },
    {
      team_id    = github_team.all["ci-duty"].name
      permission = github_organization_repository_role.ci_maintainer.name
    }
  ]
  # Native GitHub review, as in osac: one approval, dropped when a new commit is pushed. Step A of the move to the shared
  # flow of osac-ci: the two cheap checks. `CI` (ci.yml) sums up pre-commit and the script tests; `jira-reference` says the
  # title names a Jira issue or NO-ISSUE. The E2E check is added in step B, once the suites have run for real.
  # Both are posted by GitHub Actions. The old gates (e2e-*-gate, check-labels, pre-commit) are no longer produced.
  allow_update_branch   = true
  required_approvals    = 1
  dismiss_stale_reviews = true
  # A path listed in CODEOWNERS needs approval from its owner team (the CI definition under .github/ and the suite
  # workflows need wg-infra), and a path with no owner needs nobody in particular.
  require_code_owner_reviews = true
  # ci-duty can force-merge ("Merge without waiting for requirements to be met"): that needs a bypass of the review
  # requirements as well as of the ci-status-checks ruleset. Admins (managers) bypass them already.
  pull_request_bypassers = ["osac-project/${github_team.all["ci-duty"].name}"]

  # `E2E` is the full-install suites on a real cluster (e2e-pr.yml for a pull request, e2e-queue.yml for a merge queue
  # entry). It is required from the OSAC CI app only (integration id 4966101, the app that writes it), so a workflow
  # that is not that app cannot satisfy it.
  required_status_checks = [
    { context = "CI", integration_id = 15368 },
    { context = "jira-reference", integration_id = 15368 },
    { context = "E2E", integration_id = 4966101 },
  ]
  ruleset_bypass_team_ids = [
    github_team.all["managers"].id,
    github_team.all["ci-duty"].id,
  ]
  environments = [{ name = "e2e-test" }]

  # Full-install E2E gates can take over two hours; leave room for slow runs.
  merge_queue = {
    merge_method                      = "SQUASH"
    max_entries_to_build              = 4
    max_entries_to_merge              = 5
    min_entries_to_merge              = 1
    min_entries_to_merge_wait_minutes = 5
    check_response_timeout_minutes    = 180
    grouping_strategy                 = "ALLGREEN"
  }
}

module "repo_osac_ci" {
  source      = "./modules/common_repository"
  visibility  = "public"
  name        = "osac-ci"
  description = "Planner that decides which CI jobs run on OSAC pull requests and what each PR is waiting for"
  # The repository already exists (created by hand), so never generate it
  # from the public template; it has to be imported into state first.
  use_public_template = false
  # Always show "Update branch" (merge or rebase) on this repository's PRs.
  allow_update_branch = true
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    },
    {
      team_id    = "wg-infra"
      permission = "push"
    }
  ]
  # The planner can eventually decide what merges in other repositories, so
  # every change needs a code owner (CODEOWNERS: wg-infra) to approve it, and
  # an approval must not stay valid after the code changes. Until OSAC CI is
  # a required check, GitHub is the only thing enforcing this.
  required_approvals         = 1
  require_code_owner_reviews = true
  dismiss_stale_reviews      = true
  required_status_checks = [
    { context = "lint", integration_id = 15368 },
    { context = "unit-tests", integration_id = 15368 },
    { context = "legacy-differential", integration_id = 15368 },
  ]
  ruleset_bypass_team_ids = [github_team.all["managers"].id]
}

module "repo_massopencloud_templates" {
  source            = "./modules/common_repository"
  visibility        = "public"
  name              = "osac-massopencloud-templates"
  description       = "OSAC MOC-specific templates"
  contributor_teams = local.contributor_teams
}

module "repo_osac_ui" {
  source      = "./modules/common_repository"
  visibility  = "public"
  name        = "osac-ui"
  description = "OSAC UI Web Console"
  # Merged into osac mono-repo, with full commit history preserved; archived.
  archived          = true
  lock_branch       = true
  contributor_teams = local.contributor_teams
}

module "repo_osac_ux" {
  source            = "./modules/common_repository"
  visibility        = "public"
  name              = "osac-ux"
  description       = "OSAC UX Roadmap Console"
  contributor_teams = local.contributor_teams
  users = [
    {
      username   = "liatb-rh"
      permission = "admin"
    },
    {
      username   = "yfrimanm"
      permission = "admin"
    },
    {
      username   = "heyethankim"
      permission = "admin"
    }
  ]
  pages = {
    build_type = "legacy"
    source = {
      branch = "gh-pages"
      path   = "/"
    }
  }
}

module "repo_host_management_openstack" {
  source      = "./modules/common_repository"
  visibility  = "public"
  name        = "host-management-openstack"
  description = "[Archived] OSAC Host Management Operator for OpenStack"
  # archived (OSAC-3445)
  archived          = true
  lock_branch       = true
  contributor_teams = local.contributor_teams
}

module "repo_bare_metal_operator" {
  source      = "./modules/common_repository"
  visibility  = "public"
  name        = "bare-metal-fulfillment-operator"
  description = "OSAC Operator for Bare Metal Fulfillment"
  # Merged into osac mono-repo (OSAC-1732/OSAC-3395); archived (OSAC-1737).
  archived          = true
  lock_branch       = true
  contributor_teams = local.contributor_teams
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    }
  ]
  push_allowances = ["/openshift-merge-robot", "osac-project/${github_team.all["managers"].name}", "osac-project/org-admins"]
}

module "repo_osac_workspace" {
  source            = "./modules/common_repository"
  visibility        = "public"
  name              = "osac-workspace"
  description       = "Workspace for operating on OSAC repositories with AI tooling"
  contributor_teams = local.contributor_teams
  pages = {
    build_type = "workflow"
    source = {
      branch = "main"
      path   = "/"
    }
  }
}

module "repo_cluster_tool" {
  source            = "./modules/common_repository"
  visibility        = "public"
  name              = "cluster-tool"
  description       = "Instant OpenShift SNO clusters from snapshots, distributed as OCI images"
  contributor_teams = local.contributor_teams
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    }
  ]
  push_allowances = ["/openshift-merge-robot", "osac-project/${github_team.all["managers"].name}", "osac-project/org-admins"]
}

module "repo_osac_csi_driver" {
  source      = "./modules/common_repository"
  visibility  = "public"
  name        = "osac-csi-driver"
  description = "OSAC CSI driver for persistent storage"
  # Merged into osac mono-repo (OSAC-1732/OSAC-3530); archived (OSAC-1737).
  archived          = true
  lock_branch       = true
  contributor_teams = local.contributor_teams
  teams = [
    {
      team_id    = github_team.all["managers"].name
      permission = "admin"
    }
  ]
  required_approvals = null
  push_allowances    = ["/openshift-merge-robot", "osac-project/${github_team.all["managers"].name}", "osac-project/org-admins"]
  environments       = [{ name = "e2e-test" }]
}
