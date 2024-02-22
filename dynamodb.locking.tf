#create dynamodb table for using as locking:
resource "aws_dynamodb_table" "terraform_locking" {
  name         = "tf-state-file"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"


  attribute {
    name = "LockID"
    type = "S"
  }
}