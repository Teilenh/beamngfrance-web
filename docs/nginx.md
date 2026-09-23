# Configuration Nginx locale

Le fichier `nginx.conf` sert le dossier `site/` et relaie trois API publiques. Cette page explique les options présentes afin de pouvoir l’adapter sans casser les statistiques.

## Serveur statique

| Option | Rôle | Quand la modifier |
| --- | --- | --- |
| `listen 8080` | Port écouté par Nginx. | Si l’hébergeur attend un autre port. |
| `server_name _` | Accepte tous les noms d’hôte. | Remplacer `_` par le domaine si Nginx reçoit directement le trafic public. |
| `root /usr/share/nginx/html` | Dossier contenant `index.html`. | Si les fichiers du site sont installés ailleurs. |
| `index index.html` | Fichier servi pour un dossier. | À conserver avec la structure actuelle. |
| `charset utf-8` | Envoie le bon encodage pour les textes français. | À conserver. |
| `server_tokens off` | Masque la version de Nginx dans les réponses. | À conserver. |
| `access_log off` | Désactive le journal de chaque visite. | L’activer temporairement pour diagnostiquer un problème de routage. |

La route `/` sert uniquement les fichiers existants avec `try_files`. La route exacte `/informations-legales` renvoie la page située dans `site/informations-legales/index.html`.

## Cache des API

La directive suivante crée le cache partagé utilisé par les trois relais :

```nginx
proxy_cache_path /tmp/beamng-cache levels=1:2 keys_zone=public_api:1m max_size=20m inactive=5m;
```

| Paramètre | Effet |
| --- | --- |
| `/tmp/beamng-cache` | Emplacement des fichiers de cache. Le processus Nginx doit pouvoir y écrire. |
| `levels=1:2` | Répartit les fichiers dans des sous-dossiers. |
| `keys_zone=public_api:1m` | Réserve 1 Mo de mémoire pour les clés du cache nommé `public_api`. |
| `max_size=20m` | Limite les fichiers en cache à 20 Mo. |
| `inactive=5m` | Supprime les réponses qui n’ont pas été utilisées depuis cinq minutes. |

`proxy_cache_key $uri` sépare les réponses par chemin. Le code d’invitation Discord fait partie du chemin, donc chaque invitation possède sa propre entrée.

Les réponses BeamMP restent en cache 60 secondes. Les réponses Discord restent en cache 300 secondes. Le navigateur reçoit `Cache-Control: no-store` : Nginx peut ainsi mutualiser les appels sans laisser le navigateur afficher longtemps une ancienne réponse.

## Réglages communs aux relais

| Option | Rôle |
| --- | --- |
| `proxy_ssl_server_name on` | Envoie le nom du serveur pendant la connexion TLS à l’API distante. |
| `proxy_ssl_verify on` | Vérifie le certificat de l’API distante. |
| `proxy_ssl_verify_depth 3` | Autorise une chaîne de certificats allant jusqu’à trois niveaux. |
| `proxy_ssl_trusted_certificate …` | Indique le fichier local contenant les autorités de certification. Son chemin dépend du système. |
| `proxy_set_header Host $proxy_host` | Envoie à l’API le nom d’hôte attendu. |
| `proxy_pass_request_headers off` | Ne transmet pas les en-têtes du visiteur. |
| `proxy_pass_request_body off` | Ne transmet aucun corps de requête. |
| `proxy_connect_timeout 5s` | Abandonne une connexion distante trop lente après cinq secondes. |
| `proxy_read_timeout 10s` | Abandonne la lecture si l’API ne répond pas dans les dix secondes. |
| `proxy_cache_lock on` | Évite plusieurs appels identiques lorsque le cache expire. |
| `proxy_hide_header …` | Retire les cookies et consignes de cache envoyés par l’API distante. |

Chaque relais accepte uniquement `GET` grâce à `limit_except GET { deny all; }`.

## Les trois relais

### BeamMP

`/api/beammp` relaie `https://backend.beammp.com/servers-info`. Modifier l’adresse uniquement si BeamMP change son API publique. Le fichier `site/beammp.js` attend la structure JSON actuelle.

### Widget Discord

`/api/discord-widget` relaie le widget public du serveur Discord. L’identifiant du serveur se trouve dans l’URL :

```nginx
proxy_pass https://discord.com/api/guilds/828656939365957742/widget.json;
```

La procédure complète pour changer de serveur se trouve dans [Adapter le widget Discord](widget-discord.md).

### Invitation Discord

`/api/discord-invite/CODE` récupère le nombre approximatif de membres associé à l’invitation fournie par le widget. L’expression régulière n’accepte que les caractères utilisés par Discord et limite le code à 32 caractères. La destination reste fixée à `discord.com`.

## Adapter la configuration à un hébergeur

Vérifier ces points :

1. le chemin de `root` correspond au dossier publié ;
2. le port de `listen` correspond au port attendu par l’hébergeur ;
3. le fichier indiqué par `proxy_ssl_trusted_certificate` existe ;
4. le dossier de cache est accessible en écriture ;
5. le domaine public utilise HTTPS ;
6. les trois chemins `/api/…` arrivent bien sur ce serveur Nginx.

Après une modification :

```sh
nginx -t
nginx -s reload
```

Puis vérifier les deux sources principales :

```sh
curl http://localhost:8080/api/beammp
curl http://localhost:8080/api/discord-widget
```

Adapter le port des commandes à l’installation locale.
