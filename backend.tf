# Define where terraform will store the shared state.
terraform {
  backend "s3" {
    bucket                      = "osac-terraform-state"
    key                         = "osac.tfstate"
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
