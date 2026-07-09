output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "ecr_repository_name" {
  value = aws_ecr_repository.app.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "mongo_public_ip" {
  value = aws_instance.mongo.public_ip
}

output "mongo_private_ip" {
  value = aws_instance.mongo.private_ip
}

output "mongo_backup_bucket" {
  value = aws_s3_bucket.mongo_backups.bucket
}

output "mongo_uri_ssm_parameter" {
  value = aws_ssm_parameter.mongo_uri.name
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "intentional_findings" {
  value = [
    "EC2 Mongo VM: SSH open to 0.0.0.0/0",
    "EC2 Mongo VM: AmazonEC2FullAccess + AmazonS3FullAccess attached",
    "MongoDB: 5.0 package line from MongoDB 5.0 repository",
    "Linux: Ubuntu 20.04 AMI",
    "S3 backups: public ListBucket and GetObject allowed",
    "Kubernetes app: service account bound to cluster-admin"
  ]
}
