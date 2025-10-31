/*
===============================================================================
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
===============================================================================
*/


--------------------------------------------------------------------------------
-- NUMERO: 1
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Importar consorcios
--------------------------------------------------------------------------------

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


--------------------------------------------------------------------------------
-- NUMERO: 2
-- ARCHIVO: UF por consorcio.txt
-- PROCEDIMIENTO: Importar unidades funcionales, cocheras y bauleras
-- CONSIDERACIONES: Sin cuenta origen asociada (se carga en el siguiente)
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- NUMERO: 3
-- ARCHIVO: inquilino-propietarios-UF.csv
-- PROCEDIMIENTO: Importar cuentas origen para las UF ya creadas
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- NUMERO: 4
-- ARCHIVO: inquilino-propietarios-datos.csv
-- PROCEDIMIENTO: Importar personas y su relacion con las unidades funcionales (persona_unidad_funcional)
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_importar_personas
    @path NVARCHAR(255)
AS
BEGIN
    -- Declaración de variables necesarias
    DECLARE @sqlBulkInsert NVARCHAR(MAX);
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;
    
    -- Iniciar la transacción para asegurar atomicidad
    BEGIN TRANSACTION
    
    BEGIN TRY
        
        -- 1. CREAR TABLA TEMPORAL (MODIFICADA: Col7_Inquilino es DECIMAL)
        IF OBJECT_ID('tempdb..#temporal') IS NOT NULL
            DROP TABLE #temporal;
            
        CREATE TABLE #temporal (
            Col1_Nombre         VARCHAR(100),
            Col2_Apellido       VARCHAR(100),
            Col3_DNI            VARCHAR(50),
            Col4_Email          VARCHAR(100),
            Col5_Telefono       VARCHAR(50),
            Col6_CuentaOrigen   CHAR(22),
            Col7_Inquilino      DECIMAL(2, 0) -- <--- CAMBIO A DECIMAL(2, 0)
        );
        
        ---
        
        -- 2. CARGAR CSV (ÚNICO BLOQUE DINÁMICO)
        SET @sqlBulkInsert = '
            BULK INSERT #temporal
            FROM ''' + @path + '''
            WITH (
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''0x0A'',
                FIRSTROW = 2,
                CODEPAGE = ''1252''
            );
        ';
        
        EXEC sp_executesql @sqlBulkInsert;

        ---
        
        -- 3. INSERTAR EN consorcio.persona (ESTÁTICO)
        WITH DatosLimpios AS (
            SELECT  
                -- Limpieza de Nombre
                RTRIM(
                    (
                        SELECT  
                            UPPER(LEFT(value, 1)) + LOWER(SUBSTRING(value, 2, LEN(value))) + ' '
                        FROM STRING_SPLIT(
                            LTRIM(RTRIM(
                                REPLACE(REPLACE(REPLACE(t.Col1_Nombre, '‚', 'é'), '¥', 'ñ'), '¡', 'í') 
                            )), ' '
                        )
                        FOR XML PATH(''), TYPE
                    ).value('.', 'NVARCHAR(MAX)')
                ) AS nombre,

                -- Limpieza de Apellido
                RTRIM(
                    (
                        SELECT  
                            UPPER(LEFT(value, 1)) + LOWER(SUBSTRING(value, 2, LEN(value))) + ' '
                        FROM STRING_SPLIT(
                            LTRIM(RTRIM(
                                REPLACE(REPLACE(REPLACE(t.Col2_Apellido, '‚', 'é'), '¥', 'ñ'), '¡', 'í') 
                            )), ' '
                        )
                        FOR XML PATH(''), TYPE
                    ).value('.', 'NVARCHAR(MAX)')
                ) AS apellido,

                -- DNI en entero
                CAST(LTRIM(RTRIM(t.Col3_DNI)) AS INT) AS dni,

                -- Email limpiado
                LOWER(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                LTRIM(RTRIM(
                                    REPLACE(REPLACE(REPLACE(t.Col4_Email, '‚', 'é'), '¥', 'ñ'), '¡', 'í') 
                                )),
                                ' ', '_'
                            ),
                            '__', '_'
                        ),
                        '_@', '@'
                    )
                ) AS email,

                -- Teléfono y cuenta origen
                LTRIM(RTRIM(t.Col5_Telefono)) AS telefono,
                LTRIM(RTRIM(t.Col6_CuentaOrigen)) AS cuentaOrigen,
                
                -- Deduplicación
                ROW_NUMBER() OVER (PARTITION BY t.Col3_DNI ORDER BY t.Col1_Nombre) as rn
            FROM #temporal t
            WHERE 
                ISNUMERIC(LTRIM(RTRIM(t.Col3_DNI))) = 1
                AND LTRIM(RTRIM(t.Col3_DNI)) <> ''
        )
        
        INSERT INTO consorcio.persona (
            nombre, apellido, dni, email, telefono, cuentaOrigen
        )
        SELECT  
            dl.nombre, dl.apellido, dl.dni, dl.email, dl.telefono, dl.cuentaOrigen
        FROM DatosLimpios dl
        WHERE
            dl.rn = 1
            AND NOT EXISTS (
                SELECT 1 
                FROM consorcio.persona p 
                WHERE p.dni = dl.dni
            );

        ---
        
        -- 4. INSERTAR RELACIONES EN consorcio.persona_unidad_funcional (ESTÁTICO)
        INSERT INTO consorcio.persona_unidad_funcional (idPersona, idUnidadFuncional, rol)
        SELECT
            p.idPersona,
            uf.idUnidadFuncional,
            -- ASIGNACIÓN DE ROL SIMPLE CON COMPARACIÓN NUMÉRICA (1 para inquilino, 0 para propietario)
            CASE  
                WHEN t.Col7_Inquilino = 1 THEN 'inquilino'
                ELSE 'propietario'
            END AS rol
        FROM #temporal t      
        
        INNER JOIN consorcio.persona p  
            ON p.dni = CAST(LTRIM(RTRIM(t.Col3_DNI)) AS INT)
        
        INNER JOIN consorcio.unidad_funcional uf
            ON uf.cuentaOrigen = LTRIM(RTRIM(t.Col6_CuentaOrigen))
        
        -- FILTRO DE DNI Y VALIDACIÓN DE EXISTENCIA DE RELACIÓN
        WHERE 
            ISNUMERIC(LTRIM(RTRIM(t.Col3_DNI))) = 1 AND LTRIM(RTRIM(t.Col3_DNI)) <> ''
            
            AND NOT EXISTS (
                SELECT 1 
                FROM consorcio.persona_unidad_funcional puf
                WHERE puf.idUnidadFuncional = uf.idUnidadFuncional
                -- Lógica de deduplicación también usa la comparación numérica simple
                AND puf.rol = CASE  
                                  WHEN t.Col7_Inquilino = 1 THEN 'inquilino'
                                  ELSE 'propietario'
                              END
            );
        
        ---
        
        -- 5. ÉXITO Y COMMIT
        COMMIT TRANSACTION
        
        -- 6. LIMPIEZA DE TABLA TEMPORAL
        IF OBJECT_ID('tempdb..#temporal') IS NOT NULL
            DROP TABLE #temporal;
            
        SELECT 'Importación de datos de persona y relaciones completada con éxito. La columna Inquilino se cargó como DECIMAL(2, 0), permitiendo una asignación de rol simple: **1 = inquilino, 0 = propietario**.' AS Resultado;

    END TRY
    BEGIN CATCH
        
        -- 5. MANEJO DE ERROR Y ROLLBACK
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SELECT 
            @ErrorMessage = ERROR_MESSAGE(), 
            @ErrorSeverity = ERROR_SEVERITY(), 
            @ErrorState = ERROR_STATE();

        -- 6. LIMPIEZA DE TABLA TEMPORAL EN CASO DE ERROR
        IF OBJECT_ID('tempdb..#temporal') IS NOT NULL
            DROP TABLE #temporal;
            
        SELECT
            'Error al importar los datos. La tabla temporal fue limpiada y la transacción revertida.' AS Resultado,
            ERROR_NUMBER() AS ErrorNumber,
            @ErrorMessage AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;

        THROW;
        RETURN 1;

    END CATCH

    RETURN 0;
END
GO

--------------------------------------------------------------------------------
-- NUMERO: 5
-- ARCHIVO: pagos_consorcios.csv
-- PROCEDIMIENTO: Importar pagos
--------------------------------------------------------------------------------
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