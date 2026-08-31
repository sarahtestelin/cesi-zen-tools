# Procédure de rollback — CESIZen

## Objectif

Cette procédure décrit comment revenir à une version précédente de l’application lorsqu’un déploiement introduit une régression.

## Principe

Le rollback repose sur Git et Docker :

1. identifier le commit problématique ;
2. créer un commit d’annulation avec `git revert` ;
3. reconstruire l’image Docker ;
4. redéployer le service ;
5. vérifier que la version précédente fonctionne de nouveau.

## Test réalisé

Un test réel a été effectué sur le frontend CESIZen.

Une modification volontaire du titre HTML a été créée et commitée :

`c86a780 test: add rollback marker`

La version modifiée a ensuite été construite et déployée avec Docker Compose.

La présence de la nouvelle version a été vérifiée avec :

`curl -s http://localhost:4300 | grep "<title>"`

Résultat :

`<title>CesiZenFront Rollback Test</title>`

Le rollback a ensuite été effectué avec :

`git revert --no-edit c86a780`

Git a créé le commit :

`0b47dee Revert "test: add rollback marker"`

L’image frontend a été reconstruite puis redéployée.

La vérification finale a retourné :

`<title>CesiZenFront</title>`

Le rollback a donc permis de restaurer correctement la version précédente sans modification de la base de données.

## Limites

Ce scénario valide un rollback applicatif sans migration de données.

En présence d’une évolution de schéma PostgreSQL incompatible, une procédure spécifique de restauration de base doit être appliquée en complément du rollback applicatif.
