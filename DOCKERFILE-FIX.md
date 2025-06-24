# Guide de Correction - Erreur de Build Apache Polaris

## 🚨 Problème Identifié

Erreur lors de la construction du Dockerfile :
```
245.5 cp: cannot stat 'polaris-service/build/install/polaris-service/*': No such file or directory
```

Cette erreur indique que la structure du projet Apache Polaris 0.9.0 ne correspond pas aux chemins attendus dans le Dockerfile.

## ✅ Solutions Disponibles

### Solution 1: Dockerfile Simplifié (Recommandé)

Utilisez le Dockerfile simplifié qui gère automatiquement la structure du projet :

```bash
# Construction avec le Dockerfile simplifié
BUILD_METHOD=simple ./build-polaris.sh

# Ou directement avec Docker
docker build -f Dockerfile.simple -t dlkh-platform-polaris .
```

### Solution 2: Image Officielle Apache Polaris

Si disponible, utilisez l'image officielle :

```bash
# Test de l'image officielle
docker pull apache/polaris:latest

# Construction avec l'image officielle
BUILD_METHOD=official ./build-polaris.sh

# Ou directement
docker build -f Dockerfile.official -t dlkh-platform-polaris .
```

### Solution 3: Dockerfile Corrigé Principal

Le Dockerfile principal a été corrigé pour être plus robuste :

```bash
# Construction standard corrigée
BUILD_METHOD=source ./build-polaris.sh

# Ou avec le Makefile
make build
```

### Solution 4: Construction Hybride (Automatique)

Le script de build essaie automatiquement différentes méthodes :

```bash
# Construction automatique avec fallback
BUILD_METHOD=auto ./build-polaris.sh

# Ou construction avec nettoyage
BUILD_METHOD=clean ./build-polaris.sh
```

## 🔧 Méthodes de Build Disponibles

| Méthode | Description | Commande |
|---------|-------------|----------|
| `simple` | Dockerfile simplifié et robuste | `BUILD_METHOD=simple ./build-polaris.sh` |
| `official` | Image Docker officielle Apache | `BUILD_METHOD=official ./build-polaris.sh` |
| `source` | Construction depuis les sources | `BUILD_METHOD=source ./build-polaris.sh` |
| `hybrid` | Automatique avec fallback | `BUILD_METHOD=hybrid ./build-polaris.sh` |
| `auto` | Identique à hybrid | `BUILD_METHOD=auto ./build-polaris.sh` |
| `clean` | Nettoyage puis construction | `BUILD_METHOD=clean ./build-polaris.sh` |

## 🛠️ Dépannage Étape par Étape

### 1. Vérification des Prérequis

```bash
# Vérifier Docker
docker --version
# Attendu: Docker version 20.10+

# Vérifier Docker Compose v2
docker compose version  
# Attendu: Docker Compose version v2.0+

# Vérifier l'espace disque
df -h
# Requis: 15GB libre minimum

# Vérifier la mémoire
free -h
# Recommandé: 8GB RAM
```

### 2. Nettoyage de l'Environnement

```bash
# Nettoyer Docker
docker system prune -a -f

# Arrêter les services existants
make down

# Supprimer les volumes (ATTENTION: supprime les données)
docker compose down -v --remove-orphans
```

### 3. Construction avec Diagnostic

```bash
# Construction avec logs détaillés
BUILD_METHOD=simple ./build-polaris.sh 2>&1 | tee build.log

# Analyser les logs en cas d'erreur
grep -i error build.log
grep -i "no such file" build.log
```

### 4. Fallback Manuel

Si tous les builds automatiques échouent, construction manuelle :

```bash
# 1. Nettoyer complètement
docker system prune -a -f

# 2. Construire seulement PostgreSQL d'abord
docker compose up -d postgres

# 3. Attendre que PostgreSQL soit prêt
docker compose logs postgres

# 4. Essayer la construction simple
docker build -f Dockerfile.simple -t dlkh-platform-polaris . --no-cache

# 5. Marquer l'image pour docker-compose
docker tag dlkh-platform-polaris dlkh-platform-polaris:latest

# 6. Démarrer tous les services
docker compose up -d
```

## 📁 Fichiers de Configuration Alternatives

### Dockerfile.simple
- Construction plus robuste
- Gestion automatique de la structure de projet
- Détection intelligente des JARs

### Dockerfile.official  
- Basé sur l'image officielle Apache Polaris
- Configuration personnalisée PostgreSQL
- Plus rapide si l'image est disponible

### polaris-start-simple.sh
- Script de démarrage simplifié
- Détection automatique du JAR principal
- Gestion d'erreurs améliorée

## 🚀 Instructions Recommandées

### Pour un Démarrage Rapide

```bash
# 1. Utiliser la méthode la plus robuste
BUILD_METHOD=simple ./build-polaris.sh

# 2. Si succès, démarrer les services
make up

# 3. Vérifier la santé
make health
```

### Pour le Développement

```bash
# 1. Construction avec nettoyage
BUILD_METHOD=clean ./build-polaris.sh

# 2. Démarrage en mode dev
make dev

# 3. Suivi des logs
make logs
```

### Pour la Production

```bash
# 1. Copier le fichier d'environnement
cp .env.example .env

# 2. Éditer les variables de production
vim .env

# 3. Construction production
COMPOSE_FILE=docker-compose.prod.yml BUILD_METHOD=simple ./build-polaris.sh

# 4. Démarrage production
make production
```

## ⚠️ Notes Importantes

1. **Java 21 Requis**: Apache Polaris 0.9.0 nécessite absolument Java 21
2. **Ressources**: 8GB RAM et 15GB disque recommandés pour la construction
3. **Temps**: La première construction peut prendre 10-15 minutes
4. **Réseau**: Connexion internet requise pour télécharger les dépendances

## 🆘 Support

Si le problème persiste après avoir essayé toutes ces solutions :

1. **Créer un issue** avec les logs complets
2. **Inclure** la sortie de `docker --version` et `docker compose version`
3. **Préciser** la méthode de build utilisée
4. **Joindre** les logs d'erreur complets

---

**Status**: ✅ SOLUTIONS MULTIPLES DISPONIBLES  
**Recommandation**: Utiliser `BUILD_METHOD=simple` pour la fiabilité maximale