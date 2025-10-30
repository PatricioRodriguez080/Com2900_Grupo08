/*
-----------------------------------------------------------------
Materia:         Bases de Datos Aplicadas
Comisión:        Com 01-2900
Grupo:           G08
Fecha de Entrega: 04/11/2025
Integrantes:
    Bentancur Suarez, Ismael 45823439
    Rodriguez Arrien, Juan Manuel 44259478
    Rodriguez, Patricio 45683229
    Ruiz, Leonel Emiliano 45537914
Enunciado:       "02 - Creación de Procedimientos Almacenados"
-----------------------------------------------------------------
*/

USE Com2900G08
------------ Archivo datos varios.xlsx --------------------------
-- Enable Ad Hoc Distributed Queries
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1; RECONFIGURE;
GO

-- Set provider properties for Microsoft.ACE.OLEDB.12.0
EXEC sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'AllowInProcess', 1;
EXEC sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'DynamicParameters', 1;
GO


CREATE OR ALTER PROCEDURE consorcio.SP_importar_consorcios_excel
    @path NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Crear tabla temporal (AÑADIENDO nro_consorcio_excel)
    IF OBJECT_ID('consorcio.consorcio_temp', 'U') IS NOT NULL
        DROP TABLE consorcio.consorcio_temp;

    CREATE TABLE consorcio.consorcio_temp (
        id_consorcio_temp INT IDENTITY (1,1) PRIMARY KEY,
        nro_consorcio_excel VARCHAR(20), -- Columna para capturar 'Consorcio 1', etc.
        nombre VARCHAR(50) NOT NULL,
        direccion VARCHAR(50) NOT NULL,
        cant_unidades_funcionales INT NOT NULL,
        m2_totales INT NOT NULL
    );

    DECLARE @sql NVARCHAR(MAX);

    -------------------------------------------------------------------------
    -- 2. INSERTAR EN LA TABLA TEMPORAL (SQL Dinámico)
    -------------------------------------------------------------------------
    SET @sql = N'
    INSERT INTO consorcio.consorcio_temp (
        nro_consorcio_excel, nombre, direccion, cant_unidades_funcionales, m2_totales
    )
    SELECT 
        LTRIM(RTRIM(CAST([Consorcio] AS VARCHAR(20)))) AS nro_consorcio_excel, -- Captura el ID de origen
        LTRIM(RTRIM([Nombre del consorcio])) AS nombre,
        LTRIM(RTRIM([Domicilio])) AS direccion,
        TRY_CAST([Cant unidades funcionales] AS INT) AS cant_unidades_funcionales,
        TRY_CAST([m2 totales] AS INT) AS m2_totales
    FROM OPENROWSET(
        ''Microsoft.ACE.OLEDB.12.0'',
        ''Excel 12.0;Database=' + @path + ';HDR=YES;IMEX=1;'',
        ''SELECT * FROM [Consorcios$]'' 
    ) AS t
    WHERE 
        -- Filtros de validación
        LTRIM(RTRIM(CAST([Consorcio] AS VARCHAR(20)))) IS NOT NULL
        AND TRY_CAST([Cant unidades funcionales] AS INT) IS NOT NULL
        AND TRY_CAST([Cant unidades funcionales] AS INT) > 0
        AND TRY_CAST([m2 totales] AS INT) IS NOT NULL
        AND TRY_CAST([m2 totales] AS INT) > 0
        AND LTRIM(RTRIM([Nombre del consorcio])) IS NOT NULL
        AND LTRIM(RTRIM([Domicilio])) IS NOT NULL
    ;';

    EXEC sp_executesql @sql;

    -------------------------------------------------------------------------
    -- 3. INSERTAR EN LA TABLA FINAL (Lectura de la tabla temporal)
    -------------------------------------------------------------------------
    INSERT INTO consorcio.consorcio (
        idConsorcio, nombre, direccion, cantidadUnidadesFuncionales, metrosCuadradosTotales
    )
    SELECT
        -- Se extrae el número del texto 'Consorcio X'
        CAST(REPLACE(t.nro_consorcio_excel, 'Consorcio ', '') AS INT) AS idConsorcio,
        t.nombre,
        t.direccion,
        t.cant_unidades_funcionales,
        t.m2_totales
    FROM consorcio.consorcio_temp AS t
    -- Prevenir duplicados en la tabla final consorcio.consorcio
    WHERE NOT EXISTS (
        SELECT 1 
        FROM consorcio.consorcio c 
        WHERE c.idConsorcio = CAST(REPLACE(t.nro_consorcio_excel, 'Consorcio ', '') AS INT)
    );

END;
GO

------- Archivo inquilino-propietarios-datos.csv -----------------
-- La ruta debe ser ABSOLUTA y ACCESIBLE por el servicio de SQL Server, por eso elegimos alojar los docs en la raíz del disco C
CREATE OR ALTER PROCEDURE consorcio.SP_importar_personas
    @path NVARCHAR(255)
AS
BEGIN
    DECLARE @sqlQuery NVARCHAR(MAX);

    BEGIN TRY
        SET @sqlQuery = '
            -- 1. CREAR TABLA TEMPORAL
            IF OBJECT_ID(''tempdb..#temporal'') IS NOT NULL
                DROP TABLE #temporal;
            
            CREATE TABLE #temporal (
                Col1_Nombre         VARCHAR(100),
                Col2_Apellido       VARCHAR(100),
                Col3_DNI            VARCHAR(50),
                Col4_Email          VARCHAR(100),
                Col5_Telefono       VARCHAR(50),
                Col6_CuentaOrigen   CHAR(22),
                Col7_Inquilino      VARCHAR(10)
            );
            
            -- 2. CARGAR CSV
            BULK INSERT #temporal
            FROM ''' + @path + '''
            WITH (
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''0x0A'',
                FIRSTROW = 2,
                CODEPAGE = ''65001''
            );

            -- 3. INSERTAR EN TABLA FINAL (con limpieza y validación)
            INSERT INTO consorcio.persona (
                nombre,
                apellido,
                dni,
                email,
                telefono,
                cuentaOrigen
            )
            SELECT DISTINCT
                -- Nombre: primera letra de cada palabra en mayúscula, conservando espacios
                RTRIM(
                    (
                        SELECT 
                            UPPER(LEFT(value,1)) + LOWER(SUBSTRING(value,2,LEN(value))) + '' ''
                        FROM STRING_SPLIT(LTRIM(RTRIM(Col1_Nombre)), '' '')
                        FOR XML PATH(''''), TYPE
                    ).value(''.'', ''NVARCHAR(MAX)'')
                ) AS nombre,

                -- Apellido: primera letra de cada palabra en mayúscula, conservando espacios
                RTRIM(
                    (
                        SELECT 
                            UPPER(LEFT(value,1)) + LOWER(SUBSTRING(value,2,LEN(value))) + '' ''
                        FROM STRING_SPLIT(LTRIM(RTRIM(Col2_Apellido)), '' '')
                        FOR XML PATH(''''), TYPE
                    ).value(''.'', ''NVARCHAR(MAX)'')
                ) AS apellido,

                -- DNI en entero
                CAST(LTRIM(RTRIM(Col3_DNI)) AS INT) AS dni,

                -- Email limpiado
                LOWER(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    LTRIM(RTRIM(Col4_Email)),
                                    ''  '', '' ''
                                ),
                                '' '', ''_'' 
                            ),
                            ''__'', ''_'' 
                        ),
                        ''_@'', ''@''
                    )
                ) AS email,

                -- Teléfono y cuenta origen normales
                LTRIM(RTRIM(Col5_Telefono)) AS telefono,

                CAST(
                    LEFT(
                        REPLACE(
                            REPLACE(LTRIM(RTRIM(Col6_CuentaOrigen)), '','', ''''),
                        ''E+21'', '''')
                         + REPLICATE(''0'',22),
                    22) AS CHAR(22)
                ) AS cuentaOrigen

            FROM #temporal t
            WHERE 
                -- Evitar duplicados en la tabla destino
                NOT EXISTS (
                    SELECT 1 
                    FROM consorcio.persona p 
                    WHERE p.dni = CAST(LTRIM(RTRIM(t.Col3_DNI)) AS INT)
                )
                AND ISNUMERIC(LTRIM(RTRIM(t.Col3_DNI))) = 1
                AND LTRIM(RTRIM(t.Col3_DNI)) <> '''';  -- Evitar DNIs vacíos

            -- 4. LIMPIEZA
            IF OBJECT_ID(''tempdb..#temporal'') IS NOT NULL
                DROP TABLE #temporal;
        ';

        EXEC sp_executesql @sqlQuery;
        SELECT 'Importación de datos de persona completada con éxito.' AS Resultado;
    END TRY
    BEGIN CATCH
        SELECT
            'Error al importar los datos. La tabla temporal fue limpiada.' AS Resultado,
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;

        SET @sqlQuery = 'IF OBJECT_ID(''tempdb..#temporal'') IS NOT NULL DROP TABLE #temporal;';
        EXEC sp_executesql @sqlQuery;

        THROW;
        RETURN 1;
    END CATCH

    RETURN 0;
END
GO

------------ Archivo UF por consorcio.txt --------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_importar_unidades_funcionales
    @path NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF OBJECT_ID('tempdb..#TempUF') IS NOT NULL
            DROP TABLE #TempUF;
        CREATE TABLE #TempUF (
            nombreConsorcio NVARCHAR(100),
            numeroUnidadFuncional NVARCHAR(10),
            piso CHAR(2),
            departamento CHAR(1),
            coeficiente NVARCHAR(10),
            metrosCuadrados NVARCHAR(10),
            bauleras NVARCHAR(2),
            cochera NVARCHAR(2),
            m2_baulera NVARCHAR(10),
            m2_cochera NVARCHAR(10)
        );

        DECLARE @sql NVARCHAR(MAX);
        SET @sql = N'
            BULK INSERT #TempUF
            FROM ''' + @path + N'''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = ''\t'',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''65001'',
                DATAFILETYPE = ''char''
            );';
        EXEC sp_executesql @sql;

        INSERT INTO consorcio.unidad_funcional
            (idConsorcio, cuentaOrigen, numeroUnidadFuncional, piso, departamento, coeficiente, metrosCuadrados)
        SELECT
            c.idConsorcio,
            ROW_NUMBER() OVER(PARTITION BY c.idConsorcio ORDER BY t.numeroUnidadFuncional) AS cuentaOrigen,
            TRY_CAST(t.numeroUnidadFuncional AS INT),
            t.piso,
            t.departamento,
            TRY_CAST(REPLACE(t.coeficiente, ',', '.') AS DECIMAL(5,2)),
            TRY_CAST(t.metrosCuadrados AS INT)
        FROM #TempUF t
        INNER JOIN consorcio.consorcio c
            ON LTRIM(RTRIM(c.nombre)) = LTRIM(RTRIM(t.nombreConsorcio))
        WHERE NOT EXISTS (
            SELECT 1
            FROM consorcio.unidad_funcional uf
            WHERE uf.idConsorcio = c.idConsorcio
              AND uf.piso = t.piso
              AND uf.departamento = t.departamento
        );

        INSERT INTO consorcio.cochera (idUnidadFuncional, metrosCuadrados, coeficiente)
        SELECT
            uf.idUnidadFuncional,
            TRY_CAST(REPLACE(t.m2_cochera, ',', '.') AS INT),
            TRY_CAST(REPLACE(t.coeficiente, ',', '.') AS DECIMAL(5,2))
        FROM #TempUF t
        INNER JOIN consorcio.consorcio c
            ON LTRIM(RTRIM(c.nombre)) = LTRIM(RTRIM(t.nombreConsorcio))
        INNER JOIN consorcio.unidad_funcional uf
            ON uf.idConsorcio = c.idConsorcio
           AND uf.piso = t.piso
           AND uf.departamento = t.departamento
        WHERE t.cochera = 'SI' AND TRY_CAST(REPLACE(t.m2_cochera, ',', '.') AS INT) > 0;

        INSERT INTO consorcio.baulera (idUnidadFuncional, metrosCuadrados, coeficiente)
        SELECT
            uf.idUnidadFuncional,
            TRY_CAST(REPLACE(t.m2_baulera, ',', '.') AS INT),
            TRY_CAST(REPLACE(t.coeficiente, ',', '.') AS DECIMAL(5,2))
        FROM #TempUF t
        INNER JOIN consorcio.consorcio c
            ON LTRIM(RTRIM(c.nombre)) = LTRIM(RTRIM(t.nombreConsorcio))
        INNER JOIN consorcio.unidad_funcional uf
            ON uf.idConsorcio = c.idConsorcio
           AND uf.piso = t.piso
           AND uf.departamento = t.departamento
        WHERE t.bauleras = 'SI' AND TRY_CAST(REPLACE(t.m2_baulera, ',', '.') AS INT) > 0;

        DROP TABLE #TempUF;

    END TRY
    BEGIN CATCH
        PRINT ERROR_MESSAGE();
    END CATCH
END;
GO


CREATE OR ALTER PROCEDURE consorcio.SP_importar_unidades_funcionales_csv
    @path NVARCHAR(255) -- Ruta a Inquilino-propietarios-UF.csv
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Crear tabla temporal de staging
    IF OBJECT_ID('tempdb..#tempUF_CSV', 'U') IS NOT NULL
        DROP TABLE #tempUF_CSV;

    CREATE TABLE #tempUF_CSV (
        stg_cvu_cbu            NVARCHAR(50),
        stg_nombre_consorcio   NVARCHAR(50),
        stg_nroUnidadFuncional NVARCHAR(10),
        stg_piso               NVARCHAR(10),
        stg_departamento       NVARCHAR(10)
    );

    -- 2. Cargar datos del CSV
    DECLARE @BulkSqlCmd NVARCHAR(MAX);
    SET @BulkSqlCmd = N'
        BULK INSERT #tempUF_CSV
        FROM ''' + @path + '''
        WITH
        (
            FIELDTERMINATOR = ''|'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''ACP'',
            FIRSTROW = 2
        );
    ';
    EXEC sp_executesql @BulkSqlCmd;

    -- 3. ACTUALIZAR la tabla final
    UPDATE uf
    SET
        -- Actualizamos la cuentaOrigen con el CVU/CBU del archivo
        uf.cuentaOrigen = CAST(TRIM(t.stg_cvu_cbu) AS CHAR(22))
    FROM
        consorcio.unidad_funcional AS uf
    INNER JOIN
        consorcio.consorcio AS c ON uf.idConsorcio = c.idConsorcio
    INNER JOIN
        #tempUF_CSV AS t ON 
            TRIM(t.stg_nombre_consorcio) = c.nombre
            AND TRIM(t.stg_piso) = uf.piso
            AND TRIM(t.stg_departamento) = uf.departamento
    WHERE
        -- Solo actualizamos las que tienen la cuentaOrigen incorrecta (ROW_NUMBER)
        ISNUMERIC(uf.cuentaOrigen) = 1 AND uf.cuentaOrigen != CAST(TRIM(t.stg_cvu_cbu) AS CHAR(22));
    
    DROP TABLE #tempUF_CSV;
END;
GO
---------- Archivo pagos_consorcios.csv ------------
CREATE OR ALTER PROCEDURE consorcio.SP_carga_pagos
    @path NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #pago_staging (
        stg_idPago      NVARCHAR(50),
        stg_fecha       NVARCHAR(50),
        stg_cvu_cbu     NVARCHAR(50),
        stg_valor       NVARCHAR(50)
    );

    DECLARE @BulkSqlCmd NVARCHAR(MAX);

    SET @BulkSqlCmd = N'
        BULK INSERT #pago_staging
        FROM ''' + @path + '''
        WITH
        (
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''ACP'',
            FIRSTROW = 2
        );
    ';

    EXEC sp_executesql @BulkSqlCmd;

    INSERT INTO consorcio.pago (
        idPago,
        fecha,
        cuentaOrigen,
        importe,
        estaAsociado
    )
    SELECT
        CAST(TRIM(stg_idPago) AS INT),
        CONVERT(DATE, stg_fecha, 103),
        CAST(TRIM(stg_cvu_cbu) AS CHAR(22)),
        CAST(
            REPLACE(TRIM(stg_valor), '$', '')
            AS DECIMAL(12,3)
        ),
        0
    FROM
        #pago_staging
    WHERE
        stg_idPago IS NOT NULL
        AND ISNUMERIC(REPLACE(TRIM(stg_valor), '$', '')) = 1;

    DROP TABLE #pago_staging;
END
GO