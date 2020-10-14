# Credentials
resource "random_string" "db_username" {
  length = 16
  special = false
}

resource "random_string" "db_password" {
  length = 32
  special = false
  override_special = " @"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "ETL_DB_credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = random_string.db_username.result
    password = random_string.db_password.result
  })
}

# RDS
resource "aws_db_subnet_group" "etl_db_subnet_group" {
  name       = "etl-db-subnet-group"
  subnet_ids = [aws_subnet.etl_private_a.id, aws_subnet.etl_private_b.id]

  tags = {
    Name = "ETL DB Subnet Group"
  }
}

resource "aws_db_instance" "etl_db" {
  identifier              = "etl-db"
  engine                  = "postgres"
  engine_version          = "12.3"
  instance_class          = "db.t2.micro"
  allocated_storage       = 20
  storage_type            = "gp2"
  backup_retention_period = 0
  db_subnet_group_name    = aws_db_subnet_group.etl_db_subnet_group.name

  name                 = "postgres"
  username             = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string)["username"]
  password             = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string)["password"]
  parameter_group_name = "default.postgres12"

  publicly_accessible = false
  # Since the data is recreatable, we don't need a final snapshot
  skip_final_snapshot = true
}
