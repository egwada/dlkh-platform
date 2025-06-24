# Guide de Migration vers Apache Polaris 0.9.0

Ce guide vous aide à migrer votre installation existante vers Apache Polaris 0.9.0-incubating.

## 🚨 Changements Importants

### Apache Polaris 0.9.0-incubating

**BREAKING CHANGE**: Première version officielle d'Apache Polaris sous l'incubateur Apache
- **Java 21 requis**: Apache Polaris 0.9.0 nécessite Java 21 (migration depuis Java 17)
- **Source uniquement**: Seule la distribution source est disponible (pas de binaires)
- **Construction requise**: Le projet doit être compilé depuis les sources avec Gradle
- **Configuration modifiée**: Nouvelle structure de configuration Spring Boot

### Docker Compose v2

- **BREAKING CHANGE**: Migration vers Docker Compose v2 (commande `docker compose`)
- **Compatibilité**: Nécessite Docker Compose v2.0+ 
- **Format**: Suppression de l'attribut `version` obsolète

## 📋 Prérequis de Migration

### Système
- Docker >= 20.10
- Docker Compose >= 2.0 (avec support de `docker compose`)
- Java 21 (requis par Apache Polaris 0.9.0, fourni dans le conteneur Docker)
- 8GB RAM recommandés (construction Gradle avec Java 21)
- 15GB d'espace disque libre

### Sauvegarde
```bash
# Sauvegarder vos données existantes
make backup-db

# Ou manuellement
docker-compose exec postgres pg_dump -U polaris -d polaris > backup-pre-migration.sql
```

## 🔄 Étapes de Migration

### 1. Vérification de l'environnement

```bash
# Vérifier Docker Compose v2
docker compose version

# Si vous avez encore v1, installer v2
sudo apt-get update && sudo apt-get install docker-compose-plugin
```

### 2. Arrêt de l'installation existante

```bash
# Avec l'ancienne syntaxe
docker-compose down

# Ou avec Make
make down
```

### 3. Mise à jour du code

```bash
# Récupérer les dernières modifications
git pull origin main

# Vérifier les nouveaux fichiers
ls -la
```

### 4. Construction et démarrage

```bash
# Construction complète (peut prendre 10-15 minutes)
make rebuild

# Ou étape par étape
make build
make up
```

## 📁 Nouveaux Fichiers

### Fichiers ajoutés
- `docker-compose.prod.yml` - Configuration production
- `.env.example` - Variables d'environnement
- `CHANGELOG.md` - Journal des modifications
- `MIGRATION-0.9.0.md` - Ce guide

### Fichiers modifiés
- `Dockerfile` - Construction depuis les sources
- `docker-compose.yml` - Format v2, sans `version`
- `Makefile` - Commandes `docker compose`
- `config/polaris.properties` - Configuration 0.9.0
- `polaris-start.sh` - Script de démarrage adapté

## ⚙️ Changements de Configuration

### Base de données
```properties
# Ancien format
polaris.database.host=${DB_HOST}
polaris.database.port=${DB_PORT}

# Nouveau format (Spring Boot)
spring.datasource.url=jdbc:postgresql://${DB_HOST:postgres}:${DB_PORT:5432}/${DB_NAME:polaris}
```

### Sécurité
```properties
# Ancien format
polaris.security.jwt.secret=secret

# Nouveau format
polaris.oauth2.default-client-secret=polaris-secret
polaris.auth.token-broker.secret=change-this-secret-in-production
```

### API
```properties
# Ancien format
polaris.rest.api.base-path=/api

# Nouveau format
polaris.api.management.base-path=/api/management
polaris.api.catalog.base-path=/api/catalog
```

## 🔧 Dépannage

### Problème: Construction Gradle échoue

```bash
# Vérifier l'espace disque
df -h

# Nettoyer Docker
docker system prune -f

# Reconstruire avec plus de mémoire (Java 21)
export JAVA_OPTS="-Xmx4g -XX:+UseG1GC --add-opens=java.base/java.lang=ALL-UNNAMED"
make build
```

### Problème: Polaris ne démarre pas

```bash
# Vérifier les logs de construction
make logs-polaris

# Tester la connectivité DB
docker compose exec postgres pg_isready -U polaris

# Vérifier la configuration
docker compose exec polaris ls -la /opt/polaris/
```

### Problème: Commandes Docker Compose

```bash
# Si vous avez des erreurs avec docker-compose
which docker-compose
which docker

# Installer Docker Compose v2
curl -SL https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

## 🌐 Nouveaux Points d'Accès

### Polaris 0.9.0
- **Management API**: http://localhost:8080/api/management/v1
- **Catalog API**: http://localhost:8080/api/catalog/v1  
- **Health Check**: http://localhost:8080/actuator/health
- **Metrics**: http://localhost:8080/actuator/metrics

### Authentification
```bash
# Nouveau format OAuth2
curl -X POST http://localhost:8080/api/management/v1/oauth/tokens \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "client_credentials",
    "client_id": "polaris-client",
    "client_secret": "polaris-secret"
  }'
```

## 📊 Performance

### Temps de construction
- **Première fois**: 10-15 minutes (téléchargement + compilation)
- **Reconstructions**: 3-5 minutes (cache Gradle)
- **Images**: ~2GB (sources + dépendances)

### Ressources
- **RAM**: 4-8GB pendant la construction, 2GB en fonctionnement
- **CPU**: Utilisation intensive pendant la construction
- **Disque**: 15GB temporaire, 5GB final

## 🔍 Validation

### Tests de base
```bash
# Santé des services
make health

# API Management
curl http://localhost:8080/api/management/v1/catalogs

# API Catalog  
curl http://localhost:8080/api/catalog/v1/config

# Base de données
make shell-postgres
\l
\q
```

### Tests avancés
```bash
# Métriques Prometheus
curl http://localhost:8080/actuator/prometheus

# Logs applicatifs
make logs-polaris | grep "Started PolarisApplication"

# Performance
make monitor
```

## 🚀 Production

### Configuration production
```bash
# Copier le fichier d'environnement
cp .env.example .env

# Éditer les variables de production
vim .env

# Démarrer en mode production
COMPOSE_FILE=docker-compose.prod.yml make up
```

### Sécurisation
- Changer tous les mots de passe par défaut
- Configurer SSL/TLS
- Utiliser des secrets Docker
- Restreindre l'accès réseau
- Activer les logs d'audit

## 🆘 Support

### En cas de problème
1. **Consultez les logs**: `make logs`
2. **Vérifiez la santé**: `make health` 
3. **Analysez les erreurs**: `make analyze-logs`
4. **Nettoyage complet**: `make clean` puis `make install`

### Rollback
```bash
# Restaurer l'ancienne version
git checkout previous-version

# Restaurer les données
make restore-db BACKUP_FILE=backup-pre-migration.sql

# Redémarrer
docker-compose up -d  # ancienne syntaxe
```

### Ressources
- [Documentation officielle Polaris](https://polaris.apache.org/)
- [GitHub Apache Polaris](https://github.com/apache/polaris)
- [Docker Compose v2](https://docs.docker.com/compose/compose-v2/)

---

## 📝 Notes Importantes

⚠️ **Migration irréversible**: Les données migrées peuvent ne pas être compatibles avec les versions antérieures.

**Temps de construction**: La première construction peut prendre jusqu'à 15 minutes (compilation Java 21).

⚠️ **Ressources système**: Assurez-vous d'avoir suffisamment de RAM (8GB+) et d'espace disque pour Java 21.

✅ **Tests recommandés**: Testez d'abord sur un environnement de développement.

✅ **Sauvegarde obligatoire**: Toujours sauvegarder avant de migrer.