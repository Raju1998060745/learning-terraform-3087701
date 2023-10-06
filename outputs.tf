output "instance_ami" {
  value = aws_instance.tester.ami
}

output "instance_arn" {
  value = aws_instance.tester.arn
}
