# BeamNG France

Site communautaire en **HTML, CSS et JavaScript vanilla**, sans framework, dépendance npm ni compilation. Le conteneur Nginx sert les fichiers et relaie les données publiques BeamMP et Discord.

## Lancer le site

Prérequis sous Linux : Bash, Podman configuré en mode rootless, curl et les outils système habituels (`sha256sum`, `find`, `sort`, `xargs`). Une connexion Internet est nécessaire au premier lancement pour télécharger l’image Nginx, puis pour consulter BeamMP. Aucune installation automatique sur l’hôte.

```sh
./start.sh
```

Ouvrir <http://localhost:3000>. Le script vérifie les prérequis, construit l’image si les sources ont changé, puis crée ou démarre le conteneur. Il attend une réponse HTTP avant d’annoncer le site disponible.

```sh
./start.sh --stop       # arrêter le site
./start.sh --rebuild    # forcer la reconstruction
PORT=3001 ./start.sh    # utiliser un autre port local
podman logs beamng-france-static
```

Le conteneur est rootless, sans privilèges supplémentaires, avec un système de fichiers en lecture seule et un espace temporaire en mémoire. Il n’a aucun volume de données. Le port est exposé uniquement sur `127.0.0.1`. Les cgroups sont désactivés pour fonctionner aussi sans session systemd utilisateur.

## Modifier le site

```text
site/
  index.html                     Accueil et liens Discord
  informations-legales/index.html Informations accessibles depuis le footer
  styles.css                     Apparence, responsive et thèmes
  app.js                         Thème et actualisation des statistiques
  beammp.js                      Filtrage et présentation des serveurs
  assets/logo.png                Logo affiché en rond
nginx.conf                       Serveur statique et relais BeamMP
Containerfile                    Image Nginx sans étape de compilation
start.sh                         Démarrage et arrêt avec Podman
tests/beammp.test.mjs             Tests du filtrage (Node facultatif)
```

Modifier les fichiers puis relancer `./start.sh` : seuls l’image et le conteneur de ce projet sont remplacés si nécessaire. Le choix clair/sombre reste en mémoire dans la page, sans cookie ni stockage local.

## Statistiques BeamMP

Le navigateur appelle `/api/beammp`, que Nginx relaie vers `https://backend.beammp.com/servers-info`. Ce petit relais est nécessaire : l’API ne fournit pas les en-têtes CORS permettant un appel direct depuis le navigateur. Il ne transmet pas les cookies ni les en-têtes des visiteurs à BeamMP.

Le panneau Discord utilise de la même façon `/api/discord-widget`, qui relaie le [widget public Discord](https://discord.com/api/guilds/828656939365957742/widget.json). Il affiche le nombre de personnes en ligne et au plus quatre pseudos connectés, sans charger d’avatars depuis Discord dans le navigateur. Le widget ne fournit pas le nombre total de membres : la carte « Plus de … membres » utilise `/api/discord-invite`, un relais vers l’[invitation publique Discord](https://discord.com/api/v10/invites/h9RD9KW8?with_counts=true). Son total est approximatif et la carte l’arrondit au palier inférieur de 500. Ces données sont mises en cache cinq minutes. Les liens du site utilisent le code d’invitation `h9RD9KW8` défini dans les fichiers HTML et Nginx.

Le JavaScript retient les serveurs **BeamNG France** hébergés par Slapush ainsi que les serveurs **Slapush'Server** du partenaire. Il affiche le total de joueurs connectés et les cartes distinctes. Aucun maximum de joueurs ni détail sur les mods n’est affiché.

La liste est mise en cache pendant 60 secondes côté Nginx et consultée chaque minute lorsque la page est visible. BeamMP peut également mettre ses données en cache : il ne s’agit pas d’un suivi instantané. Si l’API échoue, la page indique que les statistiques sont indisponibles et conserve les dernières valeurs reçues, sans déclarer les serveurs hors ligne.

Pour un hébergement public, placer le service derrière ton reverse proxy HTTPS. Si tu utilises un autre serveur web, servir `site/` à la racine et conserver les trois relais de même origine définis dans `nginx.conf` ; ouvrir simplement le fichier HTML ne suffit pas pour les statistiques.

## Tests facultatifs

Avec une version récente de Node.js (v24 utilisée pour la vérification), sans installer de paquet :

```sh
node --test tests/beammp.test.mjs
```

## Publication du code

Le dépôt à publier contient les sources à la racine (`site/`, `nginx.conf`, `Containerfile`, `start.sh`, `tests/` et ce README). Aucun fichier généré ni secret n’est nécessaire. `.gitignore` exclut les fichiers `.env` et les journaux locaux. Ajouter le dépôt distant GitHub et pousser uniquement quand il aura été créé et que son adresse sera connue.
