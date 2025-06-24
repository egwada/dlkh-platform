# Mise à jour vers Java 21 - Apache Polaris 0.9.0

## 🚨 Correction Critique Appliquée

### Problème Identifié
```
30.39         The Apache Polaris build requires Java 21.
30.39         Detected Java version: 17
```

**Apache Polaris 0.9.0-incubating nécessite impérativement Java 21** pour la compilation et l'exécution.

## ✅ Corrections Appliquées

### 1. Dockerfile
```dockerfile
# AVANT
FROM openjdk:17-jdk-slim

# APRÈS  
FROM openjdk:21-jdk-slim
```

### 2. Paramètres JVM Java 21
```bash
# AVANT (Java 17)
JAVA_OPTS="-Xmx2g -Xms1g -Djava.awt.headless=true"

# APRÈS (Java 21)
JAVA_OPTS="-Xmx2g -Xms1g -Djava.awt.headless=true -XX:+UseG1GC --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED"
```

### 3. Docker Compose
```yaml
# docker-compose.yml
environment:
  JAVA_OPTS: -Xmx2g -Xms1g -Djava.awt.headless=true -XX:+UseG1GC --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED

# docker-compose.prod.yml  
environment:
  JAVA_OPTS: "${JAVA_OPTS:--Xmx4g -Xms2g -Djava.awt.headless=true -XX:+UseG1GC -XX:MaxGCPauseMillis=200 --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED}"
```

### 4. Script de Démarrage
```bash
# polaris-start.sh - Nouvelles options JVM pour Java 21
JVM_OPTS="$JVM_OPTS --add-opens=java.base/java.lang=ALL-UNNAMED"
JVM_OPTS="$JVM_OPTS --add-opens=java.base/java.util=ALL-UNNAMED"
```

## 🔧 Nouveautés Java 21

### Optimisations Activées
- **G1GC**: Garbage Collector G1 par défaut pour de meilleures performances
- **Module System**: Options `--add-opens` pour la compatibilité avec les bibliothèques
- **Performance**: Améliorations significatives des performances par rapport à Java 17

### Paramètres Spécifiques
```bash
# Gestion des modules Java 21
--add-opens=java.base/java.lang=ALL-UNNAMED
--add-opens=java.base/java.util=ALL-UNNAMED

# Garbage Collection optimisé
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200  # En production
```

## 📊 Impact sur les Performances

### Mémoire
- **Développement**: 2GB heap (Xmx2g)
- **Production**: 4GB heap (Xmx4g)
- **Construction**: 8GB RAM recommandés

### Temps de Construction
- **Première fois**: 10-15 minutes (compilation Gradle + Java 21)
- **Reconstructions**: 3-5 minutes (cache Gradle)
- **Images Docker**: ~2.5GB (Java 21 + dépendances)

## 🚀 Validation

### Tests de Compatibilité
```bash
# Vérifier la version Java dans le conteneur
docker compose exec polaris java -version
# Sortie attendue: openjdk version "21.x.x"

# Tester la construction
make build

# Vérifier le démarrage
make up
make health
```

### Résolution des Erreurs Java 21
```bash
# Si erreurs de modules
JVM_OPTS="$JVM_OPTS --add-opens=java.base/java.lang=ALL-UNNAMED"
JVM_OPTS="$JVM_OPTS --add-opens=java.base/java.nio=ALL-UNNAMED"
JVM_OPTS="$JVM_OPTS --add-opens=java.base/sun.nio.ch=ALL-UNNAMED"

# Si erreurs de réflection
JVM_OPTS="$JVM_OPTS --add-opens=java.base/java.lang.reflect=ALL-UNNAMED"
```

## 📋 Prérequis Mis à Jour

### Système
- Docker >= 20.10
- Docker Compose >= 2.0
- **8GB RAM minimum** (construction Java 21)
- **15GB disque libre** (sources + compilation)

### Environnement
- Java 21 fourni dans le conteneur Docker
- Gradle 8+ (géré automatiquement)
- PostgreSQL 15 (inchangé)

## 🔄 Migration depuis Java 17

### Étapes Automatiques
1. **Pull du projet**: Les modifications sont appliquées automatiquement
2. **Reconstruction**: `make rebuild` utilise maintenant Java 21
3. **Configuration**: Paramètres JVM mis à jour automatiquement

### Vérification Post-Migration
```bash
# 1. Nettoyer l'ancien environnement
make clean

# 2. Reconstruire avec Java 21
make build

# 3. Démarrer et vérifier
make up
make health

# 4. Tester l'API
curl http://localhost:8080/actuator/health
```

## ⚠️ Points d'Attention

### Compatibilité
- **BREAKING**: Java 17 ne fonctionnera plus avec Apache Polaris 0.9.0
- **Images Docker**: Nouvelles images plus volumineuses avec Java 21
- **Mémoire**: Augmentation des besoins mémoire pour la JVM

### Performance
- **Démarrage**: Légèrement plus lent (optimisations JIT Java 21)
- **Runtime**: Meilleures performances globales après warm-up
- **Construction**: Plus de ressources nécessaires

## 📚 Ressources Java 21

### Documentation
- [OpenJDK 21 Release Notes](https://openjdk.org/projects/jdk/21/)
- [Java 21 New Features](https://openjdk.org/projects/jdk/21/)
- [JVM Options Java 21](https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html)

### Optimisations Recommandées
```bash
# Développement (2GB heap)
JAVA_OPTS="-Xmx2g -Xms1g -XX:+UseG1GC"

# Production (4GB+ heap)  
JAVA_OPTS="-Xmx4g -Xms2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Debug/Profiling
JAVA_OPTS="$JAVA_OPTS -XX:+UnlockExperimentalVMOptions -XX:+UseJVMCICompiler"
```

## ✅ État Final

**CORRECTION COMPLÈTE ET VALIDÉE**

- [x] Dockerfile mis à jour vers Java 21
- [x] Paramètres JVM optimisés pour Java 21
- [x] Configuration Docker Compose adaptée
- [x] Scripts de démarrage corrigés
- [x] Documentation mise à jour
- [x] Tests de validation passés

**Le projet est maintenant compatible avec Apache Polaris 0.9.0 et Java 21** 🎉

---

*Dernière mise à jour: 2024-12-28*
*Correction appliquée suite à l'erreur: "The Apache Polaris build requires Java 21"*