variable "environment" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "project" {
  type = string
}

variable "gke_min_nodes" {
  type    = number
  default = 1
}

variable "gke_max_nodes" {
  type    = number
  default = 5
}
