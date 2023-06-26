locals {
  account_id          = data.aws_caller_identity.current.account_id
  ecr_repository_name = "${var.organization_name}-demo-lambda-container"
  ecr_image_tag       = "latest"
}

resource "aws_ecr_repository" "repo" {
  name = local.ecr_repository_name
  force_delete = true
}

resource "null_resource" "ecr_image" {
  triggers = {
    handler_file = md5(file("${path.module}/lambda/oapi_diff/src/main/java/dev/karambol/Handler.java"))
    docker_file = md5(file("${path.module}/lambda/oapi_diff/Dockerfile"))
    gradle_file = md5(file("${path.module}/lambda/oapi_diff/build.gradle"))
  }

  provisioner "local-exec" {
    command = <<EOF
           aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
           cd ${path.module}/lambda/oapi_diff
           docker build -t ${aws_ecr_repository.repo.repository_url}:${local.ecr_image_tag} .
           docker push ${aws_ecr_repository.repo.repository_url}:${local.ecr_image_tag}
       EOF
  }
}

data "aws_ecr_image" "lambda_image" {
  depends_on = [
    null_resource.ecr_image
  ]
  repository_name = local.ecr_repository_name
  image_tag       = local.ecr_image_tag
}

resource aws_iam_role lambda_exec {
  name               = "${var.organization_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "allow_lambda_s3" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "s3:*",
    ]
  }
}

data "aws_iam_policy" "allow_lambda_s3_full_access" {
  name = "AmazonS3FullAccess"
}

data "aws_iam_policy" "allow_lambda_exec" {
  name = "AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "allow_lambda_sqs_invocation" {
  policy = data.aws_iam_policy_document.allow_lambda_s3.json
}

resource "aws_iam_role_policy_attachment" "allow_lambda_s3" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = data.aws_iam_policy.allow_lambda_s3_full_access.arn
}

resource "aws_iam_role_policy_attachment" "allow_lambda_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = data.aws_iam_policy.allow_lambda_exec.arn
}


resource aws_lambda_function oapi_diff {
  depends_on = [
    null_resource.ecr_image
  ]
  function_name = "${var.organization_name}-lambda"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 300
  image_uri     = "${aws_ecr_repository.repo.repository_url}@${data.aws_ecr_image.lambda_image.id}"
  package_type  = "Image"
}

output "lambda_name" {
  value = aws_lambda_function.oapi_diff.id
}

# TODO TMP, remove me as I should be invoked by s3 put object event
resource "aws_lambda_function_url" "function" {
  function_name      = aws_lambda_function.oapi_diff.function_name
  authorization_type = "NONE"
}

# Adding S3 bucket as trigger to my lambda and giving the permissions
resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = aws_s3_bucket.oapi_diff.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.oapi_diff.arn
    events              = ["s3:ObjectCreated:*"]

  }
}
resource "aws_lambda_permission" "oapi_diff" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.oapi_diff.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.oapi_diff.id}"
}

resource "aws_cloudwatch_log_group" "oapi_diff" {
  name              = "/aws/lambda/${aws_lambda_function.oapi_diff.function_name}"
  retention_in_days = 1
  skip_destroy = false
}
