# PRA / PCA — CESIZen

## 1. Objectif

Ce document décrit les mesures prévues pour assurer la sauvegarde, la restauration et la continuité de service de CESIZen en cas d’incident.

L’environnement actuel repose sur Docker Compose avec :
- une application Spring Boot ;
- un frontend Angular ;
- une base PostgreSQL 16 ;
- un volume Docker persistant pour les données PostgreSQL.

## 2. PRA — Plan de Reprise d’Activité

### Risques couverts

Le PRA couvre principalement :
- la perte ou la corruption de la base PostgreSQL ;
- une erreur lors d’un déploiement ;
- l’indisponibilité du conteneur PostgreSQL ;
- la nécessité de restaurer les données depuis une sauvegarde.

### Sauvegarde PostgreSQL

Un script automatisé est disponible : `./scripts/backup-db.sh`

Il réalise :
- le chargement des variables depuis `.env` ;
- un `pg_dump` de la base PostgreSQL ;
- la création d’une archive au format `custom` dans `backups/` ;
- la vérification que le fichier n’est pas vide ;
- la validation de l’archive avec `pg_restore --list`.

Les fichiers présents dans `backups/` sont exclus du dépôt Git afin d’éviter de versionner des données applicatives.

### Test de restauration

Un second script permet de vérifier automatiquement qu’une sauvegarde peut réellement être restaurée : `./scripts/restore-db-test.sh`

Le script :
- sélectionne la sauvegarde la plus récente ;
- démarre une instance PostgreSQL temporaire et isolée ;
- restaure le dump avec `pg_restore` ;
- compare les données principales entre la base source et la base restaurée ;
- supprime automatiquement le conteneur et le volume de test.

La base active n’est donc jamais modifiée pendant ce contrôle.

### Test réellement réalisé

Le test effectué le 29/08/2026 a donné :
- base source : 12 tables publiques / 15 utilisateurs ;
- base restaurée : 12 tables publiques / 15 utilisateurs ;
- aucune erreur pendant la restauration ;
- durée de restauration du dump : moins d’une seconde sur le jeu de données actuel.

Ce temps correspond uniquement à la restauration du dump et ne constitue pas le RTO complet du système.

### RPO et RTO

Le RPO dépend de la fréquence des sauvegardes.

Par exemple, avec une sauvegarde quotidienne, la perte maximale théorique de données est de 24 heures.

Le RTO complet doit prendre en compte :
- le diagnostic de l’incident ;
- la mise à disposition de l’infrastructure ;
- la restauration de PostgreSQL ;
- le redémarrage du backend et du frontend ;
- les contrôles fonctionnels après reprise.

Il n’est donc pas limité au seul temps mesuré par `pg_restore`.

## 3. PCA — Plan de Continuité d’Activité

L’architecture actuelle est une architecture mono-instance et ne met pas en œuvre de haute disponibilité automatique.

En cas d’indisponibilité d’un conteneur, la continuité repose sur :
- Docker Compose pour redémarrer les services ;
- les healthchecks pour contrôler leur état ;
- les images Docker reproductibles ;
- le code et la configuration versionnés dans Git ;
- la possibilité de reconstruire l’application depuis les dépôts ;
- les sauvegardes PostgreSQL pour restaurer les données si nécessaire.

La solution ne garantit donc pas une continuité sans interruption. Le PCA vise principalement à réduire le temps de reprise et à rendre les opérations reproductibles.

## 4. Procédure en cas d’incident PostgreSQL

1. Identifier et qualifier l’incident.
2. Éviter toute opération destructive sur la base ou le volume existant.
3. Identifier la dernière sauvegarde valide.
4. Tester la sauvegarde sur une instance PostgreSQL isolée.
5. Vérifier la cohérence des données restaurées.
6. Restaurer l’environnement cible si nécessaire.
7. Redémarrer les services CESIZen.
8. Contrôler le healthcheck backend et l’accès au frontend.
9. Effectuer des contrôles fonctionnels.
10. Documenter l’incident et les actions réalisées dans l’outil de suivi.

## 5. Sécurité des sauvegardes

Les sauvegardes :
- ne sont pas versionnées dans Git ;
- peuvent contenir des données personnelles et doivent être protégées ;
- doivent être stockées sur un emplacement sécurisé dans un environnement réel ;
- doivent faire l’objet de tests de restauration réguliers.

Les secrets et mots de passe ne sont pas écrits directement dans les scripts : ils sont chargés depuis le fichier `.env`.

## 6. Améliorations prévues

Les évolutions possibles sont :
- la planification automatique des sauvegardes ;
- le stockage externe et sécurisé des dumps ;
- une politique de rétention des sauvegardes ;
- le chiffrement des sauvegardes ;
- la surveillance des échecs de sauvegarde ;
- des tests réguliers de restauration ;
- une infrastructure redondante pour améliorer le PCA ;
- la mesure complète d’un RTO lors d’un scénario de reprise global.

La migration éventuelle de l’image PostgreSQL Debian vers une image Alpine durcie devra être réalisée par sauvegarde et restauration dans une nouvelle instance, et non par réutilisation directe du volume PostgreSQL existant.
