resource "aws_elasticache_subnet_group" "subnet-redis" {
  name       = "${var.env}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "new-redis" {
  description          = "New Redis cache for toggle-master services"
  replication_group_id = "${var.env}-redis"
  cluster_mode         = "disabled"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"
  num_cache_clusters   = 1

  subnet_group_name = aws_elasticache_subnet_group.subnet-redis.name

  tags = {
    team = "fiap"
  }
}