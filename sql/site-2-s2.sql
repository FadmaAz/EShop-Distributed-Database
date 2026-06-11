 CREATE DATABASE LINK eshop_link
CONNECT TO BDDVenteS2 IDENTIFIED BY "1111"
USING '(DESCRIPTION=
          (ADDRESS=(PROTOCOL=TCP)(HOST=oracle-tp1)(PORT=1521))
          (CONNECT_DATA=(SERVICE_NAME=XEPDB1)))';


CREATE TABLE produits2 AS
    (SELECT DISTINCT p.IDPRODUIT, p.DESIGNATION, p.IDCATEG, p.PRIXUNITAIRE
     FROM BDDVenteS2.produits@eshop_link p, BDDVenteS2.Lignecommandes@eshop_link lc
     WHERE p.idproduit = lc.idproduit
     AND lc.quantite < 100);
     
     
     
     
     
CREATE TABLE lignecommandes2 AS
    (SELECT * FROM BDDVenteS2.Lignecommandes@eshop_link
     WHERE idproduit IN (SELECT idproduit FROM produits2)
     AND Quantite < 100);

CREATE TABLE commandes2 AS
    (SELECT DISTINCT * FROM BDDVenteS2.commandes@eshop_link
     WHERE idcommande IN (SELECT idcommande FROM Lignecommandes2));

CREATE TABLE clients2 AS
    (SELECT DISTINCT * FROM BDDVenteS2.clients@eshop_link
     WHERE idclient IN (SELECT idclient FROM commandes2));
     
     

--les contraintes d'integrete

ALTER TABLE clients2       ADD CONSTRAINT c1 PRIMARY KEY (idclient);
ALTER TABLE commandes2     ADD CONSTRAINT c2 PRIMARY KEY (idcommande);
ALTER TABLE lignecommandes2 ADD CONSTRAINT c3 PRIMARY KEY (idlignecommande);
ALTER TABLE produits2      ADD CONSTRAINT c4 PRIMARY KEY (idproduit);


ALTER TABLE commandes2 ADD CONSTRAINT f1 
    FOREIGN KEY (idclient) REFERENCES clients2(idclient) ON DELETE CASCADE;

ALTER TABLE lignecommandes2 ADD CONSTRAINT f2 
    FOREIGN KEY (idcommande) REFERENCES commandes2(idcommande) ON DELETE CASCADE;

ALTER TABLE lignecommandes2 ADD CONSTRAINT f3 
    FOREIGN KEY (idproduit) REFERENCES produits2(idproduit) ON DELETE CASCADE;
    
    
--insert ligne de commande 
CREATE OR REPLACE PROCEDURE INSERTligne(
    a Lignecommandes2.Idlignecommande%TYPE,
    b Lignecommandes2.Idcommande%TYPE,
    c Lignecommandes2.Idproduit%TYPE,
    d Lignecommandes2.quantite%TYPE,
    e Lignecommandes2.remise%TYPE
) IS
    PRAGMA AUTONOMOUS_TRANSACTION; -- <--- AJOUTEZ CECI
    nc  INTEGER;
    np  INTEGER;
    n   INTEGER;
    Rc  commandes2%ROWTYPE;
BEGIN
    -- 1. Gestion de la commande
    SELECT COUNT(*) INTO nc FROM commandes2 WHERE idcommande = b;
    IF (nc = 0) THEN
        SELECT * INTO Rc FROM BDDVenteS2.Commandes@eshop_link WHERE idcommande = b;

        -- Vérifier le client
        SELECT COUNT(*) INTO n FROM clients2 WHERE idclient = Rc.idclient;
        IF (n = 0) THEN
            INSERT INTO clients2
                SELECT * FROM BDDVenteS2.clients@eshop_link 
                WHERE idclient = Rc.idclient;
        END IF;

        INSERT INTO commandes2
            SELECT * FROM BDDVenteS2.Commandes@eshop_link 
            WHERE idcommande = b;
    END IF;

    -- 2. Gestion du produit (CORRECTION ICI)
    SELECT COUNT(*) INTO np FROM produits2 WHERE idproduit = c;
    IF (np = 0) THEN
        -- On respecte l'ordre de l'image : ID, DESIGNATION, CATEG, PRIX
        INSERT INTO produits2 (IDPRODUIT, DESIGNATION, IDCATEG, PRIXUNITAIRE)
            SELECT p.idproduit, p.Designation, p.IdCateg, p.PrixUnitaire 
            FROM BDDVenteS2.produits@eshop_link p
            WHERE p.idproduit = c;
    END IF;

    -- 3. Insertion finale
    INSERT INTO lignecommandes2 (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
    VALUES (a, b, c, d, e);
    
    COMMIT;
END;
/



-- ============================================================
-- PROCEDURE DELETEligne
-- Supprime une ligne de commande dans site1
-- Si la commande n'a plus de lignes → supprime la commande
-- Si le client n'a plus de commandes → supprime le client
-- (La FK ON DELETE CASCADE gère la suppression en cascade
--  mais ici on gère manuellement pour contrôler l'ordre)
-- ============================================================
CREATE OR REPLACE PROCEDURE DELETEligne(
    a Lignecommandes2.Idlignecommande%TYPE
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    nc  INTEGER;
    np  INTEGER;
    ncL INTEGER;
    n   INTEGER;
    idc commandes2.idcommande%TYPE;
    idp produits2.idproduit%TYPE;
    idcL clients2.idclient%TYPE;
BEGIN
    SELECT COUNT(*) INTO n FROM lignecommandes2 WHERE idlignecommande = a;
    IF (n = 0) THEN
        COMMIT;
        RETURN;
    END IF;

    -- Récupérer idcommande et idproduit de la ligne à supprimer
    SELECT idcommande, idproduit INTO idc, idp 
    FROM lignecommandes2
    WHERE idlignecommande = a;

    -- Supprimer la ligne de commande
    DELETE Lignecommandes2 WHERE idlignecommande = a;

    -- Si la commande n'a plus de lignes → supprimer la commande
    SELECT COUNT(*) INTO nc FROM Lignecommandes2 WHERE idcommande = idc;
    IF (nc = 0) THEN
        SELECT idclient INTO idcL FROM Commandes2 WHERE idcommande = idc;
        DELETE Commandes2 WHERE idcommande = idc;

        -- Si le client n'a plus de commandes → supprimer le client
        SELECT COUNT(*) INTO ncL FROM Commandes2 WHERE idclient = idcL;
        IF (ncL = 0) THEN
            DELETE Clients2 WHERE idclient = idcL;
        END IF;
    END IF;

    SELECT COUNT(*) INTO np FROM Lignecommandes2 WHERE idproduit = idp;
    IF (np = 0) THEN
        DELETE Produits2 WHERE idproduit = idp;
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/


-- ============================================================
-- PROCEDURE updateligne
-- Met à jour idproduit, quantite, remise d'une ligne
-- Si le nouveau produit n'existe pas dans site1 → l'importe
-- Si l'ancien produit n'est plus utilisé → le supprime
-- ============================================================
CREATE OR REPLACE PROCEDURE updateligne(
    a lignecommandes2.idlignecommande%TYPE,
    b lignecommandes2.idcommande%TYPE,
    c lignecommandes2.idproduit%TYPE,
    d lignecommandes2.quantite%TYPE,
    e lignecommandes2.remise%TYPE
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    n          INTEGER;
    old_cmd    commandes2.idcommande%TYPE;
    old_prod   produits2.idproduit%TYPE;
    old_client clients2.idclient%TYPE;
    Rc         commandes2%ROWTYPE;
BEGIN
    SELECT COUNT(*) INTO n FROM lignecommandes2 WHERE idlignecommande = a;
    IF (n = 0) THEN
        INSERTligne(a, b, c, d, e);
        RETURN;
    END IF;

    -- Récupérer l'ancien idproduit
    SELECT idcommande, idproduit INTO old_cmd, old_prod
    FROM lignecommandes2
    WHERE idlignecommande = a;

    SELECT COUNT(*) INTO n FROM commandes2 WHERE idcommande = b;
    IF (n = 0) THEN
        SELECT * INTO Rc FROM BDDVenteS2.Commandes@eshop_link WHERE idcommande = b;

        SELECT COUNT(*) INTO n FROM clients2 WHERE idclient = Rc.idclient;
        IF (n = 0) THEN
            INSERT INTO clients2
                SELECT * FROM BDDVenteS2.clients@eshop_link
                WHERE idclient = Rc.idclient;
        END IF;

        INSERT INTO commandes2
            SELECT * FROM BDDVenteS2.Commandes@eshop_link
            WHERE idcommande = b;
    END IF;

    -- Vérifier si le nouveau produit existe dans site1
    SELECT COUNT(*) INTO n FROM produits2 WHERE idproduit = c;
    IF (n = 0) THEN
        INSERT INTO produits2 (IDPRODUIT, DESIGNATION, IDCATEG, PRIXUNITAIRE)
            SELECT p.idproduit, p.Designation, p.IdCateg, p.PrixUnitaire 
            FROM BDDVenteS2.produits@eshop_link p
            WHERE p.idproduit = c;
    END IF;

    -- Mettre à jour la ligne
    UPDATE lignecommandes2 
    SET idcommande = b, idproduit = c, quantite = d, remise = e
    WHERE idlignecommande = a;

    -- Si l'ancien produit n'est plus utilisé dans site1 → le supprimer
    SELECT COUNT(*) INTO n FROM Lignecommandes2 WHERE idproduit = old_prod;
    IF n = 0 THEN
        DELETE Produits2 WHERE idproduit = old_prod;
    END IF;

    SELECT COUNT(*) INTO n FROM Lignecommandes2 WHERE idcommande = old_cmd;
    IF n = 0 THEN
        SELECT idclient INTO old_client FROM Commandes2 WHERE idcommande = old_cmd;
        DELETE Commandes2 WHERE idcommande = old_cmd;

        SELECT COUNT(*) INTO n FROM Commandes2 WHERE idclient = old_client;
        IF n = 0 THEN
            DELETE Clients2 WHERE idclient = old_client;
        END IF;
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

