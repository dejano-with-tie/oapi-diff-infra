resource "aws_s3_bucket" "oapi_diff" {
  bucket        = "${var.organization_name}-${var.project_name}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "oapi_diff" {
  bucket = aws_s3_bucket.oapi_diff.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "oapi_diff" {
  bucket = aws_s3_bucket.oapi_diff.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }

  depends_on = [aws_s3_bucket_public_access_block.oapi_diff]
}

resource "aws_s3_bucket_public_access_block" "oapi_diff" {
  bucket = aws_s3_bucket.oapi_diff.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "oapi_diff" {
  depends_on = [
    aws_s3_bucket_ownership_controls.oapi_diff,
    aws_s3_bucket_public_access_block.oapi_diff,
  ]

  bucket = aws_s3_bucket.oapi_diff.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.oapi_diff.id
  policy = data.aws_iam_policy_document.allow_public_access.json
  depends_on = [aws_s3_bucket_public_access_block.oapi_diff]
}

data "aws_iam_policy_document" "allow_public_access" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject",
#      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.oapi_diff.arn,
      "${aws_s3_bucket.oapi_diff.arn}/*",
    ]
  }
}

resource "aws_s3_object" "swagger" {
  bucket  = aws_s3_bucket.oapi_diff.id
  key     = "index.html"
  content = templatefile("./swagger/index.html.tpl", {
    spec_url = "https://${aws_s3_bucket.oapi_diff.bucket_regional_domain_name}/openapi-spec/petstore.yaml"
  })
  content_type = "text/html"
}

resource "aws_s3_object" "swagger_diff_css" {
  bucket  = aws_s3_bucket.oapi_diff.id
  key     = "diff.css"
  source = "./swagger/diff.css"
  content_type = "text/css"
}
