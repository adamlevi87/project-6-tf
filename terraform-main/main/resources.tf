# terraform-main/main/resources.tf

# Generate passwords
resource "random_password" "generated_passwords" {
    for_each = {
        for name, config in var.secrets_config : name => config
        if config.generate_password == true
    }
    
    length  = each.value.password_length
    special = each.value.password_special

    # empty string protection (return the value, if its empty return null)
    # excluding specific characters from password creation (good for some services)
    override_special = each.value.password_override_special != "" ? each.value.password_override_special : null
}
