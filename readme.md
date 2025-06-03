# 🚀 DevOps Todo List Application

<div align="center">

![Python](https://img.shields.io/badge/python-v3.8+-blue.svg)
![Flask](https://img.shields.io/badge/flask-v2.3+-green.svg)
![Terraform](https://img.shields.io/badge/terraform-v1.6+-623CE4.svg?logo=terraform&logoColor=white)
![Jenkins](https://img.shields.io/badge/jenkins-v2.426+-D24939.svg?logo=jenkins&logoColor=white)
![Ansible](https://img.shields.io/badge/ansible-v2.15+-EE0000.svg?logo=ansible&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/postgres-v15+-336791.svg?logo=postgresql&logoColor=white)
![AWS](https://img.shields.io/badge/aws-deployed-FF9900.svg?logo=amazon-aws&logoColor=white)


*Una aplicación Flask para gestión de tareas con infraestructura automatizada en AWS*

[Instalación](#-instalación-rápida) • [Desarrollo](#-desarrollo-local) • [Despliegue](#-despliegue) • [Contribuir](#-contribuir)

</div>

---

## 📋 Tabla de Contenidos

- [🎯 Características](#-características)
- [🏗️ Arquitectura](#️-arquitectura)
- [🚀 Instalación Rápida](#-instalación-rápida)
- [🛠️ Desarrollo Local](#️-desarrollo-local)
- [📦 Despliegue](#-despliegue)
- [🔄 CI/CD Pipeline](#-cicd-pipeline)
- [🤝 Contribuir](#-contribuir)

---

## 🎯 Características

### 💻 Aplicación Web
- ✅ **Gestión de Tareas**: Crear, editar, eliminar y marcar tareas como completadas
- 🔐 **Autenticación**: Sistema de registro y login de usuarios
- 📱 **Interfaz Responsive**: Diseño adaptativo para dispositivos móviles
- 💾 **Base de Datos**: Persistencia con PostgreSQL en AWS RDS

### 🚀 DevOps & Infraestructura
- 🤖 **Automatización**: Despliegue automatizado con Ansible
- 🏗️ **Infrastructure as Code**: Terraform para gestión de infraestructura AWS
- 🔄 **CI/CD Pipeline**: Jenkins con despliegue automático
- ☁️ **AWS Cloud**: EC2 + RDS para producción

---

## 🏗️ Arquitectura

La aplicación se despliega en AWS usando una arquitectura simple y eficiente:

- **EC2 Instance (t2.micro)**: Servidor de aplicación con Flask + Nginx
- **RDS PostgreSQL (db.t3.micro)**: Base de datos gestionada
- **Security Groups**: Configuración de firewall para EC2 y RDS
- **VPC Default**: Usando la VPC por defecto de AWS

### 📁 Estructura del Proyecto

```
devops-todolist/
├── 🐍 todor/                    # Aplicación Flask principal
│   ├── __init__.py             # Configuración de la aplicación
│   ├── config.py               # Configuraciones por entorno
│   ├── models.py               # Modelos SQLAlchemy
│   ├── auth.py                 # Autenticación de usuarios
│   ├── todo.py                 # Gestión de tareas
│   └── templates/              # Plantillas HTML
├── 🤖 ansible/                 # Automatización de despliegue
│   ├── deploy.yml             # Playbook principal
│   ├── ansible.cfg            # Configuración
│   ├── hosts                  # Inventario de servidores
│   └── templates/             # Configuraciones Nginx/Systemd
├── 🏗️ infrastructure/terraform/ # Infrastructure as Code
│   ├── main.tf                # Recursos AWS principales
│   ├── variables.tf           # Variables de configuración
│   ├── outputs.tf             # Outputs de Terraform
│   └── terraform.tfvars       # Valores de variables
├── 🧪 tests/                   # Tests básicos
│   └── test.py                # Tests de la aplicación
├── 🔄 Jenkinsfile             # Pipeline CI/CD
├── 📋 requirements.txt         # Dependencias Python
├── 🚀 run.py                  # Punto de entrada
└── 📖 README.md               # Este archivo
```

---

## 🚀 Instalación Rápida

### Prerrequisitos

```bash
# Verificar herramientas
python --version  # Python 3.8+
git --version
```

### 🎯 Setup Local

```bash
# 1️⃣ Clonar repositorio
git clone https://github.com/SantiagoMartinez22/devops-todolist.git
cd devops-todolist

# 2️⃣ Configurar entorno virtual
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 3️⃣ Instalar dependencias
pip install -r requirements.txt

# 4️⃣ Ejecutar aplicación
python run.py
```

🎉 **¡Listo!** Visita http://localhost:5000

---

## 🛠️ Desarrollo Local

### Variables de Entorno

Crear archivo `.env` en la raíz:

```bash
# Configuración Flask
FLASK_ENV=development
FLASK_DEBUG=1
FLASK_HOST=127.0.0.1
FLASK_PORT=5000

# Base de datos local
DATABASE_URL=url db
SECRET_KEY=tu-clave-secreta-para-desarrollo
```

### Comandos Útiles

```bash
# Modo desarrollo
export FLASK_ENV=development
python run.py

# Ejecutar test básico
python -m pytest tests/test.py -v
```

---

## 📦 Despliegue

### 🤖 Despliegue Automatizado con Ansible

```bash
# 1️⃣ Instalar Ansible
pip install -r requirements-ansible.txt

# 2️⃣ Configurar inventario
cp ansible/hosts.example ansible/hosts
# Editar ansible/hosts con la IP de tu servidor

# 3️⃣ Ejecutar despliegue
cd ansible
ansible-playbook -i hosts deploy.yml
```

### ☁️ Infraestructura AWS con Terraform

```bash
# 1️⃣ Configurar credenciales AWS
export AWS_ACCESS_KEY_ID=tu-access-key
export AWS_SECRET_ACCESS_KEY=tu-secret-key

# 2️⃣ Desplegar infraestructura
cd infrastructure/terraform
terraform init
terraform plan -var="db_password=tu-password-seguro"
terraform apply -var="db_password=tu-password-seguro"

# 3️⃣ Obtener IP del servidor
terraform output
```

### 📋 Requisitos para Despliegue

- **AWS Account** con permisos para EC2 y RDS
- **Key Pair** configurado en AWS para acceso SSH
- **Variables de entorno** configuradas para el pipeline

---

## 🔄 CI/CD Pipeline

El pipeline de Jenkins automatiza todo el proceso de despliegue:

1. **📥 Checkout**: Descarga el código del repositorio
2. **🔧 Install Tools**: Instala Terraform y Ansible
3. **🏗️ Deploy Infrastructure**: Crea recursos AWS con Terraform
4. **🚀 Deploy Application**: Despliega la app con Ansible
5. **✅ Verify**: Verifica que la aplicación esté funcionando

### Variables de Jenkins Requeridas

```bash
# Credenciales AWS
AWS_ACCESS_KEY_ID=tu-access-key
AWS_SECRET_ACCESS_KEY=tu-secret-key

# Base de datos
DB_PASSWORD=password-seguro-para-rds

# Repositorio
GITHUB_REPO= url repositorio

# SSH para acceso al servidor
SSH_PRIVATE_KEY=clave-privada-ssh
```

### Triggers del Pipeline

- ✅ **Push a main**: Despliegue automático
- ✅ **Manual**: Opción para destruir y recrear infraestructura

---

## 🤝 Contribuir

### Flujo de Trabajo

1. **Fork** el repositorio
2. **Crear rama**: `git checkout -b feature/nueva-funcionalidad`
3. **Desarrollar** y probar localmente
4. **Commit**: `git commit -m "DEVOPS-123: Descripción"`
5. **Push**: `git push origin feature/nueva-funcionalidad`
6. **Pull Request** con descripción

### Convenciones de Commits

```
DEVOPS-[número]: [tipo] Descripción breve



---


### 🛠️ Mejoras Técnicas

- [ ] 🐳 **Docker** containerización
- [ ] 📊 **CloudWatch** monitoring
- [ ] 🔍 **Logging** centralizado
- [ ] 🔒 **HTTPS** con certificados SSL
- [ ] ⚡ **Auto Scaling** para alta demanda

---

<div align="center">

**⭐ Si este proyecto te resulta útil, ¡dale una estrella! ⭐**

*Desarrollado con dedicacion y esfuerzo para aprender el uso de herramientas DevOps en el project lab de Softserve*

</div> 