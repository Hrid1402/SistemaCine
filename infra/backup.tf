# Main Region Backup Vault
resource "aws_backup_vault" "main" {
  name          = "${var.project_name}-main-vault"
  kms_key_arn   = aws_kms_key.main.arn
  force_destroy = true

  tags = {
    Name = "${var.project_name}-main-vault"
  }
}

# Secondary disaster recovery (DR) region backup vault
resource "aws_backup_vault" "dr" {
  provider      = aws.dr
  name          = "${var.project_name}-dr-vault"
  kms_key_arn   = aws_kms_key.dr.arn
  force_destroy = true

  tags = {
    Name = "${var.project_name}-dr-vault"
  }
}

# Multi-region backup plan
resource "aws_backup_plan" "cine_backup_plan" {
  name = "${var.project_name}-backup-plan"

  rule {
    rule_name         = "respaldo-incremental-diario"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 * * ? *)" # Todos los días a las 05:00 UTC

    lifecycle {
      delete_after = 30
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.dr.arn
      lifecycle {
        delete_after = 30
      }
    }
  }

  rule {
    rule_name         = "respaldo-completo-semanal"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 6 ? * SUN *)"

    lifecycle {
      delete_after = 30
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.dr.arn
      lifecycle {
        delete_after = 30
      }
    }
  }

  tags = {
    Name = "${var.project_name}-backup-plan"
  }
}

# Target databases selection
resource "aws_backup_selection" "cine_databases" {
  iam_role_arn = aws_iam_role.aws_backup.arn
  name         = "${var.project_name}-db-backup-selection"
  plan_id      = aws_backup_plan.cine_backup_plan.id

  resources = [
    aws_db_instance.postgres.arn,
    aws_dynamodb_table.seats.arn
  ]
}