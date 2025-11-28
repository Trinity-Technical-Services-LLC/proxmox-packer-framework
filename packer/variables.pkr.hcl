# ============================================================================================ #
# - File: {root}/variables.pkr.hcl                                          | Version: v1.0.0  #
# --- [ Description ] ------------------------------------------------------------------------ #
#                                                                                              #
# ============================================================================================ #

#region ------ [ Proxmox Settings ] ---------------------------------------------------------- #

  variable "proxmox_hostname" {
    type        = string
    description = "FQDN or IP address of the target Proxmox node (single node in the cluster)."
    sensitive   = false

    validation {
      condition     = length(var.proxmox_hostname) > 0
      error_message = "proxmox_hostname must not be empty."
    }
  }

  variable "proxmox_api_token_id" {
    type        = string
    description = "Proxmox API token ID in USER@REALM!TOKENID format (e.g. packer@pam!packer_pve_token)."
    sensitive   = true

    validation {
      condition     = can(regex(".+@.+!.+", var.proxmox_api_token_id))
      error_message = "proxmox_api_token_id must be in USER@REALM!TOKENID format, e.g. packer@pam!packer_pve_token."
    }
  }

  variable "proxmox_api_token_secret" {
    type        = string
    description = "Secret associated with the Proxmox API token ID."
    sensitive   = true

    validation {
      condition     = length(var.proxmox_api_token_secret) >= 16
      error_message = "proxmox_api_token_secret appears too short; check that you are passing the full token secret."
    }
  }

  variable "proxmox_skip_tls_verify" {
    description = "true/false to skip Proxmox TLS certificate checks."
    type        = bool
    default     = false
    sensitive   = true
  }

#endregion --- [ Proxmox Settings ] ---------------------------------------------------------- #

#region ------ [ Packer Settings ] ----------------------------------------------------------- #

  variable "deploy_user_name" {
    type        = string
    description = "SSH user used for provisioning inside the guest (e.g. 'ubuntu' or 'root')."
    sensitive   = true

    validation {
      condition     = length(var.deploy_user_name) > 0
      error_message = "deploy_user_name must not be empty."
    }
  }

  variable "deploy_user_password" {
    type        = string
    description = "Password for the deploy/provisioning user (used only if password auth / become_pass is required)."
    sensitive   = true

    validation {
      condition     = length(var.deploy_user_password) > 0
      error_message = "deploy_user_password must not be empty when used."
    }
  }

variable "deploy_user_key" {
  type        = string
  description = "SSH public key for the deploy/provisioning user (authorized_keys entry)."
  sensitive   = true

  validation {
    condition     = length(var.deploy_user_key) > 0
    error_message = "deploy_user_password must not be empty when used."
  }
}

#endregion --- [ Packer Settings ] ----------------------------------------------------------- #

#region ------ [ Packer Image ] -------------------------------------------------------------- #

  variable "packer_image" {

    description = "Composite Proxmox VM/template configuration used by the proxmox-iso builder."

    type = object({

      # OS Installation & Configuration
      install_method            = string
      additional_packages       = list(string)

      # Template Metadata
      os_language               = string
      os_keyboard               = string
      os_timezone               = string
      os_family                 = string
      os_name                   = string
      os_version                = string

      # General Settings
      template_description      = string
      template_name             = string
      vm_id                     = number
      pool                      = string
      node                      = string
      vm_name                   = string
      tags                      = list(string)

      # QEMU Agent
      qemu_agent                = bool
      qemu_additional_args      = string

      # Misc Settings
      disable_kvm               = bool
      machine                   = string
      os                        = string
      task_timeout              = string

      # VM Configuration: Boot Settings
      bios                      = string
      boot                      = string
      boot_key_interval         = string
      boot_keygroup_interval    = string
      boot_wait                 = string
      boot_command              = list(string)

      # VM Configuration: Cloud-Init
      cloud_init                = bool
      cloud_init_disk_type      = string
      cloud_init_storage_pool   = string

      # Hardware: CPU
      cores                     = number
      cpu_type                  = string
      sockets                   = number

      # Hardware: Memory
      ballooning_minimum        = number
      memory                    = number
      numa                      = bool

      # Hardware: Misc
      scsi_controller           = string
      serials                   = list(string)
      vm_interface              = string

    })

    #region ------ [ Validation ] ------------------------------------------------------------ #

      #region ------ [ Validation: OS Installation & Configuration ] ------------------------- #

        validation {
          condition = contains(
            [ "kickstart", "autoinstall", "unattend" ],
            lower(var.packer_image.install_method)
          )
          error_message = <<-EOT
            packer_image.install_method must be one of:
              - kickstart   (RHEL/Rocky/Alma)
              - autoinstall (Ubuntu)
              - unattend    (Windows)
            EOT
        }

      #endregion --- [ Validation: OS Installation & Configuration ] ------------------------- #

      #region ------ [ Validation: Template Metadata ] --------------------------------------- #

        # os_family
        validation {
          condition = contains(
            ["rhel", "ubuntu", "windows"],
            lower(var.packer_image.os_family)
          )

          error_message = <<-EOT
            Invalid packer_image.os_family.
            Allowed values are:
              - rhel
              - ubuntu
              - windows

            Use 'rhel' for RHEL-compatible distributions (RHEL, Rocky, Alma, etc.).
          EOT
        }

        # os_name
        validation {
          condition = (
            # non-empty, safe characters
            length(trimspace(var.packer_image.os_name)) > 0 &&
            can(regex("^[A-Za-z0-9_.-]+$", var.packer_image.os_name)) &&
            # must contain the os_family label somewhere (case-insensitive)
            contains(
              lower(var.packer_image.os_name),
              lower(var.packer_image.os_family)
            )
          )

          error_message = <<-EOT
            Invalid packer_image.os_name.

            Requirements:
              - must be non-empty
              - may only contain letters, digits, '.', '_' and '-'
              - must include the os_family string (e.g.:
                  os_family = "rhel"    -> os_name might be "rhel-8" or "rhel-8-minimal"
                  os_family = "ubuntu"  -> os_name might be "ubuntu-22.04"
                  os_family = "windows" -> os_name might be "windows-server-2022")
          EOT
        }

        # os_version
        validation {
          condition = anytrue([
            # RHEL-family (RHEL, Rocky, Alma, etc.): major.minor (e.g. 8.9)
            (
              lower(var.packer_image.os_family) == "rhel" &&
              can(regex("^[0-9]+\\.[0-9]+$", var.packer_image.os_version))
            ),

            # Ubuntu: YY.MM (e.g. 22.04, 20.04)
            (
              lower(var.packer_image.os_family) == "ubuntu" &&
              can(regex("^[0-9]{2}\\.[0-9]{2}$", var.packer_image.os_version))
            ),

            # Windows: 2–4 digit numeric version (e.g. 2019, 2022, 10, 11)
            (
              lower(var.packer_image.os_family) == "windows" &&
              can(regex("^[0-9]{2,4}$", var.packer_image.os_version))
            )
          ])

          error_message = <<-EOT
            Invalid packer_image.os_version for the selected os_family.

            Expected formats:
              - os_family = "rhel"    -> os_version like "8.9", "9.3"
              - os_family = "ubuntu"  -> os_version like "22.04", "20.04"
              - os_family = "windows" -> os_version like "2019", "2022", "10", "11"
          EOT
        }

      #endregion --- [ Validation: Template Metadata ] --------------------------------------- #

      #region ------ [ Validation: General Settings ] ---------------------------------------- #

        # template_description
        validation {
          condition = (
            length(trimspace(var.packer_image.template_description)) > 0 &&
            length(var.packer_image.template_description) <= 1024
          )

          error_message = <<-EOT
            Invalid packer_image.template_description.
            Description must be non-empty and at most 1024 characters.
          EOT
        }

        # template_name
        validation {
          condition = can(
            regex(
              "^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$",
              var.packer_image.template_name,
            )
          )

          error_message = <<-EOT
            Invalid packer_image.template_name.
            Template names must follow the same rules as VM names:
              - 1–63 characters
              - letters, digits, and '-'
              - '-' cannot be the first or last character
          EOT
        }

        # vm_id
        validation {
          condition = (
            var.packer_image.vm_id >= 900000000 &&
            var.packer_image.vm_id <= 999999999
          )

          error_message = <<-EOT
            Invalid packer_image.vm_id.
            Proxmox VM IDs must be between 100 and 999999999.
          EOT
        }

        # pool
        validation {
          condition = can(
            regex(
              "^[A-Za-z][A-Za-z0-9_.-]*[A-Za-z0-9]$",
              var.packer_image.pool,
            )
          )

          error_message = <<-EOT
            Invalid packer_image.pool.
            Pool IDs must:
              - start with a letter
              - end with a letter or digit
              - only contain letters, digits, '_', '-' and '.'
          EOT
        }

        # node
        validation {
          condition = can(
            regex(
              "^[A-Za-z][A-Za-z0-9_.-]*[A-Za-z0-9]$",
              var.packer_image.node,
            )
          )

          error_message = <<-EOT
            Invalid packer_image.node.
            Node names must:
              - start with a letter
              - end with a letter or digit
              - only contain letters, digits, '_', '-' and '.'
          EOT
        }

        # vm_name
        validation {
          condition = can(
            regex(
              "^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$",
              var.packer_image.vm_name,
            )
          )

          error_message = <<-EOT
            Invalid packer_image.vm_name.
            VM names must be valid DNS hostnames:
              - 1–63 characters
              - letters, digits, and '-'
              - '-' cannot be the first or last character
          EOT
        }


        # tags
        validation {
          condition = alltrue([
            for t in var.packer_image.tags :
            can(regex("^[A-Za-z0-9_.+-]+$", t)) && length(t) > 0
          ])

          error_message = <<-EOT
            Invalid packer_image.tags.
            Each tag must be non-empty and may only contain:
              - letters (a–z, A–Z)
              - digits (0–9)
              - '_', '-', '+', '.'
          EOT
        }

      #endregion --- [ Validation: General Settings ] ---------------------------------------- #

      #region ------ [ Validation: QEMU Agent ] ---------------------------------------------- #

        validation {
          condition = (
            length(var.packer_image.qemu_additional_args) == 0 ||
            can(regex("^[^\\n;]{1,512}$", var.packer_image.qemu_additional_args))
          )

          error_message = <<-EOT
            packer_image.qemu_additional_args should normally be empty.

            If you set it, it must:
              - be a single line (no newlines)
              - not contain ';'
              - be at most 512 characters long

            This keeps QEMU arguments manageable and reduces the risk of malformed or
            unsafe command lines.
          EOT
        }


      #endregion --- [ Validation: QEMU Agent ] ---------------------------------------------- #

      #region ------ [ Validation: Misc Settings ] ------------------------------------------- #

        # disable_kvm: None needed; its yes/no.

        # machine
        validation {
          condition = contains(["pc", "q35"], lower(var.packer_image.machine))

          error_message = <<-EOT
            Invalid packer_image.machine.
            Supported machine types are:
              - pc
              - q35
          EOT
        }

        # os
        validation {
          condition = anytrue([
            # RHEL / Ubuntu -> Linux 2.6+ ostype
            (lower(var.packer_image.os_family) == "rhel"   &&
            lower(var.packer_image.os) == "l26"),
            (lower(var.packer_image.os_family) == "ubuntu" &&
            lower(var.packer_image.os) == "l26"),

            # Windows -> one of the known Windows ostype codes
            (
              lower(var.packer_image.os_family) == "windows" &&
              contains(
                [
                  "wxp", "w2k", "w2k3", "w2k8", "wvista",
                  "win7", "win8", "win10", "win11"
                ],
                lower(var.packer_image.os)
              )
            )
          ])

          error_message = <<-EOT
            Invalid packer_image.os for the selected os_family.

            Expected:
              - os_family = "rhel"   -> os = "l26"
              - os_family = "ubuntu" -> os = "l26"
              - os_family = "windows" -> one of:
                  wxp, w2k, w2k3, w2k8, wvista, win7, win8, win10, win11

            Adjust this list if your Proxmox cluster or plugin supports additional ostype
            codes (for example, new Windows or Linux variants).
          EOT
        }

        # task_timeout
        validation {
          condition = can(
            regex(
              "^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$",
              trimspace(var.packer_image.task_timeout)
            )
          )

          error_message = <<-EOT
            Invalid packer_image.task_timeout.
            Use a Go-style duration string, for example:
              - "30s"
              - "5m"
              - "10m"
              - "1h30m"
          EOT
        }



      #endregion --- [ Validation: Misc Settings ] ------------------------------------------- #

      #region ------ [ Validation: VM Configuration: Boot Settings ] ------------------------- #

        # bios
        validation {
          condition = contains(
            ["seabios", "ovmf"],
            lower(var.packer_image.bios)
          )

          error_message = <<-EOT
            Invalid packer_image.bios.
            Supported values are:
              - seabios  (legacy BIOS)
              - ovmf     (UEFI firmware)

            See the Proxmox ISO builder documentation: bios can be set to
            'ovmf' or 'seabios' only.
          EOT
        }

        # boot
        validation {
          condition = (
            length(trimspace(var.packer_image.boot)) == 0 ||
            can(
              regex(
                "^order=[A-Za-z0-9._-]+(;[A-Za-z0-9._-]+)*$",
                trimspace(var.packer_image.boot)
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.boot.

            When set, boot must use the Proxmox 'order=' syntax, for example:
              order=virtio0;ide2;net0

            Leave it empty to let Proxmox/Packer use the default boot order.
          EOT
        }

        # boot_key_interval
        validation {
          condition = (
            length(trimspace(var.packer_image.boot_key_interval)) == 0 ||
            can(
              regex(
                "^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$",
                trimspace(var.packer_image.boot_key_interval)
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.boot_key_interval.
            Use a Go-style duration string, for example:
              "250ms", "5s", "1m30s"
            Leave it empty to use the builder default.
          EOT
        }

        # boot_keygroup_interval
        validation {
          condition = (
            length(trimspace(var.packer_image.boot_keygroup_interval)) == 0 ||
            can(
              regex(
                "^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$",
                trimspace(var.packer_image.boot_keygroup_interval)
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.boot_keygroup_interval.
            Use a Go-style duration string, for example:
              "250ms", "5s", "1m30s"
            Leave it empty to use the builder default.
          EOT
        }

        # boot_wait
        validation {
          condition = (
            length(trimspace(var.packer_image.boot_wait)) == 0 ||
            can(
              regex(
                "^-?([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$",
                trimspace(var.packer_image.boot_wait)
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.boot_wait.
            Use a Go-style duration string, for example:
              "10s", "30s", "1m30s"
            To effectively set boot_wait to 0s, use a small negative duration such as "-1s".
          EOT
        }

        # boot_command
        validation {
          condition = alltrue([
            for cmd in var.packer_image.boot_command :
            length(trimspace(cmd)) > 0 &&
            length(cmd) <= 512 &&
            !strcontains(cmd, "\n")
          ])

          error_message = <<-EOT
            Invalid packer_image.boot_command entry.

            Each element in boot_command must:
              - be non-empty
              - be at most 512 characters
              - not contain newline characters

            Use multiple entries in the list instead of embedding newlines, and use
            tokens like <enter>, <wait>, etc. as documented in the Packer boot
            command reference.
          EOT
        }

      #endregion --- [ Validation: VM Configuration: Boot Settings ] ------------------------- #

      #region ------ [ Validation: VM Configuration: Cloud-Init ] ---------------------------- #

        # cloud_init_disk_type
        validation {
            # If cloud_init is disabled, we don't care what the disk type is (it's ignored)
          var.packer_image.cloud_init == false ||

          condition = contains(
            ["scsi", "sata", "ide"],
            lower(var.packer_image.cloud_init_disk_type)
          )

          error_message = <<-EOT
            Invalid packer_image.cloud_init_disk_type.

            Supported Cloud-Init disk types are:
              - scsi
              - sata
              - ide

            For modern guests, 'scsi' is generally preferred for performance and
            compatibility. 'ide' is mostly for legacy scenarios.
          EOT
        }

        # cloud_init
        validation {
          condition = (
            # If cloud_init is disabled, we don't care what the pool is (it's ignored)
            var.packer_image.cloud_init == false ||

            # If cloud_init is enabled, require a non-empty, ID-shaped storage name
            (
              length(trimspace(var.packer_image.cloud_init_storage_pool)) > 0 &&
              can(regex(
                "^[A-Za-z][A-Za-z0-9_.-]*[A-Za-z0-9]$",
                trimspace(var.packer_image.cloud_init_storage_pool)
              ))
            )
          )

          error_message = <<-EOT
            Invalid packer_image.cloud_init_storage_pool.

            When cloud_init is true, cloud_init_storage_pool must:
              - be non-empty
              - start with a letter
              - end with a letter or digit
              - only contain letters, digits, '_', '-' and '.'

            Example values:
              - local
              - local-lvm
              - nfs-templates
          EOT
        }

      #endregion --- [ Validation: VM Configuration: Cloud-Init ] ---------------------------- #

      #region ------ [ Validation: Hardware: CPU ] ------------------------------------------- #

        # cores, sockets
        validation {
          condition = (
            var.packer_image.cores   >= 1 &&
            var.packer_image.sockets >= 1 &&
            floor(var.packer_image.cores)   == var.packer_image.cores &&
            floor(var.packer_image.sockets) == var.packer_image.sockets &&
            (var.packer_image.cores * var.packer_image.sockets) <= 96
          )

          error_message = <<-EOT
            Invalid CPU topology in packer_image.cores / packer_image.sockets.

            Requirements:
              - cores   must be an integer >= 1
              - sockets must be an integer >= 1
              - cores * sockets must be <= 96

            Adjust cores and/or sockets so that their product does not exceed 96.
          EOT
        }

        # cpu_type
        validation {
          condition = contains(
            [ "host", "x86-64-v2-aes", "kvm64" ],
            lower(var.packer_image.cpu_type)
          )

          error_message = <<-EOT
            Invalid packer_image.cpu_type.

            Allowed values (organization-approved) are:
              - x86-64-v2-aes
              - host
              - kvm64

            These correspond to the QEMU/Proxmox CPU models documented as safe defaults
            or recommended starting points. If you need a different CPU model
            (for example a specific Intel or AMD microarchitecture), extend the
            local.approved_cpu_types list explicitly.
          EOT
        }

      #endregion --- [ Validation: Hardware: CPU ] ------------------------------------------- #

      #region ------ [ Validation: Hardware: Memory ] ---------------------------------------- #

        # memory, ballooning_minimum
        validation {
          condition = (
            # memory: integer MB, at least 256 MB
            var.packer_image.memory >= 256 &&
            floor(var.packer_image.memory) == var.packer_image.memory &&

            # ballooning_minimum: integer MB, >= 0
            var.packer_image.ballooning_minimum >= 0 &&
            floor(var.packer_image.ballooning_minimum)
              == var.packer_image.ballooning_minimum &&

            # relationship: min <= max
            var.packer_image.ballooning_minimum <= var.packer_image.memory
          )

          error_message = <<-EOT
            Invalid memory configuration in packer_image.memory /
            packer_image.ballooning_minimum.

            Requirements:
              - memory (max RAM) must be an integer >= 256 (MB)
              - ballooning_minimum (min RAM) must be an integer >= 0 (MB)
              - ballooning_minimum must be <= memory
              - set ballooning_minimum = 0 to disable ballooning

            Proxmox interprets:
              - memory             as the maximum RAM the VM can use (in MB)
              - ballooning_minimum as the minimum guaranteed RAM when ballooning
                is enabled.
          EOT
        }

      #endregion --- [ Validation: Hardware: Memory ] ---------------------------------------- #

      #region ------ [ Validation: Hardware: Misc ] ------------------------------------------ #

        # scsi_controller
        validation {
          condition = contains(
            [
              "lsi",
              "lsi53c810",
              "virtio-scsi-pci",
              "virtio-scsi-single",
              "megasas",
              "pvscsi",
            ],
            lower(var.packer_image.scsi_controller)
          )

          error_message = <<-EOT
            Invalid packer_image.scsi_controller.

            Supported SCSI controller models are:
              - lsi
              - lsi53c810
              - virtio-scsi-pci
              - virtio-scsi-single
              - megasas
              - pvscsi

            For most modern guests and best performance, 'virtio-scsi-single' or
            'virtio-scsi-pci' are recommended controller types.
          EOT
        }

      #endregion --- [ Validation: Hardware: Misc ] ------------------------------------------ #

    #endregion --- [ Validation ] ------------------------------------------------------------ #

  }

  variable "additional_iso_files" {
    description = "Additional ISO files to be attached to the VM."
    default = []
    type = list(
      object({
        /* Required Variables */
        iso_checksum         = string
        /* Either iso_url or iso_urls Required */
        iso_file             = string
        iso_urls             = list(string)
        /* Optional Variables */
        cd_content           = map(string)
        cd_files             = list(string)
        cd_label             = string
        index                = number
        iso_download_pve     = bool
        iso_storage_pool     = string
        iso_target_extension = string
        iso_target_path      = string
        keep_cdrom_device    = bool
        type                 = string
        unmount              = bool
      })
    )
  }

  variable "boot_iso" {
    description = "The boot ISO configuration for the VM."
    type = object({
      /* Required Variables */
      iso_checksum         = string
      /* Either iso_url or iso_urls Required */
      iso_file             = string
      iso_urls             = list(string)
      /* Optional Variables */
      cd_label             = string
      index                = number
      iso_download_pve     = bool
      iso_storage_pool     = string
      iso_target_extension = string
      iso_target_path      = string
      keep_cdrom_device    = bool
      type                 = string
      unmount              = bool
    })

    validation {
      condition     = can(regex("^[a-z0-9]+:[0-9a-fA-F]+$", var.boot_iso.iso_checksum))
      error_message = "boot_iso.iso_checksum must include algorithm and hex digest (e.g. sha256:abc123...)."
    }
  }

  variable "disks" {
    description = "List of disks to attach to the VM."
    type = list(
      object({
        asyncio             = string
        cache_mode          = string
        discard             = bool
        exclude_from_backup = bool
        format              = string
        io_thread           = bool
        size                = string
        ssd                 = bool
        storage_pool        = string
        type                = string
      })
    )
  }

  variable "efi_config" {
    description = "EFI configuration for the VM (empty settings mean no EFI disk)."
    type = object({
      efi_format        = string
      efi_storage_pool  = string
      efi_type          = string
      pre_enrolled_keys = bool
    })
  }

  variable "network_adapters" {
    description = "List of network adapters to attach to the VM."
    type = list(
      object({
        /* Optional Variables */
          # Network Configuration
          ipv4_address = string
          ipv4_netmask = number
          ipv4_gateway = string
          dns          = list(string)
          # Hardware Configuration
          bridge        = string
          firewall      = bool
          mac_address   = string
          model         = string
          mtu           = number
          packet_queues = number
          vlan_tag      = number
      })
    )
  }

  variable "pci_devices" {
    description = "List of PCI devices to passthrough to the VM."
    type = list(
      object({
        /* Note: Either 'host' or 'mapping' Required */
        host          = string
        mapping       = string
        /* Optional Variables */
        device_id     = string
        hide_rombar   = bool
        legacy_igd    = bool
        mdev          = string
        pcie          = bool
        romfile       = string
        sub_device_id = string
        sub_vendor_id = string
        vendor_id     = string
        x_vga         = bool
      })
    )
  }

  variable "rng0" {
    description = "VirtIO RNG device configuration for the VM (entropy source)."
    type = object({
      /* Optional Variables */
      source    = string
      max_bytes = number
      period    = number
    })
  }

  variable "tpm_config" {
    description = "TPM device configuration for the VM."
    type = object({
      /* Optional Variables */
      tpm_storage_pool = string
      tpm_version      = string
    })
  }

  variable "vga" {
    description = "VGA adapter configuration for the VM console."
    type = object({
      /* Optional Variables */
      type   = string
      memory = number
    })
  }

#endregion --- [ Packer Image ] -------------------------------------------------------------- #

#region ------ [ Virtual Machine (VM) Settings ] --------------------------------------------- #

    # variable "vm_disk_partitions" {
    #   type = list(object({
    #     name = string
    #     size = number
    #     format = object({
    #       label  = string
    #       fstype = string
    #     })
    #     mount = object({
    #       path    = string
    #       options = string
    #     })
    #     volume_group = string
    #   }))
    #   description = "The disk partitions for the virtual disk."
    # }

    # variable "vm_disk_lvm" {
    #   type = list(object({
    #     name    = string
    #     partitions = list(object({
    #       name = string
    #       size = number
    #       format = object({
    #         label  = string
    #         fstype = string
    #       })
    #       mount = object({
    #         path    = string
    #         options = string
    #       })
    #     }))
    #   }))
    #   description = "The LVM configuration for the virtual disk."
    #   default     = []
    # }

  #endregion --- [ Virtual Machine (VM) Settings - Storage ] --------------------------------- #

variable "vm_disk_use_swap" {
  type        = bool
  description = "Whether to use a swap partition."
}

variable "vm_disk_partitions" {
  type = list(object({
    name = string
    size = number
    format = object({
      label  = string
      fstype = string
    })
    mount = object({
      path    = string
      options = string
    })
    volume_group = string
  }))
  description = "The disk partitions for the virtual disk."
}

variable "vm_disk_lvm" {
  type = list(object({
    name    = string
    partitions = list(object({
      name = string
      size = number
      format = object({
        label  = string
        fstype = string
      })
      mount = object({
        path    = string
        options = string
      })
    }))
  }))
  description = "The LVM configuration for the virtual disk."
  default     = []
}
