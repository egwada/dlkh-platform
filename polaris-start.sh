#!/bin/bash

set -e

# Variables d'environnement
POLARIS_HOME=${POLARIS_HOME:-/opt/polaris}
JAVA_OPTS=${JAVA_OPTS:-"-Xmx2g -Xms1g -XX:+UseG1GC"}
DB_HOST=${DB_HOST:-postgres}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-polaris}
DB_USER=${DB_USER:-polaris}
DB_PASSWORD=${DB_PASSWORD:-polaris123}

echo "=== Démarrage d'Apache Polaris ==="
echo "POLARIS_HOME: $POLARIS_HOME"
echo "DB_HOST: $DB_HOST"
echo "DB_PORT: $DB_PORT"
echo "DB_NAME: $DB_NAME"
echo "DB_USER: $DB_USER"

# Attendre que PostgreSQL soit disponible
echo "Attente de la disponibilité de PostgreSQL..."
timeout=60
counter=0
while ! nc -z $DB_HOST $DB_PORT; do
    echo "PostgreSQL n'est pas encore disponible - attente... ($counter/$timeout)"
    sleep 5
    counter=$((counter + 5))
    if [ $counter -ge $timeout ]; then
        echo "Timeout: PostgreSQL n'est pas disponible après $timeout secondes"
        exit 1
    fi
done
echo "PostgreSQL est disponible!"

# Test de connexion à la base de données
echo "Test de connexion à la base de données..."
export PGPASSWORD=$DB_PASSWORD
retry_count=0
max_retries=10
while [ $retry_count -lt $max_retries ]; do
    if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
        echo "Connexion à la base de données réussie!"
        break
    else
        retry_count=$((retry_count + 1))
        echo "Tentative de connexion $retry_count/$max_retries échouée, nouvelle tentative dans 3 secondes..."
        sleep 3
    fi
done

if [ $retry_count -eq $max_retries ]; then
    echo "Erreur: Impossible de se connecter à la base de données après $max_retries tentatives"
    exit 1
fi

# Configuration du classpath
CLASSPATH="$POLARIS_HOME/lib/*:$POLARIS_HOME/config:$POLARIS_HOME:$POLARIS_HOME/bin"

# Variables JVM pour Java 21
JVM_OPTS="$JAVA_OPTS"
JVM_OPTS="$JVM_OPTS -Djava.awt.headless=true"
JVM_OPTS="$JVM_OPTS -Dfile.encoding=UTF-8"
JVM_OPTS="$JVM_OPTS -Duser.timezone=UTC"
JVM_OPTS="$JVM_OPTS -Dpolaris.home=$POLARIS_HOME"
JVM_OPTS="$JVM_OPTS -Dpolaris.config=$POLARIS_HOME/config/polaris.properties"
JVM_OPTS="$JVM_OPTS -Dlog4j.configurationFile=$POLARIS_HOME/config/log4j2.xml"
JVM_OPTS="$JVM_OPTS --add-opens=java.base/java.lang=ALL-UNNAMED"
JVM_OPTS="$JVM_OPTS --add-opens=java.base/java.util=ALL-UNNAMED"

# Configuration EclipseLink
JVM_OPTS="$JVM_OPTS -Declipselink.logging.level=INFO"
JVM_OPTS="$JVM_OPTS -Declipselink.logging.timestamp=true"
JVM_OPTS="$JVM_OPTS -Declipselink.logging.thread=true"

# Variables d'environnement pour la base de données
export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD

echo "=== Configuration ==="
echo "JVM_OPTS: $JVM_OPTS"
echo "CLASSPATH: $CLASSPATH"

# Créer le répertoire des logs s'il n'existe pas
mkdir -p $POLARIS_HOME/logs

# Fonction de nettoyage
cleanup() {
    echo "Arrêt d'Apache Polaris..."
    kill -TERM $POLARIS_PID 2>/dev/null || true
    wait $POLARIS_PID 2>/dev/null || true
    echo "Apache Polaris arrêté."
}

# Intercepter les signaux pour un arrêt propre
trap cleanup SIGTERM SIGINT

# Démarrer Apache Polaris
echo "=== Démarrage d'Apache Polaris ==="
cd $POLARIS_HOME

# Vérifier que les fichiers nécessaires existent
echo "Vérification des dépendances..."
if [ ! -f "$POLARIS_HOME/lib/postgresql-42.7.1.jar" ]; then
    echo "Avertissement: Driver PostgreSQL non trouvé dans lib/"
fi

if [ ! -f "$POLARIS_HOME/lib/eclipselink-4.0.2.jar" ]; then
    echo "Avertissement: EclipseLink JAR non trouvé dans lib/"
fi

# Vérifier la structure Polaris
echo "Contenu de POLARIS_HOME:"
ls -la $POLARIS_HOME/
echo "Contenu de lib:"
ls -la $POLARIS_HOME/lib/ || echo "Répertoire lib introuvable"

# Trouver le JAR principal Polaris
POLARIS_JAR=$(find $POLARIS_HOME/lib -name "*polaris*.jar" -o -name "*service*.jar" | head -1)
if [ -z "$POLARIS_JAR" ]; then
    echo "Erreur: Aucun JAR Polaris trouvé dans lib/"
    echo "JARs disponibles:"
    find $POLARIS_HOME/lib -name "*.jar" | head -10
    exit 1
fi
echo "JAR Polaris trouvé: $POLARIS_JAR"

# Commande de démarrage pour Apache Polaris 0.9.0 construit depuis les sources
echo "Démarrage d'Apache Polaris avec les paramètres de base de données..."

# Utiliser le script de démarrage généré par Gradle si disponible
if [ -f "$POLARIS_HOME/bin/polaris-service" ]; then
    echo "Utilisation du script Gradle..."
    export POLARIS_CONF_DIR=$POLARIS_HOME/config
    export POLARIS_LOG_DIR=$POLARIS_HOME/logs
    $POLARIS_HOME/bin/polaris-service &
else
    # Fallback vers le démarrage Java direct avec le JAR trouvé
    echo "Utilisation du démarrage Java direct avec JAR: $POLARIS_JAR"

    # Déterminer la classe principale
    MAIN_CLASS="org.apache.polaris.service.PolarisApplication"

    # Vérifier si le JAR contient la classe principale
    if jar tf "$POLARIS_JAR" | grep -q "org/apache/polaris/service/PolarisApplication.class"; then
        echo "Classe principale trouvée dans $POLARIS_JAR"
    else
        echo "Recherche de la classe principale dans les JARs..."
        for jar in $POLARIS_HOME/lib/*.jar; do
            if jar tf "$jar" 2>/dev/null | grep -q "org/apache/polaris.*Application.class"; then
                POLARIS_JAR="$jar"
                echo "Classe principale trouvée dans $jar"
                break
            fi
        done
    fi

    java $JVM_OPTS \
        -cp "$CLASSPATH" \
        -jar "$POLARIS_JAR" \
        --spring.config.location=file:$POLARIS_HOME/config/polaris.properties \
        --spring.datasource.url="jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME" \
        --spring.datasource.username="$DB_USER" \
        --spring.datasource.password="$DB_PASSWORD" \
        --spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect \
        --logging.config=file:$POLARIS_HOME/config/log4j2.xml &
fi

POLARIS_PID=$!
echo "Apache Polaris démarré avec le PID: $POLARIS_PID"

# Attendre que le processus se termine
wait $POLARIS_PID
