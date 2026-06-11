-- ============================================================
-- Monitoring principal - Scenario 1
-- A executer dans le schema BDDVente
-- ============================================================

SET LINESIZE 200;
SET PAGESIZE 100;
SET SERVEROUTPUT ON;

PROMPT === Test database links ===
SELECT 'site1_link' AS db_link, dummy FROM dual@site1_link;
SELECT 'site2_link' AS db_link, dummy FROM dual@site2_link;

PROMPT === Objets invalides et erreurs ===
SELECT object_name, object_type, status
FROM user_objects
WHERE status <> 'VALID'
ORDER BY object_type, object_name;

SELECT name, type, line, position, text
FROM user_errors
ORDER BY name, sequence;

PROMPT === Statut triggers principaux ===
SELECT object_name, status, last_ddl_time
FROM user_objects
WHERE object_type = 'TRIGGER'
ORDER BY object_name;

PROMPT === Coherence fragmentation - Scenario 1 ===
SELECT 'principal_lignes_site1' AS zone, COUNT(*) AS nb_lignes
FROM lignecommandes lc
JOIN produits p ON p.idproduit = lc.idproduit
WHERE p.idcateg = 50 AND lc.quantite > 100
UNION ALL
SELECT 'site1_lignes' AS zone, COUNT(*)
FROM Site1User.lignecommandes1@site1_link
UNION ALL
SELECT 'principal_lignes_site2' AS zone, COUNT(*)
FROM lignecommandes lc
JOIN produits p ON p.idproduit = lc.idproduit
WHERE p.idcateg = 35 AND lc.quantite > 50
UNION ALL
SELECT 'site2_lignes' AS zone, COUNT(*)
FROM Site2User.lignecommandes2@site2_link;

PROMPT === Index principaux ===
SELECT index_name, table_name, status, last_analyzed
FROM user_indexes
ORDER BY table_name, index_name;

PROMPT === Statistiques tables principales ===
SELECT table_name, num_rows, blocks, last_analyzed
FROM user_tables
ORDER BY table_name;

PROMPT === Plan - commandes par client ===
EXPLAIN PLAN SET STATEMENT_ID = 'S1_CMD_CLIENT' FOR
SELECT c.idclient, COUNT(cm.idcommande) AS nb_commandes
FROM clients c
JOIN commandes cm ON c.idclient = cm.idclient
WHERE EXTRACT(YEAR FROM cm.datecommande) = 2026
GROUP BY c.idclient;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'S1_CMD_CLIENT'));

PROMPT === Plan - chiffre affaires distribue ===
EXPLAIN PLAN SET STATEMENT_ID = 'S1_CA_DIST' FOR
SELECT categorie, SUM(ca_partiel) AS ca_total_2026
FROM (
    SELECT p.idcateg AS categorie,
           SUM(p.prixunitaire * lc.quantite * (1 - lc.remise / 100)) AS ca_partiel
    FROM Site1User.produits1@site1_link p
    JOIN Site1User.lignecommandes1@site1_link lc ON p.idproduit = lc.idproduit
    JOIN Site1User.commandes1@site1_link c ON lc.idcommande = c.idcommande
    WHERE EXTRACT(YEAR FROM c.datecommande) = 2026
    GROUP BY p.idcateg
    UNION ALL
    SELECT p.idcateg AS categorie,
           SUM(p.prixunitaire * lc.quantite * (1 - lc.remise / 100)) AS ca_partiel
    FROM Site2User.produits2@site2_link p
    JOIN Site2User.lignecommandes2@site2_link lc ON p.idproduit = lc.idproduit
    JOIN Site2User.commandes2@site2_link c ON lc.idcommande = c.idcommande
    WHERE EXTRACT(YEAR FROM c.datecommande) = 2026
    GROUP BY p.idcateg
)
GROUP BY categorie;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'S1_CA_DIST'));
