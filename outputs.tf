output "cognito_domain" {
  description = "Cognito hosted UI domain"
  value       = aws_cognito_user_pool_domain.this.domain
}

output "hosted_ui_login_url" {
  description = "Cognito Hosted UI login URL (authorization code flow) - redirects directly to Azure AD"
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com/oauth2/authorize?client_id=${aws_cognito_user_pool_client.this.id}&response_type=code&scope=openid+email+profile&redirect_uri=${urlencode("https://${aws_cloudfront_distribution.website.domain_name}")}&identity_provider=AzureAD"
}

output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.this.id
}

output "app_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.this.id
}

output "redirect_uri" {
  description = "SAML Reply URL (Assertion Consumer Service URL) to configure in Azure AD"
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com/saml2/idpresponse"
}

output "entity_id" {
  description = "SAML Entity ID (Identifier) to configure in Azure AD"
  value       = "urn:amazon:cognito:sp:${aws_cognito_user_pool.this.id}"
}

output "website_url" {
  description = "CloudFront HTTPS website URL (use this for OAuth callbacks)"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "website_domain" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name (for reference)"
  value       = aws_s3_bucket.website.id
}
