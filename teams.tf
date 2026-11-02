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
  name                 = "maintainers"
  description          = "Everyone who may approve changes: the members of the working-group teams (their parent team)"
  privacy              = "closed"
  notification_setting = "notifications_disabled" # see the comment below: nobody is told when the team is requested
}

# The code review settings of the maintainers team: review request delegation is OFF. CODEOWNERS requests this team for
# every path no working group owns, and any member may approve; GitHub must not pick one member of it for the pull request
# (the provider enables delegation when a review_request_delegation block is present, and this resource has none, so every
# apply keeps it off). Notifications are the notification_setting of the team above: CODEOWNERS requests this team on every
# pull request no working group owns, and nobody is to be told. The provider defaults that field to "notifications_enabled"
# and sets it on every apply, so it has to be stated.
resource "github_team_settings" "maintainers" {
  team_id = github_team.maintainers.id
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
