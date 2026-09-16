# MétéoCarnet Mali — version serveur (Node.js + PostgreSQL)

Cette version remplace le stockage d'artefact Claude par une vraie base de données
PostgreSQL que vous contrôlez entièrement, servie par un petit serveur Node.js.
Elle fonctionne sur votre Windows Server 2019, avec ou sans connexion à Claude.

Architecture :

```
Navigateur (public/index.html)  →  Serveur Node.js (server/)  →  PostgreSQL (le vôtre)
                                                                        ↑
                                                                    pgAdmin
                                                          (pour consulter/administrer)
```

## 1. Prérequis (une seule fois)

- **Node.js** installé sur le serveur (version 18 ou plus récente) — https://nodejs.org
- **PostgreSQL** installé et accessible (local sur le même serveur, ou distant)
- **pgAdmin** pour créer la base et exécuter le script SQL

## 2. Créer la base de données

Dans pgAdmin :

1. Créez une nouvelle base, par exemple `meteocarnet`.
2. Ouvrez l'outil de requête ("Query Tool") sur cette base.
3. Ouvrez le fichier `server/schema.sql` de ce dossier, copiez-collez son contenu, exécutez.
   Cela crée les tables : `stations`, `carnet_days`, `mensuel`, `users`, `session`.

Vous pouvez à tout moment rouvrir ces tables dans pgAdmin pour consulter ou corriger
des données directement en SQL — c'est justement l'intérêt d'une vraie base.

## 3. Configurer les identifiants (jamais partagés, restent chez vous)

Dans le dossier `server/` :

1. Copiez `.env.example` en `.env`.
2. Ouvrez `.env` et remplissez vos vraies valeurs (connexion PostgreSQL, port, secret de
   session — voir les sections suivantes pour HTTPS et le compte administrateur).

Ce fichier `.env` ne doit **jamais** être envoyé à qui que ce soit ni poussé sur Git
(le `.gitignore` fourni l'exclut déjà automatiquement).

## 4. Lancer l'application

**Deux façons de la démarrer, selon le besoin :**

### A. Test rapide (manuel)

Double-cliquez sur **`start.bat`**.

- La première fois, il installe automatiquement les dépendances Node (`npm install`).
- Il ouvre aussi le port dans le pare-feu Windows automatiquement s'il est lancé
  en tant qu'administrateur (sinon, faites-le une fois « en tant qu'administrateur »).
- Il affiche l'adresse à ouvrir, y compris celle utilisable depuis les autres
  postes du réseau.

⚠️ Ce mode ne survit pas à un redémarrage du serveur ni à la fermeture de la
fenêtre : c'est fait pour tester, pas pour la production.

### B. Production sur le serveur (recommandé) : installation en service Windows

Pour que l'application démarre **toute seule** à chaque redémarrage du serveur,
**même si personne n'est connecté**, et se **relance automatiquement si elle plante** :

1. Faites un clic droit sur **`install-service.bat`** → *Exécuter en tant
   qu'administrateur*.
2. C'est tout : le script crée une tâche planifiée Windows « MeteoCarnetMali »
   (démarrage automatique + relance toutes les 5 min si arrêtée) ainsi qu'une
   tâche de surveillance « MeteoCarnetMali-Watchdog » qui vérifie toutes les
   3 minutes que le site **répond vraiment** (pas juste que le processus
   existe), ouvre le pare-feu, et démarre immédiatement.
3. À partir de là, l'application tourne en permanence en arrière-plan (vous
   n'avez plus besoin de `start.bat`, ni de garder une fenêtre ouverte).

Scripts fournis pour gérer ce service au quotidien :

| Script | Effet |
|---|---|
| `service-status.bat` | Affiche si la tâche planifiée tourne |
| `restart-service.bat` | Redémarre l'application (après une modif du `.env` par ex.) |
| `stop-service.bat` | Arrête l'application |
| `view-logs.bat` | Affiche les dernières lignes des journaux (`logs/out.log`, `logs/err.log`) |
| `uninstall-service.bat` | Supprime les tâches planifiées (à exécuter en administrateur) |

Vous pouvez aussi le gérer via le **Planificateur de tâches** de Windows
(`taskschd.msc`, tâches « MeteoCarnetMali » et « MeteoCarnetMali-Watchdog »).

**Port utilisé : 9555** par défaut (configuré dans `server/.env`, réglé volontairement
sur 9555 plutôt que 3000 pour éviter les conflits avec les autres applications déjà
présentes sur ce serveur). Le pare-feu Windows est ouvert automatiquement sur ce port
par `install-service.bat` (et par `start.bat` si lancé en administrateur), afin que
l'application soit accessible depuis **toutes les machines du réseau du serveur**,
à l'adresse `http://<IP_DU_SERVEUR>:9555`.

Si PostgreSQL tourne sur ce même serveur, `install-service.bat` affiche une commande
optionnelle pour faire dépendre le service de celui de PostgreSQL, afin qu'il démarre
toujours après lui au redémarrage.

## 5. Connexion et comptes utilisateurs

L'application demande désormais une connexion. Au tout premier démarrage, un compte
administrateur est créé automatiquement — regardez la fenêtre du serveur, vous y verrez :

```
 Premier compte administrateur créé automatiquement :
   Utilisateur : admin
   Mot de passe : ...
```

Notez ce mot de passe (ou définissez le vôtre à l'avance dans `.env` via `ADMIN_PASSWORD`
et `ADMIN_USERNAME`). Connectez-vous, puis créez les comptes de votre équipe dans l'onglet
**Utilisateurs** (visible uniquement pour les administrateurs) :

- **Administrateur** : voit tout, y compris qui a saisi chaque relevé, quand, et depuis où
  (heure + position GPS de la saisie).
- **Observateur** : peut saisir/consulter les données météo normalement, mais ne voit
  jamais ces informations de localisation/horodatage — réservées aux administrateurs,
  pour le suivi de l'équipe. Ne peut pas non plus ajouter/archiver des stations ni gérer
  les comptes.

## 6. Activer le HTTPS (nécessaire pour la géolocalisation hors de ce serveur)

Par défaut (`ENABLE_HTTPS=false`), l'application tourne en HTTP simple sur le port
9555 — le plus simple pour un usage sur réseau local. Les navigateurs bloquent
cependant la géolocalisation sur un site non sécurisé (sauf `localhost`) : si vous
voulez que la fonction « qui/où/quand a saisi une heure » (visible par les admins)
fonctionne aussi **depuis d'autres postes** que le serveur lui-même, activez le HTTPS.

Dans `server/.env` :

```
ENABLE_HTTPS=true
HTTPS_PORT=9556
```

Puis relancez le service (`restart-service.bat`, ou relancez `install-service.bat`
en administrateur pour que le pare-feu s'ouvre aussi automatiquement sur le port 9556).

Un certificat auto-signé est généré automatiquement au premier démarrage (dossier
`server/certs/`, jamais envoyé sur Git). Ouvrez ensuite **https://<IP_DU_SERVEUR>:9556**
depuis un autre poste. L'ancien port 9555 continue de fonctionner mais redirige
automatiquement vers HTTPS.

La première fois, le navigateur affichera un avertissement ("connexion non privée") car
le certificat n'est pas signé par une autorité reconnue — normal pour un usage interne.
Deux façons de gérer ça :

- **Le plus simple** : cliquez sur "Avancé" puis "Continuer quand même" — à refaire une
  fois par navigateur/appareil.
- **Plus propre** (aucun avertissement) : installez `server/certs/cert.pem` comme
  certificat de confiance sur les postes de votre équipe. Sous Windows, en Administrateur :
  ```
  certutil -addstore -f "ROOT" server\certs\cert.pem
  ```

Si un jour le serveur a un vrai nom de domaine public, un certificat gratuit et reconnu
(Let's Encrypt) devient possible — dites-le-moi le moment venu, la configuration diffère.

## 7. Scan IA des photos (optionnel)

Le bouton "Analyser avec l'IA" ne fonctionne que si vous ajoutez votre propre clé
dans `.env` :

```
ANTHROPIC_API_KEY=sk-ant-votre-cle
```

Cette clé se crée sur https://console.anthropic.com et est facturée à l'usage
(quelques centimes par photo environ), séparément d'un abonnement Claude.ai.
Sans cette clé, tout le reste de l'application fonctionne normalement — seul
le scan est désactivé, avec un message clair à l'écran.

La clé reste uniquement dans `server/.env`, jamais envoyée au navigateur ni
visible dans le code source de la page — c'est le serveur qui l'utilise en votre nom.

## 8. Mettre le code sur Git (avec votre propre compte)

Depuis ce dossier, dans un terminal :

```
git init
git add .
git commit -m "MétéoCarnet Mali - version serveur"
git remote add origin <URL_DE_VOTRE_DEPOT>
git push -u origin main
```

Le fichier `.env` et le dossier `server/certs/` (vos identifiants et votre certificat)
ne seront jamais inclus grâce au `.gitignore`. Sur le serveur qui récupère (`git pull`),
il faudra recréer le `.env` manuellement une fois (étape 3), puisqu'il n'est
volontairement jamais versionné.

## 9. Archiver une station

Le bouton "Archiver" (onglet Stations, réservé aux administrateurs) ne supprime rien :
la station disparaît de la liste active mais tous ses jours et tableaux mensuels restent
intacts en base. Une section "Stations archivées" permet de la réactiver à tout moment.

Une vraie suppression définitive (avec cascade sur toutes les données) reste possible
manuellement, en dernier recours, directement dans pgAdmin avec une requête SQL
(`DELETE FROM stations WHERE id = '...'`) — volontairement non proposée comme un
simple bouton dans l'application.

## 10. Sauvegardes

Deux niveaux, complémentaires :

- **Dans l'app** : bouton "Télécharger une sauvegarde complète" (onglet Stations) —
  pratique pour une copie rapide.
- **Niveau base de données** (recommandé en plus, pas à la place) : PostgreSQL a son
  propre outil de sauvegarde professionnel, `pg_dump`. Exemple de commande à planifier
  (Tâche planifiée Windows) :

  ```
  pg_dump -U postgres -d meteocarnet -F c -f sauvegarde_meteocarnet.dump
  ```

  C'est la vraie garantie de fond — la sauvegarde JSON de l'app est un filet
  complémentaire, pas un substitut.

## Structure du dossier

```
meteocarnet-server/
├── server/
│   ├── server.js        (le serveur : API, auth, HTTPS, fichiers web)
│   ├── auth.js           (sessions, mots de passe, rôles admin/observateur)
│   ├── https-cert.js     (génération du certificat auto-signé)
│   ├── db.js              (connexion PostgreSQL)
│   ├── schema.sql        (à exécuter une fois dans pgAdmin)
│   ├── package.json
│   └── .env.example      (copier en .env et remplir — port 9555 par défaut)
├── public/
│   └── index.html        (l'application, servie par server.js)
├── start.bat              (test rapide manuel)
├── install-service.bat    (production : installe le service Windows — clic droit "Exécuter en tant qu'administrateur")
├── uninstall-service.bat  (supprime le service Windows)
├── restart-service.bat    (redémarre le service)
├── stop-service.bat       (arrête le service)
├── service-status.bat     (affiche l'état du service)
├── view-logs.bat          (affiche les derniers journaux)
├── tools/                 (nssm.exe, téléchargé automatiquement — pas versionné)
├── logs/                  (out.log / err.log du service — pas versionné)
├── .gitignore
└── README.md              (ce fichier)
```
