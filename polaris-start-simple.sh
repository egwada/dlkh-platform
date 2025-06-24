#!/bin/bash

set -e

# Script de démarrage simplifié pour Apache Polaris 0.9.0
echo "=== Démarrage Apache Polaris 0.9.0 (Script Simplifié) ==="

# Variables d'environnement
POLARIS_HOME=${POLARIS_HOME:-/opt/polaris}
JAVA_OPTS=${JAVA_OPTS:-"-Xmx2g -Xms1g -XX:+UseG1GC --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED"}
DB_HOST=${DB_HOST:-postgres}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-polaris}
DB_USER=${DB_USER:-polaris}
DB_PASSWORD=${DB_PASSWORD:-polaris123}

echo "Configuration:"
echo "- POLARIS_HOME: $POLARIS_HOME"
echo "- DB_HOST: $DB_HOST:$DB_PORT"
echo "- DB_NAME: $DB_NAME"
echo "- DB_USER: $DB_USER"

# Attendre PostgreSQL
echo "Attente de PostgreSQL..."
timeout=60
counter=0
while ! nc -z $DB_HOST $DB_PORT; do
    echo "PostgreSQL non disponible - attente... ($counter/$timeout)"
    sleep 5
    counter=$((counter + 5))
    if [ $counter -ge $timeout ]; then
        echo "ERREUR: PostgreSQL non disponible après $timeout secondes"
        exit 1
    fi
done
echo "✅ PostgreSQL disponible"

# Test de connexion à la base
echo "Test de connexion à la base de données..."
export PGPASSWORD=$DB_PASSWORD
for i in {1..5}; do
    if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" >/dev/null 2>&1; then
        echo "✅ Connexion DB réussie"
        break
    else
        echo "Tentative $i/5 - Connexion DB échouée, retry dans 3s..."
        sleep 3
        if [ $i -eq 5 ]; then
            echo "ERREUR: Impossible de se connecter à la DB après 5 tentatives"
            exit 1
        fi
    fi
done

# Configuration du classpath
CLASSPATH="$POLARIS_HOME/lib/*:$POLARIS_HOME/config:$POLARIS_HOME"

# Variables JVM
JVM_OPTS="$JAVA_OPTS"
JVM_OPTS="$JVM_OPTS -Djava.awt.headless=true"
JVM_OPTS="$JVM_OPTS -Dfile.encoding=UTF-8"
JVM_OPTS="$JVM_OPTS -Duser.timezone=UTC"
JVM_OPTS="$JVM_OPTS -Dpolaris.home=$POLARIS_HOME"

echo "Configuration JVM: $JVM_OPTS"

# Vérification des fichiers
echo "Vérification des fichiers..."
echo "Contenu de $POLARIS_HOME:"
ls -la $POLARIS_HOME/

echo "JARs disponibles:"
ls -la $POLARIS_HOME/lib/*.jar 2>/dev/null || echo "Aucun JAR trouvé"

# Trouver le JAR principal
POLARIS_JAR=""
if [ -f "$POLARIS_HOME/polaris.jar" ]; then
    POLARIS_JAR="$POLARIS_HOME/polaris.jar"
    echo "✅ Utilisation du JAR principal: $POLARIS_JAR"
else
    # Rechercher un JAR avec des mots-clés Polaris
    for pattern in "*polaris*service*.jar" "*polaris*.jar" "*service*.jar"; do
        JAR_FOUND=$(find $POLARIS_HOME/lib -name "$pattern" 2>/dev/null | head -1)
        if [ -n "$JAR_FOUND" ] && [ -f "$JAR_FOUND" ]; then
            POLARIS_JAR="$JAR_FOUND"
            echo "✅ JAR trouvé avec pattern $pattern: $POLARIS_JAR"
            break
        fi
    done
fi

# Si aucun JAR spécifique trouvé, utiliser le premier disponible
if [ -z "$POLARIS_JAR" ]; then
    POLARIS_JAR=$(ls $POLARIS_HOME/lib/*.jar 2>/dev/null | head -1)
    if [ -n "$POLARIS_JAR" ]; then
        echo "⚠️ Utilisation du premier JAR disponible: $POLARIS_JAR"
    else
        echo "❌ ERREUR: Aucun JAR trouvé dans $POLARIS_HOME/lib/"
        exit 1
    fi
fi

# Vérifier le contenu du JAR
echo "Vérification du JAR: $POLARIS_JAR"
jar tf "$POLARIS_JAR" | grep -i "application\|main" | head -5 || echo "Classes non listées"

# Créer le répertoire des logs
mkdir -p $POLARIS_HOME/logs

# Fonction de nettoyage
cleanup() {
    echo "Arrêt d'Apache Polaris..."
    if [ -n "$POLARIS_PID" ]; then
        kill -TERM $POLARIS_PID 2>/dev/null || true
        wait $POLARIS_PID 2>/dev/null || true
    fi
    echo "Apache Polaris arrêté."
}

# Intercepter les signaux pour un arrêt propre
trap cleanup SIGTERM SIGINT

# Démarrage d'Apache Polaris
echo "=== Démarrage d'Apache Polaris ==="
cd $POLARIS_HOME

# Essayer différentes méthodes de démarrage
echo "Tentative de démarrage avec JAR: $POLARIS_JAR"

# Méthode 1: Démarrage avec -jar
java $JVM_OPTS \
    -jar "$POLARIS_JAR" \
    --spring.config.location=file:$POLARIS_HOME/config/polaris.properties \
    --spring.datasource.url="jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME" \
    --spring.datasource.username="$DB_USER" \
    --spring.datasource.password="$DB_PASSWORD" \
    --spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect \
    --logging.config=file:$POLARIS_HOME/config/log4j2.xml \
    --server.port=8080 \
    --management.endpoints.web.exposure.include=health,info,metrics &

POLARIS_PID=$!
echo "✅ Apache Polaris démarré avec PID: $POLARIS_PID"

# Attendre que le processus se termine
wait $POLARIS_PID
