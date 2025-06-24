# Makefile pour Apache Polaris avec PostgreSQL

.PHONY: help build up down logs restart clean status health

# Variables
COMPOSE_FILE = docker-compose.yml
PROJECT_NAME = polaris

# Couleurs pour les messages
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

help: ## Affiche cette aide
	@echo "$(GREEN)Apache Polaris avec PostgreSQL - Commandes disponibles:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

build: ## Construire les images Docker
	@echo "$(GREEN)Construction des images Docker...$(NC)"
	./build-polaris.sh

up: ## Démarrer tous les services
	@echo "$(GREEN)Démarrage des services...$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) up -d
	@echo "$(GREEN)Services démarrés!$(NC)"
	@echo "$(YELLOW)Polaris UI: http://localhost:8080$(NC)"
	@echo "$(YELLOW)PgAdmin: http://localhost:8081$(NC)"

down: ## Arrêter tous les services
	@echo "$(RED)Arrêt des services...$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) down

stop: ## Arrêter les services sans supprimer les conteneurs
	@echo "$(YELLOW)Arrêt des services...$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) stop

start: ## Redémarrer les services existants
	@echo "$(GREEN)Redémarrage des services...$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) start

restart: ## Redémarrer tous les services
	@echo "$(YELLOW)Redémarrage complet...$(NC)"
	$(MAKE) down
	$(MAKE) up

logs: ## Afficher les logs de tous les services
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs -f

logs-polaris: ## Afficher les logs de Polaris uniquement
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs -f polaris

logs-postgres: ## Afficher les logs de PostgreSQL uniquement
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs -f postgres

status: ## Afficher le statut des services
	@echo "$(GREEN)Statut des services:$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) ps

health: ## Vérifier la santé des services
	@echo "$(GREEN)Vérification de la santé des services:$(NC)"
	@echo "$(YELLOW)PostgreSQL:$(NC)"
	@docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec postgres pg_isready -U polaris || echo "$(RED)PostgreSQL non disponible$(NC)"
	@echo "$(YELLOW)Polaris:$(NC)"
	@curl -s -f http://localhost:8080/health > /dev/null && echo "$(GREEN)Polaris OK$(NC)" || echo "$(RED)Polaris non disponible$(NC)"

shell-polaris: ## Accéder au shell du conteneur Polaris
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec polaris /bin/bash

shell-postgres: ## Accéder au shell PostgreSQL
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec postgres psql -U polaris -d polaris

backup-db: ## Sauvegarder la base de données
	@echo "$(GREEN)Sauvegarde de la base de données...$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec postgres pg_dump -U polaris -d polaris > backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)Sauvegarde terminée!$(NC)"

restore-db: ## Restaurer la base de données (nécessite BACKUP_FILE=fichier.sql)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(RED)Erreur: Spécifiez le fichier de sauvegarde avec BACKUP_FILE=fichier.sql$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Restauration de la base de données depuis $(BACKUP_FILE)...$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec -T postgres psql -U polaris -d polaris < $(BACKUP_FILE)
	@echo "$(GREEN)Restauration terminée!$(NC)"

clean: ## Nettoyer complètement (ATTENTION: supprime les données)
	@echo "$(RED)ATTENTION: Cette commande va supprimer tous les conteneurs, volumes et données!$(NC)"
	@read -p "Êtes-vous sûr? (oui/non): " confirm && [ "$$confirm" = "oui" ] || exit 1
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) down -v --remove-orphans
	docker system prune -f
	docker volume prune -f

clean-images: ## Supprimer les images Docker
	@echo "$(YELLOW)Suppression des images Docker...$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) down --rmi all

rebuild: ## Reconstruire et redémarrer tous les services
	@echo "$(GREEN)Reconstruction complète...$(NC)"
	$(MAKE) down
	BUILD_METHOD=clean ./build-polaris.sh
	$(MAKE) up

dev: ## Mode développement avec rechargement automatique
	@echo "$(GREEN)Démarrage en mode développement...$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) up --build

production: ## Démarrage en mode production
	@echo "$(GREEN)Démarrage en mode production...$(NC)"
	export COMPOSE_FILE=docker-compose.prod.yml && $(MAKE) up

monitor: ## Surveiller l'utilisation des ressources
	@echo "$(GREEN)Surveillance des ressources:$(NC)"
	docker stats $(shell docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) ps -q)

update: ## Mettre à jour les images Docker
	@echo "$(GREEN)Mise à jour des images...$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) pull
	$(MAKE) restart

config: ## Valider la configuration Docker Compose
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) config

test: ## Exécuter les tests de connectivité
	@echo "$(GREEN)Tests de connectivité...$(NC)"
	@echo "Test PostgreSQL..."
	@docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec postgres psql -U polaris -d polaris -c "SELECT version();" || echo "$(RED)Erreur PostgreSQL$(NC)"
	@echo "Test Polaris API..."
	@curl -s -f http://localhost:8080/api/v1/catalogs > /dev/null && echo "$(GREEN)API Polaris OK$(NC)" || echo "$(RED)API Polaris non disponible$(NC)"

install: ## Installation initiale complète
	@echo "$(GREEN)Installation d'Apache Polaris...$(NC)"
	@echo "1. Création des répertoires de configuration..."
	mkdir -p config init-scripts
	@echo "2. Vérification des fichiers de configuration..."
	@ls -la config/ init-scripts/ || echo "Répertoires créés"
	chmod +x polaris-start.sh build-polaris.sh 2>/dev/null || true
	@echo "3. Construction des images..."
	BUILD_METHOD=hybrid ./build-polaris.sh
	@echo "4. Démarrage des services..."
	$(MAKE) up
	@echo "$(GREEN)Installation terminée!$(NC)"

init-dev: ## Initialisation pour le développement
	@echo "$(GREEN)Initialisation de l'environnement de développement...$(NC)"
	mkdir -p config init-scripts logs data
	@echo "$(YELLOW)Créez les fichiers de configuration dans le dossier config/$(NC)"
	@echo "$(YELLOW)Placez les scripts d'initialisation dans init-scripts/$(NC)"

inspect: ## Inspecter la configuration réseau
	@echo "$(GREEN)Inspection de la configuration réseau:$(NC)"
	docker network ls | grep polaris || echo "Réseau Polaris non trouvé"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Commandes de maintenance
maintenance-start: ## Démarrer la maintenance (arrêt de Polaris)
	@echo "$(YELLOW)Mode maintenance activé$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) stop polaris

maintenance-end: ## Terminer la maintenance (redémarrage de Polaris)
	@echo "$(GREEN)Fin du mode maintenance$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) start polaris

# Commandes d'analyse
analyze-logs: ## Analyser les logs pour les erreurs
	@echo "$(GREEN)Analyse des logs...$(NC)"
	@echo "$(YELLOW)Erreurs dans Polaris:$(NC)"
	@docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs polaris 2>&1 | grep -i error || echo "Aucune erreur trouvée"
	@echo "$(YELLOW)Erreurs dans PostgreSQL:$(NC)"
	@docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs postgres 2>&1 | grep -i error || echo "Aucune erreur trouvée"

check-ports: ## Vérifier les ports utilisés
	@echo "$(GREEN)Ports utilisés:$(NC)"
	@echo "$(YELLOW)Port 8080 (Polaris):$(NC)"
	@lsof -i :8080 || echo "Port 8080 libre"
	@echo "$(YELLOW)Port 5432 (PostgreSQL):$(NC)"
	@lsof -i :5432 || echo "Port 5432 libre"
	@echo "$(YELLOW)Port 8081 (PgAdmin):$(NC)"
	@lsof -i :8081 || echo "Port 8081 libre"

# Commandes utilitaires
reset-db: ## Réinitialiser la base de données
	@echo "$(RED)ATTENTION: Cette commande va supprimer toutes les données!$(NC)"
	@read -p "Êtes-vous sûr? (oui/non): " confirm && [ "$$confirm" = "oui" ] || exit 1
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) stop polaris
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec postgres psql -U polaris -d polaris -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) start polaris

show-env: ## Afficher les variables d'environnement
	@echo "$(GREEN)Variables d'environnement:$(NC)"
	docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec polaris env | grep -E "(DB_|POLARIS_|JAVA_)" || echo "Variables non trouvées"

# Aide par défaut
.DEFAULT_GOAL := help
