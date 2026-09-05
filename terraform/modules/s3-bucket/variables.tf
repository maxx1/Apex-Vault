variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
}

variable "purpose" {
  description = "Purpose of this bucket (for tagging)"
  type        = string
  default     = "data-storage"
}

variable "versioning_enabled" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = true
}

variable "enable_lifecycle" {
  description = "Enable lifecycle policies for cost optimization"
  type        = bool
  default     = true
}

variable "expiration_days" {
  description = "Number of days before objects are deleted"
  type        = number
  default     = 90
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even if it contains objects"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
