# BeamNG France

Site communautaire en **HTML, CSS et JavaScript vanilla**, sans framework, dépendance npm ni compilation. Nginx sert les fichiers statiques et relaie les données publiques BeamMP et Discord nécessaires à la page.

Le projet utilise directement l’image officielle `nginxinc/nginx-unprivileged`. Les sources et la configuration Nginx sont montées en lecture seule dans le conteneur : aucune image locale ni étape de build n’est nécessaire.

## Lancer le site

Prérequis sous Linux : Bash, Podman configuré en mode rootless et curl. Une connexion Internet est nécessaire au premier lancement pour télécharger l’image Nginx, puis pour consulter BeamMP et Discord. Aucune installation automatique sur l’hôte.

```sh
./start.sh
```

Ouvrir <http://localhost:3000>. Le script vérifie les prérequis, crée le conteneur s’il manque ou démarre celui qui existe. Il attend une réponse HTTP avant d’annoncer le site disponible.

```sh
./start.sh --stop       # arrêter le site
./start.sh --restart    # recharger la configuration Nginx
podman logs beamng-france-static
```

Le conteneur est rootless, sans privilèges supplémentaires, avec un système de fichiers en lecture seule et un espace temporaire en mémoire. Les dossiers `site/` et `nginx.conf` y sont montés en lecture seule. Le port est exposé uniquement sur `127.0.0.1`. Les cgroups sont désactivés pour fonctionner aussi sans session systemd utilisateur.

## Modifier le site

```text
site/
  index.html                        Accueil et liens Discord
  informations-legales/index.html  Informations accessibles depuis le footer
  styles.css                        Apparence, responsive et thèmes
  app.js                            Thème et actualisation des statistiques
  beammp.js                         Filtrage et présentation des serveurs
  assets/logo.png                   Logo affiché en rond
nginx.conf                          Serveur statique et relais BeamMP/Discord
start.sh                            Démarrage et arrêt avec Podman
tests/beammp.test.mjs               Tests du filtrage BeamMP
```

Les modifications dans `site/` sont visibles au prochain chargement de page. Après une modification de `nginx.conf`, lancer `./start.sh --restart`. Le choix clair/sombre reste en mémoire dans la page, sans cookie ni stockage local.

## Statistiques BeamMP

Le navigateur appelle `/api/beammp`, que Nginx relaie vers `https://backend.beammp.com/servers-info`. Ce petit relais est nécessaire : l’API ne fournit pas les en-têtes CORS permettant un appel direct depuis le navigateur. Il ne transmet pas les cookies ni les en-têtes des visiteurs à BeamMP.

Le panneau Discord utilise de la même façon `/api/discord-widget`, qui relaie le [widget public Discord](https://discord.com/api/guilds/828656939365957742/widget.json). Il affiche le nombre de personnes en ligne et au plus quatre pseudos connectés, sans charger d’avatars depuis Discord dans le navigateur. Le widget fournit aussi l’invitation actuelle : le site met ses liens à jour et utilise cette invitation pour obtenir le total approximatif des membres via `/api/discord-invite/…`. La carte « Plus de … membres » arrondit ce total au palier inférieur de 500. Ces données sont mises en cache cinq minutes.

Le JavaScript retient les serveurs **BeamNG France** hébergés par Slapush ainsi que les serveurs **Slapush'Server** du partenaire. Il affiche le total de joueurs connectés et les cartes distinctes. Aucun maximum de joueurs ni détail sur les mods n’est affiché.

La liste est mise en cache pendant 60 secondes côté Nginx et consultée chaque minute lorsque la page est visible. BeamMP peut également mettre ses données en cache : il ne s’agit pas d’un suivi instantané. Si l’API échoue, la page indique que les statistiques sont indisponibles et conserve les dernières valeurs reçues, sans déclarer les serveurs hors ligne.

Pour un hébergement public, placer le service derrière ton reverse proxy HTTPS. Si tu utilises un autre serveur web, servir `site/` à la racine et conserver les trois relais de même origine définis dans `nginx.conf` ; ouvrir simplement le fichier HTML ne suffit pas pour les statistiques.

## Vérifications

Avec une version récente de Node.js (v24 utilisée pour la vérification), sans installer de paquet :

```sh
node --check site/app.js
node --check site/beammp.js
node --test tests/beammp.test.mjs
bash -n start.sh
podman exec beamng-france-static nginx -t
```

## Publication du code

Le code source est publié sur [GitHub](https://github.com/Teilenh/beamngfrance-web), branche `main`. Le dépôt contient les sources à la racine (`site/`, `nginx.conf`, `start.sh`, `tests/` et ce README). Aucun fichier généré ni secret n’est nécessaire. `.gitignore` exclut les fichiers `.env` et les journaux locaux.
