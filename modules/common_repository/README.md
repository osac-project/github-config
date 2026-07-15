# Common repository configuration

Create a repository with managed labels, permissions, and branch protection rules.

## Examples

### A very typical repository

```
module "repo_docs" {
  source      = "./modules/common_repository"
  name        = "docs"
  description = "General documentation for the AI in a Box project"
}
```

### A repository with a team collaborator

```
module "repo_docs" {
  source      = "./modules/common_repository"
  name        = "docs"
  description = "General documentation for the AI in a Box project"
  teams = [
    {
      team_id = "docs-workers"
      permission = "push"
    }
  ]
}
```
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_github"></a> [github](#provider\_github) | ~> 6.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [github_branch_protection.repo_protection](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_protection) | resource |
| [github_issue_label.repo_labels](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/issue_label) | resource |
| [github_repository.repo](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) | resource |
| [github_repository_collaborators.repo_collaborators](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_collaborators) | resource |
| [github_repository_environment.env](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_environment) | resource |
| [github_repository_ruleset.merge_queue](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_all_members_permission"></a> [all\_members\_permission](#input\_all\_members\_permission) | Permission for all organization members | `string` | `"triage"` | no |
| <a name="input_allow_merge_commit"></a> [allow\_merge\_commit](#input\_allow\_merge\_commit) | Allow merge commits on pull requests | `bool` | `true` | no |
| <a name="input_allow_rebase_merge"></a> [allow\_rebase\_merge](#input\_allow\_rebase\_merge) | Allow rebase merging on pull requests | `bool` | `true` | no |
| <a name="input_allow_squash_merge"></a> [allow\_squash\_merge](#input\_allow\_squash\_merge) | Allow squash merging on pull requests | `bool` | `true` | no |
| <a name="input_archived"></a> [archived](#input\_archived) | Whether the repository is archived | `bool` | `false` | no |
| <a name="input_branch_protection"></a> [branch\_protection](#input\_branch\_protection) | Configure branch protection if true | `bool` | `true` | no |
| <a name="input_description"></a> [description](#input\_description) | Repository description | `string` | n/a | yes |
| <a name="input_environments"></a> [environments](#input\_environments) | GitHub environments to create for this repository | <pre>list(object({<br/>    name = string<br/>    reviewers = optional(object({<br/>      teams = optional(list(string), [])<br/>      users = optional(list(string), [])<br/>    }))<br/>    deployment_branch_policy = optional(object({<br/>      protected_branches     = optional(bool, true)<br/>      custom_branch_policies = optional(bool, false)<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_is_template"></a> [is\_template](#input\_is\_template) | Set this to true if this is a template repository | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | List of labels to configure on the repository | <pre>list(object({<br/>    name        = string<br/>    color       = string<br/>    description = string<br/>  }))</pre> | `null` | no |
| <a name="input_merge_queue"></a> [merge\_queue](#input\_merge\_queue) | Enable GitHub merge queue for the default branch. When set, a repository ruleset is created that requires PRs to pass through the merge queue before merging. | <pre>object({<br/>    merge_method                   = optional(string, "SQUASH")<br/>    min_entries_to_merge           = optional(number, 1)<br/>    max_entries_to_merge           = optional(number, 5)<br/>    check_response_timeout_minutes = optional(number, 90)<br/>    grouping_strategy              = optional(string, "ALLGREEN")<br/>  })</pre> | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the repository | `string` | n/a | yes |
| <a name="input_pages"></a> [pages](#input\_pages) | Configuration for github pages | <pre>object({<br/>    source = optional(object({<br/>      branch = string<br/>      path   = string<br/>    }))<br/>    build_type = optional(string, "legacy")<br/>    cname      = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_push_allowances"></a> [push\_allowances](#input\_push\_allowances) | Actors allowed to push to the protected branch. When set, restricts both direct pushes and PR merges to these actors only. Actor names must begin with '/' for users or 'org-name/' for teams. | `list(string)` | `null` | no |
| <a name="input_required_approvals"></a> [required\_approvals](#input\_required\_approvals) | Number of approvals required before merging a pull request | `number` | `1` | no |
| <a name="input_required_status_checks"></a> [required\_status\_checks](#input\_required\_status\_checks) | A list of status checks that must pass before a PR can merge | `list(string)` | `[]` | no |
| <a name="input_strict_status_checks"></a> [strict\_status\_checks](#input\_strict\_status\_checks) | Require the PR branch to be up to date with the base branch before merging. Disable when using merge queues, which handle this automatically. | `bool` | `true` | no |
| <a name="input_teams"></a> [teams](#input\_teams) | Teams with access to this repository | <pre>list(object({<br/>    team_id    = string<br/>    permission = string<br/>  }))</pre> | `[]` | no |
| <a name="input_use_public_template"></a> [use\_public\_template](#input\_use\_public\_template) | Use the public\_template repository as the template for a new repository | `bool` | `true` | no |
| <a name="input_users"></a> [users](#input\_users) | Users with access to this repository | <pre>list(object({<br/>    username   = string<br/>    permission = string<br/>  }))</pre> | `[]` | no |
| <a name="input_visibility"></a> [visibility](#input\_visibility) | Repository visibility (public or private) | `string` | `"public"` | no |
| <a name="input_vulnerability_alerts"></a> [vulnerability\_alerts](#input\_vulnerability\_alerts) | Enable or disable dependabot vulnerability alerts | `bool` | `false` | no |
