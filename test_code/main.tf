terraform {
  required_version = "1.16.0"

  cloud {
    hostname = "tfe-ibm.aws.munnep.com" 
    organization = "test"

    workspaces {
      name = "test"
    }
  }
}

resource "null_resource" "name" {

}