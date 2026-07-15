resource "github_repository" "repo" {
  name                 = var.name
  archived             = var.archived
  visibility           = var.visibility
  description          = var.description
  auto_init            = true
  allow_auto_merge     = var.visibility == "private" ? false : true
  allow_merge_commit   = var.allow_merge_commit
  allow_squash_merge   = var.allow_squash_merge
  allow_rebase_merge   = var.allow_rebase_merge
  has_issues           = true
  has_downloads        = false
  has_projects         = false
  has_wiki             = false
  is_template          = var.is_template
  vulnerability_alerts = var.vulnerability_alerts

  dynamic "template" {
    # Use the public_template repository as a template unless the repository is
    # private or is a template
    for_each = var.visibility == "private" ? [] : var.is_template ? [] : var.use_public_template ? ["enabled"] : []

    content {
      owner      = "osac-project"
      repository = "public_template"
    }
  }

  dynamic "pages" {
    # enable this block if `pages` is not null
    for_each = var.pages[*]

    content {
      cname      = pages.value.cname
      build_type = pages.value.build_type

      dynamic "source" {
        for_each = var.pages.source[*]

        content {
          branch = source.value.branch
          path   = source.value.path
        }
      }
    }
  }
}

resource "github_issue_label" "repo_labels" {
  repository = var.name

  # Generate label blocks from the value of local.values, which by default is initialized
  # by the contents of the "labels.csv" file.
  for_each = {
    for label in local.labels :
    label.name => label
  }

  name        = each.value.name
  color       = each.value.color
  description = each.value.description

  depends_on = [github_repository.repo]
}

resource "github_branch_protection" "repo_protection" {
  # This odd looking construct lets us control the creation of the
  # branch protection resource with a boolean variable.
  count = var.visibility == "private" ? 0 : var.branch_protection ? 1 : 0

  repository_id = var.name
  pattern       = "main"

  required_linear_history         = true
  allows_deletions                = false
  allows_force_pushes             = false
  enforce_admins                  = false
  require_conversation_resolution = false
  require_signed_commits          = false

  force_push_bypassers = [
    "osac-project/org-admins",
  ]

  dynamic "restrict_pushes" {
    for_each = var.push_allowances != null ? [1] : []
    content {
      push_allowances = var.push_allowances
    }
  }

  dynamic "required_pull_request_reviews" {
    for_each = var.required_approvals[*]

    content {
      required_approving_review_count = var.required_approvals
    }
  }

  required_status_checks {
    strict   = var.strict_status_checks
    contexts = var.required_status_checks
  }

  depends_on = [github_repository.repo, github_repository_collaborators.repo_collaborators]
}

data "github_team" "merge_queue_bypass" {
  for_each = var.merge_queue != null ? toset(["wg-infra", "org-admins"]) : []
  slug     = each.value
}

resource "github_repository_ruleset" "merge_queue" {
  count       = var.merge_queue != null ? 1 : 0
  name        = "merge-queue"
  repository  = github_repository.repo.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = data.github_team.merge_queue_bypass
    content {
      actor_id    = bypass_actors.value.id
      actor_type  = "Team"
      bypass_mode = "pull_request"
    }
  }

  rules {
    merge_queue {
      merge_method                   = var.merge_queue.merge_method
      min_entries_to_merge           = var.merge_queue.min_entries_to_merge
      max_entries_to_merge           = var.merge_queue.max_entries_to_merge
      check_response_timeout_minutes = var.merge_queue.check_response_timeout_minutes
      grouping_strategy              = var.merge_queue.grouping_strategy
    }
  }

  depends_on = [github_repository.repo]
}

resource "github_repository_environment" "env" {
  for_each = {
    for env in var.environments :
    env.name => env
  }

  repository  = var.name
  environment = each.value.name

  dynamic "reviewers" {
    for_each = each.value.reviewers != null ? [each.value.reviewers] : []
    content {
      teams = reviewers.value.teams
      users = reviewers.value.users
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = each.value.deployment_branch_policy != null ? [each.value.deployment_branch_policy] : []
    content {
      protected_branches     = deployment_branch_policy.value.protected_branches
      custom_branch_policies = deployment_branch_policy.value.custom_branch_policies
    }
  }

  depends_on = [github_repository.repo]
}

resource "github_repository_collaborators" "repo_collaborators" {
  repository = var.name

  # Always grant org-admins push (write) access to repository. This is necessary to support the
  # force_push_bypassers configuration (above).
  team {
    team_id    = "org-admins"
    permission = "push"
  }

  # Permission for all organization members
  team {
    team_id    = "all-members"
    permission = var.all_members_permission
  }

  # Generate team blocks from the value of the "teams" input variable.
  dynamic "team" {
    for_each = {
      for team in var.teams :
      team.team_id => team
    }
    content {
      team_id    = team.value.team_id
      permission = team.value.permission
    }
  }

  # Generate user blocks from the value of the "users" input variable.
  dynamic "user" {
    for_each = {
      for user in var.users :
      user.username => user
    }
    content {
      username   = user.value.username
      permission = user.value.permission
    }
  }

  depends_on = [github_repository.repo]
}
