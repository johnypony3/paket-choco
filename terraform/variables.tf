variable "github_username" {
  type = string
}

variable "github_password" {
  type      = string
  sensitive = true
}

variable "choco_key" {
  type      = string
  sensitive = true
}

variable "branch" {
  type    = string
  default = "test-before-push"
}
