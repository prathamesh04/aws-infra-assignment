output "db_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_username" {
  value = aws_db_instance.this.username
}

output "db_arn" {
  value = aws_db_instance.this.arn
}

output "db_identifier" {
  value = aws_db_instance.this.identifier
}
