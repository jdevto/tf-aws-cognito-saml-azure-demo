# S3 Bucket for Static Website
resource "aws_s3_bucket" "website" {
  bucket = "cognito-demo-website-${local.random_suffix}"
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  # Block public access - CloudFront will access via OAC
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload website files
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = file("${path.module}/www/index.html")
  content_type = "text/html"
  etag         = filemd5("${path.module}/www/index.html")
}

resource "aws_s3_object" "app_js" {
  bucket = aws_s3_bucket.website.id
  key    = "app.js"
  content = templatefile("${path.module}/www/app.js.tpl", {
    cognito_domain = aws_cognito_user_pool_domain.this.domain
    client_id      = aws_cognito_user_pool_client.this.id
    aws_region     = data.aws_region.current.region
  })
  content_type = "application/javascript"
}

resource "aws_s3_object" "styles_css" {
  bucket       = aws_s3_bucket.website.id
  key          = "styles.css"
  content      = file("${path.module}/www/styles.css")
  content_type = "text/css"
  etag         = filemd5("${path.module}/www/styles.css")
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website.id
  key          = "error.html"
  content      = file("${path.module}/www/error.html")
  content_type = "text/html"
  etag         = filemd5("${path.module}/www/error.html")
}
