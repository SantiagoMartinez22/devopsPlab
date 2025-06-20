output "master_public_ip" {
  description = "IP pública del Jenkins Master"
  value       = azurerm_public_ip.master.ip_address
}

output "master_private_ip" {
  description = "IP privada del Jenkins Master"
  value       = azurerm_network_interface.master.private_ip_address
}

output "slave_private_ip" {
  description = "IP privada del Jenkins Slave"
  value       = azurerm_network_interface.slave.private_ip_address
}

output "jenkins_url" {
  description = "URL para acceder al Jenkins Master"
  value       = "http://${azurerm_public_ip.master.ip_address}:8080"
}

output "ssh_private_key" {
  description = "Clave SSH privada generada automáticamente (SENSIBLE)"
  value       = tls_private_key.jenkins_ssh.private_key_pem
  sensitive   = true
}

output "ssh_connection_master" {
  description = "Comando para conectarse al Master (usar la clave privada del output)"
  value       = "ssh -i azure_jenkins_key azureuser@${azurerm_public_ip.master.ip_address}"
}

output "ssh_connection_slave_via_master" {
  description = "Comando para conectarse al Slave vía Master"
  value       = "ssh -i azure_jenkins_key -J azureuser@${azurerm_public_ip.master.ip_address} azureuser@${azurerm_network_interface.slave.private_ip_address}"
}

# Splunk outputs
output "splunk_enterprise_url" {
  description = "URL para acceder a Splunk Enterprise"
  value       = "http://${azurerm_public_ip.master.ip_address}:8000"
}

output "splunk_enterprise_credentials" {
  description = "Credenciales de Splunk Enterprise"
  value       = {
    username = "admin"
    password = "Projectlabdevops"
    url      = "http://${azurerm_public_ip.master.ip_address}:8000"
  }
  sensitive = true
}

output "splunk_forwarder_credentials" {
  description = "Credenciales de Splunk Universal Forwarder"
  value       = {
    username = "admin"
    password = "ProjectlabdevopsUF"
  }
  sensitive = true
}

output "access_information" {
  description = "Información completa de acceso"
  value = {
    jenkins = {
      url = "http://${azurerm_public_ip.master.ip_address}:8080"
      note = "Password inicial en /var/lib/jenkins/secrets/initialAdminPassword"
    }
    splunk_enterprise = {
      url = "http://${azurerm_public_ip.master.ip_address}:8000"
      username = "admin"
      password = "Projectlabdevops"
    }
    ssh = {
      master = "ssh -i azure_jenkins_key azureuser@${azurerm_public_ip.master.ip_address}"
      slave_via_master = "ssh -i azure_jenkins_key -J azureuser@${azurerm_public_ip.master.ip_address} azureuser@${azurerm_network_interface.slave.private_ip_address}"
    }
  }
} 