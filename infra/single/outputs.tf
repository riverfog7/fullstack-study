output "instance_id" {
  value = aws_instance.app.id
}

output "public_ip" {
  value = aws_instance.app.public_ip
}

output "web_url" {
  value = "http://${aws_instance.app.public_ip}:8080"
}

output "security_group_id" {
  value = aws_security_group.app.id
}

output "ssh_command" {
  description = "키 파일을 받은 Downloads 폴더에서 실행합니다."
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.app.public_ip}"
}
