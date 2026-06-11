-- ============================================================
-- Indexation - Site principal
-- A executer dans BDDVente ou BDDVenteS2
-- ============================================================

SET SERVEROUTPUT ON;

DECLARE
    PROCEDURE create_index_if_missing(
        p_index_name IN VARCHAR2,
        p_sql        IN VARCHAR2
    ) IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM user_indexes
        WHERE index_name = UPPER(p_index_name);

        IF v_count = 0 THEN
            EXECUTE IMMEDIATE p_sql;
            DBMS_OUTPUT.PUT_LINE('Index cree : ' || p_index_name);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Index existe deja : ' || p_index_name);
        END IF;
    END;
BEGIN
    create_index_if_missing(
        'idx_cmd_client',
        'CREATE INDEX idx_cmd_client ON commandes(idclient)'
    );

    create_index_if_missing(
        'idx_cmd_date',
        'CREATE INDEX idx_cmd_date ON commandes(EXTRACT(YEAR FROM datecommande))'
    );

    create_index_if_missing(
        'idx_lc_commande',
        'CREATE INDEX idx_lc_commande ON lignecommandes(idcommande)'
    );

    create_index_if_missing(
        'idx_lc_produit',
        'CREATE INDEX idx_lc_produit ON lignecommandes(idproduit)'
    );

    create_index_if_missing(
        'idx_prod_categ',
        'CREATE INDEX idx_prod_categ ON produits(idcateg)'
    );

    create_index_if_missing(
        'idx_prod_stock',
        'CREATE INDEX idx_prod_stock ON produits(unitesenstock)'
    );
END;
/

BEGIN
    DBMS_STATS.GATHER_SCHEMA_STATS(
        ownname => USER,
        cascade => TRUE
    );
END;
/

SELECT index_name, table_name, status
FROM user_indexes
WHERE index_name IN (
    'IDX_CMD_CLIENT',
    'IDX_CMD_DATE',
    'IDX_LC_COMMANDE',
    'IDX_LC_PRODUIT',
    'IDX_PROD_CATEG',
    'IDX_PROD_STOCK'
)
ORDER BY table_name, index_name;
