output "cluster_name" {
  value = aws_eks_cluster.main.name
}
output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}
output "repository_urls" {
  value = { for name, repo in aws_ecr_repository.service : name => repo.repository_url }
}
output "rds_endpoints" {
  value = { for name, db in aws_db_instance.postgres : name => db.address }
}
output "redis_endpoint" {
  value = aws_elasticache_replication_group.main.primary_endpoint_address
}
output "queue_url" {
  value = aws_sqs_queue.events.url
}
output "dynamodb_table" {
  value = aws_dynamodb_table.events.name
}
