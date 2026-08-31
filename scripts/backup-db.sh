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

mkdir -p backups

BACKUP_FILE="backups/cesizen-$(date +%Y%m%d-%H%M%S).dump"

echo "Sauvegarde PostgreSQL en cours..."

docker compose exec -T db sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom' \
  > "$BACKUP_FILE"

if [ ! -s "$BACKUP_FILE" ]; then
  echo "Erreur : la sauvegarde est vide."
  rm -f "$BACKUP_FILE"
  exit 1
fi

docker compose exec -T db pg_restore --list < "$BACKUP_FILE" > /dev/null

echo "Sauvegarde valide créée : $BACKUP_FILE"
