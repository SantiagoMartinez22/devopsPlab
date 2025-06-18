pipeline {
    agent {
        label 'azure'  // Usa el label que configuraste en el slave
    }
    parameters {
        booleanParam(name: 'DESTROY_INFRASTRUCTURE', defaultValue: false, description: 'Marcar para destruir la infraestructura existente antes del despliegue')
    }

    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        DB_PASSWORD          = credentials('DB_PASSWORD')
        GITHUB_REPO          = credentials('GITHUB_REPO')
        SSH_PRIVATE_KEY_FILE = credentials('SSH_PRIVATE_KEY')
        SSH_PRIVATE_KEY_TEXT = credentials('SSH_PRIVATE_KEY')
        TERRAFORM_VERSION    = '1.6.0'
    }

    stages {
        stage('Install Terraform') {
            steps {
                sh '''
                    # Verificar herramientas disponibles
                    echo "Verificando herramientas disponibles..."
                    which curl || echo "curl no encontrado"
                    which unzip || echo "unzip no encontrado"
                    which python3 || echo "python3 no encontrado"
                    which pip3 || echo "pip3 no encontrado"
                    
                    # Para contenedores Docker, intentar instalar herramientas básicas si es posible
                    if ! command -v unzip &> /dev/null; then
                        echo "unzip no disponible, intentando continuar..."
                    fi
                    
                    # Crear entorno virtual para Ansible (compatible con contenedores)
                    echo "Creando entorno virtual para Ansible..."
                    python3 -m venv /tmp/ansible-venv-${BUILD_NUMBER}
                    . /tmp/ansible-venv-${BUILD_NUMBER}/bin/activate
                    
                    # Instalar Ansible en el entorno virtual
                    echo "Instalando Ansible en entorno virtual..."
                    pip install --upgrade pip
                    pip install ansible>=6.0.0
                    
                    # Verificar instalación de Ansible
                    echo "✅ Ansible instalado correctamente en entorno virtual:"
                    ansible-playbook --version
                    
                    # Crear directorio temporal para Terraform
                    mkdir -p /tmp/terraform-${BUILD_NUMBER}
                    cd /tmp/terraform-${BUILD_NUMBER}
                    
                    # Descargar e instalar Terraform usando curl
                    echo "Descargando Terraform ${TERRAFORM_VERSION}..."
                    curl -fsSL -o terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                    
                    echo "Extrayendo Terraform..."
                    if command -v unzip &> /dev/null; then
                        unzip -o -q terraform.zip
                    else
                        # Alternativa si unzip no está disponible
                        python3 -c "
import zipfile
with zipfile.ZipFile('terraform.zip', 'r') as zip_ref:
    zip_ref.extractall('.')
"
                    fi
                    chmod +x terraform
                    
                    # Verificar instalación
                    echo "Verificando instalación de Terraform:"
                    ./terraform version
                '''
            }
        }

        stage('Destroy Existing Infrastructure') {
            when {
                expression { params.DESTROY_INFRASTRUCTURE == true }
            }
            steps {
                dir('infrastructure/terraform') {
                    sh '''
                        echo "🔥 DESTRUYENDO INFRAESTRUCTURA EXISTENTE..."
                        
                        # Usar Terraform desde la ubicación temporal
                        TERRAFORM_BIN="/tmp/terraform-${BUILD_NUMBER}/terraform"
                        
                        # Inicializar Terraform
                        $TERRAFORM_BIN init
                        
                        # Destruir infraestructura existente
                        echo "Destruyendo recursos existentes..."
                        $TERRAFORM_BIN destroy -auto-approve -var="db_password=${DB_PASSWORD}"
                        
                        echo "✅ Infraestructura destruida exitosamente"
                    '''
                }
            }
        }

        stage('Deploy Infrastructure') {
            steps {
                dir('infrastructure/terraform') {
                    sh '''
                        # Crear directorio para logs personalizados (evitar plugin Splunk)
                        mkdir -p /tmp/aws-pipeline-logs-${BUILD_NUMBER}
                        LOG_DIR="/tmp/aws-pipeline-logs-${BUILD_NUMBER}"
                        
                        echo "📁 Logs se guardarán en: $LOG_DIR"
                        
                        # Configurar logging de Terraform
                        export TF_LOG=DEBUG
                        export TF_LOG_PATH="$LOG_DIR/terraform-deploy.log"
                        
                        # Usar Terraform desde la ubicación temporal
                        TERRAFORM_BIN="/tmp/terraform-${BUILD_NUMBER}/terraform"
                        
                        # Log inicial
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - [TERRAFORM] Iniciando despliegue AWS infraestructura" | tee -a $TF_LOG_PATH
                        
                        # Inicializar Terraform con logging
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - [TERRAFORM] terraform init" | tee -a $TF_LOG_PATH
                        $TERRAFORM_BIN init 2>&1 | tee -a $TF_LOG_PATH
                        
                        # Crear plan con logging
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - [TERRAFORM] terraform plan" | tee -a $TF_LOG_PATH
                        $TERRAFORM_BIN plan -out=tfplan \
                            -var="db_password=${DB_PASSWORD}" 2>&1 | tee -a $TF_LOG_PATH
                        
                        # Aplicar cambios con logging
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - [TERRAFORM] terraform apply" | tee -a $TF_LOG_PATH
                        $TERRAFORM_BIN apply -auto-approve tfplan 2>&1 | tee -a $TF_LOG_PATH
                        
                        # Mostrar outputs con logging
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - [TERRAFORM] terraform output" | tee -a $TF_LOG_PATH
                        $TERRAFORM_BIN output 2>&1 | tee -a $TF_LOG_PATH
                        
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - [TERRAFORM] ✅ Completado" | tee -a $TF_LOG_PATH
                        echo "📊 Log de Terraform guardado en: $TF_LOG_PATH"
                    '''
                }
            }
        }

        stage('Setup SSH and Wait for EC2') {
            steps {
                sh '''
                    echo "Configurando SSH para acceso a EC2..."
                    
                    # Configurar SSH (compatible con contenedores Docker)
                    mkdir -p ~/.ssh
                    chmod 700 ~/.ssh
                    
                    # Detectar y procesar clave SSH (Secret File o Secret Text)
                    echo "Detectando tipo de credencial SSH..."
                    
                    # Verificar si la credencial está configurada como Secret File
                    if [ -f "$SSH_PRIVATE_KEY_FILE" ] && [ -s "$SSH_PRIVATE_KEY_FILE" ]; then
                        echo "✅ Credencial detectada como Secret File"
                        
                        # Verificar que el archivo contiene una clave privada
                        if grep -q "BEGIN.*PRIVATE KEY" "$SSH_PRIVATE_KEY_FILE"; then
                            echo "✅ Archivo de clave SSH tiene formato correcto"
                            echo "Tipo de clave detectado:"
                            head -1 "$SSH_PRIVATE_KEY_FILE"
                            
                            # Copiar el archivo directamente (preserva formato binario)
                            echo "Copiando clave SSH desde Secret File..."
                            cp "$SSH_PRIVATE_KEY_FILE" ~/.ssh/id_rsa
                            SSH_SOURCE="file"
                        else
                            echo "❌ Error: El archivo no contiene una clave privada válida"
                            echo "Contenido del archivo (primeras 5 líneas):"
                            head -5 "$SSH_PRIVATE_KEY_FILE"
                            exit 1
                        fi
                        
                    elif [ ! -z "$SSH_PRIVATE_KEY_TEXT" ]; then
                        echo "✅ Credencial detectada como Secret Text, procesando..."
                        
                        # Verificar que el texto contiene una clave privada
                        if echo "$SSH_PRIVATE_KEY_TEXT" | grep -q "BEGIN.*PRIVATE KEY"; then
                            echo "✅ Texto de clave SSH tiene formato correcto"
                            echo "Tipo de clave detectado:"
                            echo "$SSH_PRIVATE_KEY_TEXT" | head -1
                        else
                            echo "❌ Error: El texto no contiene una clave privada válida"
                            echo "Contenido recibido (primeros 100 caracteres):"
                            echo "$SSH_PRIVATE_KEY_TEXT" | head -c 100
                            exit 1
                        fi
                        
                        # Procesar clave desde texto
                        echo "Procesando clave SSH desde Secret Text..."
                        echo "$SSH_PRIVATE_KEY_TEXT" > ~/.ssh/id_rsa_raw
                        
                        # Limpiar caracteres problemáticos
                        cat ~/.ssh/id_rsa_raw | tr -d '\\r' | sed 's/\\\\n/\\n/g' > ~/.ssh/id_rsa_clean
                        
                        # Verificar si la clave está codificada en base64 o en una línea
                        if ! grep -q "BEGIN.*PRIVATE KEY" ~/.ssh/id_rsa_clean; then
                            echo "Clave parece estar en formato no estándar. Intentando decodificar..."
                            
                            # Intentar decodificar base64
                            if echo "$SSH_PRIVATE_KEY_TEXT" | base64 -d > ~/.ssh/id_rsa_decoded 2>/dev/null && grep -q "BEGIN.*PRIVATE KEY" ~/.ssh/id_rsa_decoded; then
                                echo "Clave decodificada desde base64 exitosamente"
                                cp ~/.ssh/id_rsa_decoded ~/.ssh/id_rsa_clean
                            else
                                # Intentar reformatear desde una línea
                                echo "Intentando reformatear clave de una línea..."
                                echo "$SSH_PRIVATE_KEY_TEXT" | sed 's/-----BEGIN RSA PRIVATE KEY-----/-----BEGIN RSA PRIVATE KEY-----\\n/g' | sed 's/-----END RSA PRIVATE KEY-----/\\n-----END RSA PRIVATE KEY-----/g' | sed 's/-----BEGIN PRIVATE KEY-----/-----BEGIN PRIVATE KEY-----\\n/g' | sed 's/-----END PRIVATE KEY-----/\\n-----END PRIVATE KEY-----/g' | tr ' ' '\\n' | grep -v '^$' > ~/.ssh/id_rsa_clean
                            fi
                        fi
                        
                        # Verificar que la clave procesada tenga el formato correcto
                        if grep -q "BEGIN.*PRIVATE KEY" ~/.ssh/id_rsa_clean && grep -q "END.*PRIVATE KEY" ~/.ssh/id_rsa_clean; then
                            cp ~/.ssh/id_rsa_clean ~/.ssh/id_rsa
                            echo "✅ Clave SSH procesada correctamente desde texto"
                            SSH_SOURCE="text"
                        else
                            echo "❌ Error: La clave SSH no tiene el formato correcto después del procesamiento"
                            echo "Contenido procesado (primeras 5 líneas):"
                            head -5 ~/.ssh/id_rsa_clean
                            exit 1
                        fi
                        
                        # Limpiar archivos temporales del procesamiento de texto
                        rm -f ~/.ssh/id_rsa_raw ~/.ssh/id_rsa_clean ~/.ssh/id_rsa_decoded
                        
                    else
                        echo "❌ Error: No se pudo detectar ninguna credencial SSH válida"
                        echo "SSH_PRIVATE_KEY_FILE: $SSH_PRIVATE_KEY_FILE"
                        echo "SSH_PRIVATE_KEY_TEXT: [$(echo "$SSH_PRIVATE_KEY_TEXT" | wc -c) caracteres]"
                        exit 1
                    fi
                    
                    # Establecer permisos correctos
                    chmod 600 ~/.ssh/id_rsa
                    
                    # Verificar permisos y contenido
                    echo "Verificando archivo de clave final:"
                    ls -la ~/.ssh/id_rsa
                    echo "Estructura de la clave:"
                    head -1 ~/.ssh/id_rsa
                    tail -1 ~/.ssh/id_rsa
                    echo "Número de líneas: $(wc -l < ~/.ssh/id_rsa)"
                    echo "Fuente de la clave: $SSH_SOURCE"
                    
                    # Verificar que ssh-keygen puede leer la clave
                    echo "Verificando compatibilidad con ssh-keygen..."
                    if ssh-keygen -l -f ~/.ssh/id_rsa 2>/dev/null; then
                        echo "✅ ssh-keygen puede leer la clave correctamente"
                        SSH_KEY_VALID=true
                    else
                        echo "⚠️ ssh-keygen no puede leer la clave. Intentando conversión..."
                        SSH_KEY_VALID=false
                        
                        # Crear una copia de respaldo
                        cp ~/.ssh/id_rsa ~/.ssh/id_rsa_backup
                        
                        # Intentar conversión a formato OpenSSH
                        if ssh-keygen -p -m OpenSSH -f ~/.ssh/id_rsa -N "" -P "" 2>/dev/null; then
                            echo "✅ Clave convertida a formato OpenSSH"
                            SSH_KEY_VALID=true
                        else
                            echo "Conversión OpenSSH falló. Intentando formato PEM..."
                            cp ~/.ssh/id_rsa_backup ~/.ssh/id_rsa
                            if ssh-keygen -p -m PEM -f ~/.ssh/id_rsa -N "" -P "" 2>/dev/null; then
                                echo "✅ Clave convertida a formato PEM"
                                SSH_KEY_VALID=true
                            else
                                echo "⚠️ No se pudo convertir la clave, usando formato original"
                                cp ~/.ssh/id_rsa_backup ~/.ssh/id_rsa
                            fi
                        fi
                        
                        # Verificar nuevamente
                        if ssh-keygen -l -f ~/.ssh/id_rsa 2>/dev/null; then
                            echo "✅ Clave ahora es compatible con ssh-keygen"
                            SSH_KEY_VALID=true
                        else
                            echo "⚠️ Clave sigue siendo incompatible, pero continuando..."
                        fi
                    fi
                    
                    # Configurar SSH client para ser menos estricto
                    cat > ~/.ssh/config << SSHEOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    IdentitiesOnly yes
    PubkeyAuthentication yes
    PreferredAuthentications publickey
    ServerAliveInterval 60
    ServerAliveCountMax 3
    PasswordAuthentication no
SSHEOF
                    chmod 600 ~/.ssh/config
                    
                    # Configurar ssh-agent
                    echo "Configurando ssh-agent..."
                    eval $(ssh-agent -s)
                    if ssh-add ~/.ssh/id_rsa 2>/dev/null; then
                        echo "✅ Clave agregada a ssh-agent exitosamente"
                        SSH_AGENT_WORKING=true
                    else
                        echo "⚠️ No se pudo agregar clave a ssh-agent, pero continuando..."
                        SSH_AGENT_WORKING=false
                    fi
                    
                    # Obtener IP de la instancia
                    cd infrastructure/terraform
                    TERRAFORM_BIN="/tmp/terraform-${BUILD_NUMBER}/terraform"
                    EC2_IP=$($TERRAFORM_BIN output -raw ec2_public_ip)
                    echo "EC2 IP obtenida: $EC2_IP"
                    
                    # Agregar host a known_hosts
                    echo "Agregando host a known_hosts..."
                    ssh-keyscan -H $EC2_IP >> ~/.ssh/known_hosts 2>/dev/null || echo "ssh-keyscan falló, continuando..."
                    
                    # MÉTODO PREFERIDO: Conexión directa con clave válida
                    if [ "$SSH_KEY_VALID" = "true" ]; then
                        echo "=== PROBANDO CONEXIÓN DIRECTA CON CLAVE VÁLIDA ==="
                        for i in {1..10}; do
                            echo "Intento $i/10 - Probando conexión SSH directa..."
                            
                            if ssh -o ConnectTimeout=15 -o BatchMode=yes -o PasswordAuthentication=no -o IdentitiesOnly=yes -i ~/.ssh/id_rsa ec2-user@$EC2_IP "echo 'Conexión exitosa con clave directa'" 2>/dev/null; then
                                echo "✅ ¡Conexión exitosa con clave directa!"
                                SSH_METHOD="direct"
                                break
                            fi
                            
                            echo "Intento $i falló, esperando 10 segundos..."
                            sleep 10
                        done
                    fi
                    
                    # MÉTODO ALTERNATIVO: ssh-agent si la clave directa no funcionó
                    if [ "$SSH_METHOD" != "direct" ] && [ "$SSH_AGENT_WORKING" = "true" ]; then
                        echo "=== PROBANDO MÉTODO ssh-agent ==="
                        for i in {1..5}; do
                            echo "Intento $i/5 - Probando conexión SSH con ssh-agent..."
                            
                            if ssh -o ConnectTimeout=15 -o BatchMode=yes -o PasswordAuthentication=no ec2-user@$EC2_IP "echo 'Conexión exitosa con ssh-agent'" 2>/dev/null; then
                                echo "✅ ¡Conexión exitosa con ssh-agent!"
                                SSH_METHOD="agent"
                                break
                            fi
                            
                            echo "Intento $i falló, esperando 5 segundos..."
                            sleep 5
                        done
                    fi
                    
                    # MÉTODO ALTERNATIVO: configuración SSH automática
                    if [ "$SSH_METHOD" != "direct" ] && [ "$SSH_METHOD" != "agent" ]; then
                        echo "=== PROBANDO MÉTODO AUTOMÁTICO ==="
                        for i in {1..5}; do
                            echo "Intento $i/5 - Probando conexión SSH automática..."
                            
                            if ssh -o ConnectTimeout=15 -o BatchMode=yes -o PasswordAuthentication=no ec2-user@$EC2_IP "echo 'Conexión exitosa automática'" 2>/dev/null; then
                                echo "✅ ¡Conexión exitosa automática!"
                                SSH_METHOD="auto"
                                break
                            fi
                            
                            echo "Intento $i falló, esperando 5 segundos..."
                            sleep 5
                        done
                    fi
                    
                    # Verificar que al menos un método funcionó
                    if [ -z "$SSH_METHOD" ]; then
                        echo "❌ Error: No se pudo establecer conexión SSH con ningún método"
                        echo ""
                        echo "=== INFORMACIÓN DE DEBUG COMPLETA ==="
                        echo "- IP: $EC2_IP"
                        echo "- Usuario: ec2-user"
                        echo "- SSH Agent PID: $SSH_AGENT_PID"
                        echo "- SSH Agent Working: $SSH_AGENT_WORKING"
                        echo "- SSH Key Valid: $SSH_KEY_VALID"
                        echo ""
                        echo "=== CREDENCIALES SSH ==="
                        echo "- SSH_PRIVATE_KEY_FILE: $SSH_PRIVATE_KEY_FILE"
                        echo "- Archivo existe: $([ -f "$SSH_PRIVATE_KEY_FILE" ] && echo "Sí" || echo "No")"
                        echo "- SSH_PRIVATE_KEY_TEXT: [$(echo "$SSH_PRIVATE_KEY_TEXT" | wc -c) caracteres]"
                        echo "- Fuente usada: $SSH_SOURCE"
                        echo ""
                        echo "=== ARCHIVO DE CLAVE ==="
                        ls -la ~/.ssh/id_rsa
                        echo "Primeras 3 líneas:"
                        head -3 ~/.ssh/id_rsa
                        echo "Últimas 3 líneas:"
                        tail -3 ~/.ssh/id_rsa
                        echo ""
                        echo "=== VERIFICACIÓN ssh-keygen ==="
                        ssh-keygen -l -f ~/.ssh/id_rsa || echo "ssh-keygen falló"
                        echo ""
                        echo "=== CONFIGURACIÓN SSH ==="
                        cat ~/.ssh/config
                        echo ""
                        echo "=== DEBUG DE CONEXIÓN DETALLADO ==="
                        ssh -vvv -o ConnectTimeout=15 -o BatchMode=yes -i ~/.ssh/id_rsa ec2-user@$EC2_IP "echo test" 2>&1 | head -50 || true
                        exit 1
                    fi
                    
                    # Exportar método SSH exitoso para usar en siguientes etapas
                    echo "SSH_METHOD=$SSH_METHOD" > ~/.ssh/method
                    echo "✅ Método SSH exitoso: $SSH_METHOD"
                    
                    # Limpiar archivos temporales
                    rm -f ~/.ssh/id_rsa_backup
                '''
            }
        }

        stage('Deploy Application') {
            steps {
                sh '''
                    # Obtener información de Terraform
                    cd infrastructure/terraform
                    TERRAFORM_BIN="/tmp/terraform-${BUILD_NUMBER}/terraform"
                    EC2_IP=$($TERRAFORM_BIN output -raw ec2_public_ip)
                    DB_HOST=$($TERRAFORM_BIN output -raw rds_endpoint)
                    
                    echo "Desplegando aplicación en: $EC2_IP"
                    echo "Base de datos en: $DB_HOST"
                    
                    # Activar entorno virtual de Ansible
                    echo "Activando entorno virtual de Ansible..."
                    . /tmp/ansible-venv-${BUILD_NUMBER}/bin/activate
                    
                    # Verificar que Ansible está disponible
                    echo "✅ Ansible disponible en entorno virtual:"
                    ansible-playbook --version
                    
                    # Preparar inventario dinámico
                    cd ../../ansible
                    echo "[webservers]" > hosts
                    echo "$EC2_IP ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/id_rsa" >> hosts
                    
                    echo "Inventario creado:"
                    cat hosts
                    
                    # Crear directorio de logs para Ansible (mismo que Terraform)
                    LOG_DIR="/tmp/aws-pipeline-logs-${BUILD_NUMBER}"
                    mkdir -p $LOG_DIR
                    ANSIBLE_LOG="$LOG_DIR/ansible-deploy.log"
                    
                    # Exportar variables de entorno para Ansible
                    export GITHUB_REPO="$GITHUB_REPO"
                    export DB_PASSWORD="$DB_PASSWORD"
                    export DB_HOST="$DB_HOST"
                    
                    # Log inicial de Ansible
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ANSIBLE] Iniciando despliegue aplicación AWS" | tee -a $ANSIBLE_LOG
                    
                    # Ejecutar playbook de Ansible con logging detallado
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ANSIBLE] Ejecutando playbook deploy.yml" | tee -a $ANSIBLE_LOG
                    ansible-playbook -i hosts deploy.yml -vvv 2>&1 | tee -a $ANSIBLE_LOG
                    
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ANSIBLE] ✅ Completado" | tee -a $ANSIBLE_LOG
                    echo "📊 Log de Ansible guardado en: $ANSIBLE_LOG"
                '''
            }
        }

        stage('Save Pipeline Logs') {
            steps {
                sh '''
                    echo "📁 Guardando logs del pipeline AWS..."
                    
                    # Directorio temporal de logs
                    LOG_DIR="/tmp/aws-pipeline-logs-${BUILD_NUMBER}"
                    
                    # Directorio permanente para logs (usar directorio temporal para evitar problemas de permisos)
                    PERMANENT_LOG_DIR="/tmp/jenkins-pipeline-logs"
                    
                    # Crear directorio con manejo de errores
                    if mkdir -p "$PERMANENT_LOG_DIR" 2>/dev/null; then
                        echo "✅ Directorio de logs creado: $PERMANENT_LOG_DIR"
                    else
                        echo "⚠️ No se pudo crear directorio permanente, usando temporal"
                        PERMANENT_LOG_DIR="/tmp/pipeline-logs-backup-${BUILD_NUMBER}"
                        mkdir -p "$PERMANENT_LOG_DIR"
                    fi
                    
                    if [ -d "$LOG_DIR" ]; then
                        # Crear log consolidado
                        CONSOLIDATED_LOG="$PERMANENT_LOG_DIR/aws-pipeline-${BUILD_NUMBER}-$(date +%Y%m%d-%H%M%S).log"
                        
                        echo "=== PIPELINE AWS BUILD ${BUILD_NUMBER} ===" > "$CONSOLIDATED_LOG" 2>/dev/null || {
                            echo "⚠️ Error escribiendo archivo consolidado, mostrando logs en consola"
                            echo "=== PIPELINE AWS BUILD ${BUILD_NUMBER} ==="
                            echo "Fecha: $(date)"
                            echo "Usuario: ${BUILD_USER:-Jenkins}"
                            echo ""
                            
                            # Mostrar logs directamente en consola si no se puede escribir archivo
                            if [ -f "$LOG_DIR/terraform-deploy.log" ]; then
                                echo "=== TERRAFORM LOGS ==="
                                tail -20 "$LOG_DIR/terraform-deploy.log"
                                echo ""
                            fi
                            
                            if [ -f "$LOG_DIR/ansible-deploy.log" ]; then
                                echo "=== ANSIBLE LOGS ==="
                                tail -20 "$LOG_DIR/ansible-deploy.log"
                                echo ""
                            fi
                            
                            echo "✅ Logs mostrados en consola debido a problemas de permisos"
                            exit 0
                        }
                        
                        echo "Fecha: $(date)" >> "$CONSOLIDATED_LOG"
                        echo "Usuario: ${BUILD_USER:-Jenkins}" >> "$CONSOLIDATED_LOG"
                        echo "" >> "$CONSOLIDATED_LOG"
                        
                        # Agregar logs de Terraform si existen
                        if [ -f "$LOG_DIR/terraform-deploy.log" ]; then
                            echo "=== TERRAFORM LOGS ===" >> "$CONSOLIDATED_LOG"
                            cat "$LOG_DIR/terraform-deploy.log" >> "$CONSOLIDATED_LOG"
                            echo "" >> "$CONSOLIDATED_LOG"
                        fi
                        
                        # Agregar logs de Ansible si existen
                        if [ -f "$LOG_DIR/ansible-deploy.log" ]; then
                            echo "=== ANSIBLE LOGS ===" >> "$CONSOLIDATED_LOG"
                            cat "$LOG_DIR/ansible-deploy.log" >> "$CONSOLIDATED_LOG"
                            echo "" >> "$CONSOLIDATED_LOG"
                        fi
                        
                        # Copiar logs individuales también
                        cp -r "$LOG_DIR"/* "$PERMANENT_LOG_DIR/" 2>/dev/null || echo "⚠️ No se pudieron copiar logs individuales"
                        
                        echo "✅ Logs guardados en:"
                        echo "   📄 Consolidado: $CONSOLIDATED_LOG"
                        echo "   📁 Individuales: $PERMANENT_LOG_DIR"
                        echo "   📊 Total archivos: $(ls -1 "$PERMANENT_LOG_DIR" 2>/dev/null | wc -l)"
                        
                        # Mostrar últimas líneas de cada log
                        echo ""
                        echo "📋 Resumen de logs:"
                        for logfile in "$LOG_DIR"/*.log; do
                            if [ -f "$logfile" ]; then
                                echo "   $(basename "$logfile"): $(wc -l < "$logfile") líneas"
                            fi
                        done
                    else
                        echo "⚠️ No se encontraron logs temporales en $LOG_DIR"
                    fi
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "Iniciando verificación del despliegue..."
                    
                    # Obtener IP de la instancia
                    cd infrastructure/terraform
                    TERRAFORM_BIN="/tmp/terraform-${BUILD_NUMBER}/terraform"
                    EC2_IP=$($TERRAFORM_BIN output -raw ec2_public_ip)
                    echo "Verificando aplicación en IP: $EC2_IP"
                    
                    # Esperar a que la aplicación esté lista
                    echo "Esperando a que la aplicación responda en puerto 80..."
                    sleep 30
                    
                    # Verificar que la aplicación responde
                    echo "Probando conectividad HTTP..."
                    for i in {1..10}; do
                        echo "Intento $i/10 - Verificando http://$EC2_IP/"
                        
                        # Usar curl con timeouts apropiados para contenedores
                        if curl -f -s --connect-timeout 10 --max-time 30 http://$EC2_IP/ > /dev/null 2>&1; then
                            echo "¡Aplicación responde correctamente!"
                            echo "URL: http://$EC2_IP/"
                            echo "Obteniendo contenido de la página:"
                            curl -s --connect-timeout 10 --max-time 30 http://$EC2_IP/ | head -20 || echo "Error al obtener contenido"
                            echo "¡Despliegue verificado exitosamente!"
                            
                            # Guardar la IP para el mensaje de éxito
                            echo "$EC2_IP" > /tmp/ec2_ip.txt
                            exit 0
                        fi
                        
                        echo "Aplicación no responde todavía. Esperando 10 segundos..."
                        sleep 10
                    done
                    
                    echo "❌ Error: La aplicación no responde después de varios intentos"
                    echo "Obteniendo información de diagnóstico..."
                    
                    # Verificar conectividad básica
                    echo "=== Verificando conectividad básica ==="
                    ping -c 3 $EC2_IP || echo "Ping falló"
                    
                    # Verificar logs y servicios remotamente
                    echo "=== Verificando servicios en la instancia ==="
                    
                    # Leer el método SSH exitoso
                    if [ -f ~/.ssh/method ]; then
                        . ~/.ssh/method
                        echo "Usando método SSH detectado para diagnósticos: $SSH_METHOD"
                    else
                        SSH_METHOD="auto"
                    fi
                    
                    # Función para ejecutar comandos SSH según el método exitoso
                    execute_ssh_diag() {
                        case "$SSH_METHOD" in
                            "auto")
                                ssh -o ConnectTimeout=10 -o BatchMode=yes -o PasswordAuthentication=no -o PubkeyAuthentication=yes ec2-user@$EC2_IP "$@"
                                ;;
                            "agent")
                                ssh -o ConnectTimeout=10 -o BatchMode=yes -o PasswordAuthentication=no ec2-user@$EC2_IP "$@"
                                ;;
                            "direct")
                                ssh -o ConnectTimeout=10 -o BatchMode=yes -o PasswordAuthentication=no -o IdentitiesOnly=yes -i ~/.ssh/id_rsa ec2-user@$EC2_IP "$@"
                                ;;
                            "config")
                                ssh -o ConnectTimeout=10 -o BatchMode=yes ec2-user@$EC2_IP "$@"
                                ;;
                            *)
                                ssh -o ConnectTimeout=10 -o BatchMode=yes -o PasswordAuthentication=no ec2-user@$EC2_IP "$@"
                                ;;
                        esac
                    }
                    
                    # Intentar obtener diagnósticos usando el método exitoso
                    if execute_ssh_diag << 'DIAG_EOF'
                        echo '=== Estado de Flask ==='
                        sudo systemctl status flask-app --no-pager --lines=10
                        echo ''
                        echo '=== Últimos logs de Flask ==='
                        sudo journalctl -u flask-app --no-pager -n 20
                        echo ''
                        echo '=== Estado de Nginx ==='
                        sudo systemctl status nginx --no-pager --lines=10
                        echo ''
                        echo '=== Verificando puertos ==='
                        sudo netstat -tlnp | grep -E ':(80|5000)'
DIAG_EOF
                    then
                        echo "Diagnósticos obtenidos usando método SSH: $SSH_METHOD"
                    else
                        echo "Error al obtener información de diagnóstico - todos los métodos SSH fallaron"
                    fi
                    
                    exit 1
                '''
            }
        }
    }

    post {
        always {
            sh '''
                # Limpiar ssh-agent si está corriendo
                if [ ! -z "$SSH_AGENT_PID" ]; then
                    echo "Limpiando ssh-agent..."
                    ssh-agent -k || echo "ssh-agent ya terminado"
                fi
                
                # Limpiar archivos SSH
                rm -f ~/.ssh/id_rsa
                
                # Limpiar Terraform temporal
                rm -rf /tmp/terraform-${BUILD_NUMBER}
                
                # Limpiar entorno virtual de Ansible
                rm -rf /tmp/ansible-venv-${BUILD_NUMBER}
            '''
        }
        failure {
            echo 'El pipeline falló. Iniciando limpieza de recursos...'
            script {
                try {
                    dir('infrastructure/terraform') {
                        sh '''
                            echo "Iniciando limpieza de recursos AWS..."
                            
                            # Reinstalar Terraform para la limpieza
                            mkdir -p /tmp/terraform-cleanup-${BUILD_NUMBER}
                            cd /tmp/terraform-cleanup-${BUILD_NUMBER}
                            
                            # Verificar que unzip esté disponible (sin intentar instalar para evitar problemas de permisos)
                            if ! command -v unzip &> /dev/null; then
                                echo "⚠️ unzip no disponible, usando Python como alternativa..."
                                # Se usará el método alternativo con Python más abajo
                            fi
                            
                            echo "Descargando Terraform para limpieza..."
                            curl -fsSL -o terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                            
                            # Extraer usando unzip o Python como alternativa
                            if command -v unzip &> /dev/null; then
                                unzip -o -q terraform.zip
                            else
                                echo "Usando Python para extraer el archivo..."
                                python3 -c "
import zipfile
with zipfile.ZipFile('terraform.zip', 'r') as zip_ref:
    zip_ref.extractall('.')
"
                            fi
                            chmod +x terraform
                            
                            # Volver al directorio de terraform (usar comillas para manejar espacios)
                            cd "${WORKSPACE}/infrastructure/terraform"
                            
                            # Destruir recursos
                            TERRAFORM_BIN="/tmp/terraform-cleanup-${BUILD_NUMBER}/terraform"
                            echo "Destruyendo recursos de infraestructura..."
                            $TERRAFORM_BIN init || echo "Error en terraform init durante limpieza"
                            $TERRAFORM_BIN destroy -auto-approve -var="db_password=${DB_PASSWORD}" || echo "Error al destruir recursos, algunos pueden quedar activos"
                            
                            # Limpiar directorio temporal
                            rm -rf /tmp/terraform-cleanup-${BUILD_NUMBER}
                            echo "Limpieza completada."
                        '''
                    }
                } catch (Exception e) {
                    echo "Error durante la limpieza: ${e.getMessage()}"
                    echo "Algunos recursos pueden requerir limpieza manual en AWS"
                }
            }
        }
        success {
            script {
                sh '''
                    # Leer la IP guardada durante la verificación
                    if [ -f /tmp/ec2_ip.txt ]; then
                        EC2_IP=$(cat /tmp/ec2_ip.txt)
                    else
                        EC2_IP="No disponible"
                    fi
                    
                    echo "=========================="
                    echo "¡DESPLIEGUE EXITOSO!"
                    echo "URL de la aplicación: http://$EC2_IP/"
                    echo "=========================="
                    
                    # Limpiar archivo temporal
                    rm -f /tmp/ec2_ip.txt
                '''
            }
        }
    }
} 