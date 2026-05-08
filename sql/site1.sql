
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
     
     
     
CREATE TABLE lignecommandes1 AS
    (SELECT * FROM BDDVente.Lignecommandes@eshop_link
     WHERE idproduit IN (SELECT idproduit FROM produits1)
     AND Quantite > 100);

CREATE TABLE commandes1 AS
    (SELECT DISTINCT * FROM BDDVente.commandes@eshop_link
     WHERE idcommande IN (SELECT idcommande FROM Lignecommandes1));

CREATE TABLE clients1 AS
    (SELECT DISTINCT * FROM BDDVente.clients@eshop_link
     WHERE idclient IN (SELECT idclient FROM commandes1));
     

--les contraintes d'integrete

ALTER TABLE clients1       ADD CONSTRAINT c1 PRIMARY KEY (idclient);
ALTER TABLE commandes1     ADD CONSTRAINT c2 PRIMARY KEY (idcommande);
ALTER TABLE lignecommandes1 ADD CONSTRAINT c3 PRIMARY KEY (idlignecommande);
ALTER TABLE produits1      ADD CONSTRAINT c4 PRIMARY KEY (idproduit);


ALTER TABLE commandes1 ADD CONSTRAINT f1 
    FOREIGN KEY (idclient) REFERENCES clients1(idclient) ON DELETE CASCADE;

ALTER TABLE lignecommandes1 ADD CONSTRAINT f2 
    FOREIGN KEY (idcommande) REFERENCES commandes1(idcommande) ON DELETE CASCADE;

ALTER TABLE lignecommandes1 ADD CONSTRAINT f3 
    FOREIGN KEY (idproduit) REFERENCES produits1(idproduit) ON DELETE CASCADE;
    
    
--insert ligne de commande 
CREATE OR REPLACE PROCEDURE INSERTligne(
    a Lignecommandes1.Idlignecommande%TYPE,
    b Lignecommandes1.Idcommande%TYPE,
    c Lignecommandes1.Idproduit%TYPE,
    d Lignecommandes1.quantite%TYPE,
    e Lignecommandes1.remise%TYPE
) IS
    PRAGMA AUTONOMOUS_TRANSACTION; -- <--- AJOUTEZ CECI
    nc  INTEGER;
    np  INTEGER;
    n   INTEGER;
    Rc  commandes1%ROWTYPE;
BEGIN
    -- 1. Gestion de la commande
    SELECT COUNT(*) INTO nc FROM commandes1 WHERE idcommande = b;
    IF (nc = 0) THEN
        SELECT * INTO Rc FROM BDDVente.Commandes@eshop_link WHERE idcommande = b;

        -- Vérifier le client
        SELECT COUNT(*) INTO n FROM clients1 WHERE idclient = Rc.idclient;
        IF (n = 0) THEN
            INSERT INTO clients1 
                SELECT * FROM BDDVente.clients@eshop_link 
                WHERE idclient = Rc.idclient;
        END IF;

        INSERT INTO commandes1 
            SELECT * FROM BDDVente.Commandes@eshop_link 
            WHERE idcommande = b;
    END IF;

    -- 2. Gestion du produit (CORRECTION ICI)
    SELECT COUNT(*) INTO np FROM produits1 WHERE idproduit = c;
    IF (np = 0) THEN
        -- On respecte l'ordre de l'image : ID, DESIGNATION, CATEG, PRIX
        INSERT INTO produits1 (IDPRODUIT, DESIGNATION, IDCATEG, PRIXUNITAIRE)
            SELECT p.idproduit, p.Designation, p.IdCateg, p.PrixUnitaire 
            FROM BDDVente.produits@eshop_link p
            WHERE p.idproduit = c;
    END IF;

    -- 3. Insertion finale
    INSERT INTO lignecommandes1 (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
    VALUES (a, b, c, d, e);
    
    COMMIT;
END;


-- ============================================================
-- PROCEDURE DELETEligne
-- Supprime une ligne de commande dans site1
-- Si la commande n'a plus de lignes → supprime la commande
-- Si le client n'a plus de commandes → supprime le client
-- (La FK ON DELETE CASCADE gère la suppression en cascade
--  mais ici on gère manuellement pour contrôler l'ordre)
-- ============================================================
CREATE OR REPLACE PROCEDURE DELETEligne(
    a Lignecommandes1.Idlignecommande%TYPE
) IS
    nc  INTEGER;
    np  INTEGER;
    ncL INTEGER;
    idc commandes1.idcommande%TYPE;
    idp produits1.idproduit%TYPE;
    idcL clients1.idclient%TYPE;
BEGIN
    -- Récupérer idcommande et idproduit de la ligne à supprimer
    SELECT idcommande, idproduit INTO idc, idp 
    FROM lignecommandes1 
    WHERE idlignecommande = a;

    -- Supprimer la ligne de commande
    DELETE Lignecommandes1 WHERE idlignecommande = a;

    -- Si la commande n'a plus de lignes → supprimer la commande
    SELECT COUNT(*) INTO nc FROM Lignecommandes1 WHERE idcommande = idc;
    IF (nc = 0) THEN
        SELECT idclient INTO idcL FROM Commandes1 WHERE idcommande = idc;
        DELETE Commandes1 WHERE idcommande = idc;

        -- Si le client n'a plus de commandes → supprimer le client
        SELECT COUNT(*) INTO ncL FROM Commandes1 WHERE idclient = idcL;
        IF (ncL = 0) THEN
            DELETE Clients1 WHERE idclient = idcL;
        END IF;
    END IF;
END;
/


-- ============================================================
-- PROCEDURE updateligne
-- Met à jour idproduit, quantite, remise d'une ligne
-- Si le nouveau produit n'existe pas dans site1 → l'importe
-- Si l'ancien produit n'est plus utilisé → le supprime
-- ============================================================
CREATE OR REPLACE PROCEDURE updateligne(
    a lignecommandes1.idlignecommande%TYPE,
    b lignecommandes1.idproduit%TYPE,
    c lignecommandes1.quantite%TYPE,
    d lignecommandes1.remise%TYPE
) IS
    n  INTEGER;
    x  INTEGER;
BEGIN
    -- Récupérer l'ancien idproduit
    SELECT idproduit INTO x FROM lignecommandes1 WHERE idlignecommande = a;

    -- Vérifier si le nouveau produit existe dans site1
    SELECT COUNT(*) INTO n FROM produits1 WHERE idproduit = b;
    IF (n = 0) THEN
        INSERT INTO produits1 (IDPRODUIT, DESIGNATION, IDCATEG, PRIXUNITAIRE)
            SELECT p.idproduit, p.Designation, p.IdCateg, p.PrixUnitaire 
            FROM BDDVente.produits@eshop_link p
            WHERE p.idproduit = b;
    END IF;

    -- Mettre à jour la ligne
    UPDATE lignecommandes1 
    SET idproduit = b, quantite = c, remise = d 
    WHERE idlignecommande = a;

    -- Si l'ancien produit n'est plus utilisé dans site1 → le supprimer
    SELECT COUNT(*) INTO n FROM Lignecommandes1 WHERE idproduit = x;
    IF n = 0 THEN
        DELETE Produits1 WHERE idproduit = x;
    END IF;
END;

