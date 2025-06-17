# 📋 Guía de Prerequisitos - Jenkins en Azure (SSH Automático)

Esta guía paso a paso te ayudará a configurar todo lo necesario para desplegar Jenkins Master-Slave en Azure con **claves SSH generadas automáticamente**.

🔑 **¡NUEVO!** Sin configuración manual de SSH - Terraform maneja todo automáticamente

## 📚 Índice

1. [Azure Service Principal](#1-azure-service-principal)
2. [Jenkins Local](#2-jenkins-local)  
3. [Credenciales en Jenkins](#3-credenciales-en-jenkins)
4. [Verificación Final](#4-verificación-final)
5. [Primer Despliegue](#5-primer-despliegue)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Azure Service Principal

### 1.1 Instalar Azure CLI

**Windows:**
```powershell
winget install -e --id Microsoft.AzureCLI
```

**macOS:**
```bash
brew install azure-cli
```

**Linux (Ubuntu/Debian):**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### 1.2 Login a Azure

```bash
az login
```

Se abrirá una ventana del navegador para autenticarte.

### 1.3 Verificar Suscripción

```bash
# Ver suscripciones disponibles
az account list --output table

# Usar suscripción específica (si tienes múltiples)
az account set --subscription "TU_SUBSCRIPTION_ID"

# Verificar suscripción activa
az account show
```

### 1.4 Crear Service Principal

```bash
# Obtener tu Subscription ID
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Tu Subscription ID: $SUBSCRIPTION_ID"

# Crear Service Principal con rol Contributor
az ad sp create-for-rbac \
  --name "jenkins-terraform-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/$SUBSCRIPTION_ID"
```

**Salida esperada:**
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "jenkins-terraform-sp",
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### 1.5 Guardar Credenciales

**Anota estos valores - los necesitarás en Jenkins:**

- `appId` → **AZURE_CLIENT_ID**
- `password` → **AZURE_CLIENT_SECRET**
- `tenant` → **AZURE_TENANT_ID**
- `SUBSCRIPTION_ID` → **AZURE_SUBSCRIPTION_ID**

---

## 2. Jenkins Local

### 2.1 Instalar Docker

**Windows (con WSL2):**
1. Instalar [Docker Desktop](https://docs.docker.com/desktop/windows/install/)
2. Asegurar que usa WSL2 backend

**macOS:**
1. Instalar [Docker Desktop](https://docs.docker.com/desktop/mac/install/)

**Linux:**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 2.2 Ejecutar Jenkins

```bash
# Crear directorio para persistencia
mkdir -p ~/jenkins_home

# Ejecutar Jenkins (cambiar el puerto si 8080 está ocupado)
docker run -d \
  --name jenkins-local \
  -p 8080:8080 \
  -p 50000:50000 \
  -v ~/jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --restart=unless-stopped \
  jenkins/jenkins:lts
```

### 2.3 Obtener Password Inicial

```bash
# Esperar ~2 minutos para que Jenkins inicie
docker logs jenkins-local

# O directamente obtener el password
docker exec jenkins-local cat /var/jenkins_home/secrets/initialAdminPassword
```

### 2.4 Configurar Jenkins

1. Ve a `http://localhost:8080`
2. Ingresa el password inicial
3. Instalar **plugins sugeridos**
4. Crear usuario administrador
5. Usar URL por defecto (`http://localhost:8080`)

---

## 3. Credenciales en Jenkins

### 3.1 Acceder a Credenciales

1. **Dashboard** → **Manage Jenkins** → **Manage Credentials**
2. **Stores scoped to Jenkins** → **System** → **Global credentials**
3. **Add Credentials**

### 3.2 Agregar Credenciales Azure

**Solo necesitas 4 credenciales (no SSH):**

#### Credencial 1: AZURE_CLIENT_ID
- **Kind**: Secret text
- **Secret**: `appId` del Service Principal
- **ID**: `AZURE_CLIENT_ID`
- **Description**: Azure Client ID para Terraform

#### Credencial 2: AZURE_CLIENT_SECRET
- **Kind**: Secret text  
- **Secret**: `password` del Service Principal
- **ID**: `AZURE_CLIENT_SECRET`
- **Description**: Azure Client Secret para Terraform

#### Credencial 3: AZURE_SUBSCRIPTION_ID
- **Kind**: Secret text
- **Secret**: Tu Subscription ID de Azure
- **ID**: `AZURE_SUBSCRIPTION_ID`
- **Description**: Azure Subscription ID

#### Credencial 4: AZURE_TENANT_ID
- **Kind**: Secret text
- **Secret**: `tenant` del Service Principal  
- **ID**: `AZURE_TENANT_ID`
- **Description**: Azure Tenant ID

### 3.3 Verificar Credenciales

Deberías tener exactamente **4 credenciales** configuradas:
- ✅ AZURE_CLIENT_ID
- ✅ AZURE_CLIENT_SECRET  
- ✅ AZURE_SUBSCRIPTION_ID
- ✅ AZURE_TENANT_ID

**NO necesitas configurar SSH_PRIVATE_KEY** - Terraform genera las claves automáticamente

---

## 4. Verificación Final

### 4.1 Verificar Service Principal

```bash
# Probar autenticación con Service Principal
az login --service-principal \
  --username YOUR_CLIENT_ID \
  --password YOUR_CLIENT_SECRET \
  --tenant YOUR_TENANT_ID

# Verificar permisos
az role assignment list --assignee YOUR_CLIENT_ID
```

### 4.2 Verificar Jenkins

1. Jenkins accesible en `http://localhost:8080`
2. Las 4 credenciales Azure configuradas
3. Usuario administrador creado

### 4.3 Verificar Directorio

```bash
ls -la azure-jenkins-infrastructure/
```

**Deberías ver:**
```
├── terraform/
│   ├── main.tf
│   ├── variables.tf  
│   ├── outputs.tf
│   └── terraform.tfvars
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/hosts
│   └── playbooks/install-jenkins.yml
├── Jenkinsfile-azure
├── README.md
└── GUIA-PREREQUISITOS.md
```

---

## 5. Primer Despliegue

### 5.1 Crear Pipeline en Jenkins

1. **New Item** → Escribe nombre (ej: `azure-jenkins-deploy`)
2. Selecciona **Pipeline**
3. **OK**

### 5.2 Configurar Pipeline

En la configuración del Pipeline:

1. **Pipeline Definition**: Pipeline script from SCM
2. **SCM**: Git
3. **Repository URL**: URL de tu repositorio
4. **Credentials**: Si es repositorio privado, agregar credenciales Git
5. **Branch**: `*/main` (o la rama que uses)
6. **Script Path**: `azure-jenkins-infrastructure/Jenkinsfile-azure`
7. **Save**

### 5.3 Ejecutar Primera Vez

1. **Build with Parameters**
2. Dejar parámetros por defecto:
   - `DESTROY_INFRASTRUCTURE`: ❌ false
   - `SKIP_ANSIBLE`: ❌ false
   - `AUTO_CLEANUP_ON_FAILURE`: ✅ true
3. **Build**

### 5.4 Monitorear Ejecución

La primera ejecución tomará ~10-15 minutos:

1. **Setup Terraform** (~2 min)
2. **Deploy Infrastructure** (~5 min) 
3. **Wait for VMs** (~2 min)
4. **Configure Ansible** (~1 min)
5. **Install Jenkins** (~5 min)
6. **Display Results** (~1 min)

---

## 6. Troubleshooting

### 6.1 Error: "Could not find credentials"

**Problema:** IDs de credenciales no coinciden

**Solución:**
```bash
# Verificar que los IDs en Jenkins sean exactamente:
AZURE_CLIENT_ID
AZURE_CLIENT_SECRET
AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID
```

### 6.2 Error: "Insufficient privileges"

**Problema:** Service Principal sin permisos

**Solución:**
```bash
# Verificar role assignment
az role assignment list --assignee YOUR_CLIENT_ID

# Si no tiene Contributor, agregarlo:
az role assignment create \
  --assignee YOUR_CLIENT_ID \
  --role "Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"
```

### 6.3 Error: "Quota exceeded"

**Problema:** Límites de suscripción de estudiante

**Solución:**
```bash
# Verificar uso actual
az vm list-usage --location "East US" --output table

# Si superaste límites, destruir recursos existentes:
# Ejecutar pipeline con DESTROY_INFRASTRUCTURE=true
```

### 6.4 Error: "SSH connection failed"

**Problema:** VMs no están listas

**Solución:**
- Las claves SSH se generan automáticamente
- Esperar más tiempo en el stage "Wait for VMs"
- El pipeline reintenta automáticamente

### 6.5 Error: "Terraform binary not found"

**Problema:** Terraform no se instaló correctamente

**Solución:**
```bash
# Instalar Terraform manualmente en Jenkins
docker exec -it jenkins-local bash
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
mv terraform /usr/local/bin/
```

### 6.6 Pipeline Falla Constantemente

**Reset completo:**

1. Ejecutar pipeline con `DESTROY_INFRASTRUCTURE=true`
2. Verificar que no queden recursos en Azure:
   ```bash
   az resource list --resource-group jenkins-rg --output table
   ```
3. Revisar credenciales en Jenkins
4. Reintentar con parámetros por defecto

---

## 🎯 Resumen de Diferencias Clave

### Antes (SSH Manual)
- ❌ 5 credenciales en Jenkins
- ❌ Generar claves SSH manualmente  
- ❌ Copiar clave pública a Jenkins
- ❌ Configuración compleja

### Ahora (SSH Automático)
- ✅ Solo 4 credenciales en Jenkins
- ✅ Terraform genera claves automáticamente
- ✅ Cero configuración SSH manual
- ✅ Configuración ultra-simple

---

## 🎉 ¡Listo!

Después de seguir esta guía deberías tener:

- ✅ Service Principal de Azure funcional
- ✅ Jenkins local corriendo
- ✅ 4 credenciales Azure configuradas  
- ✅ Pipeline listo para ejecutar
- ✅ SSH completamente automático

**Próximo paso:** Ejecutar tu primer despliegue y disfrutar Jenkins en la nube con claves SSH automáticas.

🚀 **¡Es mucho más fácil que la versión manual!** 