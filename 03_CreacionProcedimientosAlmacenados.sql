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
Enunciado:       "03 - Creación de Procedimientos Almacenados"
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

--------------------------------------------------------------------------------
-- NUMERO: 6
-- ARCHIVO: Servicios.Servicios.json
-- PROCEDIMIENTO: Importar expensas y gastos
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_carga_expensas
    @path NVARCHAR(255) -- Path del archivo JSON
AS
BEGIN
    SET NOCOUNT ON;

    -- [Declaraciones de variables - Sin cambios]
    DECLARE 
        @SQL NVARCHAR(MAX), @i INT, @max INT, @nomConsorcio VARCHAR(100),
        @periodo VARCHAR(50), @idConsorcio INT, @idExpensa INT, @idGasto INT,
        @idGastoOrdCreado INT;
    DECLARE
        @stg_gasto_banc NVARCHAR(50), @stg_gasto_limp NVARCHAR(50),
        @stg_gasto_adm NVARCHAR(50), @stg_gasto_seg NVARCHAR(50),
        @stg_gasto_gen NVARCHAR(50), @stg_gasto_pub_agua NVARCHAR(50),
        @stg_gasto_pub_luz NVARCHAR(50);
    DECLARE 
        @importe DECIMAL(12,2), @nroFactura INT = 1;
        
    -- Variables de ayuda para la limpieza de números
    DECLARE 
        @ImporteString NVARCHAR(50),
        @ImporteLimpio NVARCHAR(50),
        @PosPeriod INT,
        @PosComma INT;


    -- [Sección 1, 2, 3 - Carga de Staging - Sin cambios]
    IF OBJECT_ID('tempdb..#expensa_staging') IS NOT NULL 
        DROP TABLE #expensa_staging;
    CREATE TABLE #expensa_staging (
        stg_nom_consorcio VARCHAR(50), stg_periodo VARCHAR(50),
        stg_gasto_banc NVARCHAR(50), stg_gasto_limp NVARCHAR(50),
        stg_gasto_adm NVARCHAR(50), stg_gasto_seg NVARCHAR(50),
        stg_gasto_gen NVARCHAR(50), stg_gasto_pub_agua NVARCHAR(50),
        stg_gasto_pub_luz NVARCHAR(50)
    );
    SET @SQL = N'
    INSERT INTO #expensa_staging(
        stg_nom_consorcio, stg_periodo, stg_gasto_banc, stg_gasto_limp, stg_gasto_adm, 
        stg_gasto_seg, stg_gasto_gen, stg_gasto_pub_agua, stg_gasto_pub_luz
    )
    SELECT 
        stg_nom_consorcio, stg_periodo, stg_gasto_banc, stg_gasto_limp, stg_gasto_adm, 
        stg_gasto_seg, stg_gasto_gen, stg_gasto_pub_agua, stg_gasto_pub_luz
    FROM OPENROWSET (BULK ''' + @path + N''', SINGLE_CLOB) AS j
    CROSS APPLY OPENJSON(BulkColumn)  
    WITH (
        stg_nom_consorcio VARCHAR(50) ''$."Nombre del consorcio"'',
        stg_periodo VARCHAR(50) ''$.Mes'',
        stg_gasto_banc NVARCHAR(50) ''$.BANCARIOS'',
        stg_gasto_limp NVARCHAR(50) ''$.LIMPIEZA'',
        stg_gasto_adm NVARCHAR(50) ''$.ADMINISTRACION'',
        stg_gasto_seg NVARCHAR(50) ''$.SEGUROS'',
        stg_gasto_gen NVARCHAR(50) ''$."GASTOS GENERALES"'',
        stg_gasto_pub_agua NVARCHAR(50) ''$."SERVICIOS PUBLICOS-Agua"'',
        stg_gasto_pub_luz NVARCHAR(50) ''$."SERVICIOS PUBLICOS-Luz"''
    );';
    EXEC sp_executesql @SQL;
    IF OBJECT_ID('tempdb..#cte_expensa') IS NOT NULL DROP TABLE #cte_expensa;
    SELECT 
        s.stg_nom_consorcio, s.stg_periodo, 
        ROW_NUMBER() OVER (ORDER BY s.stg_nom_consorcio) AS rn
    INTO #cte_expensa
    FROM #expensa_staging AS s;
    SELECT @max = MAX(rn) FROM #cte_expensa;
    SET @i = 1;

    -- [Inicio del Bucle WHILE]
    WHILE @i <= @max
    BEGIN
        -- 5.1 Obtener datos de iteración y staging
        SELECT 
            @nomConsorcio = t.stg_nom_consorcio, @periodo = t.stg_periodo,
            @stg_gasto_banc = s.stg_gasto_banc, @stg_gasto_limp = s.stg_gasto_limp,
            @stg_gasto_adm = s.stg_gasto_adm, @stg_gasto_seg = s.stg_gasto_seg,
            @stg_gasto_gen = s.stg_gasto_gen, @stg_gasto_pub_agua = s.stg_gasto_pub_agua,
            @stg_gasto_pub_luz = s.stg_gasto_pub_luz
        FROM #cte_expensa AS t
        INNER JOIN #expensa_staging AS s 
            ON t.stg_nom_consorcio = s.stg_nom_consorcio AND t.stg_periodo = s.stg_periodo
        WHERE rn = @i;

        PRINT '----------------------------------------------------';
        PRINT 'INICIANDO Iteración ' + CAST(@i AS VARCHAR) + ' para Consorcio: ' + ISNULL(@nomConsorcio, 'NULL');
        
        -- Obtener idConsorcio
        SELECT @idConsorcio = c.idConsorcio
        FROM consorcio.consorcio AS c
        WHERE c.nombre = @nomConsorcio;
        
        PRINT '-> idConsorcio encontrado: ' + ISNULL(CAST(@idConsorcio AS VARCHAR), 'NO ENCONTRADO');

        IF @idConsorcio IS NOT NULL
        BEGIN
            -- 5.2 Insertar Expensa
            SET @idExpensa = NULL;
            EXEC consorcio.sp_insertarExpensa 
                @idConsorcio = @idConsorcio, @periodo = @periodo, @anio = 2025,
                @idExpensaCreada = @idExpensa OUTPUT; 
            
            -- 5.3 Insertar Gasto (Padre)
            IF @idExpensa IS NOT NULL
            BEGIN
                SET @idGasto = NULL;
                EXEC consorcio.sp_insertarGasto 
                    @idExpensa = @idExpensa, @subTotalOrdinarios = 0, @subTotalExtraOrd = 0, 
                    @idGastoCreado = @idGasto OUTPUT; 

                -- 5.4 Insertar Gastos Ordinarios (Detalle)
                IF @idGasto IS NOT NULL
                BEGIN
                    PRINT '... Preparando inserción de gastos ordinarios ...';
                    
                    -- A. Gasto Bancario
                    SET @ImporteString = ISNULL(@stg_gasto_banc, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma)
                        SET @ImporteLimpio = REPLACE(@ImporteString, ',', ''); -- Formato US
                    ELSE
                        SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.'); -- Formato ES
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));
                    
                    PRINT '  A. Gasto Banc: Staging=' + ISNULL(@stg_gasto_banc, 'NULL') + ', Limpio=' + ISNULL(@ImporteLimpio, 'NULL') + ', Cast=' + ISNULL(CAST(@importe AS VARCHAR), 'NULL');
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        PRINT '     -> Insertando Bancario...';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'mantenimiento', '', '-', @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                    END
                    ELSE PRINT '     -> OMITIDO (Importe es NULL o 0)';
                    SET @nroFactura += 1;

                    -- B. Gasto Limpieza
                    SET @ImporteString = ISNULL(@stg_gasto_limp, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma)
                        SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE
                        SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));

                    PRINT '  B. Gasto Limp: Staging=' + ISNULL(@stg_gasto_limp, 'NULL') + ', Limpio=' + ISNULL(@ImporteLimpio, 'NULL') + ', Cast=' + ISNULL(CAST(@importe AS VARCHAR), 'NULL');
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        PRINT '     -> Insertando Limpieza...';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'limpieza', '', '-', @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                    END
                    ELSE PRINT '     -> OMITIDO (Importe es NULL o 0)';
                    SET @nroFactura += 1;

                    -- C. Gasto Administración
                    SET @ImporteString = ISNULL(@stg_gasto_adm, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma)
                        SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE
                        SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));

                    PRINT '  C. Gasto Adm: Staging=' + ISNULL(@stg_gasto_adm, 'NULL') + ', Limpio=' + ISNULL(@ImporteLimpio, 'NULL') + ', Cast=' + ISNULL(CAST(@importe AS VARCHAR), 'NULL');
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        PRINT '     -> Insertando Administracion...';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'administracion', '', '-', @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                    END
                    ELSE PRINT '     -> OMITIDO (Importe es NULL o 0)';
                    SET @nroFactura += 1;

                    -- D. Gasto Seguros
                    SET @ImporteString = ISNULL(@stg_gasto_seg, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma)
                        SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE
                        SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));

                    PRINT '  D. Gasto Seg: Staging=' + ISNULL(@stg_gasto_seg, 'NULL') + ', Limpio=' + ISNULL(@ImporteLimpio, 'NULL') + ', Cast=' + ISNULL(CAST(@importe AS VARCHAR), 'NULL');
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        PRINT '     -> Insertando Seguros...';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'seguros', '', '-', @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                    END
                    ELSE PRINT '     -> OMITIDO (Importe es NULL o 0)';
                    SET @nroFactura += 1;

                    -- E. Gasto Generales
                    SET @ImporteString = ISNULL(@stg_gasto_gen, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma)
                        SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE
                        SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));

                    PRINT '  E. Gasto Gen: Staging=' + ISNULL(@stg_gasto_gen, 'NULL') + ', Limpio=' + ISNULL(@ImporteLimpio, 'NULL') + ', Cast=' + ISNULL(CAST(@importe AS VARCHAR), 'NULL');
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        PRINT '     -> Insertando Generales...';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'generales', '', '-', @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                    END
                    ELSE PRINT '     -> OMITIDO (Importe es NULL o 0)';
                    SET @nroFactura += 1;

                    -- F. Servicios Públicos - Agua
                    SET @ImporteString = ISNULL(@stg_gasto_pub_agua, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma)
                        SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE
                        SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));

                    PRINT '  F. Gasto Agua: Staging=' + ISNULL(@stg_gasto_pub_agua, 'NULL') + ', Limpio=' + ISNULL(@ImporteLimpio, 'NULL') + ', Cast=' + ISNULL(CAST(@importe AS VARCHAR), 'NULL');
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        PRINT '     -> Insertando Agua...';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'servicios publicos', 'agua', '-', @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                    END
                    ELSE PRINT '     -> OMITIDO (Importe es NULL o 0)';
                    SET @nroFactura += 1;

                    -- G. Servicios Públicos - Luz
                    SET @ImporteString = ISNULL(@stg_gasto_pub_luz, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma)
                        SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE
                        SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));

                    PRINT '  G. Gasto Luz: Staging=' + ISNULL(@stg_gasto_pub_luz, 'NULL') + ', Limpio=' + ISNULL(@ImporteLimpio, 'NULL') + ', Cast=' + ISNULL(CAST(@importe AS VARCHAR), 'NULL');
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        PRINT '     -> Insertando Luz...';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'servicios publicos', 'luz', '-', @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                    END
                    ELSE PRINT '     -> OMITIDO (Importe es NULL o 0)';
                    SET @nroFactura += 1;

                END
            END
        END
        ELSE
        BEGIN
            PRINT 'ERROR: No se encontró el consorcio: ' + ISNULL(@nomConsorcio, 'NOMBRE NULO');
        END

        PRINT 'FIN Iteración ' + CAST(@i AS VARCHAR);
        SET @i += 1;
    END; -- Fin del Bucle WHILE


    IF OBJECT_ID('tempdb..#cte_expensa') IS NOT NULL DROP TABLE #cte_expensa;
    IF OBJECT_ID('tempdb..#expensa_staging') IS NOT NULL DROP TABLE #expensa_staging;

END
GO

EXEC consorcio.SP_carga_expensas @path = 'C:\Archivos para el TP\Servicios.Servicios.json'
SELECT * FROM consorcio.expensa
SELECT * FROM consorcio.gasto_ordinario



--------------------------------------------------------------------------------
-- NUMERO: 7
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Importar Proveedores
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_importar_proveedores_excel
    @path NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('consorcio.proveedor_temp', 'U') IS NOT NULL
        DROP TABLE consorcio.proveedor_temp;

    CREATE TABLE consorcio.proveedor_temp (
        id_temp INT IDENTITY(1,1) PRIMARY KEY,
        tipoGasto VARCHAR(100) NOT NULL,
        nomEmpresa VARCHAR(100) NULL,
        descripcion VARCHAR(100) NULL,
        nombreConsorcio VARCHAR(100) NOT NULL
    );

    -------------------------------------------------------------------------
    -- 2. Cargar datos del Excel (rango especÃ­fico)
    -------------------------------------------------------------------------
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'
    INSERT INTO consorcio.proveedor_temp (tipoGasto, nomEmpresa, descripcion, nombreConsorcio)
    SELECT
        LTRIM(RTRIM(CAST(t.F1 AS VARCHAR(100)))) AS tipoGasto,
        LTRIM(RTRIM(CAST(t.F2 AS VARCHAR(100)))) AS nomEmpresa,
        LTRIM(RTRIM(CAST(t.F3 AS VARCHAR(255)))) AS descripcion,
        LTRIM(RTRIM(CAST(t.F4 AS VARCHAR(100)))) AS nombreConsorcio
    FROM OPENROWSET(
        ''Microsoft.ACE.OLEDB.12.0'',
        ''Excel 12.0;Database=' + @path + ';HDR=NO;IMEX=1;'',
        ''SELECT * FROM [Proveedores$B3:E30]''
    ) AS t
    WHERE
        t.F1 IS NOT NULL
        AND t.F4 IS NOT NULL;';

    EXEC sp_executesql @sql;

    -------------------------------------------------------------------------
    -- 3. Insertar en la tabla definitiva (relacionando con consorcio)
    -------------------------------------------------------------------------
    INSERT INTO consorcio.proveedor (
        idConsorcio,
        tipoGasto,
        nomEmpresa,
        descripcion
    )
    SELECT
        c.idConsorcio,
        t.tipoGasto,
        t.nomEmpresa,
        t.descripcion
    FROM consorcio.proveedor_temp AS t
    INNER JOIN consorcio.consorcio AS c
        ON LTRIM(RTRIM(t.nombreConsorcio)) = c.nombre;

    -------------------------------------------------------------------------
    -- 4. Limpiar tabla temporal
    -------------------------------------------------------------------------
    DROP TABLE consorcio.proveedor_temp;
END;
GO