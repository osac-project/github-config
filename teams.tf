# Create teams from the contents of "teams.csv"
resource "github_team" "all" {
  for_each = {
    for team in csvdecode(file("teams.csv")) :
    team.name => team
  }

  name           = each.value.name
  description    = each.value.description
  privacy        = each.value.privacy
  parent_team_id = each.value.maintainer == "true" ? github_team.maintainers.id : null
}

# The parent of every working-group team (the teams flagged "maintainer" in teams.csv: the wg-* teams). GitHub counts the
# members of a child team as members of its parent, so "@osac-project/maintainers" in CODEOWNERS means "a person of any
# working group", and a bot, which is in none of them, is not one. Child teams inherit the access of their parent; the
# parent only has push on osac (see repositories.tf), which they all have already.
resource "github_team" "maintainers" {
  name        = "maintainers"
  description = "Everyone who may approve changes: the members of the working-group teams (their parent team)"
  privacy     = "closed"
}

# The only DIRECT member of maintainers. A pull request that CODEOWNERS sends to maintainers has GitHub assign one member of
# the team to review it (review assignment, set after every apply, see .github/workflows/apply.yaml), and only that member is
# notified, not the 80-odd people of the working groups. The assignment is limited to direct members (the members of the
# child teams are left out), so it always picks this account, which approves nothing: nobody is picked, nobody is
# broadcast to, and any member of a working group may still approve (members of a child team count as members of
# maintainers for CODEOWNERS). osac-ci-bot is already a member of the organization and of wg-infra.
resource "github_team_membership" "maintainers_review_sink" {
  team_id  = github_team.maintainers.id
  username = "osac-ci-bot"
  role     = "member"
}

# Review assignment used to be managed here (github_team_settings), but the provider cannot set the option that leaves the
# child teams out of the assignment, and an apply would undo it. It is set by apply.yaml instead; forget the old resource
# without destroying it.
removed {
  from = github_team_settings.maintainers

  lifecycle {
    destroy = false
  }
}

# Populate team members based on the csv files in the team-members directory.
resource "github_team_membership" "members" {
  for_each = { for tm in local.team_members : tm.name => tm }

  team_id  = each.value.team_id
  username = each.value.username
  role     = each.value.role

  depends_on = [
    github_team.all
  ]
}

# This creates an "all-members" team containing all organization members.
resource "github_team" "all-members" {
  name        = "all-members"
  description = "All organization members"
  privacy     = "closed"

}

resource "github_team_membership" "all-members" {
  for_each = {
    for member in csvdecode(file("members.csv")) :
    member.username => member
  }

  team_id  = "all-members"
  role     = each.value.role == "admin" ? "maintainer" : "member"
  username = each.value.username

  depends_on = [
    github_team.all-members
  ]
}
