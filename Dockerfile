FROM openjdk:21-jdk-slim

# Installation des dépendances système
RUN apt-get update && \
    apt-get install -y wget curl netcat-traditional postgresql-client git && \
    rm -rf /var/lib/apt/lists/*

# Variables d'environnement
ENV POLARIS_HOME=/opt/polaris
ENV JAVA_OPTS="-Xmx2g -Xms1g -XX:+UseG1GC --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED"
ENV DB_HOST=postgres
ENV DB_PORT=5432
ENV DB_NAME=polaris
ENV DB_USER=polaris
ENV DB_PASSWORD=polaris123

# Création des répertoires
RUN mkdir -p ${POLARIS_HOME}/lib \
    ${POLARIS_HOME}/config \
    ${POLARIS_HOME}/logs \
    /tmp/polaris-build

WORKDIR /tmp/polaris-build

# Téléchargement et construction d'Apache Polaris 0.9.0-incubating
RUN git clone --depth 1 --branch apache-polaris-0.9.0-incubating https://github.com/apache/polaris.git . && \
    echo "=== Structure du projet ===" && \
    ls -la && \
    echo "=== Construction avec Gradle ===" && \
    ./gradlew build -x test --no-daemon && \
    echo "=== Recherche des JARs construits ===" && \
    find . -name "*.jar" -path "*/build/libs/*" && \
    echo "=== Copie des JARs vers POLARIS_HOME ===" && \
    find . -name "*.jar" -path "*/build/libs/*" -exec cp {} ${POLARIS_HOME}/lib/ \; && \
    echo "=== Recherche des fichiers exécutables ===" && \
    find . -name "*.sh" -executable || true && \
    echo "=== Copie des scripts s'ils existent ===" && \
    find . -name "*.sh" -executable -exec cp {} ${POLARIS_HOME}/ \; 2>/dev/null || true && \
    echo "=== Nettoyage ===" && \
    cd ${POLARIS_HOME} && \
    rm -rf /tmp/polaris-build

# Ajout des drivers PostgreSQL et EclipseLink
RUN wget -O ${POLARIS_HOME}/lib/postgresql-42.7.1.jar https://jdbc.postgresql.org/download/postgresql-42.7.1.jar && \
    wget -O ${POLARIS_HOME}/lib/eclipselink-4.0.2.jar https://repo1.maven.org/maven2/org/eclipse/persistence/eclipselink/4.0.2/eclipselink-4.0.2.jar && \
    wget -O ${POLARIS_HOME}/lib/jakarta.persistence-api-3.1.0.jar https://repo1.maven.org/maven2/jakarta/persistence/jakarta.persistence-api/3.1.0/jakarta.persistence-api-3.1.0.jar

# Configuration JPA/EclipseLink
COPY config/persistence.xml ${POLARIS_HOME}/config/
COPY config/polaris.properties ${POLARIS_HOME}/config/
COPY config/log4j2.xml ${POLARIS_HOME}/config/

# Script de démarrage
COPY polaris-start.sh ${POLARIS_HOME}/start-polaris.sh
RUN chmod +x ${POLARIS_HOME}/start-polaris.sh

# Vérification finale du contenu
RUN echo "=== Contenu final de POLARIS_HOME ===" && \
    ls -la ${POLARIS_HOME}/ && \
    echo "=== Contenu du répertoire lib ===" && \
    ls -la ${POLARIS_HOME}/lib/ && \
    echo "=== Contenu du répertoire config ===" && \
    ls -la ${POLARIS_HOME}/config/

WORKDIR ${POLARIS_HOME}

# Exposition des ports
EXPOSE 8080 8443

# Variables d'environnement finales
ENV PATH="${POLARIS_HOME}/bin:${POLARIS_HOME}:${PATH}"
ENV CLASSPATH="${POLARIS_HOME}/lib/*:${POLARIS_HOME}/config:${POLARIS_HOME}"

# Point d'entrée
CMD ["./start-polaris.sh"]
