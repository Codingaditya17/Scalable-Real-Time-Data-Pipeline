output "msk_cluster_arn" { value = aws_msk_serverless_cluster.events.arn }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "checkpoint_bucket" { value = aws_s3_bucket.checkpoints.bucket }

