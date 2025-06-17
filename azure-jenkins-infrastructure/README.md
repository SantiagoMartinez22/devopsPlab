# Jenkins Master-Slave en Azure (Claves SSH Automáticas)

Automatización **ultra-simplificada** para desplegar Jenkins Master-Slave en Azure con **claves SSH generadas automáticamente**.

🔑 **SIN MANEJO MANUAL DE SSH** - Terraform genera las claves automáticamente

## 🏗️ Arquitectura

- **Master**: VM con IP pública, Jenkins Master con JDK 17
- **Slave**: VM con IP privada, Jenkins Agent con JDK 17
- **Costo optimizado**: Recursos mínimos para suscripción de estudiante
- **SSH Automático**: Claves generadas por Terraform (como AWS Key Pairs)

## 📋 Prerequisitos

1. **Azure Service Principal** configurado
2. **Jenkins local** corriendo en Docker
3. **Azure CLI** instalado

⚠️ **NO necesitas generar claves SSH manualmente** - Terraform las crea automáticamente

## ⚙️ Configuración en Jenkins

### 1. Configurar Credenciales de Azure

Ve a **Manage Jenkins > Manage Credentials** y agrega **SECRET TEXT** para cada uno:

- `AZURE_CLIENT_ID`: appId del Service Principal
- `AZURE_CLIENT_SECRET`: password del Service Principal
- `AZURE_SUBSCRIPTION_ID`: Tu subscription ID de Azure
- `AZURE_TENANT_ID`: tenant del Service Principal

**Solo 4 credenciales de Azure - No SSH keys!**

### 2. Configurar Service Principal de Azure

```bash
# Obtener tu Subscription ID
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

# Crear Service Principal
az ad sp create-for-rbac \
  --name "jenkins-terraform-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/$SUBSCRIPTION_ID"
```

## 🚀 Uso

### 1. Crear Pipeline en Jenkins

1. **New Item > Pipeline**
2. **Pipeline script from SCM**
3. **Repository URL**: Tu repositorio
4. **Script Path**: `azure-jenkins-infrastructure/Jenkinsfile-azure`

### 2. Ejecutar Pipeline

El pipeline tiene tres parámetros:
- `DESTROY_INFRASTRUCTURE`: false (por defecto)
- `SKIP_ANSIBLE`: false (por defecto)  
- `AUTO_CLEANUP_ON_FAILURE`: true (por defecto)

### 3. Fases del Pipeline

1. **Setup Terraform**: Instala Terraform si no existe
2. **Deploy Infrastructure**: Crea VMs y genera claves SSH automáticamente
3. **Wait for VMs**: Espera a que las VMs estén disponibles
4. **Configure Ansible**: Actualiza inventario con IPs reales
5. **Install Jenkins**: Instala Jenkins Master-Slave con Ansible
6. **Display Results**: Muestra información de acceso con clave SSH
7. **Cleanup**: Elimina archivos temporales

## 🔑 Ventajas de las Claves SSH Automáticas

- ✅ **Cero configuración manual** de SSH
- ✅ **Gratuito** para cuentas de estudiante
- ✅ **Claves únicas** por despliegue
- ✅ **Seguro** - claves se generan en Azure
- ✅ **Compatible** con cualquier suscripción
- ✅ **Funciona igual** que AWS Key Pairs

## 📊 Recursos Creados

### Azure (Terraform)
- 1 Resource Group: `jenkins-rg`
- 1 Virtual Network: `jenkins-vnet`
- 1 Subnet: `default`
- 1 Network Security Group: `jenkins-nsg`
- 2 VMs Standard_B2s: `jenkins-master`, `jenkins-slave`
- 1 IP Pública (solo Master)
- **Claves SSH generadas automáticamente**

### Software (Ansible)
- Ubuntu 22.04 LTS
- OpenJDK 17
- Jenkins LTS (Master)
- Git y herramientas básicas (Slave)

## 🔐 Acceso Post-Instalación

Después de ejecutar el pipeline exitosamente:

### 1. Obtener información de acceso

**Al final del pipeline verás:**
```
🎉 ¡Despliegue completado exitosamente!

📊 Información de acceso:
- Jenkins URL: http://XX.XX.XX.XX:8080
- Master IP: XX.XX.XX.XX
- Slave IP: 10.0.1.X

🔐 Para acceder por SSH:
1. La clave SSH se generó automáticamente y está en: azure_jenkins_key
2. SSH al Master: ssh -i azure_jenkins_key azureuser@XX.XX.XX.XX
```

### 2. Usar la clave SSH generada

```bash
# La clave se guardó automáticamente en el workspace de Jenkins
# Copiarla a tu máquina local si necesitas acceso directo
scp jenkins@jenkins-local:/path/to/workspace/azure_jenkins_key ./

# Usar para SSH
ssh -i azure_jenkins_key azureuser@MASTER_IP

# Obtener password inicial de Jenkins
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 3. Configurar Jenkins Web

1. Ve a `http://MASTER_IP:8080`
2. Usa el password inicial obtenido
3. Instala plugins sugeridos
4. Crea usuario admin

### 4. Conectar Slave a Master

En Jenkins Web UI:
1. **Manage Jenkins** → **Manage Nodes**
2. **New Node** → `azure-slave`
3. **Remote root directory:** `/home/jenkins`
4. **Launch method:** SSH
5. **Host:** `SLAVE_PRIVATE_IP`
6. **Credentials:** Usar la misma clave SSH (`azure_jenkins_key`)

## 💰 Costos Estimados (Suscripción Estudiante)

- **2x Standard_B2s VMs**: ~$60-80 USD/mes
- **1x IP Pública**: ~$3 USD/mes
- **Storage (Standard_LRS)**: ~$5 USD/mes
- **Claves SSH**: $0 (generadas gratis por Terraform)
- **Total estimado**: ~$70-90 USD/mes

## 🔧 Troubleshooting

### Error: "Credentials not found"
```bash
# Verificar en Jenkins que los IDs coincidan exactamente:
AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID
```

### Error: "Permission denied"
```bash
# Verificar permisos del Service Principal
az role assignment list --assignee YOUR_CLIENT_ID
```

### Error: "SSH Connection Failed"
```bash
# La clave SSH se genera automáticamente
# Verificar que el archivo azure_jenkins_key existe en el workspace
# Verificar permisos: chmod 600 azure_jenkins_key
```

## 🗑️ Limpieza

Para destruir toda la infraestructura:

1. Ejecuta el pipeline con `DESTROY_INFRASTRUCTURE = true`

O manualmente:
```bash
cd azure-jenkins-infrastructure/terraform
terraform destroy -auto-approve
```

## 📁 Estructura del Proyecto

```
azure-jenkins-infrastructure/
├── .gitignore               # Protege archivos sensibles
├── terraform/
│   ├── main.tf              # Configuración principal + SSH automático
│   ├── variables.tf         # Sin variables (todo automático)
│   ├── outputs.tf           # IPs + clave SSH generada
│   └── terraform.tfvars     # Configuración automática
├── ansible/
│   ├── ansible.cfg          # Configuración simplificada
│   ├── inventory/hosts      # Usa clave SSH automática
│   └── playbooks/install-jenkins.yml  # Instalación Jenkins
├── Jenkinsfile-azure        # Pipeline simplificado
├── README.md               # Esta documentación
└── GUIA-PREREQUISITOS.md   # Guía paso a paso actualizada
```

## 🛡️ Características de Seguridad

- ✅ **Claves SSH únicas** por despliegue
- ✅ **Generación automática** por Terraform
- ✅ **Sin claves hardcodeadas** en código
- ✅ **Limpieza automática** de archivos temporales
- ✅ **Solo credenciales Azure** requeridas


## 🤝 Soporte

**Si algo falla:**
1. Revisar logs completos del pipeline
2. Verificar credenciales Azure en Jenkins
3. Ejecutar con `DESTROY_INFRASTRUCTURE=true` para limpiar
4. Crear issue en GitHub con logs (sin credenciales)

⚠️ **NUNCA incluyas credenciales en los issues de GitHub**

---

