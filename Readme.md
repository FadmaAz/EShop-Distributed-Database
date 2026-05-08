# 🛒 EShop - Optimisation et Fragmentation de Base de Données Distribuée

[![Oracle Database](https://img.shields.io/badge/Database-Oracle-red.svg)](https://www.oracle.com/database/)
[![PL/SQL](https://img.shields.io/badge/Language-PL%2FSQL-orange.svg)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 📝 Présentation

Ce projet porte sur la conception, l'implémentation et l'optimisation d'une **base de données distribuée** pour une plateforme de commerce électronique nommée **EShop**. L'objectif principal est de résoudre les problèmes de scalabilité et de performance d'un système centralisé en utilisant la **fragmentation horizontale** et des mécanismes de synchronisation avancés.

Le système répartit les données transactionnelles sur deux sites distincts :
- **Site 1 (Grossistes) :** Gère les commandes à fort volume (Quantité ≥ 100).
- **Site 2 (Détail) :** Gère les commandes de proximité (Quantité < 100).

## 🚀 Objectifs du Projet

- 🧩 **Fragmentation Horizontale** : Répartition de la table `LigneCommandes` selon des critères métier.
- ⚙️ **Procédures Stockées PL/SQL** : Automatisation des opérations CRUD (Create, Read, Update, Delete) sur les fragments.
- 🔄 **Triggers de Synchronisation** : Routage automatique des données vers le bon site lors des insertions ou modifications.
- 📊 **Optimisation** : Analyse des plans d'exécution et mise en place d'index pour améliorer les performances des requêtes complexes.
- 🌐 **Requêtes Distribuées** : Utilisation de `DATABASE LINKS` pour interroger l'ensemble du système de manière transparente.

## 📁 Structure du Projet

```bash
.
├── SQL/
│   ├── BDDVente1.sql        # Création de la base source
│   ├── Site-1.sql           # Configuration complète du Site 1 (fragments, contraintes, procédures)
│   ├── Site-2.sql           # Configuration complète du Site 2 (fragments, contraintes, procédures)
│   ├── triggers.sql         # Triggers de synchronisation globaux
│   └── ...                  # Autres scripts (tests, etc.)
├── Docs/
│   ├── Projet Eshop.docx    # Énoncé et consignes du projet
│   ├── rapport.docx         # Rapport technique détaillé
│   └── ...
└── README.md                # Documentation principale
```

## 🛠️ Installation & Configuration

### Prérequis
- **Docker** et **Docker Compose** installés.
- Un outil client comme **SQL Developer** ou **SQL*Plus**.

### Étapes d'installation

Pour simplifier le déploiement et la gestion des différentes instances Oracle, nous utiliserons Docker. Chaque site (global, site1, site2) sera représenté par un conteneur Oracle distinct, connectés via un réseau Docker.
Le projet propose deux scénarios de déploiement. Le **Scénario 1** est la configuration standard. Le **Scénario 2** est une configuration alternative utilisant le suffixe `S2` pour les conteneurs, utilisateurs et scripts.

---

### 🟢 Scénario 1 : Configuration Standard

1.  **Télécharger l'image Docker Oracle** :
    Nous utiliserons l'image `gvenzl/oracle-xe` qui fournit une version légère d'Oracle Database Express Edition.
    ```bash
    docker pull gvenzl/oracle-xe
    ```

2.  **Créer un réseau Docker** :
    Ce réseau permettra à vos conteneurs de communiquer entre eux.
    ```bash
    docker network create oracle-net
    ```

3.  **Lancer les conteneurs Oracle** :
    Démarrez trois conteneurs pour simuler les environnements `global`, `site1` et `site2`. Assurez-vous d'adapter les mots de passe et les ports si nécessaire.

    **Conteneur Global (BDD Principale)** :
    ```bash
    docker run -d --name oracle-tp1 --network oracle-net \
      -p 1521:1521 -p 5500:5500 \
      -e ORACLE_PASSWORD=oracle -e APP_USER=BDDVente -e APP_USER_PASSWORD=1111 \
      gvenzl/oracle-xe
    ```

    **Conteneur Site 1** :
    ```bash
    docker run -d --name oracle-site1 --network oracle-net \
      -p 1522:1521 -e ORACLE_PASSWORD=oracle -e APP_USER=site1User -e APP_USER_PASSWORD=1111 \
      gvenzl/oracle-xe
    ```

    **Conteneur Site 2** :
    ```bash
    docker run -d --name oracle-site2 --network oracle-net \
      -p 1523:1521 -e ORACLE_PASSWORD=oracle -e APP_USER=site2User -e APP_USER_PASSWORD=1111 \
      gvenzl/oracle-xe
    ```

    *Note : Les ports 1521, 1522, 1523 sont mappés sur le port 1521 interne de chaque conteneur. Les utilisateurs `BDDVente`, `site1User` et `site2User` sont créés automatiquement par l'image Docker avec les mots de passe correspondants.*

4.  **Vérifier le statut des conteneurs** :
    ```bash
    docker ps
    ```

5.  **Connexion via SQL Developer (ou autre client SQL)** :
    Pour chaque instance, utilisez les informations suivantes :
    -   **Global :** `hostname:localhost`, `port:1521`, `SID:XE`, `user:BDDVente`, `password:1111`
    -   **Site 1 :** `hostname:localhost`, `port:1522`, `SID:XE`, `user:site1User`, `password:1111`
    -   **Site 2 :** `hostname:localhost`, `port:1523`, `SID:XE`, `user:site2User`, `password:1111`

6.  **Configuration de la base globale (`oracle-tp1`)**

    **a. Création de l'utilisateur `BDDVente` et octroi des privilèges**
    Entrez dans le conteneur `oracle-tp1` en tant que `sysdba` pour créer l'utilisateur `BDDVente` et lui accorder les privilèges nécessaires. Cet utilisateur sera le propriétaire du schéma de la base de données globale.
    ```bash
    docker exec -it oracle-tp1 sqlplus / as sysdba
    ```
    Une fois dans `sqlplus`, exécutez les commandes suivantes :
    ```sql
    ALTER SESSION SET CONTAINER = XEPDB1;
    CREATE USER BDDVente IDENTIFIED BY "1111";
    GRANT CONNECT, RESOURCE, DBA TO BDDVente;
    EXIT;
    ```

    **b. Copie des scripts SQL dans le conteneur `oracle-tp1`**
    Assurez-vous d'avoir décompressé votre archive `E_Shop.zip` (ou `projet.zip` si c'est le nom de votre archive) sur votre machine locale. Ensuite, copiez le dossier contenant les scripts SQL dans le conteneur `oracle-tp1`.
    ```bash
    # Extrait le zip d'abord sur ta machine (si ce n'est pas déjà fait)
    unzip E_Shop.zip # ou unzip projet.zip

    # Copie le dossier des scripts dans le conteneur oracle-tp1
    docker cp E_Shop oracle-tp1:/tmp/E_Shop
    ```

    **c. Exécution des scripts de création de tables pour la base globale**
    Entrez dans le conteneur `oracle-tp1` et connectez-vous à `sqlplus` avec l'utilisateur `BDDVente` que vous venez de créer :
    ```bash
    docker exec -it oracle-tp1 bash
    # Une fois dans le bash du conteneur, lance sqlplus
    sqlplus BDDVente/1111@//localhost:1521/XEPDB1
    ```
    Dans `SQL*Plus`, définissez le format de date et exécutez les scripts de création de tables un par un :
    ```sql
    ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';
    @/tmp/E_Shop/categorie.sql
    @/tmp/E_Shop/Clients.sql
    @/tmp/E_Shop/Employe.sql
    @/tmp/E_Shop/Fournisseur.sql
    @/tmp/E_Shop/produits.sql
    @/tmp/E_Shop/commandes.sql
    @/tmp/E_Shop/lignecommandes.sql
    EXIT;
    ```

7.  **Configuration du Site 1 (`oracle-site1`)**

    **a. Exécution du script de configuration complet du Site 1**
    Le script `Site-1.sql` contient la création du Database Link vers la base globale, la création des tables fragmentées, les contraintes d'intégrité, ainsi que les procédures stockées (`INSERT`, `UPDATE`, `DELETE`) spécifiques au Site 1.
    ```bash
    # Copie le dossier des scripts dans le conteneur oracle-site1
    docker cp E_Shop oracle-site1:/tmp/E_Shop
    ```
    Connectez-vous à `oracle-site1` en tant que `site1User/1111` et exécutez le script :
    ```bash
    docker exec -it oracle-site1 bash
    sqlplus site1User/1111@//localhost:1521/XEPDB1
    ```
    Dans `SQL*Plus` :
    ```sql
    @/tmp/E_Shop/Site-1.sql
    EXIT;
    ```
    *Le fichier `Site-1.sql` devrait contenir des commandes similaires à celles-ci :*
    ```sql
    CREATE DATABASE LINK eshop_link
    CONNECT TO BDDVente IDENTIFIED BY "1111"
    USING '(DESCRIPTION=
              (ADDRESS=(PROTOCOL=TCP)(HOST=oracle-tp1)(PORT=1521))
              (CONNECT_DATA=(SERVICE_NAME=XEPDB1)))';

    CREATE TABLE produits1 AS
        (SELECT DISTINCT p.IDPRODUIT, p.DESIGNATION, p.IDCATEG, p.PRIXUNITAIRE
         FROM BDDVente.produits@eshop_link p, BDDVente.Lignecommandes@eshop_link lc
         WHERE p.idproduit = lc.idproduit
         AND p.idcateg = 50
         AND lc.quantite > 100);

    -- ... (autres tables fragmentées, contraintes d'intégrité et procédures CRUD)
    ```

8.  **Configuration du Site 2 (`oracle-site2`)**

    **a. Exécution du script de configuration complet du Site 2**
    Le script `Site-2.sql` contient la création du Database Link vers la base globale, la création des tables fragmentées, les contraintes d'intégrité, ainsi que les procédures stockées (`INSERT`, `UPDATE`, `DELETE`) spécifiques au Site 2.
    ```bash
    # Copie le dossier des scripts dans le conteneur oracle-site2
    docker cp E_Shop oracle-site2:/tmp/E_Shop
    ```
    Connectez-vous à `oracle-site2` en tant que `site2User/1111` et exécutez le script :
    ```bash
    docker exec -it oracle-site2 bash
    sqlplus site2User/1111@//localhost:1521/XEPDB1
    ```
    Dans `SQL*Plus` :
    ```sql
    @/tmp/E_Shop/Site-2.sql
    EXIT;
    ```
    *Le fichier `Site-2.sql` devrait contenir des commandes similaires à celles-ci :*
    ```sql
    CREATE DATABASE LINK eshop_link
    CONNECT TO BDDVente IDENTIFIED BY "1111"
    USING '(DESCRIPTION=
              (ADDRESS=(PROTOCOL=TCP)(HOST=oracle-tp1)(PORT=1521))
              (CONNECT_DATA=(SERVICE_NAME=XEPDB1)))';

    CREATE TABLE produits2 AS
        (SELECT DISTINCT p.IDPRODUIT, p.DESIGNATION, p.IDCATEG, p.PRIXUNITAIRE
         FROM BDDVente.produits@eshop_link p, BDDVente.Lignecommandes@eshop_link lc
         WHERE p.idproduit = lc.idproduit
         AND p.idcateg = 35
         AND lc.quantite > 50);

    -- ... (autres tables fragmentées, contraintes d'intégrité et procédures CRUD)
    ```

9.  **Déploiement des triggers globaux sur `oracle-tp1`**
    Une fois les sites configurés et leurs fragments créés, il est temps de déployer les triggers de synchronisation (`SYC_INSERT_LIGNE`, `SYC_DELETE_LIGNE`, `SYC_UPDATE_LIGNE`) sur la base de données globale (`oracle-tp1`). Ces triggers sont essentiels pour acheminer correctement les données vers les sites fragmentés.

    **a. Copie du script `BDDVente.sql` dans le conteneur `oracle-tp1`**
    Assurez-vous que le fichier `BDDVente.sql` est bien dans le dossier `E_Shop` sur votre machine locale, puis copiez-le dans le conteneur `oracle-tp1`.
    ```bash
    docker cp E_Shop/BDDVente.sql oracle-tp1:/tmp/E_Shop/BDDVente.sql
    ```

    **b. Exécution du script `BDDVente.sql` sur `oracle-tp1`**
    Connectez-vous à `oracle-tp1` en tant que `BDDVente/1111` et exécutez le script `BDDVente.sql`.
    ```bash
    docker exec -it oracle-tp1 bash
    sqlplus BDDVente/1111@//localhost:1521/XEPDB1
    ```
    Dans `SQL*Plus` :
    ```sql
    @/tmp/E_Shop/BDDVente.sql
    EXIT;
    ```
---

### 🔵 Scénario 2 : Configuration Alternative (Suffixe S2)

Ce scénario suit exactement la même logique que le Scénario 1, mais utilise le suffixe `S2` pour isoler cet environnement.


1.  **Télécharger l'image Docker Oracle** :
    Nous utiliserons l'image `gvenzl/oracle-xe` qui fournit une version légère d'Oracle Database Express Edition.
    ```bash
    docker pull gvenzl/oracle-xe
    ```

2.  **Créer un réseau Docker** :
    Ce réseau permettra à vos conteneurs de communiquer entre eux.
    ```bash
    docker network create oracle-net-s2
    ```

3.  **Lancer les conteneurs Oracle** :
    Démarrez trois conteneurs pour simuler les environnements `global`, `site1` et `site2`. Assurez-vous d'adapter les mots de passe et les ports si nécessaire.

    **Conteneur Global (BDD Principale)** :
    ```bash
    docker run -d --name oracle-tp1-s2 --network oracle-net-s2 \
      -p 1531:1521 -p 5500:5500 \
      -e ORACLE_PASSWORD=oracle -e APP_USER=BDDVenteS2 -e APP_USER_PASSWORD=1111 \
      gvenzl/oracle-xe
    ```

    **Conteneur Site 1** :
    ```bash
    docker run -d --name oracle-site1-s2 --network oracle-net-s2 \
      -p 1532:1521 -e ORACLE_PASSWORD=oracle -e APP_USER=site1UserS2 -e APP_USER_PASSWORD=1111 \
      gvenzl/oracle-xe
    ```

    **Conteneur Site 2** :
    ```bash
    docker run -d --name oracle-site2-s2 --network oracle-net-s2 \
      -p 1533:1521 -e ORACLE_PASSWORD=oracle -e APP_USER=site2UserS2 -e APP_USER_PASSWORD=1111 \
      gvenzl/oracle-xe
    ```

    *Note : Les ports 1531, 1532, 1533 évitent tout conflit avec le Scénario 1. Les utilisateurs BDDVenteS2, site1UserS2 et site2UserS2 sont créés automatiquement.*

4.  **Vérifier le statut des conteneurs** :
    ```bash
    docker ps
    ```

5.  **Connexion via SQL Developer (ou autre client SQL)** :
    Pour chaque instance, utilisez les informations suivantes :

    -   **Global :** `hostname:localhost`, `port:1531`, `SID:XE`, `user:BDDVenteS2`, `password:1111`
    -   **Site 1 :** `hostname:localhost`, `port:1532`, `SID:XE`, `user:site1UserS2`, `password:1111`
    -   **Site 2 :** `hostname:localhost`, `port:1533`, `SID:XE`, `user:site2UserS2`, `password:1111`

6.  **Configuration de la base globale (`oracle-tp1-s2`)**

    **a. Création de l'utilisateur `BDDVenteS2` et octroi des privilèges**
    Entrez dans le conteneur `oracle-tp1-s2` en tant que `sysdba` pour créer l'utilisateur `BDDVenteS2` et lui accorder les privilèges nécessaires. Cet utilisateur sera le propriétaire du schéma de la base de données globale.
    ```bash
    docker exec -it oracle-tp1-s2 sqlplus / as sysdba
    ```
    Une fois dans `sqlplus`, exécutez les commandes suivantes :
    ```sql
    ALTER SESSION SET CONTAINER = XEPDB1;
    CREATE USER BDDVenteS2 IDENTIFIED BY "1111";
    GRANT CONNECT, RESOURCE, DBA TO BDDVenteS2;
    EXIT;
    ```

    **b. Copie des scripts SQL dans le conteneur `oracle-tp1-s2`**
    Assurez-vous d'avoir décompressé votre archive `E_Shop.zip` (ou `projet.zip` si c'est le nom de votre archive) sur votre machine locale. Ensuite, copiez le dossier contenant les scripts SQL dans le conteneur `oracle-tp1`.
    ```bash
    # Extrait le zip d'abord sur ta machine (si ce n'est pas déjà fait)
    unzip E_Shop.zip # ou unzip projet.zip

    # Copie le dossier des scripts dans le conteneur oracle-tp1-s2
    docker cp E_Shop oracle-tp1-s2:/tmp/E_Shop
    ```

    **c. Exécution des scripts de création de tables pour la base globale**
    Entrez dans le conteneur `oracle-tp1-s2` et connectez-vous à `sqlplus` avec l'utilisateur `BDDVenteS2` que vous venez de créer :
    ```bash
    docker exec -it oracle-tp1 bash
    # Une fois dans le bash du conteneur, lance sqlplus
    sqlplus BDDVenteS2/1111@//localhost:1521/XEPDB1
    ```
    Dans `SQL*Plus`, définissez le format de date et exécutez les scripts de création de tables un par un :
    ```sql
    ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';
    @/tmp/E_Shop/categorie.sql
    @/tmp/E_Shop/Clients.sql
    @/tmp/E_Shop/Employe.sql
    @/tmp/E_Shop/Fournisseur.sql
    @/tmp/E_Shop/produits.sql
    @/tmp/E_Shop/commandes.sql
    @/tmp/E_Shop/lignecommandes.sql
    EXIT;
    ```

7.  **Configuration du Site 1 (`oracle-site1-s2`)**

    **a. Exécution du script de configuration complet du Site 1**
    Le script `Site-1-s2.sql` contient la création du Database Link vers la base globale, la création des tables fragmentées, les contraintes d'intégrité, ainsi que les procédures stockées (`INSERT`, `UPDATE`, `DELETE`) spécifiques au Site 1.
    ```bash
    # Copie le dossier des scripts dans le conteneur oracle-site1
    docker cp E_Shop oracle-site1:/tmp/E_Shop
    ```
    Connectez-vous à `oracle-site1-s2` en tant que `site1User-S2/1111` et exécutez le script :
    ```bash
    docker exec -it oracle-site1-s2 bash
    sqlplus site1UserS2/1111@//localhost:1521/XEPDB1
    ```
    Dans `SQL*Plus` :
    ```sql
    @/tmp/E_Shop/Site-1-s2.sql
    EXIT;
    ```
    *Le fichier `Site-1-s2.sql` devrait contenir des commandes similaires à celles-ci :*
    ```sql
    CREATE DATABASE LINK eshop_link
    CONNECT TO BDDVenteS2 IDENTIFIED BY "1111"
    USING '(DESCRIPTION=
              (ADDRESS=(PROTOCOL=TCP)(HOST=oracle-tp1)(PORT=1521))
              (CONNECT_DATA=(SERVICE_NAME=XEPDB1)))';

    CREATE TABLE produits1 AS
        (SELECT DISTINCT p.IDPRODUIT, p.DESIGNATION, p.IDCATEG, p.PRIXUNITAIRE
         FROM BDDVenteS2.produits@eshop_link p, BDDVenteS2.Lignecommandes@eshop_link lc
         WHERE p.idproduit = lc.idproduit
         AND p.idcateg = 50
         AND lc.quantite > 100);

    -- ... (autres tables fragmentées, contraintes d'intégrité et procédures CRUD)
    ```

8.  **Configuration du Site 2 (`oracle-site2-s2`)**

    **a. Exécution du script de configuration complet du Site 2**
    Le script `Site-2-s2.sql` contient la création du Database Link vers la base globale, la création des tables fragmentées, les contraintes d'intégrité, ainsi que les procédures stockées (`INSERT`, `UPDATE`, `DELETE`) spécifiques au Site 2.
    ```bash
    # Copie le dossier des scripts dans le conteneur oracle-site2
    docker cp E_Shop oracle-site2:/tmp/E_Shop
    ```
    Connectez-vous à `oracle-site2-s2` en tant que `site2User|S2/1111` et exécutez le script :
    ```bash
    docker exec -it oracle-site2 bash
    sqlplus site2UserS2/1111@//localhost:1521/XEPDB1
    ```
    Dans `SQL*Plus` :
    ```sql
    @/tmp/E_Shop/Site-2-s2.sql
    EXIT;
    ```
    *Le fichier `Site-2-s2.sql` devrait contenir des commandes similaires à celles-ci :*
    ```sql
    CREATE DATABASE LINK eshop_link
    CONNECT TO BDDVenteS2 IDENTIFIED BY "1111"
    USING '(DESCRIPTION=
              (ADDRESS=(PROTOCOL=TCP)(HOST=oracle-tp1)(PORT=1521))
              (CONNECT_DATA=(SERVICE_NAME=XEPDB1)))';

    CREATE TABLE produits2 AS
        (SELECT DISTINCT p.IDPRODUIT, p.DESIGNATION, p.IDCATEG, p.PRIXUNITAIRE
         FROM BDDVenteS2.produits@eshop_link p, BDDVenteS2.Lignecommandes@eshop_link lc
         WHERE p.idproduit = lc.idproduit
         AND p.idcateg = 35
         AND lc.quantite > 50);

    -- ... (autres tables fragmentées, contraintes d'intégrité et procédures CRUD)
    ```

9.  **Déploiement des triggers globaux sur `oracle-tp1-s2`**
    Une fois les sites configurés et leurs fragments créés, il est temps de déployer les triggers de synchronisation (`SYC_INSERT_LIGNE`, `SYC_DELETE_LIGNE`, `SYC_UPDATE_LIGNE`) sur la base de données globale (`oracle-tp1-s2`). Ces triggers sont essentiels pour acheminer correctement les données vers les sites fragmentés.

    **a. Copie du script `BDDVenteS2.sql` dans le conteneur `oracle-tp1-s2`**
    Assurez-vous que le fichier `BDDVenteS2.sql` est bien dans le dossier `E_Shop` sur votre machine locale, puis copiez-le dans le conteneur `oracle-tp1-s2`.
    ```bash
    docker cp E_Shop/BDDVenteS2.sql oracle-tp1-s2:/tmp/E_Shop/BDDVenteS2.sql
    ```

    **b. Exécution du script `BDDVenteS2.sql` sur `oracle-tp1-s2`**
    Connectez-vous à `oracle-tp1-s2` en tant que `BDDVenteS2/1111` et exécutez le script `BDDVenteS2.sql`.
    ```bash
    docker exec -it oracle-tp1-s2 bash
    sqlplus BDDVenteS2/1111@//localhost:1521/XEPDB1
    ```
    Dans `SQL*Plus` :
    ```sql
    @/tmp/E_Shop/BDDVenteS2.sql
    EXIT;
    ```
---
