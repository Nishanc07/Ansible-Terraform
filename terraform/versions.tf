terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 4.33.0"
    }
    random = {
        source = "hashicorp/random"
        version = "~> 3.6.3"
    }
    }
    
  
}

provider "azurerm" {
  # Configuration options
  features {
    
  }
  subscription_id = "a584d13d-2dd5-4bbf-85ff-b0c51f60baca"
  
}

