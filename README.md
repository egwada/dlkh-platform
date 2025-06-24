# Apache Polaris 0.9.0 avec PostgreSQL et EclipseLink

Cette configuration vous permet de déployer Apache Polaris 0.9.0 avec PostgreSQL comme backend et EclipseLink comme ORM, utilisant Java 21.

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Apache        │    │   PostgreSQL     │    │   PgAdmin       │
│   Polaris       │────┤   Database       │    │   (Web UI)      │
│   (Port 8080)   │    │   (Port 5432)    │    │   (Port 8081)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📋 Prérequis

- Docker >= 20.10
- Docker Compose >= 2.0 (utilise la commande `docker compose` sans tiret)
- Java 21 (utilisé dans le conteneur Docker)
- Make (optionnel, pour utiliser le Makefile)
- 8GB de RAM disponible (construction Gradle avec Java 21)
- 15GB d'espace disque libre

## 🚀 Installation rapide

### 1. Cloner et préparer l'environnement

```bash
# Créer le répertoire du projet
mkdir polaris-setup && cd polaris-setup

# Créer la structure des dossiers
mkdir -p config init-scripts logs
```

### 2. Créer les fichiers de configuration

Copiez tous les fichiers fournis dans leurs répertoires respectifs :

```
polaris-setup/
├── Dockerfile
├── docker-compose.yml
├── Makefile
├── polaris-start.sh
├── config/
│   ├── persistence.xml
│   ├── polaris.properties
│   └── log4j2.xml
└── init-scripts/
    └── init.sql
```

### 3. Rendre le script exécutable

```bash
chmod +x polaris-start.sh
```

### 4. Démarrer les services

```bash
# Avec Make (recommandé)
make install

# Ou manuellement
docker compose up --build -d
```

## 🛠️ Utilisation avec Make

Le Makefile fourni simplifie la gestion du projet :

```bash
# Afficher l'aide
make help

# Construire les images
make build

# Démarrer les services
make up

# Arrêter les services
make down

# Voir les logs
make logs

# Vérifier le statut
make status

# Vérifier la santé des services
make health
```

## 🔧 Configuration

### Variables d'environnement

Modifiez le fichier `docker-compose.yml` pour personnaliser :

```yaml
environment:
  DB_HOST: postgres
  DB_PORT: 5432
  DB_NAME: polaris
  DB_USER: polaris
  DB_PASSWORD: polaris123  # ⚠️ Changez en production
  JAVA_OPTS: "-Xmx2g -Xms1g"
```

### Configuration de la base de données

Le fichier `persistence.xml` configure EclipseLink :

- **Provider** : EclipseLink JPA
- **Base de données** : PostgreSQL
- **Pool de connexions** : 5-20 connexions
- **Cache** : Activé avec SoftWeak
- **DDL** : Création automatique des tables

### Configuration Polaris

Le fichier `polaris.properties` contient :

- Configuration du serveur (ports, SSL)
- Paramètres de base de données
- Configuration de sécurité
- Paramètres de cache et métriques

## 🌐 Accès aux services

Une fois démarrés, les services sont accessibles via :

| Service | URL | Identifiants |
|---------|-----|--------------|
| **Polaris API** | http://localhost:8080 | - |
| **Polaris Health** | http://localhost:8080/health | - |
| **PgAdmin** | http://localhost:8081 | admin@polaris.local / admin123 |
| **PostgreSQL** | localhost:5432 | polaris / polaris123 |

## 📊 Monitoring et logs

### Visualiser les logs

```bash
# Tous les logs
make logs

# Logs de Polaris seulement
make logs-polaris

# Logs de PostgreSQL seulement
make logs-postgres

# Analyser les erreurs
make analyze-logs
```

### Métriques et santé

```bash
# Vérifier la santé des services
make health

# Surveiller les ressources
make monitor

# Vérifier les ports
make check-ports
```

## 🔒 Sécurité

### Configuration par défaut

⚠️ **Important** : La configuration par défaut utilise des mots de passe faibles. **Changez-les en production !**

### Utilisateurs par défaut

- **Admin Polaris** : admin / admin123
- **User Polaris** : user / user123
- **PostgreSQL** : polaris / polaris123
- **PgAdmin** : admin@polaris.local / admin123

### Sécurisation pour la production

1. **Changez tous les mots de passe**
2. **Activez SSL/TLS**
3. **Configurez un reverse proxy (nginx)**
4. **Utilisez des secrets Docker**
5. **Limitez l'accès réseau**

## 🗄️ Gestion de la base de données

### Sauvegarde

```bash
# Sauvegarde automatique
make backup-db

# Sauvegarde manuelle
docker compose exec postgres pg_dump -U polaris -d polaris > backup.sql
```

### Restauration

```bash
# Restauration avec Make
make restore-db BACKUP_FILE=backup.sql

# Restauration manuelle
docker compose exec -T postgres psql -U polaris -d polaris < backup.sql
```

### Réinitialisation

```bash
# Réinitialiser la base de données
make reset-db

# Nettoyage complet (⚠️ supprime tout)
make clean
```

## 🐛 Dépannage

### Problèmes courants

#### Polaris ne démarre pas

1. **Vérifiez les logs** :
   ```bash
   make logs-polaris
   ```

2. **Vérifiez la connexion DB** :
   ```bash
   make shell-postgres
   # Dans le shell PostgreSQL :
   \l  # Lister les bases de données
   \dt # Lister les tables
   ```

3. **Vérifiez les ports** :
   ```bash
   make check-ports
   ```

#### Erreurs de connexion PostgreSQL

1. **Attendez que PostgreSQL soit prêt** :
   ```bash
   docker compose logs postgres
   ```

2. **Testez la connexion** :
   ```bash
   docker compose exec postgres pg_isready -U polaris
   ```

#### Problèmes de performances

1. **Augmentez la mémoire Java** :
   ```yaml
   environment:
     JAVA_OPTS: "-Xmx4g -Xms2g -XX:+UseG1GC --add-opens=java.base/java.lang=ALL-UNNAMED"  # Augmenter selon vos besoins
   ```

2. **Ajustez le pool de connexions** dans `persistence.xml`

3. **Surveillez les ressources** :
   ```bash
   make monitor
   ```

### Logs utiles

```bash
# Erreurs EclipseLink
docker compose logs polaris | grep -i eclipselink

# Erreurs SQL
docker compose logs polaris | grep -i sql

# Erreurs de connexion
docker compose logs polaris | grep -i connection
```

## 🔄 Mise à jour

```bash
# Arrêter les services
make down

# Mettre à jour les images
make update

# Reconstruire si nécessaire
make rebuild
```

## 📚 Développement

### Mode développement

```bash
# Démarrage en mode dev avec rebuild automatique
make dev

# Accès aux shells
make shell-polaris    # Shell Polaris
make shell-postgres   # Shell PostgreSQL
```

### Configuration personnalisée

1. **Modifiez les fichiers dans `config/`**
2. **Redémarrez les services** :
   ```bash
   make restart
   ```

## 🆕 Nouveautés version 0.9.0

### Améliorations apportées

- **Apache Polaris 0.9.0** : Version plus stable avec de meilleures performances
- **Java 21** : Utilisation de la dernière version LTS de Java pour de meilleures performances
- **Docker Compose v2** : Utilisation de la syntaxe moderne `docker compose` (sans tiret)
- **Timeouts améliorés** : Gestion plus robuste des démarrages et connexions
- **Logging enrichi** : Meilleure séparation des logs par composant
- **Healthchecks** : Vérifications de santé plus complètes

### Changements techniques

- **Java 21** : Migration vers Java 21 (requis par Apache Polaris 0.9.0)
- **URL de téléchargement** : Mise à jour vers Polaris 0.9.0
- **Construction Gradle** : Compilation depuis les sources avec Java 21
- **Dépendances** : Ajout de `netcat-traditional` et `postgresql-client` dans le conteneur
- **Script de démarrage** : Gestion des timeouts et retry logic améliorés
- **Configuration réseau** : Réseau Docker nommé explicitement
- **Paramètres JVM** : Options Java 21 avec G1GC et modules ouverts

## 🤝 Support

Pour obtenir de l'aide :

1. **Consultez les logs** : `make logs`
2. **Vérifiez la santé** : `make health`
3. **Analysez les erreurs** : `make analyze-logs`
4. **Consultez la documentation Apache Polaris 0.9.0**

## 📄 Licence

Configuration basée sur Apache Polaris 0.9.0 (Licence Apache 2.0)

---

**⚠️ Note importante** : Cette configuration utilise Apache Polaris 0.9.0 avec Java 21 et Docker Compose v2. Elle est conçue pour le développement et les tests. Pour un déploiement en production, veillez à sécuriser tous les composants et à suivre les bonnes pratiques de sécurité.