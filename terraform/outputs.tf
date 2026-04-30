output "instance_ip" {
  value = aws_instance.build.public_ip
}

output "windows_password" {
  value = nonsensitive(random_password.windows.result)
}
