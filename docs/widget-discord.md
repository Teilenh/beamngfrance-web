# Adapter le widget Discord

Le panneau Discord de l’accueil utilise le widget public du serveur. Il affiche le nombre de personnes en ligne et une estimation du nombre total de membres.

## Ce qu’il faut préparer

- activer le widget public dans les réglages du serveur Discord ;
- relever l’identifiant du serveur ;
- définir une invitation permanente comme invitation du widget ;
- vérifier que l’invitation mène bien au même serveur.

## Changer de serveur Discord

### 1. Modifier la source Nginx

Dans `nginx.conf`, remplacer l’identifiant présent dans l’URL du widget :

```nginx
proxy_pass https://discord.com/api/guilds/IDENTIFIANT_DU_SERVEUR/widget.json;
```

### 2. Modifier la validation JavaScript

Dans `site/app.js`, rechercher l’identifiant actuel `828656939365957742` et remplacer toutes ses occurrences. Cette vérification empêche une réponse inattendue d’un autre serveur d’être affichée.

### 3. Modifier l’invitation de secours

Rechercher `https://discord.gg/DRcuhcj2JW` dans :

- `site/index.html` ;
- `site/informations-legales/index.html`.

Remplacer chaque occurrence par l’invitation permanente du nouveau serveur. Remplacer également la valeur de `inviteCode` dans `site/app.js`, utilisée pour obtenir le nombre approximatif de membres.

## Comment les données circulent

1. La page appelle `/api/discord-widget`.
2. Nginx demande le widget public à Discord et garde la réponse en cache cinq minutes.
3. `site/app.js` vérifie l’identifiant du serveur et affiche le nombre de personnes en ligne.
4. La page appelle `/api/discord-invite/CODE` avec l’invitation configurée pour obtenir le nombre approximatif de membres.
5. Nginx relaie cet appel vers l’API Discord et le résultat alimente la carte « Plus de … membres ».

En cas d’échec, la page garde la dernière valeur valide et affiche un message d’indisponibilité.

## Repères dans le HTML

| Élément | Utilité |
| --- | --- |
| `#discord-online-count` | Nombre de personnes actuellement en ligne. |
| `#discord-widget-message` | État du chargement ou message d’erreur. |
| `#discord-member-range` | Estimation arrondie du nombre total de membres. |

Conserver ces attributs et identifiants si le texte ou la mise en page du panneau change.

## Ajuster le comportement

Les valeurs suivantes se trouvent dans `site/app.js` :

| Réglage | Valeur actuelle | Effet |
| --- | --- | --- |
| Fréquence Discord | `300000` ms | Actualisation toutes les cinq minutes. |
| Délai maximal | `12000` ms | Abandon d’un appel après douze secondes. |
| Palier des membres | `500` | Arrondit l’estimation au palier inférieur de 500. |

Les couleurs, espacements et règles responsive du panneau se trouvent dans `site/styles.css` autour des sélecteurs `.discord-widget` et `.discord-widget-count`.

## Vérifier l’adaptation

1. Ouvrir `/api/discord-widget` et confirmer que le JSON contient le bon identifiant et `presence_count`.
2. Ouvrir `/api/discord-invite/CODE` avec le code de l’invitation et confirmer la présence de `approximate_member_count`.
3. Recharger l’accueil et vérifier le compteur ainsi que le message de mise à jour.
4. Contrôler les liens Discord du header, du bouton principal et du footer.
5. Vérifier la console du navigateur et l’affichage sur mobile.

Le compteur des personnes en ligne peut différer du nombre total de membres du serveur.
