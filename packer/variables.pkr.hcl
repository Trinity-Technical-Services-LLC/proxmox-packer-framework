# ============================================================================================ #
# - File: {root}/variables.pkr.hcl                                          | Version: v1.0.0  #
# --- [ Description ] ------------------------------------------------------------------------ #
#                                                                                              #
# ============================================================================================ #

#region ------ [ Proxmox Settings ] ---------------------------------------------------------- #

  variable "proxmox_hostname" {
    type        = string
    description = "FQDN or IP address of the target Proxmox node (single node in the cluster)."
    sensitive   = true

    validation {
      condition     = length(var.proxmox_hostname) > 0
      error_message = "The variable 'proxmox_hostname' must not be empty."
    }
  }

  variable "proxmox_api_token_id" {
    type        = string
    description = "Proxmox API token ID in USER@REALM!TOKENID format (e.g. packer@pam!packer_pve_token)."
    sensitive   = true

    validation {
      condition     = can(regex(".+@.+!.+", var.proxmox_api_token_id))
      error_message = "The variable 'proxmox_api_token_id' must be in USER@REALM!TOKENID format, e.g. packer@pam!packer_pve_token."
    }
  }

  variable "proxmox_api_token_secret" {
    type        = string
    description = "Secret associated with the Proxmox API token ID."
    sensitive   = true

    validation {
      condition     = length(var.proxmox_api_token_secret) >= 16
      error_message = "The variable 'proxmox_api_token_secret' appears too short; check that you are passing the full token secret."
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
      error_message = "The variable 'deploy_user_name' must not be empty."
    }
  }

  variable "deploy_user_password" {
    type        = string
    description = "Password for the deploy/provisioning user (used only if password auth / become_pass is required)."
    sensitive   = true

    validation {
      condition     = length(var.deploy_user_password) > 0
      error_message = "The variable 'deploy_user_password' must not be empty when used."
    }
  }

variable "deploy_user_key" {
  type        = string
  description = "SSH public key for the deploy/provisioning user (authorized_keys entry)."
  sensitive   = true

  validation {
    condition     = length(var.deploy_user_key) > 0
    error_message = "The variable 'deploy_user_password' must not be empty when used."
  }
}

#endregion --- [ Packer Settings ] ----------------------------------------------------------- #

#region ------ [ Packer Image ] -------------------------------------------------------------- #

  variable "packer_image" {

    description = "Composite Proxmox VM/template configuration used by the proxmox-iso builder."

    type = object({ 

      # 
      insecure_skip_tls_verify = bool

      # OS Installation & Configuration
      install_method            = string
      additional_packages       = list(string)

      # Template Metadata
      os_language               = string
      os_keyboard               = string
      os_timezone               = string
      os_family                 = string
      os_distribution           = string
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
            ["kickstart", "autoinstall", "unattend"],
            var.packer_image.install_method
          )

          error_message = <<-EOT
            Invalid packer_image.install_method; it must be "kickstart", "autoinstall" or "unattend".
          EOT
        }

      #endregion --- [ Validation: OS Installation & Configuration ] ------------------------- #

      #region ------ [ Validation: Template Metadata ] --------------------------------------- #

        # os_language
        validation {
          condition = (
            var.packer_image.os_language == null
            ? true
            : (
                # No leading or trailing whitespace, non-empty, sane length
                trimspace(var.packer_image.os_language)
                  == var.packer_image.os_language &&
                length(var.packer_image.os_language) > 0 &&
                length(var.packer_image.os_language) <= 64 &&

                anytrue([
                  # Linux (RHEL/Rocky/Ubuntu): POSIX locale (e.g. en_US, en_US.UTF-8, es_419.UTF-8, C.UTF-8)
                  (
                    var.packer_image.os_family == "linux" &&
                    can(
                      regex(
                        "^(C|POSIX|[A-Za-z]{2,8}(_[A-Za-z0-9]{2,8})?(\\.[A-Za-z0-9-]+)?(@[A-Za-z0-9-]+)?)$",
                        var.packer_image.os_language
                      )
                    )
                  ),

                  # Windows: BCP-47 language tag (e.g. en-US, fr-FR, zh-Hans-CN)
                  (
                    var.packer_image.os_family == "windows" &&
                    can(
                      regex(
                        "^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$",
                        var.packer_image.os_language
                      )
                    )
                  )
                ])
              )
          )

          error_message = <<-EOT
            Invalid packer_image.os_language; a Linux locale such as "en_US.UTF-8" when os_family is "linux", or a Windows language tag such as "en-US" when os_family is "windows", with no leading or trailing whitespace and a maximum length of 64 characters.
          EOT
        }


        # os_keyboard
        validation {
          condition = (
            var.packer_image.os_keyboard == null
            ? true
            : (
                # No leading or trailing whitespace
                trimspace(var.packer_image.os_keyboard)
                  == var.packer_image.os_keyboard &&

                # Reasonable length
                length(var.packer_image.os_keyboard) >= 2 &&
                length(var.packer_image.os_keyboard) <= 32 &&

                # Keyboard layout pattern: us, us-intl, de-latin1, etc.
                can(
                  regex(
                    "^[A-Za-z0-9]{2,16}([_-][A-Za-z0-9]{2,16})*$",
                    var.packer_image.os_keyboard
                  )
                )
              )
          )

          error_message = <<-EOT
            Invalid packer_image.os_keyboard; it must be null to use the
            default or a keyboard layout string such as "us", "us-intl" or
            "de-latin1", with no leading or trailing whitespace and a maximum
            length of 32 characters.
          EOT
        }

        # os_family
        validation {
          condition = contains(
            ["linux", "windows"],
            var.packer_image.os_family
          )

          error_message = <<-EOT
            Invalid packer_image.os_family; it must be "linux" or "windows".
          EOT
        }

        # os_distribution
        validation {
          condition = anytrue([
            (
              var.packer_image.os_family == "linux" &&
              contains(
                [ "rocky", "rhel", "ubuntu" ],
                var.packer_image.os_distribution
              )
            ),
            (
              var.packer_image.os_family == "windows" &&
              contains(
                [ "server", "desktop" ],
                var.packer_image.os_distribution
              )
            )
          ])

          error_message = <<-EOT
            Invalid packer_image.os_distribution for the selected os_family; for
            os_family "linux" it must be "rocky", "rhel" or "ubuntu", and for
            os_family "windows" it must be "server" or "desktop".
          EOT
        }

        # os_version
        validation {
          condition = anytrue([
            # Linux (Rocky/RHEL): major.minor (e.g. 8.9, 9.3)
            (
              lower(trimspace(var.packer_image.os_family)) == "linux" &&
              contains(
                ["rocky", "rhel"],
                lower(trimspace(var.packer_image.os_distribution))
              ) &&
              can(
                regex(
                  "^[0-9]+\\.[0-9]+$",
                  trimspace(var.packer_image.os_version)
                )
              )
            ),

            # Linux (Ubuntu): YY.MM (e.g. 22.04, 20.04)
            (
              lower(trimspace(var.packer_image.os_family)) == "linux" &&
              lower(trimspace(var.packer_image.os_distribution)) == "ubuntu" &&
              can(
                regex(
                  "^[0-9]{2}\\.[0-9]{2}$",
                  trimspace(var.packer_image.os_version)
                )
              )
            ),

            # Windows Desktop: 2-digit version (e.g. 10, 11)
            (
              lower(trimspace(var.packer_image.os_family)) == "windows" &&
              lower(trimspace(var.packer_image.os_distribution)) == "desktop" &&
              can(
                regex(
                  "^[0-9]{2}$",
                  trimspace(var.packer_image.os_version)
                )
              )
            ),

            # Windows Server: 4-digit year with optional 1–2 char suffix (e.g. 2019, 2022, 2016R2)
            (
              lower(trimspace(var.packer_image.os_family)) == "windows" &&
              lower(trimspace(var.packer_image.os_distribution)) == "server" &&
              can(
                regex(
                  "^[0-9]{4}([A-Za-z0-9]{1,2})?$",
                  trimspace(var.packer_image.os_version)
                )
              )
            )
          ])

          error_message = <<-EOT
            Invalid packer_image.os_version for the selected os_family and
            os_distribution; for linux with rocky or rhel it must look like
            "8.9" or "9.3", for linux with ubuntu it must look like "22.04" or
            "20.04", for windows with desktop it must look like "10" or "11",
            and for windows with server it must look like "2019", "2022" or
            "2016R2".
          EOT
        }

      #endregion --- [ Validation: Template Metadata ] --------------------------------------- #

      #region ------ [ Validation: General Settings ] ---------------------------------------- #

        # template_description
        validation {
          condition = (
            # No leading or trailing whitespace
            trimspace(var.packer_image.template_description)
              == var.packer_image.template_description &&

            # Non-empty after trimming
            length(var.packer_image.template_description) > 0 &&

            # Raw value must not exceed 1024 characters
            length(var.packer_image.template_description) <= 1024
          )

          error_message = <<-EOT
            Invalid packer_image.template_description; it must be non-empty,
            no longer than 1024 characters, and must not have leading or
            trailing whitespace.
          EOT
        }

        # template_name
        validation {
          condition = (
            # No leading or trailing whitespace
            trimspace(var.packer_image.template_name)
              == var.packer_image.template_name &&

            # Must match DNS-label style rules
            can(
              regex(
                "^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$",
                var.packer_image.template_name
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.template_name; it must be 1 to 63 characters
            long, contain only letters, digits or '-', must not start or end
            with '-', and must not have leading or trailing whitespace.
          EOT
        }

        # vm_id
        validation {
          condition = (
            var.packer_image.vm_id >= 10000 &&
            var.packer_image.vm_id <= 10999 &&
            var.packer_image.vm_id == floor(var.packer_image.vm_id)
          )

          error_message = <<-EOT
            Invalid packer_image.vm_id; it must be an integer between 10,000 and 10,999 inclusive.
          EOT
        }

        # pool
        validation {
          condition = (
            # No leading or trailing whitespace
            trimspace(var.packer_image.pool) == var.packer_image.pool &&

            # Must satisfy Proxmox-style ID shape
            can(
              regex(
                "^[A-Za-z][A-Za-z0-9_.-]*[A-Za-z0-9]$",
                var.packer_image.pool
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.pool; it must start with a letter, end with a
            letter or digit, contain only letters, digits, '_', '-' or '.', and
            must not have leading or trailing whitespace.
          EOT
        }

        # node
        validation {
          condition = (
            # No leading or trailing whitespace
            trimspace(var.packer_image.node) == var.packer_image.node &&

            # Must satisfy node name character rules
            can(
              regex(
                "^[A-Za-z][A-Za-z0-9_.-]*[A-Za-z0-9]$",
                var.packer_image.node
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.node; it must start with a letter, end with a
            letter or digit, contain only letters, digits, '_', '-' or '.', and
            must not have leading or trailing whitespace.
          EOT
        }

        # vm_name
        validation {
          condition = (
            trimspace(var.packer_image.vm_name)
              == var.packer_image.vm_name &&

            can(
              regex(
                "^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$",
                var.packer_image.vm_name
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.vm_name; it must be a valid DNS label between
            1 and 63 characters, use only lowercase letters, digits or '-', must
            not start or end with '-', and must not have leading or trailing
            whitespace.
          EOT
        }

        # tags
        validation {
          condition = (
            # Require at least one tag
            length(var.packer_image.tags) > 0 &&

            # Each tag must satisfy character, length, and whitespace rules
            alltrue([
              for t in var.packer_image.tags :
              trimspace(t) == t &&
              length(t) > 0 &&
              length(t) <= 63 &&
              can(regex("^[A-Za-z0-9_.+-]+$", t))
            ])
          )

          error_message = <<-EOT
            Invalid packer_image.tags; the list must contain at least one tag
            and each tag must be non-empty, no longer than 63 characters, may
            contain only letters, digits, '_', '-' '+' or '.', and must not
            have leading or trailing whitespace.
          EOT
        }

      #endregion --- [ Validation: General Settings ] ---------------------------------------- #

      #region ------ [ Validation: QEMU Agent ] ---------------------------------------------- #

        # qemu_additional_args
        validation {
          condition = (
            # Allow completely empty value
            length(var.packer_image.qemu_additional_args) == 0 ||

            # Otherwise enforce strict shape
            (
              # No leading or trailing whitespace
              trimspace(var.packer_image.qemu_additional_args)
                == var.packer_image.qemu_additional_args &&

              # Max 512 characters in the raw value
              length(var.packer_image.qemu_additional_args) <= 512 &&

              # Single line, no ';' characters
              can(
                regex(
                  "^[^\\n;]+$",
                  var.packer_image.qemu_additional_args
                )
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.qemu_additional_args; it should normally be
            empty, but if set it must be a single line with no leading or
            trailing whitespace, no ';' characters or newline characters, and
            no longer than 512 characters.
          EOT
        }

      #endregion --- [ Validation: QEMU Agent ] ---------------------------------------------- #

      #region ------ [ Validation: Misc Settings ] ------------------------------------------- #

        # machine
        validation {
          condition = (
            # Must be exactly one of the supported machine types
            contains(
              ["pc", "q35"],
              var.packer_image.machine
            )
          )

          error_message = <<-EOT
            Invalid packer_image.machine; it must be exactly "pc" or "q35".
          EOT
        }

        # os
        validation {
          condition = (
            # No leading or trailing whitespace
            trimspace(var.packer_image.os) == var.packer_image.os &&

            anytrue([
              # Linux -> Linux 2.6+ ostype
              (
                var.packer_image.os_family == "linux" &&
                var.packer_image.os == "l26"
              ),

              # Windows -> one of the known Windows ostype codes
              (
                var.packer_image.os_family == "windows" &&
                contains(
                  [
                    "wxp", "w2k", "w2k3", "w2k8", "wvista",
                    "win7", "win8", "win10", "win11"
                  ],
                  var.packer_image.os
                )
              )
            ])
          )

          error_message = <<-EOT
            Invalid packer_image.os for the selected os_family; for os_family
            "linux" the os must be "l26", and for os_family "windows" the os
            must be one of "wxp", "w2k", "w2k3", "w2k8", "wvista", "win7",
            "win8", "win10" or "win11".
          EOT
        }

        # task_timeout
        validation {
          condition = (
            trimspace(var.packer_image.task_timeout)
              == var.packer_image.task_timeout &&

            # Reasonable upper bound on length
            length(var.packer_image.task_timeout) <= 128 &&

            can(
              regex(
                "^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$",
                var.packer_image.task_timeout
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.task_timeout; it must be a valid Go-style
            duration string such as "30s", "5m", "10m" or "1h30m", with no
            leading or trailing whitespace and no longer than 128 characters.
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
            Invalid packer_image.bios; supported values are "seabios" for legacy BIOS and "ovmf" for UEFI firmware.
          EOT
        }

        # bios
        validation {
          condition = (
            # Must be exactly one of the supported BIOS types
            contains(
              ["seabios", "ovmf"],
              var.packer_image.bios
            )
          )

          error_message = <<-EOT
            Invalid packer_image.bios; it must be exactly "seabios" for legacy
            BIOS or "ovmf" for UEFI firmware.
          EOT
        }


        # boot_key_interval
        validation {
          condition = (
            var.packer_image.boot_key_interval == null
            ? true
            : (
                # No leading or trailing whitespace
                trimspace(var.packer_image.boot_key_interval)
                  == var.packer_image.boot_key_interval &&

                # Reasonable upper bound on length
                length(var.packer_image.boot_key_interval) <= 128 &&

                # Must be a valid Go-style duration (e.g. "250ms", "5s", "1m30s")
                can(
                  regex(
                    "^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$",
                    var.packer_image.boot_key_interval
                  )
                )
              )
          )

          error_message = <<-EOT
            Invalid packer_image.boot_key_interval; it must be null to use the
            builder default or a valid Go-style duration string such as "250ms",
            "5s" or "1m30s", with no leading or trailing whitespace and no
            longer than 128 characters.
          EOT
        }

        # boot_keygroup_interval
        validation {
          condition = (
            var.packer_image.boot_keygroup_interval == null
            ? true
            : (
                # No leading or trailing whitespace
                trimspace(var.packer_image.boot_keygroup_interval)
                  == var.packer_image.boot_keygroup_interval &&

                # Reasonable upper bound on length
                length(var.packer_image.boot_keygroup_interval) <= 10 &&

                # Must be a valid Go-style duration (e.g. "250ms", "5s", "1m30s")
                can(
                  regex(
                    "^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$",
                    var.packer_image.boot_keygroup_interval
                  )
                )
              )
          )

          error_message = <<-EOT
            Invalid packer_image.boot_keygroup_interval; it must be null to use
            the builder default or a valid Go-style duration string such as
            "250ms", "5s" or "1m30s", with no leading or trailing whitespace and
            no longer than 10 characters.
          EOT
        }


        # boot_command
        validation {
          condition = (
            # Require at least one boot command
            length(var.packer_image.boot_command) > 0 &&

            alltrue([
              for cmd in var.packer_image.boot_command :

              # Non-empty
              length(cmd) > 0 &&

              # At most 512 characters
              length(cmd) <= 512 &&

              # No newline or carriage-return characters
              !strcontains(cmd, "\n") &&
              !strcontains(cmd, "\r")
            ])
          )

          error_message = <<-EOT
            Invalid packer_image.boot_command; the list must contain at least
            one entry and each entry must be non-empty, no longer than 512
            characters, must not have leading or trailing whitespace, and must
            not contain newline or carriage-return characters.
          EOT
        }


      #endregion --- [ Validation: VM Configuration: Boot Settings ] ------------------------- #

      #region ------ [ Validation: VM Configuration: Cloud-Init ] ---------------------------- #

        # cloud_init_disk_type
        validation {
          condition = (
            # Allow any value if Cloud-Init is disabled
            var.packer_image.cloud_init == false ||

            # When enabled, enforce strict, canonical values
            (
              # No leading or trailing whitespace
              trimspace(var.packer_image.cloud_init_disk_type)
                == var.packer_image.cloud_init_disk_type &&

              # Non-empty
              length(var.packer_image.cloud_init_disk_type) > 0 &&

              # Must be exactly one of the supported types
              contains(
                ["scsi", "sata", "ide"],
                var.packer_image.cloud_init_disk_type
              )
            )
          )

          error_message = <<-EOT
            Invalid packer_image.cloud_init_disk_type; when cloud_init is true
            it must be exactly "scsi", "sata" or "ide" with no leading or
            trailing whitespace.
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
            Invalid packer_image.cloud_init_storage_pool; when cloud_init is true it must be non-empty, start with a letter, end with a letter or digit, and contain only letters, digits, '_', '-' or '.'.
          EOT
        }


      #endregion --- [ Validation: VM Configuration: Cloud-Init ] ---------------------------- #

      #region ------ [ Validation: Hardware: CPU ] ------------------------------------------- #

        # cores, sockets
        validation {
          condition = (
            # Derive effective values for validation, treating null as 1
            floor(coalesce(var.packer_image.cores, 1)) ==
              coalesce(var.packer_image.cores, 1) &&
            floor(coalesce(var.packer_image.sockets, 1)) ==
              coalesce(var.packer_image.sockets, 1) &&

            # 1) cores check: integer in [1, 96]
            coalesce(var.packer_image.cores, 1) >= 1 &&
            coalesce(var.packer_image.cores, 1) <= 96 &&

            # 2) sockets check: integer in [1, 96]
            coalesce(var.packer_image.sockets, 1) >= 1 &&
            coalesce(var.packer_image.sockets, 1) <= 96 &&

            # 3) combined topology check: cores * sockets <= 96
            (coalesce(var.packer_image.cores, 1) *
             coalesce(var.packer_image.sockets, 1)) <= 96
          )

          error_message = <<-EOT
            Invalid CPU topology in packer_image.cores or packer_image.sockets;
            each value must be an integer between 1 and 96 (null is treated as 1)
            and their product must not exceed 96.
          EOT
        }

        # cpu_type
        validation {
          condition = (
            var.packer_image.cpu_type == null
            ? true
            : (
                # No leading or trailing whitespace
                trimspace(var.packer_image.cpu_type)
                  == var.packer_image.cpu_type &&

                # Must be exactly one of the approved CPU types
                contains(
                  ["host", "x86-64-v2-aes", "kvm64"],
                  var.packer_image.cpu_type
                )
              )
          )

          error_message = <<-EOT
            Invalid packer_image.cpu_type; it must be null to use the default
            or exactly "x86-64-v2-aes", "host" or "kvm64" with no leading or
            trailing whitespace. These correspond to QEMU/Proxmox CPU models
            that are organization-approved safe defaults or starting points; if
            you require a different model, it must be explicitly added to the
            approved list.
          EOT
        }

      #endregion --- [ Validation: Hardware: CPU ] ------------------------------------------- #

      #region ------ [ Validation: Hardware: Memory ] ---------------------------------------- #

        # memory, ballooning_minimum
        validation {
          condition = (
            # Use effective values for validation, treating null as defaults:
            #   memory            -> 2048 MB
            #   ballooning_minimum -> 0 MB
            floor(coalesce(var.packer_image.memory, 2048))
              == coalesce(var.packer_image.memory, 2048) &&
            floor(coalesce(var.packer_image.ballooning_minimum, 0))
              == coalesce(var.packer_image.ballooning_minimum, 0) &&

            # memory: integer MB, between 256 MB and 1,048,576 MB (1 TB)
            coalesce(var.packer_image.memory, 2048) >= 256 &&
            coalesce(var.packer_image.memory, 2048) <= 1048576 &&

            # ballooning_minimum: integer MB, between 0 and effective memory
            coalesce(var.packer_image.ballooning_minimum, 0) >= 0 &&
            coalesce(var.packer_image.ballooning_minimum, 0)
              <= coalesce(var.packer_image.memory, 2048)
          )

          error_message = <<-EOT
            Invalid memory configuration in packer_image.memory or
            packer_image.ballooning_minimum; memory must be an integer between
            256 and 1,048,576 MB (null is treated as 2,048 MB), and
            ballooning_minimum must be an integer between 0 MB and memory (null
            is treated as 0 MB); you can set ballooning_minimum to 0 or null to
            effectively disable ballooning.
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
            var.packer_image.scsi_controller
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
      condition = can(regex("^[a-z0-9]+:[0-9a-fA-F]+$", var.boot_iso.iso_checksum))
      error_message = "Invalid boot_iso.iso_checksum; it must include an algorithm and hex digest (for example 'sha256:abc123...')."
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

#endregion --- [ Packer Image ] -------------------------------------------------------------- #