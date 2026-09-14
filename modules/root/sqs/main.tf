resource "aws_sqs_queue" "feature_evaluation_events" {
  name = var.name_sqs

  visibility_timeout_seconds = 30

  message_retention_seconds = 345600

  receive_wait_time_seconds = 20
}
