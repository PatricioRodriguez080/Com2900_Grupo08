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

IF OBJECT_ID('consorcio.ImportarPersonas') IS NOT NULL
    DROP PROCEDURE consorcio.ImportarPersonas;
GO

CREATE PROCEDURE consorcio.SP_importar_personas
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
                LTRIM(RTRIM(Col6_CuentaOrigen)) AS cuentaOrigen
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

---------- pagos_consorcios.csv ------------

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



------------------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE consorcio.SP_mostrar_datos_inquilinos_propietarios
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

            -- 3. MOSTRAR DATOS
            SELECT
                -- Nombre capitalizado
                RTRIM(
                    (
                        SELECT UPPER(LEFT(value,1)) + LOWER(SUBSTRING(value,2,LEN(value))) + '' ''
                        FROM STRING_SPLIT(LTRIM(RTRIM(Col1_Nombre)), '' '')
                        FOR XML PATH(''''), TYPE
                    ).value(''.'', ''NVARCHAR(MAX)'')
                ) AS nombre,
                
                -- Apellido capitalizado
                RTRIM(
                    (
                        SELECT UPPER(LEFT(value,1)) + LOWER(SUBSTRING(value,2,LEN(value))) + '' ''
                        FROM STRING_SPLIT(LTRIM(RTRIM(Col2_Apellido)), '' '')
                        FOR XML PATH(''''), TYPE
                    ).value(''.'', ''NVARCHAR(MAX)'')
                ) AS apellido,

                CAST(LTRIM(RTRIM(Col3_DNI)) AS BIGINT) AS dni,
                
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

                LTRIM(RTRIM(Col5_Telefono)) AS telefono,
                LTRIM(RTRIM(Col6_CuentaOrigen)) AS cuentaOrigen,
                
                CASE 
                    WHEN TRY_CAST(REPLACE(REPLACE(LTRIM(RTRIM(Col7_Inquilino)), CHAR(13), ''''), CHAR(10), '''') AS INT) = 1 
                        THEN ''inquilino''
                    ELSE ''propietario''
                END AS rol
            FROM #temporal;

            -- 4. LIMPIEZA
            IF OBJECT_ID(''tempdb..#temporal'') IS NOT NULL
                DROP TABLE #temporal;
        ';

        EXEC sp_executesql @sqlQuery;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#temporal') IS NOT NULL
            DROP TABLE #temporal;

        SELECT
            'Error al mostrar los datos.' AS Resultado,
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;

        THROW;
        RETURN 1;
    END CATCH

    RETURN 0;
END
GO


EXEC consorcio.SP_mostrar_datos_inquilinos_propietarios 
    @path = 'C:\Archivos para el TP\Inquilino-propietarios-datos.csv';
