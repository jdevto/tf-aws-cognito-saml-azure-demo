resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  random_suffix         = substr(random_id.suffix.hex, 0, 8)
  cognito_domain_prefix = "azure-demo-${local.random_suffix}"
}
