moved {
  from = aws_kms_key.this
  to   = aws_kms_key.queue
}

moved {
  from = aws_kms_alias.this
  to   = aws_kms_alias.queue
}
