provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = "${aws_iam_role.lambda-registry_iam.id}"
  policy = "${file("policies/lambda-role-policy.json")}"
}

resource "aws_iam_role" "lambda-registry_iam" {
  name = "lambda-registry_iam"
  assume_role_policy = "${file("policies/lambda-role.json")}"
}

resource "aws_s3_bucket_object" "lambda_function" {
  bucket = "${var.s3_bucket}"
  key = "lambda-registry.zip"
  source = "lambda-registry.zip"
  etag = "${md5(file("lambda-registry.zip"))}"
}

resource "aws_lambda_function" "lambda-registry_lambda" {
  s3_bucket = "${var.s3_bucket}"
  s3_key = "lambda-registry.zip"
  function_name = "${var.lambda_function_name}"
  role = "${aws_iam_role.lambda-registry_iam.arn}"
  handler = "index.handler"
  runtime = "nodejs4.3"
  timeout = 20
  source_code_hash = "${base64sha256(file("lambda-registry.zip"))}"
  depends_on = ["aws_s3_bucket_object.lambda_function"]
}

resource "aws_api_gateway_rest_api" "lambda-registry_api" {
  name = "lambda-registry"
  description = "API for HAProxy Configuration Generation"
  depends_on = ["aws_lambda_function.lambda-registry_lambda"]
}

resource "aws_api_gateway_resource" "lambda-registry_resource" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda-registry_api.id}"
  parent_id = "${aws_api_gateway_rest_api.lambda-registry_api.root_resource_id}"
  path_part = "generate"
}

resource "aws_api_gateway_method" "lambda-registry_method" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda-registry_api.id}"
  resource_id = "${aws_api_gateway_resource.lambda-registry_resource.id}"
  http_method = "POST"
  authorization = "NONE"

  request_models = {
    "application/json" = "${aws_api_gateway_model.lambda-registry_request_model.name}"
  }
}

resource "aws_api_gateway_integration" "lambda-registry_integration" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda-registry_api.id}"
  resource_id = "${aws_api_gateway_resource.lambda-registry_resource.id}"
  http_method = "${aws_api_gateway_method.lambda-registry_method.http_method}"
  type = "AWS"
  integration_http_method = "${aws_api_gateway_method.lambda-registry_method.http_method}"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda-registry_lambda.arn}/invocations"
  depends_on = ["aws_lambda_function.lambda-registry_lambda"]
}

resource "aws_api_gateway_model" "lambda-registry_request_model" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda-registry_api.id}"
  name = "Configuration"
  description = "A configuration schema"
  content_type = "application/json"
  schema = <<EOF
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "lambda-registryConfiguration",
  "type": "array",
  "properties": {
    "mode": { "type": "string" },
    "name": { "type": "string" },
    "predicate": { "type": "string" },
    "cookie": { "type": "string" },
    "servers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "ip": { "type": "string" }
        }
      }
    }
  }
}
EOF
}

resource "aws_api_gateway_model" "lambda-registry_response_model" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda-registry_api.id}"
  name = "ConfigurationFile"
  description = "A configuration file schema"
  content_type = "application/json"
  schema = <<EOF
{
  "type": "object"
}
EOF
}

resource "aws_api_gateway_method_response" "200" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda-registry_api.id}"
  resource_id = "${aws_api_gateway_resource.lambda-registry_resource.id}"
  http_method = "${aws_api_gateway_method.lambda-registry_method.http_method}"
  status_code = "200"

  response_models = {
    "application/json" = "${aws_api_gateway_model.lambda-registry_response_model.name}"
  }
}

resource "aws_api_gateway_integration_response" "lambda-registry_integration_response" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda-registry_api.id}"
  resource_id = "${aws_api_gateway_resource.lambda-registry_resource.id}"
  http_method = "${aws_api_gateway_method.lambda-registry_method.http_method}"
  status_code = "${aws_api_gateway_method_response.200.status_code}"
  depends_on = ["aws_api_gateway_integration.lambda-registry_integration"]
}

resource "aws_api_gateway_deployment" "production" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda-registry_api.id}"
  stage_name = "api"
  depends_on = ["aws_api_gateway_integration.lambda-registry_integration"]
}
