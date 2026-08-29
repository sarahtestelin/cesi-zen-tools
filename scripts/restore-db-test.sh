#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "Erreur : fichier .env introuvable."
  exit 1
fi

set -a
source .env
set +a

BACKUP_FILE="${1:-$(ls -t backups/*.dump 2>/dev/null | head -1)}"

if [ -z "${BACKUP_FILE:-}" ] || [ ! -f "$BACKUP_FILE" ]; then
  echo "Erreur : aucune sauvegarde .dump trouvée."
  exit 1
fi

CONTAINER="cesizen-postgres-restore-test"
VOLUME="cesizen_restore_test_data"
IMAGE="cesizen-postgres-alpine-hardened:latest"

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker volume rm "$VOLUME" >/dev/null 2>&1 || true
}

trap cleanup EXIT

cleanup

echo "Démarrage de la base PostgreSQL temporaire..."

docker run -d \
  --name "$CONTAINER" \
  -e POSTGRES_DB \
  -e POSTGRES_USER \
  -e POSTGRES_PASSWORD \
  -v "$VOLUME:/var/lib/postgresql/data" \
  "$IMAGE" >/dev/null

echo "Attente de PostgreSQL..."

until docker exec "$CONTAINER" sh -c \
  'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1
do
  sleep 1
done

echo "Restauration de $BACKUP_FILE..."

START_TIME=$(date +%s)

docker exec -i "$CONTAINER" sh -c \
  'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges' \
  < "$BACKUP_FILE"

END_TIME=$(date +%s)
RESTORE_TIME=$((END_TIME - START_TIME))

RESTORED_TABLES=$(docker exec "$CONTAINER" sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT COUNT(*) FROM pg_tables WHERE schemaname='\''public'\'';"')

RESTORED_USERS=$(docker exec "$CONTAINER" sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT COUNT(*) FROM app_user;"')

SOURCE_TABLES=$(docker compose exec -T db sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT COUNT(*) FROM pg_tables WHERE schemaname='\''public'\'';"')

SOURCE_USERS=$(docker compose exec -T db sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT COUNT(*) FROM app_user;"')

echo "Base source     : $SOURCE_TABLES tables / $SOURCE_USERS utilisateurs"
echo "Base restaurée  : $RESTORED_TABLES tables / $RESTORED_USERS utilisateurs"
echo "Temps restauration : ${RESTORE_TIME}s"

if [ "$SOURCE_TABLES" != "$RESTORED_TABLES" ] || [ "$SOURCE_USERS" != "$RESTORED_USERS" ]; then
  echo "Erreur : incohérence détectée après restauration."
  exit 1
fi

echo "Test PRA réussi : sauvegarde restaurée et données cohérentes."
