# Copyright 2023 - 2026 Dave Hall, https://proactiveops.io, MIT License

terraform {
  required_version = ">= 1.0, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, <7.0"
    }
  }
}
