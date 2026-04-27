variable "app_name" {
  description = "Application name for the SEOMP middleware runtime."
  type        = string
  default     = "seomp-middleware"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "database_plan" {
  description = "Logical database plan or tier."
  type        = string
  default     = "basic"
}
