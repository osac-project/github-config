variable "name" {
  description = "The name of the repository"
  type        = string
}

variable "description" {
  description = "Repository description"
  type        = string
}

variable "required_approvals" {
  description = "Number of approvals required before merging a pull request"
  type        = number
  default     = 1
}

variable "required_status_checks" {
  description = "A list of status checks that must pass before a PR can merge"
  type        = list(string)
  default     = []
}

variable "visibility" {
  description = "Repository visibility (public or private)"
  type        = string
  default     = "public"
  validation {
    error_message = "unknown visiblity: must be public or private"
    condition     = contains(["public", "private"], var.visibility)
  }
}

variable "branch_protection" {
  description = "Configure branch protection if true"
  type        = bool
  default     = true
}

variable "labels" {
  description = "List of labels to configure on the repository"
  type = list(object({
    name        = string
    color       = string
    description = string
  }))
  default = null
}

variable "teams" {
  description = "Teams with access to this repository"
  type = list(object({
    team_id    = string
    permission = string
  }))
  default = []
  validation {
    error_message = "unknown permission: permission must be one of pull, push, maintain, triage, or admin"
    condition = alltrue([
      for v in var.teams : contains(["pull", "push", "maintain", "triage", "admin"], v.permission)
    ])
  }
}

variable "users" {
  description = "Users with access to this repository"
  type = list(object({
    username   = string
    permission = string
  }))
  default = []
  validation {
    error_message = "unknown permission: permission must be one of pull, push, maintain, triage, or admin"
    condition = alltrue([
      for v in var.users : contains(["pull", "push", "maintain", "triage", "admin"], v.permission)
    ])
  }
}

variable "is_template" {
  description = "Set this to true if this is a template repository"
  type        = bool
  default     = false
}

variable "use_public_template" {
  description = "Use the public_template repository as the template for a new repository"
  type        = bool
  default     = true
}

variable "vulnerability_alerts" {
  description = "Enable or disable dependabot vulnerability alerts"
  type        = bool
  default     = false
}

variable "pages" {
  description = "Configuration for github pages"
  type = object({
    source = optional(object({
      branch = string
      path   = string
    }))
    build_type = optional(string, "legacy")
    cname      = optional(string)
  })
  default = null

  validation {
    error_message = "build_type must be one of \"workflow\" or \"legacy\""
    condition = var.pages == null ? true : (
      var.pages.build_type == null ||
      contains(["legacy", "workflow"], var.pages.build_type)
    )
  }
}

variable "all_members_permission" {
  description = "Permission for all organization members"
  type        = string
  default     = "triage"
  validation {
    error_message = "invalid permission name"
    condition     = contains(["pull", "push", "triage", "maintain", "admin"], var.all_members_permission)
  }
}
