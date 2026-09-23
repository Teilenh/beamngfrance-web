# BeamNG France

Site vitrine de la communauté BeamNG France. La page est écrite en HTML, CSS et JavaScript.

Elle présente le Discord, les serveurs BeamMP actifs et quelques informations sur la communauté. Les données publiques de Discord et BeamMP passent par Nginx pour rester accessibles depuis la même origine que le site.

## Mettre le site en ligne

1. Servir le dossier `site/` à la racine du domaine.
2. Reprendre les relais `/api/beammp`, `/api/discord-widget` et `/api/discord-invite/…` de `nginx.conf`.
3. Placer le domaine derrière HTTPS.

Ouvrir directement `site/index.html` permet de voir la mise en page, mais pas de charger les statistiques.

Guides :

- [Comprendre et adapter la configuration Nginx](docs/nginx.md)
- [Adapter le widget Discord](docs/widget-discord.md)

## Où modifier quoi

| Besoin | Fichier |
| --- | --- |
| Textes, liens et structure de l’accueil | `site/index.html` |
| Apparence, thèmes et responsive | `site/styles.css` |
| Actualisation des données Discord et BeamMP | `site/app.js` |
| Sélection et affichage des serveurs BeamMP | `site/beammp.js` |
| Mentions et informations légales | `site/informations-legales/index.html` |
| Relais API et cache | `nginx.conf` |

Les statistiques sont rafraîchies toutes les minutes pour BeamMP et toutes les cinq minutes pour Discord. Si une API ne répond plus, la page conserve les dernières valeurs reçues et indique que les données sont indisponibles.

## Vérifier avant publication

- charger l’accueil sur mobile et sur ordinateur ;
- tester le changement de thème et les liens Discord ;
- vérifier que `/api/beammp` et `/api/discord-widget` renvoient du JSON ;
- confirmer que les serveurs attendus apparaissent et qu’aucune erreur ne remonte dans la console ;
- recharger Nginx après toute modification de `nginx.conf`.

Code source : [github.com/Teilenh/beamngfrance-web](https://github.com/Teilenh/beamngfrance-web)
