# BeamNG France

Site communautaire en **HTML, CSS et JavaScript vanilla**, sans framework, dépendance npm ni compilation. Nginx sert les fichiers statiques et relaie les données publiques BeamMP et Discord nécessaires à la page.

Le site ne demande aucun runtime applicatif ni étape de build.

## Déploiement

Servir le contenu de `site/` à la racine du domaine et reprendre les trois relais de même origine définis dans `nginx.conf` :

- `/api/beammp` pour la liste publique des serveurs ;
- `/api/discord-widget` pour l’activité du Discord ;
- `/api/discord-invite/…` pour le nombre approximatif de membres.

Le service public doit être placé derrière HTTPS. Ouvrir directement `index.html` ne permet pas de charger les statistiques, car ces relais doivent rester sur la même origine que la page.

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
start.sh                            Aide facultative pour une prévisualisation locale
tests/beammp.test.mjs               Tests du filtrage BeamMP
```

Les modifications dans `site/` sont visibles au prochain chargement de page. Une modification de `nginx.conf` nécessite un rechargement du serveur web. Le choix clair/sombre reste en mémoire dans la page, sans cookie ni stockage local.

## Statistiques BeamMP

Le navigateur appelle `/api/beammp`, que Nginx relaie vers `https://backend.beammp.com/servers-info`. Ce petit relais est nécessaire : l’API ne fournit pas les en-têtes CORS permettant un appel direct depuis le navigateur. Il ne transmet pas les cookies ni les en-têtes des visiteurs à BeamMP.

Le panneau Discord utilise de la même façon `/api/discord-widget`, qui relaie le [widget public Discord](https://discord.com/api/guilds/828656939365957742/widget.json). Il affiche le nombre de personnes en ligne et au plus quatre pseudos connectés, sans charger d’avatars depuis Discord dans le navigateur. Le widget fournit aussi l’invitation actuelle : le site met ses liens à jour et utilise cette invitation pour obtenir le total approximatif des membres via `/api/discord-invite/…`. La carte « Plus de … membres » arrondit ce total au palier inférieur de 500. Ces données sont mises en cache cinq minutes.

Le JavaScript retient les serveurs **BeamNG France** hébergés par Slapush ainsi que les serveurs **Slapush'Server** du partenaire. Il affiche le total de joueurs connectés et les cartes distinctes. Aucun maximum de joueurs ni détail sur les mods n’est affiché.

La liste est mise en cache pendant 60 secondes côté Nginx et consultée chaque minute lorsque la page est visible. BeamMP peut également mettre ses données en cache : il ne s’agit pas d’un suivi instantané. Si l’API échoue, la page indique que les statistiques sont indisponibles et conserve les dernières valeurs reçues, sans déclarer les serveurs hors ligne.

## Publication du code

Le code source est publié sur [GitHub](https://github.com/Teilenh/beamngfrance-web), branche `main`. Le dépôt contient les sources à la racine (`site/`, `nginx.conf`, `start.sh`, `tests/` et ce README). Aucun fichier généré ni secret n’est nécessaire. `.gitignore` exclut les fichiers `.env` et les journaux locaux.
