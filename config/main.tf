resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.bucket_name}-${data.aws_caller_identity.current.account_id}"
  acl    = "private"
  versioning { enabled = true }
}