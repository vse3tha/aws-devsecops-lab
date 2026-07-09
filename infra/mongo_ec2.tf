resource "random_password" "mongo_admin" {
  length           = 24
  special          = true
  override_special = "@#%_+-="
}

resource "random_password" "mongo_app" {
  length           = 24
  special          = true
  override_special = "@#%_+-="
}

data "aws_ami" "ubuntu_2004" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "mongo" {
  key_name   = "${var.project}-mongo-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "mongo" {
  name        = "${var.project}-mongo-sg"
  description = "Intentional lab SG: public SSH, MongoDB restricted to VPC/Kubernetes network"
  vpc_id      = aws_vpc.main.id

  # Intentional weakness required by the exercise: SSH exposed to the public internet.
  ingress {
    description = "INTENTIONAL WEAKNESS: SSH from internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MongoDB is restricted to the private VPC/Kubernetes network, not the public internet.
  ingress {
    description = "MongoDB from EKS/VPC network only"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project}-mongo-sg" })
}

resource "aws_iam_role" "mongo_ec2" {
  name = "${var.project}-mongo-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Intentional weakness required by the exercise: EC2 VM has overly permissive CSP permissions.
resource "aws_iam_role_policy_attachment" "mongo_ec2_full_access" {
  role       = aws_iam_role.mongo_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "mongo_s3_full_access" {
  role       = aws_iam_role.mongo_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "mongo" {
  name = "${var.project}-mongo-instance-profile"
  role = aws_iam_role.mongo_ec2.name
}

resource "aws_s3_bucket" "mongo_backups" {
  bucket = "${var.name_prefix}-mongo-backups-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

resource "aws_s3_bucket_ownership_controls" "mongo_backups" {
  bucket = aws_s3_bucket.mongo_backups.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Intentional weakness required by the exercise: block public access is disabled for this bucket.
resource "aws_s3_bucket_public_access_block" "mongo_backups" {
  bucket                  = aws_s3_bucket.mongo_backups.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Intentional weakness required by the exercise: public read and public list on backup bucket.
resource "aws_s3_bucket_policy" "mongo_backups_public" {
  bucket = aws_s3_bucket.mongo_backups.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicListBucket"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:ListBucket"
        Resource  = aws_s3_bucket.mongo_backups.arn
      },
      {
        Sid       = "PublicReadObjects"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.mongo_backups.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.mongo_backups]
}

resource "aws_instance" "mongo" {
  ami                         = data.aws_ami.ubuntu_2004.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.mongo.id]
  iam_instance_profile        = aws_iam_instance_profile.mongo.name
  key_name                    = aws_key_pair.mongo.key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/templates/mongo-user-data.sh.tftpl", {
    mongo_admin_user     = var.mongo_admin_user
    mongo_admin_password = random_password.mongo_admin.result
    mongo_app_user       = var.mongo_app_user
    mongo_app_password   = random_password.mongo_app.result
    mongo_db_name        = var.mongo_db_name
    backup_bucket        = aws_s3_bucket.mongo_backups.bucket
    aws_region           = var.aws_region
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name           = "${var.project}-mongo-vm"
    OSIntent       = "Ubuntu_20_04_1plus_year_old"
    MongoDBIntent  = "MongoDB_5_0_1plus_year_old"
    SSHExposure    = "Public_Internet"
    PermissionRisk = "EC2FullAccess_and_S3FullAccess"
  })
}

resource "aws_ssm_parameter" "mongo_uri" {
  name        = "/${var.project}/mongo_uri"
  description = "MongoDB URI consumed by the EKS application pipeline"
  type        = "SecureString"
  value       = "mongodb://${var.mongo_app_user}:${random_password.mongo_app.result}@${aws_instance.mongo.private_ip}:27017/${var.mongo_db_name}?authSource=${var.mongo_db_name}"

  tags = local.common_tags
}
