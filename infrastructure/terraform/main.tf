locals {
  tags = {
    application = var.app_name
    environment = var.environment
    phase       = "phase-1-foundation"
  }
}

output "foundation_summary" {
  value = {
    app_name      = var.app_name
    environment   = var.environment
    database_plan = var.database_plan
    tags          = local.tags
  }
}
