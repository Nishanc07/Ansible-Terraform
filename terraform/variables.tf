variable "application_name" {
  type = string
}

variable "environment_name" {
  type = string
}

variable "primary_location" {
  type = string
}

variable "base_address_space" {
  type = string
}

variable "number_of_instances" {
  type = number
  description = "Number of instances to be created"
  default = 1
}
