moved {
  from = aws_kms_key.this
  to   = aws_kms_key.queue
}

moved {
  from = aws_kms_alias.this
  to   = aws_kms_alias.queue
}

moved {
  from = module.otel_config.aws_ssm_parameter.this[0]
  to   = aws_ssm_parameter.otel_config
}

moved {
  from = module.senzing_config.aws_ssm_parameter.this[0]
  to   = aws_ssm_parameter.senzing_config
}
