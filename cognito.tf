# Cognito User Pool
resource "aws_cognito_user_pool" "this" {
  name = "cognito-azure-demo-${local.random_suffix}"

  # Email configuration
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # Schema attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false
  }
}

# Cognito Hosted UI Domain
resource "aws_cognito_user_pool_domain" "this" {
  domain       = local.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}

# Azure AD SAML Identity Provider
resource "aws_cognito_identity_provider" "azure_ad" {
  user_pool_id    = aws_cognito_user_pool.this.id
  provider_name   = "AzureAD"
  provider_type   = "SAML"
  idp_identifiers = []

  provider_details = {
    MetadataURL           = "https://login.microsoftonline.com/${var.azure_tenant_id}/federationmetadata/2007-06/federationmetadata.xml?appid=${var.azure_client_id}"
    SSORedirectBindingURI = "https://login.microsoftonline.com/${var.azure_tenant_id}/saml2"
    SLORedirectBindingURI = "https://login.microsoftonline.com/${var.azure_tenant_id}/saml2"
  }

  attribute_mapping = {
    email       = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
    given_name  = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"
    family_name = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"
    name        = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "this" {
  name         = "cognito-client-${local.random_suffix}"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true

  # Callback URLs: Where Cognito redirects AFTER authentication (your app URL)
  # NOT /oauth2/idpresponse - that's the Cognito endpoint for identity providers
  callback_urls = ["https://${aws_cloudfront_distribution.website.domain_name}"]
  logout_urls   = ["https://${aws_cloudfront_distribution.website.domain_name}"]

  supported_identity_providers = ["AzureAD"]

  prevent_user_existence_errors = "ENABLED"

  # Ensure identity provider and CloudFront are created before app client
  depends_on = [aws_cognito_identity_provider.azure_ad, aws_cloudfront_distribution.website]
}
