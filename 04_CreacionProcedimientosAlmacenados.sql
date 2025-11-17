/*
================================================================================
Materia:          Bases de Datos Aplicadas
Comisión:         01-2900
Grupo:            G08
Fecha de Entrega: 04/11/2025
Integrantes:
    - Bentancur Suarez, Ismael (45823439)
    - Rodriguez Arrien, Juan Manuel (44259478)
    - Rodriguez, Patricio (45683229)
    - Ruiz, Leonel Emiliano (45537914)
Enunciado:        "04 - Creación de Procedimientos Almacenados"
================================================================================
*/

USE Com2900G08;
GO

--------------------------------------------------------------------------------
-- NUMERO: 1
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Importar consorcios
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_importar_consorcios_excel
    @path NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    -------------------------------------------------------------------------
    -- 1. Crear tabla staging
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#stg_consorcio', 'U') IS NOT NULL
        DROP TABLE #stg_consorcio;

    CREATE TABLE #stg_consorcio (
        stg_nroConsorcioExcel VARCHAR(20),
        stg_nombre VARCHAR(50) NOT NULL,
        stg_direccion VARCHAR(50) NOT NULL,
        stg_cantidadUnidadesFuncionales INT NOT NULL,
        stg_metrosCuadradosTotales INT NOT NULL
    );

    -------------------------------------------------------------------------
    -- 2. Cargar Excel a staging
    -------------------------------------------------------------------------
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'
    INSERT INTO #stg_consorcio (
        stg_nroConsorcioExcel, stg_nombre, stg_direccion, stg_cantidadUnidadesFuncionales, stg_metrosCuadradosTotales
    )
    SELECT 
        LTRIM(RTRIM(CAST([Consorcio] AS VARCHAR(20)))) AS stg_nroConsorcioExcel,
        LTRIM(RTRIM([Nombre del consorcio])) AS stg_nombre,
        LTRIM(RTRIM([Domicilio])) AS stg_direccion,
        TRY_CAST([Cant unidades funcionales] AS INT) AS stg_cantidadUnidadesFuncionales,
        TRY_CAST([m2 totales] AS INT) AS stg_metrosCuadradosTotales
    FROM OPENROWSET(
        ''Microsoft.ACE.OLEDB.12.0'',
        ''Excel 12.0;Database=' + @path + ';HDR=YES;IMEX=1;'',
        ''SELECT * FROM [Consorcios$]''
    ) AS t
    WHERE 
        LTRIM(RTRIM(CAST([Consorcio] AS VARCHAR(20)))) IS NOT NULL
        AND TRY_CAST([Cant unidades funcionales] AS INT) > 0
        AND TRY_CAST([m2 totales] AS INT) > 0
        AND LTRIM(RTRIM([Nombre del consorcio])) IS NOT NULL
        AND LTRIM(RTRIM([Domicilio])) IS NOT NULL;
    ';

    EXEC sp_executesql @sql;

    -------------------------------------------------------------------------
    -- 3. Crear tabla numerada para iterar
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#stg_Num', 'U') IS NOT NULL
        DROP TABLE #stg_Num;

    SELECT 
        ROW_NUMBER() OVER (ORDER BY stg_nroConsorcioExcel) AS rn,
        stg_nroConsorcioExcel,
        stg_nombre,
        stg_direccion,
        stg_cantidadUnidadesFuncionales,
        stg_metrosCuadradosTotales
    INTO #stg_Num
    FROM #stg_consorcio;

    DECLARE @i INT = 1;
    DECLARE @max INT;
    SELECT @max = MAX(rn) FROM #stg_Num;

    -------------------------------------------------------------------------
    -- 4. Iterar y llamar al SP de inserción
    -------------------------------------------------------------------------
    WHILE @i <= @max
    BEGIN
        DECLARE @idConsorcio INT,
                @nombre VARCHAR(50),
                @direccion VARCHAR(50),
                @cantidadUnidadesFuncionales INT,
                @metrosCuadradosTotales INT;

        SELECT 
            @idConsorcio = CAST(REPLACE(stg_nroConsorcioExcel, 'Consorcio ', '') AS INT),
            @nombre = stg_nombre,
            @direccion = stg_direccion,
            @cantidadUnidadesFuncionales = stg_cantidadUnidadesFuncionales,
            @metrosCuadradosTotales = stg_metrosCuadradosTotales
        FROM #stg_Num
        WHERE rn = @i;

        BEGIN TRY
            EXEC consorcio.sp_insertarConsorcio 
                @idConsorcio = @idConsorcio,
                @nombre = @nombre,
                @direccion = @direccion,
                @cantidadUnidadesFuncionales = @cantidadUnidadesFuncionales,
                @metrosCuadradosTotales = @metrosCuadradosTotales;
        END TRY
        BEGIN CATCH
            PRINT 'Error al insertar consorcio con ID ' 
                  + CAST(@idConsorcio AS VARCHAR) + ': ' + ERROR_MESSAGE();
        END CATCH;

        SET @i += 1;
    END;

    -------------------------------------------------------------------------
    -- 5. Limpiar staging
    -------------------------------------------------------------------------
    DROP TABLE #stg_Num;
    DROP TABLE #stg_consorcio;
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

    -------------------------------------------------------------------------
    -- 1. Crear tabla staging
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#stg_unidadesFuncionales', 'U') IS NOT NULL
        DROP TABLE #stg_unidadesFuncionales;

    CREATE TABLE #stg_unidadesFuncionales (
        stg_nombreConsorcio NVARCHAR(100),
        stg_numeroUnidadFuncional NVARCHAR(10),
        stg_piso CHAR(2),
        stg_departamento CHAR(1),
        stg_coeficiente NVARCHAR(10),
        stg_metrosCuadrados NVARCHAR(10),
        stg_bauleras NVARCHAR(2),
        stg_cochera NVARCHAR(2),
        stg_m2_baulera NVARCHAR(10),
        stg_m2_cochera NVARCHAR(10)
    );

    -------------------------------------------------------------------------
    -- 2. Cargar archivo con BULK INSERT
    -------------------------------------------------------------------------
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
        BULK INSERT #stg_unidadesFuncionales
        FROM ''' + @path + N'''
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ''\t'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            DATAFILETYPE = ''char''
        );';
    EXEC sp_executesql @sql;

    -------------------------------------------------------------------------
    -- 3. Crear tabla numerada para iterar
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#stg_Num', 'U') IS NOT NULL
        DROP TABLE #stg_Num;

    SELECT
        ROW_NUMBER() OVER (ORDER BY stg_nombreConsorcio, stg_numeroUnidadFuncional) AS rn,
        stg_nombreConsorcio,
        stg_numeroUnidadFuncional,
        stg_piso,
        stg_departamento,
        stg_coeficiente,
        stg_metrosCuadrados,
        stg_bauleras,
        stg_cochera,
        stg_m2_baulera,
        stg_m2_cochera
    INTO #stg_Num
    FROM #stg_unidadesFuncionales;

    DECLARE @i INT = 1;
    DECLARE @max INT;
    SELECT @max = MAX(rn) FROM #stg_Num;

    -------------------------------------------------------------------------
    -- 4. Iterar y llamar a SPs de inserción
    -------------------------------------------------------------------------
    WHILE @i <= @max
    BEGIN
        DECLARE 
            @nombreConsorcio NVARCHAR(100),
            @numeroUnidadFuncional INT,
            @piso CHAR(2),
            @departamento CHAR(1),
            @coeficiente DECIMAL(5,2),
            @metrosCuadrados INT,
            @bauleras NVARCHAR(2),
            @cochera NVARCHAR(2),
            @m2_baulera INT,
            @m2_cochera INT,
            @idConsorcio INT,
            @idUFCreada INT,
            @idCochera INT,
            @idBaulera INT;

        -- Obtener fila actual y castear
        SELECT
            @nombreConsorcio = stg_nombreConsorcio,
            @numeroUnidadFuncional = TRY_CAST(stg_numeroUnidadFuncional AS INT),
            @piso = stg_piso,
            @departamento = stg_departamento,
            @coeficiente = TRY_CAST(REPLACE(stg_coeficiente, ',', '.') AS DECIMAL(5,2)),
            @metrosCuadrados = TRY_CAST(stg_metrosCuadrados AS INT),
            @bauleras = stg_bauleras,
            @cochera = stg_cochera,
            @m2_baulera = TRY_CAST(REPLACE(stg_m2_baulera, ',', '.') AS INT),
            @m2_cochera = TRY_CAST(REPLACE(stg_m2_cochera, ',', '.') AS INT)
        FROM #stg_Num
        WHERE rn = @i;

        -- Obtener idConsorcio
        SELECT @idConsorcio = idConsorcio
        FROM consorcio.consorcio
        WHERE LTRIM(RTRIM(nombre)) = LTRIM(RTRIM(@nombreConsorcio));

        IF @idConsorcio IS NOT NULL
        BEGIN
            -- Insertar Unidad Funcional
            EXEC consorcio.sp_insertarUnidadFuncional
                @idConsorcio = @idConsorcio,
                @cuentaOrigen = 0,
                @numeroUnidadFuncional = @numeroUnidadFuncional,
                @piso = @piso,
                @departamento = @departamento,
                @coeficiente = @coeficiente,
                @metrosCuadrados = @metrosCuadrados,
                @idUFCreada = @idUFCreada OUTPUT;

            -- Insertar cochera si corresponde
            IF @cochera = 'SI' AND @m2_cochera > 0
            BEGIN
                EXEC consorcio.sp_insertarCochera
                    @idUnidadFuncional = @idUFCreada,
                    @metrosCuadrados = @m2_cochera,
                    @coeficiente = @coeficiente,
                    @idCocheraCreada = @idCochera OUTPUT;
            END

            -- Insertar baulera si corresponde
            IF @bauleras = 'SI' AND @m2_baulera > 0
            BEGIN
                EXEC consorcio.sp_insertarBaulera
                    @idUnidadFuncional = @idUFCreada,
                    @metrosCuadrados = @m2_baulera,
                    @coeficiente = @coeficiente,
                    @idBauleraCreada = @idBaulera OUTPUT;
            END
        END

        SET @i = @i + 1;
    END

    -------------------------------------------------------------------------
    -- 5. Limpiar staging
    -------------------------------------------------------------------------
    DROP TABLE #stg_Num;
    DROP TABLE #stg_unidadesFuncionales;
END;
GO


--------------------------------------------------------------------------------
-- NUMERO: 3
-- ARCHIVO: inquilino-propietarios-UF.csv
-- PROCEDIMIENTO: Importar cuentas origen para las UF ya creadas
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_importar_unidades_funcionales_csv
    @path NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------------
    -- 1. Crear tabla staging
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#tempUF_CSV', 'U') IS NOT NULL
        DROP TABLE #tempUF_CSV;

    CREATE TABLE #tempUF_CSV (
        stg_cvu_cbu            NVARCHAR(50),
        stg_nombre_consorcio   NVARCHAR(50),
        stg_nroUnidadFuncional NVARCHAR(10),
        stg_piso               NVARCHAR(10),
        stg_departamento       NVARCHAR(10)
    );

    -------------------------------------------------------------------------
    -- 2. Cargar archivo con BULK INSERT
    -------------------------------------------------------------------------
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
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
    EXEC sp_executesql @sql;

    -------------------------------------------------------------------------
    -- 3. Crear tabla numerada para iterar
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#tempUF_Num', 'U') IS NOT NULL
        DROP TABLE #tempUF_Num;

    SELECT 
        ROW_NUMBER() OVER (ORDER BY t.stg_nombre_consorcio, t.stg_piso, t.stg_departamento) AS rn,
        uf.idUnidadFuncional,
        CAST(TRIM(t.stg_cvu_cbu) AS VARCHAR(22)) AS cuentaOrigen
    INTO #tempUF_Num
    FROM consorcio.unidad_funcional AS uf
    INNER JOIN consorcio.consorcio AS c
        ON uf.idConsorcio = c.idConsorcio
    INNER JOIN #tempUF_CSV AS t
        ON TRIM(t.stg_nombre_consorcio) = c.nombre
        AND TRIM(t.stg_piso) = uf.piso
        AND TRIM(t.stg_departamento) = uf.departamento
    WHERE ISNUMERIC(uf.cuentaOrigen) = 1
      AND uf.cuentaOrigen != CAST(TRIM(t.stg_cvu_cbu) AS CHAR(22));

    -------------------------------------------------------------------------
    -- 4. Iterar y llamar a SPs de modificacion
    -------------------------------------------------------------------------
    DECLARE @i INT = 1;
    DECLARE @max INT;
    DECLARE @idUF INT;
    DECLARE @cuentaOrigen VARCHAR(22);

    SELECT @max = MAX(rn) FROM #tempUF_Num;

    WHILE @i <= @max
    BEGIN
        SELECT 
            @idUF = idUnidadFuncional,
            @cuentaOrigen = cuentaOrigen
        FROM #tempUF_Num
        WHERE rn = @i;

        EXEC consorcio.sp_modificarUnidadFuncional
            @idUnidadFuncional = @idUF,
            @cuentaOrigen = @cuentaOrigen;

        SET @i = @i + 1;
    END

    -------------------------------------------------------------------------
    -- 5. Limpiar staging
    -------------------------------------------------------------------------
    DROP TABLE #tempUF_Num;
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
    SET NOCOUNT ON;
    
    -- Variables para la carga masiva (BULK INSERT)
    DECLARE @sqlBulkInsert NVARCHAR(MAX);
    
    -- Variables para el manejo de errores
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;
    
    -- Iniciar la transacción para asegurar atomicidad (todo o nada)
    BEGIN TRANSACTION
    
    BEGIN TRY
        
        --------------------------------------------------
        -- 1. CREAR TABLA TEMPORAL
        --------------------------------------------------
        -- Asegurar limpieza de tabla temporal
        IF OBJECT_ID('tempdb..#temporal') IS NOT NULL
            DROP TABLE #temporal;
            
        CREATE TABLE #temporal (
            Col1_Nombre         VARCHAR(100),
            Col2_Apellido       VARCHAR(100),
            Col3_DNI            VARCHAR(50),
            Col4_Email          VARCHAR(100),
            Col5_Telefono       VARCHAR(50),
            Col6_CuentaOrigen   CHAR(22),
            Col7_Inquilino      DECIMAL(2, 0) -- 1 = inquilino, 0 = propietario
        );
        
        --------------------------------------------------
        -- 2. CARGAR CSV (Bloque dinámico - BULK INSERT)
        --------------------------------------------------
        SET @sqlBulkInsert = '
            BULK INSERT #temporal
            FROM ''' + @path + '''
            WITH (
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''0x0A'', -- Línea nueva LF (Unix/Linux) o 0x0D0A para CR+LF (Windows)
                FIRSTROW = 2,
                CODEPAGE = ''1252'' -- Codificación para caracteres especiales como ñ, ó, é.
            );
        ';
        
        EXEC sp_executesql @sqlBulkInsert;

        --------------------------------------------------
        -- 3. INSERTAR NUEVAS PERSONAS en consorcio.persona
        --------------------------------------------------
        WITH DatosLimpios AS (
            SELECT  
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

                CAST(LTRIM(RTRIM(t.Col3_DNI)) AS INT) AS dni, -- DNI en entero

                -- Email a minúsculas y limpieza
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

                LTRIM(RTRIM(t.Col5_Telefono)) AS telefono,
                LTRIM(RTRIM(t.Col6_CuentaOrigen)) AS cuentaOrigen,
                
                -- Deduplicación por DNI: elegimos la primera aparición de un DNI
                ROW_NUMBER() OVER (PARTITION BY t.Col3_DNI ORDER BY (SELECT 1)) as rn 
            FROM #temporal t
            WHERE 
                ISNUMERIC(LTRIM(RTRIM(t.Col3_DNI))) = 1 -- Solo DNI válidos
                AND LTRIM(RTRIM(t.Col3_DNI)) <> ''
        )
        
        INSERT INTO consorcio.persona (
            nombre, apellido, dni, email, telefono, cuentaOrigen
        )
        SELECT  
            dl.nombre, dl.apellido, dl.dni, dl.email, dl.telefono, dl.cuentaOrigen
        FROM DatosLimpios dl
        WHERE
            dl.rn = 1 -- Solo el registro principal (deduplicado)
            AND NOT EXISTS ( -- Evita insertar personas que ya existen por DNI
                SELECT 1 
                FROM consorcio.persona p 
                WHERE p.dni = dl.dni
            );

        --------------------------------------------------
        -- 4. INSERTAR RELACIONES en consorcio.persona_unidad_funcional
        --------------------------------------------------
        INSERT INTO consorcio.persona_unidad_funcional (idPersona, idUnidadFuncional, rol)
        SELECT
            p.idPersona,
            uf.idUnidadFuncional,
            -- Asignación de rol simple
            CASE  
                WHEN t.Col7_Inquilino = 1 THEN 'inquilino'
                ELSE 'propietario'
            END AS rol
        FROM #temporal t         
        
        INNER JOIN consorcio.persona p -- Une con la tabla Persona (existente o recién insertada)
            ON p.dni = CAST(LTRIM(RTRIM(t.Col3_DNI)) AS INT)
        
        INNER JOIN consorcio.unidad_funcional uf -- Une con la Unidad Funcional (por cuentaOrigen)
            ON uf.cuentaOrigen = LTRIM(RTRIM(t.Col6_CuentaOrigen))
        
        WHERE 
            ISNUMERIC(LTRIM(RTRIM(t.Col3_DNI))) = 1 AND LTRIM(RTRIM(t.Col3_DNI)) <> ''
            
            AND NOT EXISTS ( -- Evita insertar relaciones ya existentes (misma UF y mismo Rol)
                SELECT 1 
                FROM consorcio.persona_unidad_funcional puf
                WHERE puf.idUnidadFuncional = uf.idUnidadFuncional
                AND puf.rol = CASE  
                                  WHEN t.Col7_Inquilino = 1 THEN 'inquilino'
                                  ELSE 'propietario'
                              END
            );
        
        --------------------------------------------------
        -- 5. ÉXITO Y COMMIT
        --------------------------------------------------
        COMMIT TRANSACTION
        
        -- 6. LIMPIEZA DE TABLA TEMPORAL
        IF OBJECT_ID('tempdb..#temporal') IS NOT NULL
            DROP TABLE #temporal;

    END TRY
    BEGIN CATCH
        
        -- 7. MANEJO DE ERROR Y ROLLBACK
        
        -- Si hay una transacción activa, revertir
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Capturar la información del error
        SELECT  
            @ErrorMessage = ERROR_MESSAGE(), 
            @ErrorSeverity = ERROR_SEVERITY(), 
            @ErrorState = ERROR_STATE();

        -- 8. LIMPIEZA DE TABLA TEMPORAL EN CASO DE ERROR
        IF OBJECT_ID('tempdb..#temporal') IS NOT NULL
            DROP TABLE #temporal;
            
        SELECT
            'Error al importar los datos. La tabla temporal fue limpiada y la transacción revertida.' AS Resultado,
            ERROR_NUMBER() AS ErrorNumber,
            @ErrorMessage AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;

        -- Re-lanzar el error para que la aplicación lo capture
        THROW; 
        
        -- Devolver un código de error
        RETURN 1;

    END CATCH
    
    -- Devolver un código de éxito al final del procedimiento
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

    -------------------------------------------------------------------------
    -- 1. Crear tabla staging
    -------------------------------------------------------------------------
    CREATE TABLE #pago_staging (
        stg_idPago      NVARCHAR(50),
        stg_fecha       NVARCHAR(50),
        stg_cvu_cbu     NVARCHAR(50),
        stg_valor       NVARCHAR(50)
    );

    -------------------------------------------------------------------------
    -- 2. Cargar archivo CSV con BULK INSERT
    -------------------------------------------------------------------------
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
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
    EXEC sp_executesql @sql;

    -------------------------------------------------------------------------
    -- 3. Crear tabla numerada
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#pago_Num', 'U') IS NOT NULL
        DROP TABLE #pago_Num;

    SELECT 
        ROW_NUMBER() OVER (ORDER BY stg_idPago) AS rn,
        stg_idPago, stg_fecha, stg_cvu_cbu, stg_valor
    INTO #pago_Num
    FROM #pago_staging
    WHERE stg_idPago IS NOT NULL AND ISNUMERIC(stg_idPago) = 1;

    DECLARE @i INT = 1;
    DECLARE @max INT;
    SELECT @max = MAX(rn) FROM #pago_Num;

    -------------------------------------------------------------------------
    -- 4. Iterar y llamar a SPs de ABM
    -------------------------------------------------------------------------
    WHILE @i <= @max
    BEGIN
        DECLARE @idPago INT,
                @fecha DATE,
                @cuentaOrigen CHAR(22),
                @importe DECIMAL(13,3),
                @estaAsociado BIT = 0;

        SELECT 
            @idPago = CAST(stg_idPago AS INT),
            @fecha = TRY_CONVERT(DATE, stg_fecha, 103),
            @cuentaOrigen = CAST(LTRIM(RTRIM(stg_cvu_cbu)) AS CHAR(22)),
             @importe = CAST(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(stg_valor)),'$',''),'.',''),',','.') AS DECIMAL(13,3))
        FROM #pago_Num
        WHERE rn = @i;

        BEGIN TRY
            EXEC consorcio.sp_insertarPago
                @idPago = @idPago,
                @cuentaOrigen = @cuentaOrigen,
                @importe = @importe,
                @estaAsociado = @estaAsociado,
                @fecha = @fecha;
        END TRY
        BEGIN CATCH
            PRINT 'Error al insertar pago con ID: ' + CAST(@idPago AS VARCHAR);
        END CATCH

        SET @i = @i + 1;
    END

    -------------------------------------------------------------------------
    -- 5. Limpiar staging
    -------------------------------------------------------------------------
    DROP TABLE #pago_Num;
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

    -------------------------------------------------------------------------
    -- 0. Declaraciones de variables
    -------------------------------------------------------------------------
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @i INT = 1, @max INT, @nomConsorcio VARCHAR(100), @periodo VARCHAR(50);
    DECLARE @idConsorcio INT, @idExpensa INT, @idGasto INT, @idGastoOrdCreado INT;
    DECLARE @stg_gasto_banc NVARCHAR(50), @stg_gasto_limp NVARCHAR(50),
            @stg_gasto_adm NVARCHAR(50), @stg_gasto_seg NVARCHAR(50),
            @stg_gasto_gen NVARCHAR(50), @stg_gasto_pub_agua NVARCHAR(50),
            @stg_gasto_pub_luz NVARCHAR(50);
    DECLARE @importe DECIMAL(12,2), @nroFactura INT = 1;
    DECLARE @ImporteString NVARCHAR(50), @ImporteLimpio NVARCHAR(50), @PosPeriod INT, @PosComma INT;
    DECLARE @subTipo NVARCHAR(50), @nomEmpresa NVARCHAR(50);
    DECLARE @subtotal DECIMAL(12,2);

    -------------------------------------------------------------------------
    -- 1. Crear y Cargar tabla staging
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#expensa_staging') IS NOT NULL DROP TABLE #expensa_staging;
    CREATE TABLE #expensa_staging (
        stg_nom_consorcio VARCHAR(50), stg_periodo VARCHAR(50), stg_gasto_banc NVARCHAR(50), stg_gasto_limp NVARCHAR(50), stg_gasto_adm NVARCHAR(50), 
        stg_gasto_seg NVARCHAR(50), stg_gasto_gen NVARCHAR(50), stg_gasto_pub_agua NVARCHAR(50), stg_gasto_pub_luz NVARCHAR(50)
    );

    SET @SQL = N'
    INSERT INTO #expensa_staging(stg_nom_consorcio, stg_periodo, stg_gasto_banc, stg_gasto_limp, stg_gasto_adm, stg_gasto_seg, stg_gasto_gen, stg_gasto_pub_agua, stg_gasto_pub_luz)
    SELECT 
        stg_nom_consorcio, stg_periodo, stg_gasto_banc, stg_gasto_limp, stg_gasto_adm, stg_gasto_seg, stg_gasto_gen, stg_gasto_pub_agua, stg_gasto_pub_luz
    FROM OPENROWSET (BULK ''' + @path + N''', SINGLE_CLOB) AS j
    CROSS APPLY OPENJSON(BulkColumn) WITH (
        stg_nom_consorcio VARCHAR(50) ''$."Nombre del consorcio"'', stg_periodo VARCHAR(50) ''$.Mes'', stg_gasto_banc NVARCHAR(50) ''$.BANCARIOS'', stg_gasto_limp NVARCHAR(50) ''$.LIMPIEZA'', 
        stg_gasto_adm NVARCHAR(50) ''$.ADMINISTRACION'', stg_gasto_seg NVARCHAR(50) ''$.SEGUROS'', stg_gasto_gen NVARCHAR(50) ''$."GASTOS GENERALES"'', 
        stg_gasto_pub_agua NVARCHAR(50) ''$."SERVICIOS PUBLICOS-Agua"'', stg_gasto_pub_luz NVARCHAR(50) ''$."SERVICIOS PUBLICOS-Luz"'' 
    );';
    EXEC sp_executesql @SQL;

    -------------------------------------------------------------------------
    -- 2. Numerar filas para iterar
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#expensa_num', 'U') IS NOT NULL DROP TABLE #expensa_num;
    SELECT ROW_NUMBER() OVER (ORDER BY stg_nom_consorcio) AS rn, *
    INTO #expensa_num FROM #expensa_staging;
    
    SELECT @max = MAX(rn) FROM #expensa_num;

    -------------------------------------------------------------------------
    -- 3. Bucle de inserción
    -------------------------------------------------------------------------
    WHILE @i <= @max
    BEGIN
        SET @subtotal = 0;

        SELECT @nomConsorcio = stg_nom_consorcio, @periodo = stg_periodo,
               @stg_gasto_banc = stg_gasto_banc, @stg_gasto_limp = stg_gasto_limp, @stg_gasto_adm = stg_gasto_adm,
               @stg_gasto_seg = stg_gasto_seg, @stg_gasto_gen = stg_gasto_gen, @stg_gasto_pub_agua = stg_gasto_pub_agua,
               @stg_gasto_pub_luz = stg_gasto_pub_luz
        FROM #expensa_num WHERE rn = @i;

        SELECT @idConsorcio = idConsorcio FROM consorcio.consorcio WHERE nombre = @nomConsorcio AND fechaBaja IS NULL;

        IF @idConsorcio IS NOT NULL
        BEGIN
            SET @idExpensa = NULL;
            EXEC consorcio.sp_insertarExpensa @idConsorcio, @periodo, 2025, @idExpensa OUTPUT;

            IF @idExpensa IS NOT NULL
            BEGIN
                SET @idGasto = NULL;
                EXEC consorcio.sp_insertarGasto @idExpensa, 0, 0, @idGasto OUTPUT;

                IF @idGasto IS NOT NULL
                BEGIN
                    -- A. Gasto Bancario
                    SET @ImporteString = ISNULL(@stg_gasto_banc, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma) SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        SET @subTipo = ''; SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'bancario', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1; SET @subtotal += @importe;
                    END

                    -- B. Gasto Limpieza
                    SET @ImporteString = ISNULL(@stg_gasto_limp, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma) SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        SET @subTipo = ''; SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'limpieza', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1; SET @subtotal += @importe;
                    END

                    -- C. Gasto Administración
                    SET @ImporteString = ISNULL(@stg_gasto_adm, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma) SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        SET @subTipo = ''; SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'administracion', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1; SET @subtotal += @importe;
                    END

                    -- D. Gasto Seguros
                    SET @ImporteString = ISNULL(@stg_gasto_seg, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma) SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        SET @subTipo = ''; SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'seguros', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1; SET @subtotal += @importe;
                    END

                    -- E. Gasto Generales
                    SET @ImporteString = ISNULL(@stg_gasto_gen, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma) SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        SET @subTipo = ''; SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'generales', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1; SET @subtotal += @importe;
                    END

                    -- F. Servicios Públicos - Agua
                    SET @ImporteString = ISNULL(@stg_gasto_pub_agua, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma) SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        SET @subTipo = 'agua'; SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'servicios publicos', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1; SET @subtotal += @importe;
                    END

                    -- G. Servicios Públicos - Luz
                    SET @ImporteString = ISNULL(@stg_gasto_pub_luz, '0');
                    SET @PosPeriod = CHARINDEX('.', REVERSE(@ImporteString));
                    SET @PosComma = CHARINDEX(',', REVERSE(@ImporteString));
                    IF @PosPeriod = 0 SET @PosPeriod = 999;
                    IF @PosComma = 0 SET @PosComma = 999;
                    IF (@PosPeriod < @PosComma) SET @ImporteLimpio = REPLACE(@ImporteString, ',', '');
                    ELSE SET @ImporteLimpio = REPLACE(REPLACE(@ImporteString, '.', ''), ',', '.');
                    SET @importe = TRY_CAST(@ImporteLimpio AS DECIMAL(12,2));
                    IF @importe IS NOT NULL AND @importe > 0
                    BEGIN
                        SET @subTipo = 'luz'; SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'servicios publicos', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1; SET @subtotal += @importe;
                    END

                    -- Actualizar gasto padre con subtotal
                    EXEC consorcio.sp_modificarGasto @idGasto, @subtotal, NULL;

                END
            END
        END

        SET @i += 1;
    END

    -------------------------------------------------------------------------
    -- 4. Limpiar staging
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#expensa_num') IS NOT NULL DROP TABLE #expensa_num;
    IF OBJECT_ID('tempdb..#expensa_staging') IS NOT NULL DROP TABLE #expensa_staging;

END
GO


--------------------------------------------------------------------------------
-- NUMERO: 7
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Importar Proveedores
-- To Do: (Pato) -> Tengo que hacer el refactor cuando este el ABM de Proveedores
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
    -- 2. Cargar datos del Excel (rango especi­fico)
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


--------------------------------------------------------------------------------
-- NUMERO: 8
-- ARCHIVO: -
-- PROCEDIMIENTO: Actualizacion de tabla gasto_ordinario con los datos de los proveedores
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_procesa_actualizacion_gastos
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#stg_gastosProcesados') IS NOT NULL DROP TABLE #stg_gastosProcesados;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Crear tabla temporal de staging con los cálculos de actualización
        SELECT 
            go.idGastoOrd,
            
            -- Cálculo de subTipoGasto_nuevo
            CASE 
                -- Extracción del subtipo si el proveedor tiene ' - '
                WHEN CHARINDEX(' - ', p.nomEmpresa) > 0 THEN
                    TRIM(SUBSTRING(p.nomEmpresa, CHARINDEX(' - ', p.nomEmpresa) + 3, LEN(p.nomEmpresa)))
                -- Mapeo Simple
                WHEN LOWER(go.tipoGasto) = 'administracion' THEN 'Honorarios'
                WHEN LOWER(go.tipoGasto) = 'limpieza' THEN 'Servicio General'
                WHEN LOWER(go.tipoGasto) = 'generales' THEN 'Varios'
                ELSE NULL 
            END AS subTipoGasto_nuevo,
            
            -- Calculo de nomEmpresa_nuevo
            CASE 
                -- Fragmentación del proveedor (toma el nombre antes del ' - ')
                WHEN p.nomEmpresa IS NOT NULL AND CHARINDEX(' - ', p.nomEmpresa) > 0 THEN
                    CAST(TRIM(LEFT(p.nomEmpresa, CHARINDEX(' - ', p.nomEmpresa) - 1)) AS VARCHAR(40))
                -- Uso del nombre completo del proveedor (si existe)
                WHEN p.nomEmpresa IS NOT NULL THEN
                    CAST(TRIM(p.nomEmpresa) AS VARCHAR(40))
                -- RESCATE para 'administracion'
                WHEN LOWER(go.tipoGasto) = 'administracion' THEN 
                    CAST(go.nomEmpresa AS VARCHAR(40)) 
                ELSE
                    NULL
            END AS nomEmpresa_nuevo
            
        INTO #stg_gastosProcesados
        FROM consorcio.gasto_ordinario AS go
        INNER JOIN consorcio.gasto AS g ON go.idGasto = g.idGasto
        INNER JOIN consorcio.expensa AS e ON g.idExpensa = e.idExpensa
        LEFT JOIN consorcio.proveedor AS p
            ON e.idConsorcio = p.idConsorcio
            AND UPPER(TRIM(p.tipoGasto)) LIKE '%' + UPPER(TRIM(go.tipoGasto)) + '%';
        
        -- 2. Aplicar la actualización de datos
        UPDATE go
        SET 
            go.subTipoGasto = COALESCE(stg.subTipoGasto_nuevo, go.subTipoGasto), 
            go.nomEmpresa = COALESCE(stg.nomEmpresa_nuevo, go.nomEmpresa)
            
        FROM consorcio.gasto_ordinario AS go
        INNER JOIN #stg_gastosProcesados AS stg
            ON go.idGastoOrd = stg.idGastoOrd;
        
        -- Limpieza de tablas temporales
        DROP TABLE #stg_gastosProcesados;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        -- Manejo de errores: deshace todos los cambios
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        RETURN;
    END CATCH;
END;
GO


--------------------------------------------------------------------------------
-- NUMERO: 9
-- ARCHIVO: -
-- PROCEDIMIENTO: Actualizacion de tabla gasto_extraOrdinario
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_crearGastosExtraordinariosJunio
AS
BEGIN
    -- Tabla temporal para mapear idGasto, generar la factura única y almacenar los datos del gasto.
    -- Utilizamos IDENTITY para generar un ID de fila que servirá como base para el nroFactura.
    DECLARE @GastosJunio TABLE (
        TempID INT IDENTITY(1,1),
        idGasto INT,
        idConsorcio INT,
        nroFactura INT,
        importe DECIMAL(12,2)
    );

    -- Variables para el nuevo gasto extraordinario
    DECLARE @TipoGasto VARCHAR(12) = 'construccion';
    DECLARE @NomEmpresa VARCHAR(40) = 'Seguridad Total S.A.';
    DECLARE @Descripcion VARCHAR(50) = 'Instalación y configuración de cámaras de seguridad (Cuota 1/1)';
    DECLARE @NroCuota INT = 1;
    DECLARE @TotalCuotas INT = 1;
    DECLARE @ImporteFijo DECIMAL(12,2) = 100000.00;
    DECLARE @BaseFactura INT = 6000;

    -- 1. Insertar los idGasto de Junio 2025 en la tabla temporal
    -- Asumimos idGasto (3, 6, 9, 15, 12) corresponden a idConsorcio (1, 2, 3, 4, 5)
    INSERT INTO @GastosJunio (idGasto, idConsorcio, importe)
    VALUES
        (3, 1, @ImporteFijo),  -- Consorcio 1, idGasto de Junio
        (6, 2, @ImporteFijo),  -- Consorcio 2, idGasto de Junio
        (9, 3, @ImporteFijo),  -- Consorcio 3, idGasto de Junio
        (15, 4, @ImporteFijo), -- Consorcio 4, idGasto de Junio
        (12, 5, @ImporteFijo); -- Consorcio 5, idGasto de Junio
    
    -- 2. Generar el número de factura único para cada registro.
    -- Actualizamos la columna nroFactura en base al ID temporal + BaseFactura.
    UPDATE @GastosJunio
    SET nroFactura = @BaseFactura + TempID;

    -- 3. Actualizar el resumen de gasto (subTotalExtraOrd) en la tabla principal
    UPDATE consorcio.gasto
    SET subTotalExtraOrd = ISNULL(g.subTotalExtraOrd, 0.00) + gj.importe
    FROM consorcio.gasto g
    INNER JOIN @GastosJunio gj ON g.idGasto = gj.idGasto;

    -- 4. Insertar el detalle del Gasto Extraordinario (Cuota 1/1) en la tabla principal
    INSERT INTO consorcio.gasto_extra_ordinario (
        idGasto, tipoGasto, nomEmpresa, nroFactura, descripcion, nroCuota, totalCuotas, importe
    )
    SELECT
        gj.idGasto,
        @TipoGasto,
        @NomEmpresa,
        gj.nroFactura,
        @Descripcion,
        @NroCuota,
        @TotalCuotas,
        gj.importe
    FROM @GastosJunio gj;

    PRINT 'Se han insertado los gastos extraordinarios de Junio (Cuota 1/1) para los 5 consorcios.';
END
GO

--------------------------------------------------------------------------------
-- NUMERO: 10
-- ARCHIVO: -
-- PROCEDIMIENTO: Generar detalles de expensas de Abril, Mayo y Junio
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_asociarPagosAUF
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @PagosAsociados INT = 0;

        -- Actualizamos la tabla 'pago' uniéndola con 'unidad_funcional'
        UPDATE P
        SET
            P.estaAsociado = 1 
        FROM
            consorcio.pago AS P
        JOIN
            consorcio.unidad_funcional AS UF
            ON P.cuentaOrigen = UF.cuentaOrigen 
        WHERE
            P.estaAsociado = 0 
            AND UF.fechaBaja IS NULL       
            AND P.idDetalleExpensa IS NULL;

        SET @PagosAsociados = @@ROWCOUNT;

        COMMIT TRANSACTION;

        PRINT 'Asociación de Pagos a UFs completada.';
        PRINT 'Pagos nuevos asociados (marcados como estaAsociado = 1): ' + CAST(@PagosAsociados AS VARCHAR(10));
        RETURN 0;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE(), @ErrNo INT = ERROR_NUMBER();
      	RAISERROR('Error al asociar Pagos a UF (Err %d): %s. Transacción revertida.', 16, 1, @ErrNo, @ErrMsg);
      	RETURN -100;
  	END CATCH
END;
GO

CREATE OR ALTER PROCEDURE consorcio.sp_generarFacturasMensuales
    @idConsorcio INT,
    @periodo VARCHAR(12),
    @anio INT,
    @fechaEmision DATE = NULL,
    @fechaPrimerVenc DATE,
    @fechaSegundoVenc DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Declaración de tasas de interés y variables
    DECLARE @TasaMoraMenor DECIMAL(5,2) = 0.02;
    DECLARE @TasaMoraMayor DECIMAL(5,2) = 0.05;
    DECLARE @mes INT;
    DECLARE @periodo_norm VARCHAR(12);

    BEGIN TRANSACTION;

    BEGIN TRY
        --Conversion de Periodo
        SET @periodo_norm = LOWER(LTRIM(RTRIM(@periodo)));
        IF @fechaEmision IS NULL SET @fechaEmision = GETDATE();

        SET @mes = CASE @periodo_norm
            WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3 WHEN 'abril' THEN 4
            WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6 WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8
            WHEN 'septiembre' THEN 9 WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
            ELSE NULL END;

        IF @mes IS NULL
        BEGIN
            RAISERROR('Periodo inválido.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN -10;
        END;

        --Validar Expensa Existente
        DECLARE @idExpensa INT;
        SELECT @idExpensa = idExpensa
        FROM consorcio.expensa
        WHERE idConsorcio = @idConsorcio
          AND periodo = @periodo_norm
          AND anio = @anio;

      	IF @idExpensa IS NULL
        BEGIN
            RAISERROR('No se encontró la expensa (Cierre) para el Consorcio y periodo indicados.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN -11;
        END;

        -- NO VOLVER A GENERAR SI YA EXISTEN
        IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @idExpensa)
      	BEGIN
        	PRINT 'Advertencia: Las facturas para este cierre (idExpensa=' + CAST(@idExpensa AS VARCHAR(10)) + ') ya existen. No se generó nada nuevo.';
        	COMMIT TRANSACTION;
        	RETURN 0;
      	END;

        -- Totales de gastos del mes actual
        DECLARE @TotalGastosOrd DECIMAL(12,2) = 0, @TotalGastosExt DECIMAL(12,2) = 0;
      	SELECT 
        	@TotalGastosOrd = ISNULL(SUM(subTotalOrdinarios),0),
        	@TotalGastosExt = ISNULL(SUM(subTotalExtraOrd),0)
      	FROM consorcio.gasto
      	WHERE idExpensa = @idExpensa;
        
      	--Buscar Expensa y Detalle del Mes Anterior
      	DECLARE @mesAnterior INT = CASE WHEN @mes = 1 THEN 12 ELSE @mes - 1 END;
      	DECLARE @anioAnterior INT = CASE WHEN @mes = 1 THEN @anio - 1 ELSE @anio END;
      	DECLARE @periodoAnterior VARCHAR(12) =
        	CASE @mesAnterior WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo' WHEN 4 THEN 'abril'
                          	WHEN 5 THEN 'mayo' WHEN 6 THEN 'junio' WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto'
                          	WHEN 9 THEN 'septiembre' WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre' END;

      	DECLARE @idExpensaAnterior INT = NULL;
      	SELECT @idExpensaAnterior = idExpensa
      	FROM consorcio.expensa
      	WHERE idConsorcio = @idConsorcio
        	AND periodo = @periodoAnterior
        	AND anio = @anioAnterior;

      	--Tabla temporal para calculos 
      	DECLARE @CalculoPrevio TABLE (
        	idUnidadFuncional INT PRIMARY KEY,
        	coeficiente DECIMAL(5,2),
        	saldoAnterior DECIMAL(12,2) DEFAULT 0,
        	pagoRecibido DECIMAL(12,2) DEFAULT 0,
  	    	deuda DECIMAL(12,2) DEFAULT 0,
        	interesPorMora DECIMAL(12,2) DEFAULT 0
      	);

      	--POBLAR TABLA TEMPORAL CON DATOS DEL ARRASTRE
      	INSERT INTO @CalculoPrevio (
        	idUnidadFuncional, coeficiente, saldoAnterior, pagoRecibido, deuda, interesPorMora
      	)
      	SELECT
        	UF.idUnidadFuncional,
        	UF.coeficiente,
        ISNULL(DE_Anterior.deuda, 0) + ISNULL(DE_Anterior.interesPorMora, 0) + ISNULL(DE_Anterior.expensasOrdinarias, 0) + ISNULL(DE_Anterior.expensasExtraordinarias, 0) AS saldoAnterior,
        	ISNULL(Pagos_Anteriores.TotalPagado, 0) AS pagoRecibido,
        (ISNULL(DE_Anterior.deuda, 0) + ISNULL(DE_Anterior.interesPorMora, 0) + ISNULL(DE_Anterior.expensasOrdinarias, 0) + ISNULL(DE_Anterior.expensasExtraordinarias, 0)) - ISNULL(Pagos_Anteriores.TotalPagado, 0) AS deuda,
        	-- CÁLCULO DE INTERESES (Solo sobre deuda neta positiva)
      	  	CASE
            	WHEN (ISNULL(DE_Anterior.totalAPagar, 0) - ISNULL(Pagos_Anteriores.TotalPagado, 0)) <= 0 THEN 0 
            	WHEN DE_Anterior.idDetalleExpensa IS NULL THEN 0 
            	WHEN @fechaEmision > DE_Anterior.fechaSegundoVenc AND DE_Anterior.fechaSegundoVenc IS NOT NULL 
                	THEN (ISNULL(DE_Anterior.totalAPagar, 0) - ISNULL(Pagos_Anteriores.TotalPagado, 0)) * @TasaMoraMayor
          	  WHEN @fechaEmision > DE_Anterior.fechaPrimerVenc 
              	  THEN (ISNULL(DE_Anterior.totalAPagar, 0) - ISNULL(Pagos_Anteriores.TotalPagado, 0)) * @TasaMoraMenor
            	ELSE 0
        	END AS interesPorMora
      	FROM consorcio.unidad_funcional UF
      	LEFT JOIN consorcio.detalle_expensa DE_Anterior
        	ON UF.idUnidadFuncional = DE_Anterior.idUnidadFuncional
        	AND DE_Anterior.idExpensa = @idExpensaAnterior
      	LEFT JOIN (
        	SELECT idDetalleExpensa, SUM(importe) AS TotalPagado
        	FROM consorcio.pago
        	WHERE idDetalleExpensa IS NOT NULL
        	GROUP BY idDetalleExpensa
      	) AS Pagos_Anteriores ON DE_Anterior.idDetalleExpensa = Pagos_Anteriores.idDetalleExpensa
  	  WHERE UF.idConsorcio = @idConsorcio
        	AND UF.fechaBaja IS NULL;
        
      	--Inserción final en detalle_expensa
      	INSERT INTO consorcio.detalle_expensa (
        	idExpensa, idUnidadFuncional,
        	fechaEmision, fechaPrimerVenc, fechaSegundoVenc,
        	saldoAnterior, pagoRecibido, deuda, interesPorMora,
        	expensasOrdinarias, expensasExtraordinarias, totalAPagar
      	)
      	SELECT
        	@idExpensa,
        	CP.idUnidadFuncional,
        	@fechaEmision,
  	    	@fechaPrimerVenc,
        	@fechaSegundoVenc,
        	CP.saldoAnterior,
  	    	CP.pagoRecibido,
        	CP.deuda,
    	    CP.interesPorMora,

        	ROUND(@TotalGastosOrd * (CP.coeficiente / 100.0), 2) AS expensasOrdinarias,
  	    	ROUND(@TotalGastosExt * (CP.coeficiente / 100.0), 2) AS expensasExtraordinarias,
            ROUND(
                (
                ROUND(@TotalGastosOrd * (CP.coeficiente / 100.0), 2)
                + ROUND(@TotalGastosExt * (CP.coeficiente / 100.0), 2)
                + CP.deuda
                + CP.interesPorMora
                ), 2)
            AS totalAPagar
      	FROM @CalculoPrevio CP;

      	COMMIT TRANSACTION;

      	PRINT 'Generación de facturas completada correctamente para idExpensa ' + CAST(@idExpensa AS VARCHAR(20));
  	    RETURN 0;
  	END TRY
  	BEGIN CATCH
  	  	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
  	  	DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE(), @ErrNo INT = ERROR_NUMBER();
  	  	RAISERROR('Error al generar facturas (Err %d): %s', 16, 1, @ErrNo, @ErrMsg);
  	  	RETURN -100;
  	END CATCH
END;
GO

CREATE OR ALTER PROCEDURE consorcio.sp_asociarPagosConsumidos
    @idConsorcio INT,
    @periodo VARCHAR(12),
    @anio INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @idExpensaAConciliar INT;
    DECLARE @mes INT;
    DECLARE @periodo_norm VARCHAR(12) = LOWER(LTRIM(RTRIM(@periodo)));
    DECLARE @fechaInicioPeriodo DATE;
    DECLARE @fechaFinPeriodo DATE;
    
    BEGIN TRY
        BEGIN TRANSACTION;

        --Conversion de Periodo y Calculo de Fechas
        SET @mes = CASE @periodo_norm
            WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3 WHEN 'abril' THEN 4
            WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6 WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8
            WHEN 'septiembre' THEN 9 WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
            ELSE NULL END;

        IF @mes IS NULL
        BEGIN
            RAISERROR('Periodo inválido.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN -10;
        END;

        SET @fechaInicioPeriodo = DATEFROMPARTS(@anio, @mes, 1);
        SET @fechaFinPeriodo = EOMONTH(@fechaInicioPeriodo);


        --IDENTIFICAR LA EXPENSA (Ej: Expensa de Abril)
        SELECT @idExpensaAConciliar = idExpensa
        FROM consorcio.expensa
        WHERE idConsorcio = @idConsorcio
          AND periodo = @periodo_norm
          AND anio = @anio;

        IF @idExpensaAConciliar IS NULL
        BEGIN
            RAISERROR('No se encontró la Expensa a conciliar (%s %d).', 16, 1, @periodo, @anio);
            ROLLBACK TRANSACTION;
            RETURN -11;
        END

        --Tabla temporal que mapea Pagos Disponibles a su idUnidadFuncional
        IF OBJECT_ID('tempdb..#PagosMapeados') IS NOT NULL DROP TABLE #PagosMapeados;

        SELECT
            p.idPago,
            uf.idUnidadFuncional
        INTO #PagosMapeados
        FROM consorcio.pago p
        JOIN consorcio.unidad_funcional uf ON p.cuentaOrigen = uf.cuentaOrigen
        WHERE p.estaAsociado = 1 
          AND p.idDetalleExpensa IS NULL
          AND p.fecha BETWEEN @fechaInicioPeriodo AND @fechaFinPeriodo;
        
        -- Si no hay pagos para ese mes y consorcio, salimos
        IF NOT EXISTS (SELECT 1 FROM #PagosMapeados)
        BEGIN
            PRINT 'No hay pagos disponibles o asociados para conciliar en el período ' + @periodo_norm + '.';
            COMMIT TRANSACTION;
            RETURN 0;
        END
        
        UPDATE p
        SET p.idDetalleExpensa = de.idDetalleExpensa
        FROM consorcio.pago p
        JOIN #PagosMapeados pm ON p.idPago = pm.idPago
        JOIN consorcio.detalle_expensa de ON pm.idUnidadFuncional = de.idUnidadFuncional
        WHERE de.idExpensa = @idExpensaAConciliar;

        DECLARE @PagosConsumidos INT = @@ROWCOUNT;
        
        COMMIT TRANSACTION;
        
        IF OBJECT_ID('tempdb..#PagosMapeados') IS NOT NULL DROP TABLE #PagosMapeados;
        
        PRINT 'Asociación de Pagos completada. Total de pagos consumidos: ' + CAST(@PagosConsumidos AS VARCHAR(10));
        RETURN 0;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#PagosMapeados') IS NOT NULL DROP TABLE #PagosMapeados;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE(), @ErrNo INT = ERROR_NUMBER();
        RAISERROR('Error al asociar Pagos (Err %d): %s.', 16, 1, @ErrNo, @ErrMsg);
        RETURN -100;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE consorcio.sp_orquestarFlujoFacturacionMensual
    @idConsorcio INT,
    @periodoExpensa VARCHAR(12),
    @anioExpensa INT,
    @fechaEmision DATE,
    @fechaPrimerVenc DATE,
    @fechaSegundoVenc DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @Msg NVARCHAR(500);
    DECLARE @periodo_norm VARCHAR(12);
    DECLARE @idExpensaExistente INT;
    
    BEGIN TRY
        PRINT N'================================================================================';
        SET @Msg = N'INICIANDO FLUJO DE FACTURACIÓN COMPLETO para: ' + @periodoExpensa + ' ' + CAST(@anioExpensa AS VARCHAR) + ' (Consorcio ' + CAST(@idConsorcio AS VARCHAR) + ')';
        PRINT @Msg;
        PRINT N'================================================================================';

        -- VALIDAR EXPENSA EXISTENTE
        SET @periodo_norm = LOWER(LTRIM(RTRIM(@periodoExpensa)));

        SELECT @idExpensaExistente = idExpensa
        FROM consorcio.expensa
        WHERE idConsorcio = @idConsorcio
          AND periodo = @periodo_norm
          AND anio = @anioExpensa;

        IF @idExpensaExistente IS NULL
        BEGIN
            RAISERROR(N'ERROR: La expensa para Consorcio %d, %s %d NO está pre-cargada en la tabla consorcio.expensa.', 16, 1, @idConsorcio, @periodoExpensa, @anioExpensa);
            RETURN -10;
        END
        
        PRINT N'Expensa base pre-cargada encontrada: ID=' + CAST(@idExpensaExistente AS VARCHAR) + '.';

        --GENERAR DETALLES DE EXPENSA
        SET @Msg = N'1. Ejecutando sp_generarFacturasMensuales...';
        PRINT @Msg;

        -- El SP generador usa los mismos parámetros de Consorcio, Período y Año para encontrar el idExpensa
        EXEC consorcio.sp_generarFacturasMensuales 
            @idConsorcio = @idConsorcio, 
            @periodo = @periodoExpensa, 
            @anio = @anioExpensa, 
            @fechaEmision = @fechaEmision,
            @fechaPrimerVenc = @fechaPrimerVenc, 
            @fechaSegundoVenc = @fechaSegundoVenc;

        --PREPARAR/MARCAR PAGOS (Asociar Pagos entrantes a Unidades Funcionales)
        SET @Msg = N'2. Ejecutando sp_asociarPagosAUF (Preparación de Pagos)...';
        PRINT @Msg;

        -- Este SP no requiere parametros de fecha/periodo, ya que solo marca los pagos nuevos
        EXEC consorcio.sp_asociarPagosAUF;

        --CONSUMIR PAGOS (Vincular Pagos a la Factura del mismo período)
        SET @Msg = N'3. Ejecutando sp_asociarPagosConsumidos (Consumo/Vinculación de Pagos)...';
        PRINT @Msg;

        -- Este SP requiere el periodo para filtrar los pagos por fecha de Abril y asociarlos a la factura de Abril.
        EXEC consorcio.sp_asociarPagosConsumidos
            @idConsorcio = @idConsorcio,
            @periodo = @periodoExpensa,
            @anio = @anioExpensa;


        PRINT N'================================================================================';
        SET @Msg = N'FLUJO DE FACTURACIÓN COMPLETO EXITOSO para ' + @periodoExpensa + ' ' + CAST(@anioExpensa AS VARCHAR);
        PRINT @Msg;
        PRINT N'================================================================================';
        
        RETURN 0;

    END TRY
    BEGIN CATCH
        SET @Msg = N'ERROR EN LA ORQUESTACIÓN: ' + ERROR_MESSAGE();
        RAISERROR(@Msg, 16, 1);
        RETURN -100;
    END CATCH
END;
GO

--------------------------------------------------------------------------------
-- NUMERO: 11
-- ARCHIVO: -
-- PROCEDIMIENTO: Verificacion de dias feriados para emision de expensas
--------------------------------------------------------------------------------
-- Configuracion 
-- Permite interactuar con las APIs

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO

CREATE OR ALTER PROCEDURE consorcio.sp_generarExpensaConFeriados
(
    @periodoExpensa VARCHAR(20),
    @anioExpensa INT,
    @fechaEmision DATE,
    @fechaPrimerVenc DATE,
    @fechaSegundoVenc DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------
    -- 1) Llamar API de feriados (Método de Captura en Tabla)
    ----------------------------------------------------
    DECLARE @Object INT = NULL;
    DECLARE @httpStatus INT = NULL;
    
    DECLARE @jsonCapture TABLE (JsonData NVARCHAR(MAX));
    DECLARE @finalJson NVARCHAR(MAX);
    
    DECLARE @Url NVARCHAR(300) =
        'https://api.argentinadatos.com/v1/feriados/' + CAST(@anioExpensa AS NVARCHAR);

    BEGIN TRY
        EXEC sp_OACreate 'MSXML2.XMLHTTP', @Object OUT;
        EXEC sp_OAMethod @Object, 'OPEN', NULL, 'GET', @Url, 'FALSE';
        EXEC sp_OAMethod @Object, 'SEND';
        
        EXEC sp_OAGetProperty @Object, 'Status', @httpStatus OUTPUT;

        IF @httpStatus = 200
        BEGIN
            INSERT INTO @jsonCapture (JsonData) 
                EXEC sp_OAGetProperty @Object, 'RESPONSETEXT';
        END
        
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'Error llamando API de feriados: ' + @Err;
        IF @Object IS NOT NULL EXEC sp_OADestroy @Object;
        RETURN;
    END CATCH;

    -- Extraer el JSON de la tabla a la variable final para su procesamiento
    SELECT @finalJson = JsonData FROM @jsonCapture;

    ----------------------------------------------------
    -- 2) Pasar JSON a tabla @feriados
    ----------------------------------------------------
    DECLARE @feriados TABLE (Fecha DATE);

    INSERT INTO @feriados (Fecha)
    SELECT fecha
    FROM OPENJSON(@finalJson)
    WITH (
        fecha DATE '$.fecha'
    );


    ----------------------------------------------------
    -- 3) Ajuste de fechas hábiles
    ----------------------------------------------------
    DECLARE @fe DATE = @fechaEmision;
    DECLARE @fv1 DATE = @fechaPrimerVenc;
    DECLARE @fv2 DATE = @fechaSegundoVenc;

    WHILE DATENAME(WEEKDAY, @fe) = 'Sunday'
       OR EXISTS (SELECT 1 FROM @feriados WHERE Fecha = @fe)
    BEGIN
        SET @fe = DATEADD(DAY, 1, @fe);
    END

    WHILE DATENAME(WEEKDAY, @fv1) = 'Sunday'
       OR EXISTS (SELECT 1 FROM @feriados WHERE Fecha = @fv1)
    BEGIN
        SET @fv1 = DATEADD(DAY, 1, @fv1);
    END

    WHILE DATENAME(WEEKDAY, @fv2) = 'Sunday'
       OR EXISTS (SELECT 1 FROM @feriados WHERE Fecha = @fv2)
    BEGIN
        SET @fv2 = DATEADD(DAY, 1, @fv2);
    END


    ----------------------------------------------------
    -- 4) Llamar SP maestro con fechas ajustadas
    ----------------------------------------------------
    EXEC consorcio.sp_orquestarFlujoParaTodosLosConsorcios
        @periodoExpensa,
        @anioExpensa,
        @fe,
        @fv1,
        @fv2;

END
GO


CREATE OR ALTER PROCEDURE consorcio.sp_orquestarFlujoParaTodosLosConsorcios
    @periodoExpensa VARCHAR(12),
    @anioExpensa INT,
    @fechaEmision DATE,
    @fechaPrimerVenc DATE,
    @fechaSegundoVenc DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    PRINT N'================================================================================';
    PRINT N'INICIANDO ORQUESTADOR GENERAL PARA: ' + @periodoExpensa + ' ' + CAST(@anioExpensa AS VARCHAR);
    PRINT N'================================================================================';

    IF OBJECT_ID('tempdb..#ConsorciosAProcesar') IS NOT NULL DROP TABLE #ConsorciosAProcesar;
    
    SELECT 
        idConsorcio,
        nombre,
        ROW_NUMBER() OVER (ORDER BY idConsorcio) AS rn
    INTO #ConsorciosAProcesar
    FROM consorcio.consorcio
    WHERE fechaBaja IS NULL;

    DECLARE @i INT = 1;
    DECLARE @max INT = (SELECT COUNT(*) FROM #ConsorciosAProcesar);
    DECLARE @idConsorcioActual INT;
    DECLARE @nombreConsorcio VARCHAR(50);
    DECLARE @Msg NVARCHAR(500);

    -- 3. Bucle por cada consorcio
    WHILE @i <= @max
    BEGIN
        SELECT 
            @idConsorcioActual = idConsorcio,
            @nombreConsorcio = nombre
        FROM #ConsorciosAProcesar
        WHERE rn = @i;

        SET @Msg = N'--- Procesando Consorcio ' + CAST(@idConsorcioActual AS VARCHAR) + ' (' + @nombreConsorcio + ') ---';
        PRINT @Msg;

        BEGIN TRY
            EXEC consorcio.sp_orquestarFlujoFacturacionMensual 
                @idConsorcio = @idConsorcioActual,
                @periodoExpensa = @periodoExpensa, 
                @anioExpensa = @anioExpensa, 
                @fechaEmision = @fechaEmision,
                @fechaPrimerVenc = @fechaPrimerVenc, 
                @fechaSegundoVenc = @fechaSegundoVenc;
        END TRY
        BEGIN CATCH
            -- Si un consorcio falla, lo informa y continua
            SET @Msg = N'ERROR: Falló el procesamiento del Consorcio ' + CAST(@idConsorcioActual AS VARCHAR) + '. Error: ' + ERROR_MESSAGE();
            PRINT @Msg;
        END CATCH

        SET @i = @i + 1;
    END

    DROP TABLE #ConsorciosAProcesar;
    PRINT N'================================================================================';
    PRINT N'ORQUESTADOR GENERAL FINALIZADO.';
    PRINT N'================================================================================';
END;
GO

--------------------------------------------------------------------------------
-- NÚMERO: 11
-- ARCHIVO: -
-- PROCEDIMIENTO: Inserción de datos a la tabla estado_financiero
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_cargar_estado_financiero
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -------------------------------------------------------------------------
        -- 1. Reiniciar tabla destino
        -------------------------------------------------------------------------
        TRUNCATE TABLE consorcio.estado_financiero;

        -------------------------------------------------------------------------
        -- 2. Generar datos en staging temporal
        -------------------------------------------------------------------------
        IF OBJECT_ID('tempdb..#stg_estado_financiero', 'U') IS NOT NULL
            DROP TABLE #stg_estado_financiero;

        WITH CteEgresos AS (
            SELECT
                e.idConsorcio,
                TRIM(e.periodo) AS periodo,
                e.anio,
                SUM(ISNULL(g.subTotalOrdinarios, 0) + ISNULL(g.subTotalExtraOrd, 0)) AS totalEgresos
            FROM consorcio.expensa AS e  LEFT JOIN consorcio.gasto AS g ON e.idExpensa = g.idExpensa
            GROUP BY e.idConsorcio, TRIM(e.periodo), e.anio
        ),
        CteIngresos AS (
            SELECT
                c.idConsorcio,
                CASE MONTH(p.fecha)
                    WHEN 1 THEN 'enero' 
                    WHEN 2 THEN 'febrero' 
                    WHEN 3 THEN 'marzo'
                    WHEN 4 THEN 'abril' 
                    WHEN 5 THEN 'mayo' 
                    WHEN 6 THEN 'junio'
                    WHEN 7 THEN 'julio' 
                    WHEN 8 THEN 'agosto' 
                    WHEN 9 THEN 'septiembre'
                    WHEN 10 THEN 'octubre' 
                    WHEN 11 THEN 'noviembre' 
                    WHEN 12 THEN 'diciembre'
                END AS periodo,
                YEAR(p.fecha) AS anio,
                SUM(ISNULL(p.importe, 0)) AS totalIngresos
            FROM consorcio.pago AS p JOIN consorcio.unidad_funcional AS uf ON p.cuentaOrigen = uf.cuentaOrigen
                 JOIN consorcio.consorcio AS c ON uf.idConsorcio = c.idConsorcio
            WHERE p.fecha IS NOT NULL
            GROUP BY c.idConsorcio, MONTH(p.fecha), YEAR(p.fecha)
        ),
        CteCombinado AS (
            SELECT
                eg.idConsorcio,
                eg.periodo,
                eg.anio,
                ISNULL(i.totalIngresos, 0) AS ingresosEnTermino,
                CAST(0 AS DECIMAL(12,2)) AS ingresosAdeudados,
                ISNULL(eg.totalEgresos, 0) AS egresos,
                CASE eg.periodo
                    WHEN 'enero' THEN 1
                    WHEN 'febrero' THEN 2
                    WHEN 'marzo' THEN 3
                    WHEN 'abril' THEN 4
                    WHEN 'mayo' THEN 5
                    WHEN 'junio' THEN 6
                    WHEN 'julio' THEN 7
                    WHEN 'agosto' THEN 8
                    WHEN 'septiembre' THEN 9
                    WHEN 'octubre' THEN 10
                    WHEN 'noviembre' THEN 11
                    WHEN 'diciembre' THEN 12
                END AS mesNumero
            FROM CteEgresos AS eg
            LEFT JOIN CteIngresos AS i
                ON eg.idConsorcio = i.idConsorcio
                AND eg.periodo = i.periodo
                AND eg.anio = i.anio
        ),
        CteSaldos AS (
            SELECT
                idConsorcio,
                periodo,
                anio,
                mesNumero,
                ingresosEnTermino,
                ingresosAdeudados,
                egresos,
                SUM(ingresosEnTermino + ingresosAdeudados - egresos) OVER (PARTITION BY idConsorcio ORDER BY anio, mesNumero) AS saldoCierre
            FROM CteCombinado
        )
        SELECT
            idConsorcio             AS stg_idConsorcio,
            ISNULL(LAG(saldoCierre, 1, 0) OVER (PARTITION BY idConsorcio ORDER BY anio, mesNumero), 0) AS stg_saldoAnterior,
            ingresosEnTermino       AS stg_ingresosEnTermino,
            ingresosAdeudados       AS stg_ingresosAdeudados,
            egresos                 AS stg_egresos,
            saldoCierre             AS stg_saldoCierre,
            periodo                 AS stg_periodo,
            anio                    AS stg_anio,
            mesNumero               AS stg_mesNumero
        INTO #stg_estado_financiero
        FROM CteSaldos
        ORDER BY idConsorcio, anio, mesNumero;

        -------------------------------------------------------------------------
        -- 3. Crear tabla numerada para iterar
        -------------------------------------------------------------------------
        IF OBJECT_ID('tempdb..#stg_estado_financiero_num', 'U') IS NOT NULL
            DROP TABLE #stg_estado_financiero_num;

        SELECT 
            ROW_NUMBER() OVER (ORDER BY stg_idConsorcio, stg_anio, stg_mesNumero) AS rn,
            stg_idConsorcio,
            stg_periodo,
            stg_anio,
            stg_saldoAnterior,
            stg_ingresosEnTermino,
            stg_ingresosAdeudados,
            stg_egresos,
            stg_saldoCierre
        INTO #stg_estado_financiero_num
        FROM #stg_estado_financiero;

        -------------------------------------------------------------------------
        -- 4. Iterar e insertar mediante consorcio.sp_insertarEstadoFinanciero
        -------------------------------------------------------------------------
        DECLARE @i INT = 1, @max INT;
        SELECT @max = MAX(rn) FROM #stg_estado_financiero_num;

        DECLARE
            @stg_idConsorcio INT,
            @stg_periodo VARCHAR(12),
            @stg_anio INT,
            @stg_saldoAnterior DECIMAL(12,2),
            @stg_ingresosEnTermino DECIMAL(12,2),
            @stg_ingresosAdeudados DECIMAL(12,2),
            @stg_egresos DECIMAL(12,2),
            @stg_saldoCierre DECIMAL(12,2),
            @idEstadoFinancieroCreado INT;

        WHILE @i <= @max
        BEGIN
            SELECT 
                @stg_idConsorcio = stg_idConsorcio,
                @stg_periodo = stg_periodo,
                @stg_anio = stg_anio,
                @stg_saldoAnterior = stg_saldoAnterior,
                @stg_ingresosEnTermino = stg_ingresosEnTermino,
                @stg_ingresosAdeudados = stg_ingresosAdeudados,
                @stg_egresos = stg_egresos,
                @stg_saldoCierre = stg_saldoCierre
            FROM #stg_estado_financiero_num
            WHERE rn = @i;

            BEGIN TRY
                EXEC consorcio.sp_insertarEstadoFinanciero
                    @idConsorcio = @stg_idConsorcio,
                    @periodo = @stg_periodo,
                    @anio = @stg_anio,
                    @saldoAnterior = @stg_saldoAnterior,
                    @ingresosEnTermino = @stg_ingresosEnTermino,
                    @ingresosAdeudados = @stg_ingresosAdeudados,
                    @egresos = @stg_egresos,
                    @saldoCierre = @stg_saldoCierre,
                    @idEstadoFinancieroCreado = @idEstadoFinancieroCreado OUTPUT;
            END TRY
            BEGIN CATCH
                PRINT 'Error al insertar estado financiero del consorcio ' 
                    + CAST(@stg_idConsorcio AS VARCHAR)
                    + ' (' + @stg_periodo + ' ' + CAST(@stg_anio AS VARCHAR) + ')';
            END CATCH;

            SET @i += 1;
        END;

        DROP TABLE #stg_estado_financiero_num;
        DROP TABLE #stg_estado_financiero;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error en SP_cargar_estado_financiero: %s', 16, 1, @ErrorMessage);
    END CATCH;
END;
GO

--------------------------------------------------------------------------------
-- NUMERO: 12
-- ARCHIVO: -
-- PROCEDIMIENTO: Modificacion de tablas para cifrado de datos sensibles
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_migrarEsquemaACifradoReversible
    @FraseClave NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @ConstraintName NVARCHAR(128);
    DECLARE @IndexName NVARCHAR(128);
    
    BEGIN TRANSACTION
    
    BEGIN TRY

        -- Eliminación de Constraints
        ALTER TABLE consorcio.persona DROP CONSTRAINT IF EXISTS chk_persona_cuentaOrigen;
        ALTER TABLE consorcio.unidad_funcional DROP CONSTRAINT IF EXISTS chk_unidadFuncional_cuentaOrigen;
        ALTER TABLE consorcio.pago DROP CONSTRAINT IF EXISTS chk_pago_cuentaOrigen;

        -- Eliminación de índices existentes
        SET @IndexName = N'IDX_unidad_funcional_filtro_consorcio_cuenta';
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = @IndexName AND object_id = OBJECT_ID(N'consorcio.unidad_funcional'))
        BEGIN
            SET @SQL = N'DROP INDEX ' + QUOTENAME(@IndexName) + ' ON consorcio.unidad_funcional;';
            EXEC sp_executesql @SQL;
            PRINT 'INFO: Índice ' + @IndexName + ' eliminado de consorcio.unidad_funcional.';
        END

        SET @IndexName = N'IDX_pago_fecha_importe';
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = @IndexName AND object_id = OBJECT_ID(N'consorcio.pago'))
        BEGIN
            SET @SQL = N'DROP INDEX ' + QUOTENAME(@IndexName) + ' ON consorcio.pago;';
            EXEC sp_executesql @SQL;
            PRINT 'INFO: Índice ' + @IndexName + ' eliminado de consorcio.pago.';
        END
        
        -- Eliminación del índice 'idx_persona_salida'
        SET @IndexName = N'idx_persona_salida';
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = @IndexName AND object_id = OBJECT_ID(N'consorcio.persona'))
        BEGIN
            SET @SQL = N'DROP INDEX ' + QUOTENAME(@IndexName) + ' ON consorcio.persona;';
            EXEC sp_executesql @SQL;
            PRINT 'INFO: Índice ' + @IndexName + ' eliminado de consorcio.persona.';
        END
        
        -- Creación de columnas temporales para el cifrado
        IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'dni_temp' AND Object_ID = OBJECT_ID(N'consorcio.persona'))
            ALTER TABLE consorcio.persona ADD dni_temp VARBINARY(256) NULL;
        IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'email_temp' AND Object_ID = OBJECT_ID(N'consorcio.persona'))
            ALTER TABLE consorcio.persona ADD email_temp VARBINARY(256) NULL;
        IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'telefono_temp' AND Object_ID = OBJECT_ID(N'consorcio.persona'))
            ALTER TABLE consorcio.persona ADD telefono_temp VARBINARY(256) NULL;
        IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'cuentaOrigen_temp' AND Object_ID = OBJECT_ID(N'consorcio.persona'))
            ALTER TABLE consorcio.persona ADD cuentaOrigen_temp VARBINARY(256) NULL;

        SET @SQL = N'
        UPDATE T
        SET 
            dni_temp = ENCRYPTBYPASSPHRASE(@FraseClaveParam, CAST(dni AS VARCHAR(50)), 1, CONVERT(VARBINARY(4), idPersona)),
            email_temp = ENCRYPTBYPASSPHRASE(@FraseClaveParam, CAST(email AS VARCHAR(100)), 1, CONVERT(VARBINARY(4), idPersona)),
            telefono_temp = ENCRYPTBYPASSPHRASE(@FraseClaveParam, CAST(telefono AS VARCHAR(20)), 1, CONVERT(VARBINARY(4), idPersona)),
            cuentaOrigen_temp = ENCRYPTBYPASSPHRASE(@FraseClaveParam, CAST(cuentaOrigen AS CHAR(22)), 1, CONVERT(VARBINARY(4), idPersona))
        FROM consorcio.persona T
        WHERE 
            dni IS NOT NULL OR 
            email IS NOT NULL OR 
            telefono IS NOT NULL OR 
            cuentaOrigen IS NOT NULL;
        ';
        EXEC sp_executesql @SQL, N'@FraseClaveParam NVARCHAR(128)', @FraseClaveParam = @FraseClave;

        -- Eliminación de restricciones de unicidad/PK en 'dni'
        SELECT @ConstraintName = NULL; 
        
        SELECT TOP 1 @ConstraintName = kc.name 
        FROM sys.key_constraints kc
        INNER JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
        INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE kc.parent_object_id = OBJECT_ID('consorcio.persona') 
          AND kc.type IN ('UQ', 'PK') 
          AND c.name = 'dni';
        
        IF @ConstraintName IS NOT NULL
        BEGIN
            SET @SQL = N'ALTER TABLE consorcio.persona DROP CONSTRAINT ' + QUOTENAME(@ConstraintName);
            EXEC sp_executesql @SQL;
            PRINT 'INFO: Restricción dependiente (' + @ConstraintName + ') en consorcio.persona.dni eliminada.';
        END
        
        -- Eliminar columnas originales
        ALTER TABLE consorcio.persona DROP COLUMN dni;
        ALTER TABLE consorcio.persona DROP COLUMN email;
        ALTER TABLE consorcio.persona DROP COLUMN telefono;
        ALTER TABLE consorcio.persona DROP COLUMN cuentaOrigen;

        -- Renombrar columnas temporales a sus nombres originales
        EXEC sp_rename 'consorcio.persona.dni_temp', 'dni', 'COLUMN';
        EXEC sp_rename 'consorcio.persona.email_temp', 'email', 'COLUMN';
        EXEC sp_rename 'consorcio.persona.telefono_temp', 'telefono', 'COLUMN';
        EXEC sp_rename 'consorcio.persona.cuentaOrigen_temp', 'cuentaOrigen', 'COLUMN';

        ALTER TABLE consorcio.persona ALTER COLUMN dni VARBINARY(256) NOT NULL;
        ALTER TABLE consorcio.persona ALTER COLUMN cuentaOrigen VARBINARY(256) NOT NULL;

        -------------------------------------------------------------
        -- MIGRACIÓN DE cuentaOrigen en otras tablas (unidad_funcional y pago)
        -------------------------------------------------------------
        
        DECLARE @TableName NVARCHAR(128);
        DECLARE @IdColumnName NVARCHAR(128);

        SET @TableName = N'consorcio.unidad_funcional';
        SET @IdColumnName = N'idUnidadFuncional';

        IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'cuentaOrigen_temp' AND Object_ID = OBJECT_ID(@TableName))
            SET @SQL = N'ALTER TABLE ' + @TableName + ' ADD cuentaOrigen_temp VARBINARY(256) NULL;';
        ELSE
            SET @SQL = N'UPDATE ' + @TableName + ' SET cuentaOrigen_temp = NULL;';
        EXEC sp_executesql @SQL;

        SET @SQL = N'
        UPDATE T
        SET cuentaOrigen_temp = ENCRYPTBYPASSPHRASE(@FraseClaveParam, CAST(cuentaOrigen AS CHAR(22)), 1, CONVERT(VARBINARY(4), ' + @IdColumnName + '))
        FROM ' + @TableName + ' T
        WHERE cuentaOrigen IS NOT NULL;
        ';
        EXEC sp_executesql @SQL, N'@FraseClaveParam NVARCHAR(128)', @FraseClaveParam = @FraseClave;
        
        SET @SQL = N'ALTER TABLE ' + @TableName + ' DROP COLUMN cuentaOrigen;';
        EXEC sp_executesql @SQL;
        
        SET @SQL = N'EXEC sp_rename ''' + @TableName + '.cuentaOrigen_temp'', ''cuentaOrigen'', ''COLUMN'';';
        EXEC sp_executesql @SQL;
        
        SET @SQL = N'ALTER TABLE ' + @TableName + ' ALTER COLUMN cuentaOrigen VARBINARY(256) NOT NULL;';
        EXEC sp_executesql @SQL;
        PRINT 'INFO: Migrada columna cuentaOrigen en ' + @TableName + '.';

        SET @TableName = N'consorcio.pago';
        SET @IdColumnName = N'idPago'; 

        -- Eliminación del índice 'idx_pago_cuenta_fecha'
        SET @IndexName = N'idx_pago_cuenta_fecha';
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = @IndexName AND object_id = OBJECT_ID(@TableName))
        BEGIN
            SET @SQL = N'DROP INDEX ' + QUOTENAME(@IndexName) + ' ON ' + @TableName + ';';
            EXEC sp_executesql @SQL;
            PRINT 'INFO: Índice ' + @IndexName + ' eliminado de ' + @TableName + '.';
        END

        IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'cuentaOrigen_temp' AND Object_ID = OBJECT_ID(@TableName))
            SET @SQL = N'ALTER TABLE ' + @TableName + ' ADD cuentaOrigen_temp VARBINARY(256) NULL;';
        ELSE
            SET @SQL = N'UPDATE ' + @TableName + ' SET cuentaOrigen_temp = NULL;';
        EXEC sp_executesql @SQL;
        
        SET @SQL = N'
        UPDATE T
        SET cuentaOrigen_temp = ENCRYPTBYPASSPHRASE(@FraseClaveParam, CAST(cuentaOrigen AS CHAR(22)), 1, CONVERT(VARBINARY(4), ' + @IdColumnName + '))
        FROM ' + @TableName + ' T
        WHERE cuentaOrigen IS NOT NULL;
        ';
        EXEC sp_executesql @SQL, N'@FraseClaveParam NVARCHAR(128)', @FraseClaveParam = @FraseClave;

        SET @SQL = N'ALTER TABLE ' + @TableName + ' DROP COLUMN cuentaOrigen;';
        EXEC sp_executesql @SQL;

        SET @SQL = N'EXEC sp_rename ''' + @TableName + '.cuentaOrigen_temp'', ''cuentaOrigen'', ''COLUMN'';';
        EXEC sp_executesql @SQL;

        SET @SQL = N'ALTER TABLE ' + @TableName + ' ALTER COLUMN cuentaOrigen VARBINARY(256) NOT NULL;';
        EXEC sp_executesql @SQL;
        PRINT 'INFO: Migrada columna cuentaOrigen en ' + @TableName + '.';

        COMMIT TRANSACTION;
        PRINT 'Migración de esquema a cifrado reversible COMPLETADA con éxito.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        THROW; 

    END CATCH
END
GO

--------------------------------------------------------------------------------
-- NUMERO: 13
-- ARCHIVO: -
-- PROCEDIMIENTO: Modificacion de tablas para descifrado de datos sensibles
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_revertirEsquemaADatosClaros
    @FraseClave NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    
    BEGIN TRANSACTION
    
    BEGIN TRY

        -------------------------------------------------------------
        -- REVERSIÓN TABLA consorcio.persona
        -------------------------------------------------------------
        
        -- Eliminación de la columna HASH de unicidad (si fue creada en la migración)
        IF EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'dni_hash_unicidad' AND Object_ID = OBJECT_ID(N'consorcio.persona'))
            ALTER TABLE consorcio.persona DROP COLUMN dni_hash_unicidad;
            
        -- Creación de columnas temporales para el descifrado
        SET @SQL = N'
            ALTER TABLE consorcio.persona DROP COLUMN IF EXISTS dni_temp_revert;
            ALTER TABLE consorcio.persona DROP COLUMN IF EXISTS email_temp_revert;
            ALTER TABLE consorcio.persona DROP COLUMN IF EXISTS telefono_temp_revert;
            ALTER TABLE consorcio.persona DROP COLUMN IF EXISTS cuentaOrigen_temp_revert;
            
            -- Se usan los tipos de dato originales
            ALTER TABLE consorcio.persona ADD dni_temp_revert VARCHAR(50) NULL; 
            ALTER TABLE consorcio.persona ADD email_temp_revert VARCHAR(100) NULL;
            ALTER TABLE consorcio.persona ADD telefono_temp_revert VARCHAR(20) NULL;
            ALTER TABLE consorcio.persona ADD cuentaOrigen_temp_revert CHAR(22) NULL;
        ';
        EXEC sp_executesql @SQL;

        -- Descifrado de datos a las columnas temporales
        SET @SQL = N'
        UPDATE T
        SET 
            dni_temp_revert = CAST(DECRYPTBYPASSPHRASE(@FraseClaveParam, dni, 1, CONVERT(VARBINARY(4), idPersona)) AS VARCHAR(50)),
            email_temp_revert = CAST(DECRYPTBYPASSPHRASE(@FraseClaveParam, email, 1, CONVERT(VARBINARY(4), idPersona)) AS VARCHAR(100)),
            telefono_temp_revert = CAST(DECRYPTBYPASSPHRASE(@FraseClaveParam, telefono, 1, CONVERT(VARBINARY(4), idPersona)) AS VARCHAR(20)),
            cuentaOrigen_temp_revert = CAST(DECRYPTBYPASSPHRASE(@FraseClaveParam, cuentaOrigen, 1, CONVERT(VARBINARY(4), idPersona)) AS CHAR(22))
        FROM consorcio.persona T;
        ';
        EXEC sp_executesql @SQL, N'@FraseClaveParam NVARCHAR(128)', @FraseClaveParam = @FraseClave;
        
        -- Eliminación de las columnas cifradas (VARBINARY)
        ALTER TABLE consorcio.persona DROP COLUMN dni;
        ALTER TABLE consorcio.persona DROP COLUMN email;
        ALTER TABLE consorcio.persona DROP COLUMN telefono;
        ALTER TABLE consorcio.persona DROP COLUMN cuentaOrigen;

        -- Renombrar columnas temporales a sus nombres originales
        EXEC sp_rename 'consorcio.persona.dni_temp_revert', 'dni', 'COLUMN';
        EXEC sp_rename 'consorcio.persona.email_temp_revert', 'email', 'COLUMN';
        EXEC sp_rename 'consorcio.persona.telefono_temp_revert', 'telefono', 'COLUMN';
        EXEC sp_rename 'consorcio.persona.cuentaOrigen_temp_revert', 'cuentaOrigen', 'COLUMN';

        -- Restaurar tipos de datos, nulabilidad y restricciones
        ALTER TABLE consorcio.persona ALTER COLUMN dni VARCHAR(50) NOT NULL; 
        ALTER TABLE consorcio.persona ALTER COLUMN email VARCHAR(100) NULL;
        ALTER TABLE consorcio.persona ALTER COLUMN telefono VARCHAR(20) NULL;
        ALTER TABLE consorcio.persona ALTER COLUMN cuentaOrigen CHAR(22) NOT NULL; 
        
        -- Restaurar restricciones
        ALTER TABLE consorcio.persona ADD CONSTRAINT uq_persona_dni UNIQUE (dni);
        ALTER TABLE consorcio.persona ADD CONSTRAINT chk_persona_cuentaOrigen CHECK (ISNUMERIC(cuentaOrigen) = 1);
        
        -------------------------------------------------------------
        -- REVERSIÓN TABLA consorcio.unidad_funcional 
        -------------------------------------------------------------
        
        -- Creación garantizada con SQL Dinámico
        SET @SQL = N'
            ALTER TABLE consorcio.unidad_funcional DROP COLUMN IF EXISTS cuentaOrigen_temp_revert;
            ALTER TABLE consorcio.unidad_funcional ADD cuentaOrigen_temp_revert CHAR(22) NULL;
        ';
        EXEC sp_executesql @SQL;
            
        SET @SQL = N'
        UPDATE T
        SET cuentaOrigen_temp_revert = CAST(DECRYPTBYPASSPHRASE(@FraseClaveParam, cuentaOrigen, 1, CONVERT(VARBINARY(4), idUnidadFuncional)) AS CHAR(22))
        FROM consorcio.unidad_funcional T;
        ';
        EXEC sp_executesql @SQL, N'@FraseClaveParam NVARCHAR(128)', @FraseClaveParam = @FraseClave;

        ALTER TABLE consorcio.unidad_funcional DROP COLUMN cuentaOrigen;
        EXEC sp_rename 'consorcio.unidad_funcional.cuentaOrigen_temp_revert', 'cuentaOrigen', 'COLUMN';
        ALTER TABLE consorcio.unidad_funcional ALTER COLUMN cuentaOrigen CHAR(22) NOT NULL;
        ALTER TABLE consorcio.unidad_funcional ADD CONSTRAINT chk_unidadFuncional_cuentaOrigen CHECK (ISNUMERIC(cuentaOrigen) = 1);

        -------------------------------------------------------------
        -- REVERSIÓN TABLA consorcio.pago
        -------------------------------------------------------------
        
        -- Creación garantizada con SQL Dinámico
        SET @SQL = N'
            ALTER TABLE consorcio.pago DROP COLUMN IF EXISTS cuentaOrigen_temp_revert;
            ALTER TABLE consorcio.pago ADD cuentaOrigen_temp_revert CHAR(22) NULL;
        ';
        EXEC sp_executesql @SQL;
            
        SET @SQL = N'
        UPDATE T
        SET cuentaOrigen_temp_revert = CAST(DECRYPTBYPASSPHRASE(@FraseClaveParam, cuentaOrigen, 1, CONVERT(VARBINARY(4), idPago)) AS CHAR(22))
        FROM consorcio.pago T;
        ';
        EXEC sp_executesql @SQL, N'@FraseClaveParam NVARCHAR(128)', @FraseClaveParam = @FraseClave;

        ALTER TABLE consorcio.pago DROP COLUMN cuentaOrigen;
        EXEC sp_rename 'consorcio.pago.cuentaOrigen_temp_revert', 'cuentaOrigen', 'COLUMN';
        ALTER TABLE consorcio.pago ALTER COLUMN cuentaOrigen CHAR(22) NOT NULL;
        ALTER TABLE consorcio.pago ADD CONSTRAINT chk_pago_cuentaOrigen CHECK (ISNUMERIC(cuentaOrigen) = 1);

        -------------------------------------------------------------
        -- REGENERACIÓN DE ÍNDICES 
        -------------------------------------------------------------

        PRINT 'INFO: Regenerando índices';
        -- Restauración del índice en consorcio.persona
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_persona_salida' AND object_id = OBJECT_ID(N'consorcio.persona'))
        BEGIN
            CREATE NONCLUSTERED INDEX idx_persona_salida
            ON consorcio.persona (idPersona)
            INCLUDE (nombre, apellido, dni, email, telefono);
            PRINT 'INFO: Índice idx_persona_salida recreado.';
        END

        -- Índice en consorcio.unidad_funcional
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IDX_unidad_funcional_filtro_consorcio_cuenta' AND object_id = OBJECT_ID(N'consorcio.unidad_funcional'))
        BEGIN
            CREATE NONCLUSTERED INDEX IDX_unidad_funcional_filtro_consorcio_cuenta
            ON consorcio.unidad_funcional (cuentaOrigen, idConsorcio, piso, departamento)
            INCLUDE (idUnidadFuncional);
            PRINT 'INFO: Índice idx_unidad_funcional_filtro_consorcio_cuenta recreado.';
        END

        -- Índice en consorcio.pago (IDX_pago_fecha_importe)
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IDX_pago_fecha_importe' AND object_id = OBJECT_ID(N'consorcio.pago'))
        BEGIN
            CREATE NONCLUSTERED INDEX IDX_pago_fecha_importe
            ON consorcio.pago (fecha DESC, cuentaOrigen)
            INCLUDE (importe);
            PRINT 'INFO: Índice idx_pago_fecha_importe recreado.';
        END
        
        -- Restauración del índice en consorcio.pago
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_pago_cuenta_fecha' AND object_id = OBJECT_ID(N'consorcio.pago'))
        BEGIN
            CREATE NONCLUSTERED INDEX idx_pago_cuenta_fecha
            ON consorcio.pago (cuentaOrigen, fecha)
            INCLUDE (importe);
            PRINT 'INFO: Índice idx_pago_cuenta_fecha recreado.';
        END

        -- Índice en consorcio.expensa (idx_expensa_periodo_id)
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_expensa_periodo_id' AND object_id = OBJECT_ID(N'consorcio.expensa'))
        BEGIN
            CREATE NONCLUSTERED INDEX idx_expensa_periodo_id
            ON consorcio.expensa (anio, periodo)
            INCLUDE (idExpensa);
            PRINT 'INFO: Índice idx_expensa_periodo_id recreado.';
        END

        -- Índice en consorcio.expensa (idx_expensa_filtro_periodo)
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_expensa_filtro_periodo' AND object_id = OBJECT_ID(N'consorcio.expensa'))
        BEGIN
            CREATE NONCLUSTERED INDEX idx_expensa_filtro_periodo
            ON consorcio.expensa (idConsorcio, anio, periodo)
            INCLUDE (idExpensa);
            PRINT 'INFO: Índice idx_expensa_filtro_periodo recreado.';
        END
        
        -- Índice en consorcio.gasto
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IDX_gasto_expensa_monto' AND object_id = OBJECT_ID(N'consorcio.gasto'))
        BEGIN
            CREATE NONCLUSTERED INDEX IDX_gasto_expensa_monto
            ON consorcio.gasto (idExpensa)
            INCLUDE (subTotalOrdinarios, subTotalExtraOrd);
            PRINT 'INFO: Índice idx_gasto_expensa_monto recreado.';
        END
        
        COMMIT TRANSACTION;
        PRINT 'Reversión de esquema a datos en claro y regeneración de índices COMPLETADA con éxito.';

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW; 

    END CATCH
END
GO