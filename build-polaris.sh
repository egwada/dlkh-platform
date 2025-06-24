#!/bin/bash

set -e

# Script de build alternatif pour Apache Polaris
# Ce script permet de choisir entre différentes approches de build

BUILD_METHOD="${BUILD_METHOD:-auto}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"

echo "=== Apache Polaris Build Script ==="
echo "BUILD_METHOD: $BUILD_METHOD"
echo "DOCKERFILE: $DOCKERFILE"

# Fonction pour tester si une image Docker existe
test_docker_image() {
    local image="$1"
    echo "Test de l'image Docker: $image"
    if docker pull "$image" >/dev/null 2>&1; then
        echo "✅ Image $image disponible"
        return 0
    else
        echo "❌ Image $image non disponible"
        return 1
    fi
}

# Fonction pour construire depuis les sources
build_from_source() {
    echo "=== Construction depuis les sources ==="
    echo "Utilisation du Dockerfile principal..."
    docker compose build --no-cache polaris
}

# Fonction pour construire avec le Dockerfile simplifié
build_simple() {
    echo "=== Construction avec Dockerfile simplifié ==="
    echo "Utilisation de Dockerfile.simple..."
    docker build -f Dockerfile.simple -t dlkh-platform-polaris .
}

# Fonction pour utiliser l'image officielle
build_from_official() {
    echo "=== Utilisation de l'image officielle ==="
    echo "Utilisation de Dockerfile.official..."
    docker compose -f docker-compose.yml build --no-cache polaris
}

# Fonction pour build hybride
build_hybrid() {
    echo "=== Build hybride ==="

    # Tenter l'image officielle d'abord
    if test_docker_image "apache/polaris:latest"; then
        echo "Utilisation de l'image officielle Apache Polaris"
        export DOCKERFILE="Dockerfile.official"
        build_from_official
    else
        echo "Image officielle non disponible, tentative avec Dockerfile simplifié"
        if build_simple; then
            echo "✅ Construction simplifiée réussie"
        else
            echo "Construction simplifiée échouée, tentative avec Dockerfile principal"
            build_from_source
        fi
    fi
}

# Fonction pour nettoyer avant le build
clean_build() {
    echo "=== Nettoyage avant build ==="
    docker system prune -f
    docker compose down -v --remove-orphans 2>/dev/null || true
}

# Fonction principale
main() {
    case "$BUILD_METHOD" in
        "official")
            build_from_official
            ;;
        "source")
            build_from_source
            ;;
        "simple")
            build_simple
            ;;
        "hybrid"|"auto")
            build_hybrid
            ;;
        "clean")
            clean_build
            build_hybrid
            ;;
        *)
            echo "❌ Méthode de build inconnue: $BUILD_METHOD"
            echo "Méthodes disponibles: official, source, simple, hybrid, auto, clean"
            exit 1
            ;;
    esac
}

# Gestion des erreurs
handle_error() {
    echo "❌ Erreur durant le build"
    echo "Tentative de diagnostic..."

    # Afficher les logs Docker
    echo "=== Logs Docker Compose ==="
    docker compose logs polaris 2>/dev/null || echo "Pas de logs disponibles"

    # Suggestions de correction
    echo ""
    echo "=== Suggestions de correction ==="
    echo "1. Vérifier l'espace disque disponible:"
    echo "   df -h"
    echo ""
    echo "2. Augmenter la mémoire Docker:"
    echo "   Docker Desktop > Settings > Resources > Memory (8GB recommandés)"
    echo ""
    echo "3. Nettoyer Docker:"
    echo "   docker system prune -a -f"
    echo ""
    echo "4. Essayer une méthode de build différente:"
    echo "   BUILD_METHOD=simple ./build-polaris.sh"
    echo "   BUILD_METHOD=official ./build-polaris.sh"
    echo "   BUILD_METHOD=source ./build-polaris.sh"
    echo ""
    echo "5. Vérifier les prérequis:"
    echo "   - Docker >= 20.10"
    echo "   - Docker Compose >= 2.0"
    echo "   - 8GB RAM disponible"
    echo "   - 15GB espace disque libre"

    exit 1
}

# Configuration du gestionnaire d'erreurs
trap handle_error ERR

# Vérifications préliminaires
echo "=== Vérifications préliminaires ==="

# Vérifier Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

# Vérifier Docker Compose
if ! docker compose version >/dev/null 2>&1; then
    echo "❌ Docker Compose v2 n'est pas disponible"
    echo "Installer avec: sudo apt-get install docker-compose-plugin"
    exit 1
fi

# Vérifier l'espace disque
AVAILABLE_SPACE=$(df . | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -lt 15000000 ]; then
    echo "⚠️ Avertissement: Espace disque faible (< 15GB)"
    echo "Espace disponible: $(df -h . | awk 'NR==2 {print $4}')"
fi

echo "✅ Vérifications passées"

# Exécution du build
main

echo ""
echo "=== Build terminé avec succès! ==="
echo "Démarrer les services avec:"
echo "  make up"
echo "ou"
echo "  docker compose up -d"
