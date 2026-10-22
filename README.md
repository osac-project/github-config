# Open Sovereign AI Cloud Github configuration

This repository contains [OpenTofu] plan to manage the [osac-project] GitHub organization.


[osac-project]: https://github.com/osac-project
[opentofu]: https://opentofu.org/

## How does it work?

When a commit is pushed to the `main` branch (e.g., when a pull request merges), that triggers the `.github/workflows/apply.yaml` workflow. This workflow acquires necessary credentials from GithHub secrets and from the "Org Config Management" GitHub app, and then uses [OpenTofu] to apply the requested configuration.

## How do I...

### Add a new organization member?

1. Open `members.csv`
1. Add a new row of the form `<username>,<role>`, where `<role>` in almost all cases should be `member`.

### Add a new team?

1. Open `teams.csv`
1. Add a new row of the form `<team_name>,<description>,<privacy>,<contributor>`, where `<privacy>` can be either `closed` (visible to all members of the organization) or `secret` (visible to organization owners and members of this team).
   Set `<contributor>` to `true` to give the team push access on every repository that uses `local.contributor_teams` in `repositories.tf` (the working group teams), or `false` otherwise.

### Add an organization member to a team?

1. Open `team-members/<team>.csv`
1. Add a new line of the form `<username>,<role>`, where `<role>` should be `member`.

Which team? Teams follow the OSAC engineering roster:

- `wg-*`: one team per working group (for example `wg-core`, `wg-storage`, `wg-infra`).
  Working group teams have push access to the OSAC repositories.
- `contributors`: people who contribute but aren't in a working group. Same push access.
- `managers`, `architects`, `wg-leads`: role teams across all working groups. `managers`
  also has admin on the main repositories and ruleset bypass (see below).
- `ci-duty`: CI duty and merge assistance (see below).
- `fulfillment-wg`: legacy team with no repository access. It is kept only because the
  hypershift1 cluster (`osac-project/managed-cluster-config`) uses it for OAuth login,
  RBAC, ArgoCD and Vault. Don't add people to it for repository access.

### Give someone runner management or merge-queue bypass without making them an org owner?

Add them to the `ci-duty` team (`team-members/ci-duty.csv`). That team:

- Holds GitHub's predefined **CI/CD admin** organization role, granting management of
  org self-hosted runners and runner groups (plus Actions policies, secrets, variables,
  and usage metrics). See `organization.tf`.
- Can force-merge ("Merge without waiting for requirements to be met") on `osac`,
  `osac-test-infra` and `enhancement-proposals`: it is a ruleset bypass actor there
  (`ruleset_bypass_team_ids`), so its members can bypass the merge queue and required status
  checks, and on `osac` it may also bypass the required reviews (`pull_request_bypassers`).
  GitHub shows that checkbox only to someone who can bypass every rule on the branch. See
  `repositories.tf`.
- Has the `ci-maintainer` custom repository role on `osac` and `osac-test-infra`: write, plus
  management of the repository's Actions secrets, variables, environments, settings and
  runners, merge queue priority (jump the queue, solo merge), and bypass of branch
  protections (which GitHub needs in order to offer the force-merge checkbox). See
  `organization.tf`.

The `managers` team holds the narrower `runner-manager` role, admin on the main
repositories, and ruleset bypass on every repository with required status checks.

### Add a new repository?

1. Open `repositories.tf`
1. Add a new block of the form:

    ```
    module "repo_<repository_name_slug>" {
      source      = "./modules/common_repository"
      name        = "<repository_name>"
      description = "<repository_description"
    }
    ```

This will create a new repository with the following configuration:

- A repository with issues enabled and wikis and projects disabled
- Branch protection rules for the `main` branch requiring at least 1 approval for pull requests and restricting force pushes to members of the `org-admins` team
- A standard set of labels

See the [README file for the common_repository module][common_repository] for more information about customizing repository configuration (including how to make a repository private and how to add collaborators).

[common_repository]: ./modules/common_repository/

### Add a new label to all managed repositories?

1. Open `modules/common_repository/labels.csv`

2. Add a new line of the form `<name>,<color>,<description>`

Where `<repository_name_slug>` is `<repository_name>` transformed to be a valid identifier in most common languages: a single word consisting of only alphanumerics and underscores. So e.g. `github-config` would become `github_config`, and `.gitjub` would become something like `dotgithub` (`_github` would also work).

## Suggested local pre-commit checks

You should ensure that you run `tofu fmt` before submitting a pull request. The easiest way of doing this is by installing the `pre-commit` tool on your local system and then running `pre-commit install`. This will configure `.git/hooks/pre-commit` to run the `pre-commit` tool whenever you create a new commit. If there are formatting changes, this will abort the commit and apply the necessary changes to your files. You can then add the modified files and update the commit.

## Prerequisites for applying the configuration

In general, you won't need to do this: the configuration is applied when a pull request merges to the `main` branch. These instructions will be useful if is necessary to apply changes manually (this can happen, for example, if someone makes changes to the organization through the GitHub web UI rather than through this repository).

1. Ensure that you have either Terraform or OpenTofu installed. There are packages for both available on Fedora:

    ```
    dnf install opentofu
    ```

1. Acquire S3 credentials.

    OpenTofu maintains state information about the target infrastructure; you need this state in order to plan and apply the configuration. We store this information in the `osac-terraform-state` S3 bucket (`us-east-1`) in an OSAC-controlled AWS account. The bucket is versioned, and OpenTofu takes a lock on the state (`osac.tfstate.tflock`) while it plans or applies. You need appropriate AWS credentials in order for OpenTofu to access the cached state. These should be provided in the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.

1. Acquire GitHub credentials.

    In order to apply the configuration, OpenTofu needs administrative access to our organization. You will need a token with at least `admin:org` and `repo` privileges for the `osac-project` organization. This should be provided in the `GITHUB_TOKEN` environment variable.

## Additional documentation

- OpenTofu [introductory documentation](https://opentofu.org/docs/intro/).

- The OpenTofu [github provider](https://search.opentofu.org/provider/opentofu/github/v6.3.0).

  This includes documentation for most of the resource types used in this repository.
