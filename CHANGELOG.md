# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-12-28

### 🎉 Changements majeurs

#### ⬆️ Mise à jour vers Apache Polaris 0.9.0
- **BREAKING CHANGE**: Mise à jour d'Apache Polaris de la version 0.1.0 à 0.9.0
- URL de téléchargement mise à jour vers la version 0.9.0
- Amélioration des performances et de la stabilité
- Nouvelles fonctionnalités disponibles dans Polaris 0.9.0

#### 🐳 Migration vers Docker Compose v2
- **BREAKING CHANGE**: Utilisation de la commande `docker compose` (sans tiret) au lieu de `docker-compose`
- Suppression de l'attribut `version` obsolète du docker-compose.yml
- Compatibilité avec Docker Compose v2+ uniquement
- Mise à jour de tous les scripts et documentation

### ✨ Nouvelles fonctionnalités

#### 📁 Structure améliorée
- Renommage de `Dokerfile` en `Dockerfile` (correction de la typo)
- Renommage de `start-polaris.sh` en `polaris-start.sh` pour plus de cohérence
- Ajout du fichier `.env.example` pour la configuration des variables d'environnement
- Création de `docker-compose.prod.yml` pour la production

#### 🚀 Configuration de production
- Nouvelle configuration Docker Compose pour la production
- Support des profils Docker Compose (monitoring, proxy)
- Intégration optionnelle de Prometheus et Grafana
- Configuration Nginx en reverse proxy
- Gestion des ressources et limits CPU/mémoire
- Configuration des volumes persistants avec bind mounts

#### 🔧 Améliorations techniques
- Ajout de `netcat-traditional` et `postgresql-client` dans le conteneur Polaris
- Script de démarrage amélioré avec retry logic et timeouts
- Meilleure gestion des erreurs de connexion à la base de données
- Vérification automatique des dépendances JAR
- Logs de démarrage plus détaillés

### 🛠️ Améliorations

#### 📋 Makefile
- Correction de toutes les commandes `docker-compose` en `docker compose`
- Correction des références aux noms de fichiers
- Amélioration de la gestion des erreurs
- Messages d'aide plus clairs avec codes couleur

#### 📖 Documentation
- README mis à jour avec les nouvelles commandes Docker Compose v2
- Documentation des nouveautés de la version 0.9.0
- Ajout des exemples de variables d'environnement
- Amélioration des instructions d'installation et de dépannage

#### 🔄 Scripts
- Script `polaris-start.sh` amélioré avec :
  - Timeouts configurables pour PostgreSQL (60 secondes par défaut)
  - Retry logic pour les connexions à la base de données (10 tentatives)
  - Vérification des fichiers JAR nécessaires
  - Meilleure gestion des signaux d'arrêt
  - Logs plus détaillés pour le debug

#### 🐳 Docker
- Configuration réseau nommée explicitement (`polaris-network`)
- Amélioration du contexte de build
- Optimisation des layers Docker
- Meilleure séparation des préoccupations (dev vs prod)

### 🔒 Sécurité

#### 🛡️ Configuration de production
- Support des Docker secrets pour les mots de passe
- Variables d'environnement sécurisées
- Configuration SSL/TLS pour Nginx
- Isolation réseau améliorée
- Exemples de configuration sécurisée dans `.env.example`

### 📊 Monitoring

#### 📈 Observabilité
- Configuration Prometheus pour les métriques
- Dashboards Grafana pré-configurés
- Logs structurés avec rotation
- Health checks améliorés avec start period
- Monitoring des ressources système

### 🐛 Corrections

#### 🔧 Corrections techniques
- Correction de la typo dans le nom du Dockerfile
- Résolution des problèmes de chemins dans les scripts
- Amélioration de la gestion des timeouts
- Correction des références de fichiers dans le Makefile

#### 📝 Corrections de documentation
- Mise à jour des exemples de commandes
- Correction des URLs et références
- Amélioration de la cohérence des noms de fichiers

### ⚠️ Changements incompatibles

1. **Docker Compose**: Nécessite Docker Compose v2+ (commande `docker compose`)
2. **Apache Polaris**: Migration vers la version 0.9.0 (nouvelles APIs possibles)
3. **Noms de fichiers**: Certains fichiers ont été renommés pour plus de cohérence

### 🔄 Migration

Pour migrer depuis la version précédente :

1. **Mettre à jour Docker Compose** :
   ```bash
   # Vérifier la version
   docker compose version
   
   # Si nécessaire, installer Docker Compose v2
   sudo apt-get update && sudo apt-get install docker-compose-plugin
   ```

2. **Sauvegarder les données existantes** :
   ```bash
   make backup-db
   ```

3. **Arrêter les services existants** :
   ```bash
   docker-compose down  # ancienne commande
   # ou
   make down
   ```

4. **Mettre à jour le projet** :
   ```bash
   git pull origin main
   ```

5. **Reconstruire et redémarrer** :
   ```bash
   make rebuild
   ```

### 📚 Notes de version

- **Compatibilité** : Cette version nécessite Docker Compose v2+
- **Performance** : Améliorations significatives avec Polaris 0.9.0
- **Production** : Nouvelle configuration optimisée pour la production
- **Monitoring** : Support complet de l'observabilité

### 🤝 Contributeurs

- Configuration initiale et migration Docker Compose v2
- Mise à jour Apache Polaris 0.9.0
- Amélioration de la robustesse et de la documentation

---

## [1.0.0] - Version initiale

### ✨ Fonctionnalités initiales

- Configuration Docker Compose avec Apache Polaris 0.1.0
- Base de données PostgreSQL 15 avec Alpine Linux
- Interface PgAdmin pour la gestion de la base de données
- ORM EclipseLink 4.0.2 avec JPA
- Configuration Log4j2 avec rotation des fichiers
- Scripts d'initialisation PostgreSQL
- Makefile avec commandes utilitaires
- Documentation complète
- Health checks pour tous les services
- Configuration de développement prête à l'emploi

### 📋 Services inclus

- **Apache Polaris 0.1.0** sur port 8080/8443
- **PostgreSQL 15** sur port 5432
- **PgAdmin 4** sur port 8081

### 🔧 Outils

- Makefile avec 25+ commandes
- Scripts de sauvegarde/restauration
- Configuration EclipseLink optimisée
- Logs structurés et rotatifs
- Variables d'environnement configurables