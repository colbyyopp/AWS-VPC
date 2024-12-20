variable "region" {
  description = "region where resources are deployed"
  type        = string
  default     = "us-east-1"
}

variable "ami" {
  description = "AWS Linux 2023 image"
  type        = string
  default     = "ami-041feb57c611358bd"
}

variable "instance_type" {
  type    = list(string)
  default = ["t2.micro", "t3.micro"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "az_a" {
  type    = string
  default = "us-east-1a"
}

variable "az_b" {
  type    = string
  default = "us-east-1b"
}

variable "all_traffic_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
