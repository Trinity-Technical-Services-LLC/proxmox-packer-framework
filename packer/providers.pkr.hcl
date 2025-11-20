# ============================================================================================ #
# - File: {root}\providers.pkr.hcl                                          | Version: v1.0.0  #
# --- [ Description ] ------------------------------------------------------------------------ #
#                                                                                              #
# ============================================================================================ #

packer {

# Homepage: https://developer.hashicorp.com/packer/install
# Github:   https://github.com/hashicorp/packer
  required_version = "1.14.3"

  required_plugins {

    ansible = {
    # Homepage: https://developer.hashicorp.com/packer/integrations/hashicorp/ansible
    # Github:   https://github.com/hashicorp/packer-plugin-ansible
      source  = "github.com/hashicorp/ansible"
      version = "= 1.1.4"
    }

    git = {
    # Homepage: https://developer.hashicorp.com/packer/integrations/ethanmdavidson/git
    # Github:   https://github.com/ethanmdavidson/packer-plugin-git
      source  = "github.com/ethanmdavidson/git"
      version = "= 0.6.5"
    }

    proxmox = {
    # Homepage: https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox
    # Github:   https://github.com/hashicorp/packer-plugin-proxmox
      source  = "github.com/hashicorp/proxmox"
      version = "= 1.2.3"
    }

  }
}
