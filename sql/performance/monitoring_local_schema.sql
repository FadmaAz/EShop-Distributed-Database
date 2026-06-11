-- ============================================================
-- Monitoring local - A executer dans n'importe quel schema
-- BDDVente, BDDVenteS2, Site1User, Site2User, Site1UserS2, Site2UserS2
-- ============================================================

SET LINESIZE 200;
SET PAGESIZE 100;
SET SERVEROUTPUT ON;

PROMPT === Objets invalides ===
SELECT object_name, object_type, status
FROM user_objects
WHERE status <> 'VALID'
ORDER BY object_type, object_name;

PROMPT === Erreurs de compilation ===
SELECT name, type, line, position, text
FROM user_errors
ORDER BY name, sequence;

PROMPT === Tables et statistiques ===
SELECT table_name, num_rows, blocks, last_analyzed
FROM user_tables
ORDER BY table_name;

PROMPT === Index et statut ===
SELECT index_name, table_name, status, last_analyzed
FROM user_indexes
ORDER BY table_name, index_name;

PROMPT === Taille des segments en MB ===
SELECT segment_name,
       segment_type,
       ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM user_segments
ORDER BY bytes DESC;

PROMPT === Procedures et triggers ===
SELECT object_name, object_type, status, last_ddl_time
FROM user_objects
WHERE object_type IN ('PROCEDURE', 'TRIGGER')
ORDER BY object_type, object_name;

PROMPT === Requetes recentes couteuses pour le schema courant ===
PROMPT Cette requete demande SELECT_CATALOG_ROLE ou SELECT ANY DICTIONARY.
PROMPT Decommenter si l'utilisateur possede les privileges necessaires.

-- SELECT sql_id,
--        executions,
--        buffer_gets,
--        disk_reads,
--        rows_processed,
--        ROUND(elapsed_time / 1000000, 2) AS elapsed_seconds
-- FROM v$sql
-- WHERE parsing_schema_name = USER
-- ORDER BY elapsed_time DESC
-- FETCH FIRST 10 ROWS ONLY;
