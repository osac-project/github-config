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

# The parent of every team flagged "maintainer" in teams.csv (the teams that have write access to the repositories). GitHub
# counts the members of a child team as members of its parent, so "@osac-project/maintainers" in CODEOWNERS means "a person
# of any of those teams" and a bot, which is in none of them, is not one. Child teams inherit the access of their parent;
# the parent only has push on osac (see repositories.tf), which they all have already.
resource "github_team" "maintainers" {
  name        = "maintainers"
  description = "Everyone who may approve changes: the members of the working-group teams (their parent team)"
  privacy     = "closed"
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
