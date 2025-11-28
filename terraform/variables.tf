variable "project_name" {
  description = "Name of the project, used for naming resources"
  type        = string
  default     = "boomi-replacement"
}

variable "salesforce_connector_profile_name" {
  description = "Name of the existing AppFlow Connector Profile for Salesforce"
  type        = string
  default     = "MySalesforceConnection" # Placeholder
}

variable "salesforce_object" {
  description = "Salesforce object to query (e.g., Account, Opportunity)"
  type        = string
  default     = "Account"
}

variable "external_api_url" {
  description = "The external API URL to POST data to"
  type        = string
  default     = "https://example.com/api/ingest" # Placeholder
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}
