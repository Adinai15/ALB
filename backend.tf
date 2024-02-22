terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "tf-lesson-7-part1"
    key            = "tf-homework7-part1-sf"
    dynamodb_table = "tf-state-file"
  }
}