# tflint-ignore: terraform_unused_declarations
variable "cluster_name" {
  description = "Name of cluster - used by Terratest for e2e test automation"
  type        = string
  default     = "tf-4"
}

variable "region" {
  description = ""
  type        = string
  default     = "cn-north-1"
}
