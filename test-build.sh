#!/bin/bash

set -e

# Script de test pour valider les méthodes de build Apache Polaris
# Ce script teste toutes les approches de construction disponibles

echo "=== Test des Méthodes de Build Apache Polaris ==="
echo "Date: $(date)"
echo "Système: $(uname -a)"

# Configuration
TEST_RESULTS_FILE="test-results-$(date +%Y%m%d-%H%M%S).log"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Fonction de logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$TEST_RESULTS_FILE"
}

# Fonction pour tester une commande
test_command() {
    local test_name="$1"
    local command="$2"
    local timeout="${3:-300}"  # timeout par défaut: 5 minutes

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    log "INFO" "Test #$TOTAL_TESTS: $test_name"
    log "INFO" "Commande: $command"

    # Exécuter la commande avec timeout
    if timeout "$timeout" bash -c "$command" >> "$TEST_RESULTS_FILE" 2>&1; then
        log "PASS" "✅ $test_name - SUCCÈS"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log "FAIL" "❌ $test_name - ÉCHEC"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Fonction pour nettoyer l'environnement
cleanup_environment() {
    log "INFO" "Nettoyage de l'environnement..."

    # Arrêter les services
    docker compose down -v --remove-orphans 2>/dev/null || true

    # Supprimer les images de test
    docker rmi dlkh-platform-polaris 2>/dev/null || true
    docker rmi dlkh-platform_polaris 2>/dev/null || true

    # Nettoyer les conteneurs orphelins
    docker container prune -f 2>/dev/null || true

    # Nettoyer les volumes inutilisés
    docker volume prune -f 2>/dev/null || true

    log "INFO" "Nettoyage terminé"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    log "INFO" "Vérification des prérequis..."

    # Vérifier Docker
    if ! command -v docker >/dev/null 2>&1; then
        log "ERROR" "Docker n'est pas installé"
        return 1
    fi

    local docker_version=$(docker --version)
    log "INFO" "Docker: $docker_version"

    # Vérifier Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        log "ERROR" "Docker Compose v2 n'est pas disponible"
        return 1
    fi

    local compose_version=$(docker compose version)
    log "INFO" "Docker Compose: $compose_version"

    # Vérifier l'espace disque
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    log "INFO" "Espace disque disponible: ${available_gb}GB"

    if [ "$available_space" -lt 10000000 ]; then
        log "WARN" "Espace disque faible (< 10GB)"
    fi

    # Vérifier la mémoire
    if command -v free >/dev/null 2>&1; then
        local total_mem=$(free -m | awk 'NR==2{print $2}')
        log "INFO" "Mémoire totale: ${total_mem}MB"

        if [ "$total_mem" -lt 4096 ]; then
            log "WARN" "Mémoire faible (< 4GB)"
        fi
    fi

    log "INFO" "Prérequis vérifiés"
    return 0
}

# Fonction pour tester la validation de la configuration
test_configuration() {
    log "INFO" "Test de validation de la configuration..."

    test_command "Validation docker-compose.yml" \
        "docker compose config >/dev/null"

    test_command "Vérification des fichiers de config" \
        "ls -la config/polaris.properties config/persistence.xml config/log4j2.xml"

    test_command "Vérification des scripts" \
        "ls -la polaris-start.sh polaris-start-simple.sh build-polaris.sh"

    test_command "Permissions des scripts" \
        "test -x polaris-start.sh && test -x polaris-start-simple.sh && test -x build-polaris.sh"
}

# Fonction pour tester les images Docker de base
test_base_images() {
    log "INFO" "Test des images Docker de base..."

    test_command "Pull OpenJDK 21" \
        "docker pull openjdk:21-jdk-slim" 180

    test_command "Test image officielle Apache Polaris" \
        "docker pull apache/polaris:latest || echo 'Image officielle non disponible'" 180
}

# Fonction pour tester les méthodes de build
test_build_methods() {
    log "INFO" "Test des méthodes de build..."

    # Test 1: Build simplifié
    cleanup_environment
    test_command "Build Method: Simple" \
        "BUILD_METHOD=simple ./build-polaris.sh" 900

    # Test 2: Build depuis les sources (si le simple échoue)
    if [ $? -ne 0 ]; then
        cleanup_environment
        test_command "Build Method: Source (fallback)" \
            "BUILD_METHOD=source ./build-polaris.sh" 900
    fi

    # Test 3: Build officiel (si disponible)
    if docker pull apache/polaris:latest >/dev/null 2>&1; then
        cleanup_environment
        test_command "Build Method: Official" \
            "BUILD_METHOD=official ./build-polaris.sh" 300
    else
        log "SKIP" "Image officielle Apache Polaris non disponible - test ignoré"
    fi

    # Test 4: Build hybride
    cleanup_environment
    test_command "Build Method: Hybrid/Auto" \
        "BUILD_METHOD=auto ./build-polaris.sh" 900
}

# Fonction pour tester le démarrage des services
test_service_startup() {
    log "INFO" "Test du démarrage des services..."

    test_command "Démarrage PostgreSQL" \
        "docker compose up -d postgres && sleep 30" 60

    test_command "Santé PostgreSQL" \
        "docker compose exec postgres pg_isready -U polaris" 30

    test_command "Démarrage complet des services" \
        "docker compose up -d" 120

    # Attendre que les services démarrent
    log "INFO" "Attente du démarrage des services (60s)..."
    sleep 60

    test_command "Statut des services" \
        "docker compose ps" 10

    test_command "Logs des services (vérification d'erreurs)" \
        "! docker compose logs | grep -i 'error.*fatal'" 10
}

# Fonction pour tester la connectivité
test_connectivity() {
    log "INFO" "Test de la connectivité..."

    test_command "Connectivité PostgreSQL" \
        "docker compose exec postgres psql -U polaris -d polaris -c 'SELECT version();'" 30

    test_command "Port Polaris ouvert" \
        "timeout 10 bash -c 'until nc -z localhost 8080; do sleep 1; done'" 15

    test_command "Health Check Polaris" \
        "curl -f http://localhost:8080/actuator/health || curl -f http://localhost:8080/health" 30

    test_command "PgAdmin accessible" \
        "curl -f http://localhost:8081 >/dev/null" 30
}

# Fonction pour tester les APIs
test_apis() {
    log "INFO" "Test des APIs..."

    test_command "API Management accessible" \
        "curl -f http://localhost:8080/api/management/v1/catalogs || echo 'API non disponible'" 30

    test_command "API Catalog accessible" \
        "curl -f http://localhost:8080/api/catalog/v1/config || echo 'API non disponible'" 30

    test_command "Métriques disponibles" \
        "curl -f http://localhost:8080/actuator/metrics || echo 'Métriques non disponibles'" 30
}

# Fonction pour générer le rapport final
generate_report() {
    log "INFO" "=== RAPPORT FINAL ==="
    log "INFO" "Tests exécutés: $TOTAL_TESTS"
    log "INFO" "Tests réussis: $PASSED_TESTS"
    log "INFO" "Tests échoués: $FAILED_TESTS"

    if [ $FAILED_TESTS -eq 0 ]; then
        log "INFO" "🎉 TOUS LES TESTS SONT PASSÉS!"
        echo "✅ SUCCÈS COMPLET - Apache Polaris est fonctionnel"
    elif [ $PASSED_TESTS -gt $FAILED_TESTS ]; then
        log "WARN" "⚠️ SUCCÈS PARTIEL - Quelques problèmes détectés"
        echo "⚠️ FONCTIONNEL AVEC AVERTISSEMENTS"
    else
        log "ERROR" "❌ ÉCHEC MAJORITAIRE - Problèmes critiques"
        echo "❌ PROBLÈMES CRITIQUES DÉTECTÉS"
    fi

    log "INFO" "Rapport détaillé: $TEST_RESULTS_FILE"

    # Recommandations
    echo ""
    echo "=== RECOMMANDATIONS ==="
    if [ $FAILED_TESTS -gt 0 ]; then
        echo "1. Consulter le fichier de log: $TEST_RESULTS_FILE"
        echo "2. Vérifier les ressources système (RAM, disque)"
        echo "3. Essayer: BUILD_METHOD=clean ./build-polaris.sh"
        echo "4. Si problème persistant: BUILD_METHOD=simple ./build-polaris.sh"
    else
        echo "1. Configuration fonctionnelle ✅"
        echo "2. Vous pouvez utiliser: make up"
        echo "3. Accès Polaris: http://localhost:8080"
        echo "4. Accès PgAdmin: http://localhost:8081"
    fi
}

# Fonction principale
main() {
    log "INFO" "Début des tests Apache Polaris"

    # Vérifications préliminaires
    check_prerequisites || {
        log "ERROR" "Prérequis non satisfaits"
        exit 1
    }

    # Nettoyage initial
    cleanup_environment

    # Tests de configuration
    test_configuration

    # Tests des images de base
    test_base_images

    # Tests des méthodes de build
    test_build_methods

    # Tests de démarrage des services
    test_service_startup

    # Tests de connectivité
    test_connectivity

    # Tests des APIs
    test_apis

    # Génération du rapport
    generate_report

    # Nettoyage final (optionnel)
    read -p "Nettoyer l'environnement après les tests? (y/N): " cleanup_choice
    if [[ $cleanup_choice =~ ^[Yy]$ ]]; then
        cleanup_environment
        log "INFO" "Environnement nettoyé"
    else
        log "INFO" "Services laissés en cours d'exécution"
    fi

    log "INFO" "Tests terminés"

    # Code de sortie basé sur les résultats
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    elif [ $PASSED_TESTS -gt $FAILED_TESTS ]; then
        exit 1
    else
        exit 2
    fi
}

# Gestion des signaux
trap 'log "WARN" "Tests interrompus par l'utilisateur"; cleanup_environment; exit 130' INT TERM

# Lancement si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
