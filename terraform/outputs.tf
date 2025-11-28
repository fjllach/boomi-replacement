output "s3_bucket_name" {
  value = aws_s3_bucket.data_bucket.bucket
}

output "appflow_flow_arn" {
  value = aws_appflow_flow.salesforce_flow.arn
}

output "step_function_arn" {
  value = aws_sfn_state_machine.orchestrator.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.processor_lambda.function_name
}
