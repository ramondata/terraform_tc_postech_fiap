output "rds_status" {
  value = [
    for db in aws_db_instance.postgres :
    db.status
  ]
}
output "rds_identifiers" {
  value = [
    for db in aws_db_instance.postgres :
    db.identifier
  ]
}
