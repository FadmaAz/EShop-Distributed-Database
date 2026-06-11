CREATE DATABASE LINK site1_link
CONNECT TO Site1UserS2 IDENTIFIED BY "1111"
USING '(DESCRIPTION=
          (ADDRESS=(PROTOCOL=TCP)(HOST=oracle-site1)(PORT=1521))
          (CONNECT_DATA=(SERVICE_NAME=XEPDB1)))';
          
CREATE DATABASE LINK site2_link
CONNECT TO Site2UserS2 IDENTIFIED BY "1111"
USING '(DESCRIPTION=
          (ADDRESS=(PROTOCOL=TCP)(HOST=oracle-site2)(PORT=1521))
          (CONNECT_DATA=(SERVICE_NAME=XEPDB1)))';
          

--auto incrementaion de ligne de commande 
DECLARE
    v_max NUMBER;
BEGIN
    -- On récupère le plus grand ID actuel
    SELECT NVL(MAX(idlignecommande), 0) INTO v_max FROM lignecommandes;
    -- On crée la séquence qui commence juste après
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_lignecommande START WITH ' || (v_max + 1) || ' INCREMENT BY 1';
END;
/


-- triggers

CREATE OR REPLACE TRIGGER "SYC_INSERT_LIGNE"
BEFORE INSERT ON lignecommandes
FOR EACH ROW
DECLARE
    Cat          produits.idcateg%TYPE;
    NQ           lignecommandes.quantite%TYPE := :NEW.quantite;
    nc           INTEGER;
    np           INTEGER;
    v_stock      produits.unitesenstock%TYPE;
BEGIN
    -- Auto-incrémentation de l'ID si non fourni
    IF :NEW.idlignecommande IS NULL THEN
        :NEW.idlignecommande := seq_lignecommande.NEXTVAL;
    END IF;

    -- 1. Vérifier que le produit existe
    SELECT COUNT(*) INTO np FROM produits WHERE idproduit = :NEW.idproduit;
    IF (np = 0) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Produit inexistant');
    END IF;

    -- 2. Vérifier que la commande existe
    SELECT COUNT(*) INTO nc FROM commandes WHERE idcommande = :NEW.idcommande;
    IF (nc = 0) THEN
        RAISE_APPLICATION_ERROR(-20002, 'Commande inexistante');
    END IF;

    -- 3. Vérifier que le stock est suffisant
    SELECT unitesenstock INTO v_stock 
    FROM produits 
    WHERE idproduit = :NEW.idproduit;

    IF (v_stock < NQ) THEN
        RAISE_APPLICATION_ERROR(-20003, 
            'Stock insuffisant ! Stock disponible : ' || v_stock || 
            ' | Quantité demandée : ' || NQ
        );
    END IF;

    -- 4. Décrémenter le stock
    UPDATE produits 
    SET unitesenstock = unitesenstock - NQ
    WHERE idproduit = :NEW.idproduit;

    -- 5. Distribuer vers Site1 ou Site2
    SELECT idcateg INTO Cat FROM produits WHERE idproduit = :NEW.idproduit;

    BEGIN
        IF (NQ >= 100) THEN
            INSERTligne@site1_link(
                :NEW.idlignecommande, :NEW.idcommande,
                :NEW.idproduit, :NEW.quantite, :NEW.remise
            );
        ELSIF ( NQ < 100) THEN
            INSERTligne@site2_link(
                :NEW.idlignecommande, :NEW.idcommande,
                :NEW.idproduit, :NEW.quantite, :NEW.remise
            );
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Attention : Site distant injoignable. Ligne stockée uniquement en local.');
    END;
END;
/


-- ============================================================
-- TRIGGER SYC_DELETE_LIGNE
-- Distribue les DELETE vers site1 ou site2 selon la catégorie
-- ============================================================
CREATE OR REPLACE TRIGGER "SYC_DELETE_LIGNE"
BEFORE DELETE ON lignecommandes
FOR EACH ROW
DECLARE
    v_Cat  produits.idcateg%TYPE; -- On utilise la table Produits
    v_OQ   lignecommandes.quantite%TYPE := :OLD.quantite;
BEGIN
    -- 1. Récupérer la catégorie du produit supprimé
    SELECT idcateg INTO v_Cat FROM produits WHERE idproduit = :OLD.idproduit;

    -- 2. Remettre la quantité dans le stock (puisque la ligne est supprimée)
    UPDATE produits 
    SET unitesenstock = unitesenstock + v_OQ 
    WHERE idproduit = :OLD.idproduit;

    -- 3. Supprimer sur les sites distants avec protection
    BEGIN
        IF ( v_OQ >= 100) THEN
            DELETEligne@site1_link(:OLD.idlignecommande);
        ELSIF ( v_OQ < 100) THEN
            DELETEligne@site2_link(:OLD.idlignecommande);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Attention : Impossible de supprimer sur le site distant (Site injoignable)');
    END;
END;
/




-- ============================================================
-- TRIGGER SYC_UPDATE_LIGNE
-- Le plus complexe : gère le cas où un produit change de catégorie
--
-- Cas 1 : ancien produit categ=50 (site1)
--   → Si nouveau produit toujours categ=50 : update dans site1
--   → Sinon : delete de site1, et si nouveau categ=35 : insert dans site2
--
-- Cas 2 : ancien produit categ=35 (site2)
--   → Si nouveau produit toujours categ=35 : update dans site2
--   → Sinon : delete de site2, et si nouveau categ=50 : insert dans site1
--
-- Cas 3 : ancien produit hors fragment (ni 50 ni 35)
--   → Si nouveau categ=50 : insert dans site1
--   → Si nouveau categ=35 : insert dans site2
-- ============================================================
CREATE OR REPLACE TRIGGER syc_update_line
BEFORE UPDATE ON lignecommandes
FOR EACH ROW
DECLARE
    OP   produits.idproduit%TYPE  := :OLD.idproduit;
    NP   produits.idproduit%TYPE  := :NEW.idproduit;
    OQ   lignecommandes.quantite%TYPE := :OLD.quantite;
    NQ   lignecommandes.quantite%TYPE := :NEW.quantite;
    OCat produits.idcateg%TYPE;
    NCat produits.idcateg%TYPE;
    nc   INTEGER;
    v_prod_count INTEGER;
    v_stock produits.unitesenstock%TYPE;
BEGIN
    IF (:NEW.idlignecommande <> :OLD.idlignecommande) THEN
        RAISE_APPLICATION_ERROR(-20004, 'Modification de idlignecommande interdite');
    END IF;

    IF (NQ <= 0) THEN
        RAISE_APPLICATION_ERROR(-20005, 'La quantite doit etre positive');
    END IF;

    SELECT COUNT(*) INTO v_prod_count FROM produits WHERE idproduit = NP;
    IF (v_prod_count = 0) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Produit inexistant');
    END IF;

    SELECT COUNT(*) INTO nc FROM commandes WHERE idcommande = :NEW.idcommande;
    IF (nc = 0) THEN
        RAISE_APPLICATION_ERROR(-20002, 'Commande inexistante');
    END IF;

    UPDATE produits
    SET unitesenstock = unitesenstock + OQ
    WHERE idproduit = OP;

    SELECT unitesenstock INTO v_stock FROM produits WHERE idproduit = NP;
    IF (v_stock < NQ) THEN
        RAISE_APPLICATION_ERROR(
            -20003,
            'Stock insuffisant ! Stock disponible : ' || v_stock ||
            ' | Quantite demandee : ' || NQ
        );
    END IF;

    UPDATE produits
    SET unitesenstock = unitesenstock - NQ
    WHERE idproduit = NP;

    SELECT idcateg INTO OCat FROM produits WHERE idproduit = OP;
    SELECT idcateg INTO NCat FROM produits WHERE idproduit = NP;

    BEGIN

    -- CAS 1 : La ligne était dans Site1 (categ=50, quantite>100)
    IF ( OQ >= 100) THEN

        IF (NQ >= 100) THEN
            -- Reste dans Site1 : mise à jour
            updateligne@site1_link(
                :NEW.idlignecommande,
                :NEW.idcommande,
                :NEW.idproduit,
                :NEW.quantite,
                :NEW.remise
            );
        ELSE
            -- Quitte Site1 : suppression
            DELETEligne@site1_link(:OLD.idlignecommande);

            -- Peut-être va dans Site2
            IF (NQ < 100) THEN
                INSERTligne@site2_link(
                    :NEW.idlignecommande,
                    :NEW.idcommande,
                    :NEW.idproduit,
                    :NEW.quantite,
                    :NEW.remise
                );
            END IF;
        END IF;

    -- CAS 2 : La ligne était dans Site2 (categ=35, quantite>50)
    ELSIF ( OQ < 100) THEN

        IF ( NQ < 100) THEN
            -- Reste dans Site2 : mise à jour
            updateligne@site2_link(
                :NEW.idlignecommande,
                :NEW.idcommande,
                :NEW.idproduit,
                :NEW.quantite,
                :NEW.remise
            );
        ELSE
            -- Quitte Site2 : suppression
            DELETEligne@site2_link(:OLD.idlignecommande);

            -- Peut-être va dans Site1
            IF ( NQ >= 100) THEN
                INSERTligne@site1_link(
                    :NEW.idlignecommande,
                    :NEW.idcommande,
                    :NEW.idproduit,
                    :NEW.quantite,
                    :NEW.remise
                );
            END IF;
        END IF;

    -- CAS 3 : La ligne n'était dans aucun fragment
    -- (nouveau produit peut entrer dans un fragment)
    ELSIF ( NQ >= 100) THEN
        INSERTligne@site1_link(
            :NEW.idlignecommande,
            :NEW.idcommande,
            :NEW.idproduit,
            :NEW.quantite,
            :NEW.remise
        );

    ELSIF ( NQ < 100) THEN
        INSERTligne@site2_link(
            :NEW.idlignecommande,
            :NEW.idcommande,
            :NEW.idproduit,
            :NEW.quantite,
            :NEW.remise
        );
    END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Attention : Impossible de synchroniser la mise a jour sur le site distant.');
    END;
END;
/



-- ===========================================================
-- ÉTAPE 4 : REQUÊTES D'OPTIMISATION (sur Site Principal)
-- ===========================================================

-- ---- Requête 1 : Nombre de commandes par client en 2020 ----

-- Sans index (plan de base)
EXPLAIN PLAN FOR
SELECT c.idclient, COUNT(cm.idcommande) AS NbCommandes
FROM BDDVenteS2.clients c, BDDVenteS2.commandes cm
WHERE c.idclient = cm.idclient
AND EXTRACT(YEAR FROM cm.datecommande) = 26
GROUP BY c.idclient;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Création des index pour optimiser
CREATE INDEX idx_cmd_date    ON BDDVenteS2.commandes (EXTRACT(YEAR FROM datecommande));
CREATE INDEX idx_cmd_client  ON BDDVenteS2.commandes (idclient);

EXPLAIN PLAN FOR
SELECT c.idclient, COUNT(cm.idcommande) AS NbCommandes
FROM BDDVenteS2.clients c, BDDVenteS2.commandes cm
WHERE c.idclient = cm.idclient
AND EXTRACT(YEAR FROM cm.datecommande) = 26
GROUP BY c.idclient;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

GRANT SELECT_CATALOG_ROLE TO BDDVENTES2;
GRANT SELECT ANY DICTIONARY TO BDDVENTES2;



-- Calcul du Chiffre d'Affaires total par catégorie en 2026 (Sites Distribués)
SELECT 
    categorie, 
    SUM(CA_Partiel) AS CA_TOTAL_2026
FROM (
    -- Calcul sur le Site 1
    SELECT 
        p.idcateg AS categorie,
        SUM(p.prixunitaire * lc.quantite * (1 - lc.remise/100)) AS CA_Partiel
    FROM Site1UserS2.produits1@site1_link p
    JOIN Site1UserS2.lignecommandes1@site1_link lc ON p.idproduit = lc.idproduit
    JOIN Site1UserS2.commandes1@site1_link c ON lc.idcommande = c.idcommande
    WHERE EXTRACT(YEAR FROM c.datecommande) =26
    GROUP BY p.idcateg

    UNION ALL

    -- Calcul sur le Site 2
    SELECT 
        p.idcateg AS categorie,
        SUM(p.prixunitaire * lc.quantite * (1 - lc.remise/100)) AS CA_Partiel
    FROM Site2UserS2.produits2@site2_link p
    JOIN Site2UserS2.lignecommandes2@site2_link lc ON p.idproduit = lc.idproduit
    JOIN Site2UserS2.commandes2@site2_link c ON lc.idcommande = c.idcommande
    WHERE EXTRACT(YEAR FROM c.datecommande) =26
    GROUP BY p.idcateg
) 
GROUP BY categorie;

