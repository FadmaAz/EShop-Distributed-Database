-- ============================================================
-- Indexation - Sites distants
-- A executer dans Site1User, Site2User, Site1UserS2 ou Site2UserS2
-- Le script detecte les tables suffixees 1 ou 2.
-- ============================================================

SET SERVEROUTPUT ON;

DECLARE
    PROCEDURE create_index_if_possible(
        p_table_name IN VARCHAR2,
        p_index_name IN VARCHAR2,
        p_sql        IN VARCHAR2
    ) IS
        v_table_count NUMBER;
        v_index_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_table_count
        FROM user_tables
        WHERE table_name = UPPER(p_table_name);

        IF v_table_count = 0 THEN
            RETURN;
        END IF;

        SELECT COUNT(*)
        INTO v_index_count
        FROM user_indexes
        WHERE index_name = UPPER(p_index_name);

        IF v_index_count = 0 THEN
            EXECUTE IMMEDIATE p_sql;
            DBMS_OUTPUT.PUT_LINE('Index cree : ' || p_index_name);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Index existe deja : ' || p_index_name);
        END IF;
    END;
BEGIN
    create_index_if_possible(
        'lignecommandes1',
        'idx_lc1_commande',
        'CREATE INDEX idx_lc1_commande ON lignecommandes1(idcommande)'
    );

    create_index_if_possible(
        'lignecommandes1',
        'idx_lc1_produit',
        'CREATE INDEX idx_lc1_produit ON lignecommandes1(idproduit)'
    );

    create_index_if_possible(
        'produits1',
        'idx_p1_categ',
        'CREATE INDEX idx_p1_categ ON produits1(idcateg)'
    );

    create_index_if_possible(
        'commandes1',
        'idx_cmd1_client',
        'CREATE INDEX idx_cmd1_client ON commandes1(idclient)'
    );

    create_index_if_possible(
        'commandes1',
        'idx_cmd1_date',
        'CREATE INDEX idx_cmd1_date ON commandes1(EXTRACT(YEAR FROM datecommande))'
    );

    create_index_if_possible(
        'lignecommandes2',
        'idx_lc2_commande',
        'CREATE INDEX idx_lc2_commande ON lignecommandes2(idcommande)'
    );

    create_index_if_possible(
        'lignecommandes2',
        'idx_lc2_produit',
        'CREATE INDEX idx_lc2_produit ON lignecommandes2(idproduit)'
    );

    create_index_if_possible(
        'produits2',
        'idx_p2_categ',
        'CREATE INDEX idx_p2_categ ON produits2(idcateg)'
    );

    create_index_if_possible(
        'commandes2',
        'idx_cmd2_client',
        'CREATE INDEX idx_cmd2_client ON commandes2(idclient)'
    );

    create_index_if_possible(
        'commandes2',
        'idx_cmd2_date',
        'CREATE INDEX idx_cmd2_date ON commandes2(EXTRACT(YEAR FROM datecommande))'
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
ORDER BY table_name, index_name;
