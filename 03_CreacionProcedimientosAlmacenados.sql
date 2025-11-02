/*
===============================================================================
Materia:          Bases de Datos Aplicadas
Comisión:         01-2900
Grupo:            G08
Fecha de Entrega: 04/11/2025
Integrantes:
    - Bentancur Suarez, Ismael (45823439)
    - Rodriguez Arrien, Juan Manuel (44259478)
    - Rodriguez, Patricio (45683229)
    - Ruiz, Leonel Emiliano (45537914)
Enunciado:        "03 - Creación de Procedimientos Almacenados"
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

    -------------------------------------------------------------------------
    -- 1. Crear tabla staging
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#personas_CSV', 'U') IS NOT NULL
        DROP TABLE #personas_CSV;

    CREATE TABLE #personas_CSV (
        stg_nombre       NVARCHAR(100),
        stg_apellido     NVARCHAR(100),
        stg_dni          NVARCHAR(50),
        stg_email        NVARCHAR(100),
        stg_telefono     NVARCHAR(50),
        stg_cuentaOrigen NVARCHAR(22),
        stg_inquilino    NVARCHAR(2) -- 1=inquilino, 0=propietario
    );

    -------------------------------------------------------------------------
    -- 2. Cargar archivo CSV con BULK INSERT
    -------------------------------------------------------------------------
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
        BULK INSERT #personas_CSV
        FROM ''' + @path + '''
        WITH
        (
            FIELDTERMINATOR = '';'',
            ROWTERMINATOR = ''0x0A'',
            CODEPAGE = ''1252'',
            FIRSTROW = 2
        );
    ';
    EXEC sp_executesql @sql;

    -------------------------------------------------------------------------
    -- 3. Crear tabla numerada con limpieza y casteos
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#personas_Num', 'U') IS NOT NULL
        DROP TABLE #personas_Num;

    SELECT
        ROW_NUMBER() OVER (ORDER BY stg_dni) AS rn,
        -- Limpieza de strings y casteos
        RTRIM((
            SELECT UPPER(LEFT(s.value,1)) + LOWER(SUBSTRING(s.value,2,LEN(s.value))) + ' '
            FROM STRING_SPLIT(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(stg_nombre)), '','é'), '¥','ñ'), '¡','í'), ' ') s
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)')) AS nombre,
        RTRIM((
            SELECT UPPER(LEFT(s.value,1)) + LOWER(SUBSTRING(s.value,2,LEN(s.value))) + ' '
            FROM STRING_SPLIT(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(stg_apellido)), '','é'), '¥','ñ'), '¡','í'), ' ') s
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)')) AS apellido,
        CAST(LTRIM(RTRIM(stg_dni)) AS INT) AS dni,
        LOWER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(stg_email)), '','é'),'¥','ñ'),'¡','í')) AS email,
        LTRIM(RTRIM(stg_telefono)) AS telefono,
        LTRIM(RTRIM(stg_cuentaOrigen)) AS cuentaOrigen,
        CASE WHEN stg_inquilino = '1' THEN 'inquilino' ELSE 'propietario' END AS rol
    INTO #personas_Num
    FROM #personas_CSV
    WHERE ISNUMERIC(LTRIM(RTRIM(stg_dni))) = 1;

    -------------------------------------------------------------------------
    -- 4. Iterar y llamar a SPs de ABM
    -------------------------------------------------------------------------
    DECLARE @i INT = 1;
    DECLARE @max INT;
    DECLARE @idPersona INT;
    DECLARE @nombre NVARCHAR(100);
    DECLARE @apellido NVARCHAR(100);
    DECLARE @dni INT;
    DECLARE @email NVARCHAR(100);
    DECLARE @telefono NVARCHAR(50);
    DECLARE @cuentaOrigen NVARCHAR(22);
    DECLARE @rol NVARCHAR(15);
    DECLARE @idUF INT;

    SELECT @max = MAX(rn) FROM #personas_Num;

    WHILE @i <= @max
    BEGIN
        SELECT
            @nombre = nombre,
            @apellido = apellido,
            @dni = dni,
            @email = email,
            @telefono = telefono,
            @cuentaOrigen = cuentaOrigen,
            @rol = rol
        FROM #personas_Num
        WHERE rn = @i;

        -- Insertar persona
        BEGIN TRY
            EXEC consorcio.sp_insertarPersona
                @nombre = @nombre,
                @apellido = @apellido,
                @dni = @dni,
                @email = @email,
                @telefono = @telefono,
                @cuentaOrigen = @cuentaOrigen,
                @idPersonaCreada = @idPersona OUTPUT;
        END TRY
        BEGIN CATCH
            PRINT 'Error al insertar persona con DNI: ' + CAST(@dni AS VARCHAR);
        END CATCH

        -- Asignar persona a UF
        SELECT @idUF = idUnidadFuncional
        FROM consorcio.unidad_funcional
        WHERE cuentaOrigen = @cuentaOrigen AND fechaBaja IS NULL;

        IF @idUF IS NOT NULL
        BEGIN
            BEGIN TRY
                EXEC consorcio.sp_insertarPersonaUF
                    @idPersona = @idPersona,
                    @idUnidadFuncional = @idUF,
                    @rol = @rol;
            END TRY
            BEGIN CATCH
                PRINT 'Error al asignar persona a UF: ' + CAST(@idPersona AS VARCHAR) + ' -> ' + CAST(@idUF AS VARCHAR);
            END CATCH
        END
        ELSE
        BEGIN
            PRINT 'No se encontró UF para cuentaOrigen: ' + @cuentaOrigen;
        END

        SET @i = @i + 1;
    END

    -------------------------------------------------------------------------
    -- 5. Limpiar staging
    -------------------------------------------------------------------------
    DROP TABLE #personas_Num;
    DROP TABLE #personas_CSV;
END;
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
                @estaAsociado BIT = 0; -- por default 0

        SELECT 
            @idPago = CAST(stg_idPago AS INT),
            @fecha = TRY_CONVERT(DATE, stg_fecha, 103),
            @cuentaOrigen = CAST(LTRIM(RTRIM(stg_cvu_cbu)) AS CHAR(22)),
            @importe = CAST(REPLACE(LTRIM(RTRIM(stg_valor)),'$','') AS DECIMAL(13,3))
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

    -- Variables de ayuda para la limpieza de números
    DECLARE @ImporteString NVARCHAR(50), @ImporteLimpio NVARCHAR(50), @PosPeriod INT, @PosComma INT;

    -- Variables para el sp_insertarGastoOrdinario
    DECLARE @tipo NVARCHAR(50), @subTipo NVARCHAR(50), @nomEmpresa NVARCHAR(50);

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
        -- 3.1 Obtener datos de la fila
        SELECT @nomConsorcio = stg_nom_consorcio, @periodo = stg_periodo,
               @stg_gasto_banc = stg_gasto_banc, @stg_gasto_limp = stg_gasto_limp, @stg_gasto_adm = stg_gasto_adm,
               @stg_gasto_seg = stg_gasto_seg, @stg_gasto_gen = stg_gasto_gen, @stg_gasto_pub_agua = stg_gasto_pub_agua,
               @stg_gasto_pub_luz = stg_gasto_pub_luz
        FROM #expensa_num WHERE rn = @i;

        -- Obtener idConsorcio
        SELECT @idConsorcio = idConsorcio FROM consorcio.consorcio WHERE nombre = @nomConsorcio AND fechaBaja IS NULL;

        IF @idConsorcio IS NOT NULL
        BEGIN
            -- Insertar Expensa y Gasto Padre
            SET @idExpensa = NULL;
            EXEC consorcio.sp_insertarExpensa @idConsorcio, @periodo, 2025, @idExpensa OUTPUT;

            IF @idExpensa IS NOT NULL
            BEGIN
                SET @idGasto = NULL;
                EXEC consorcio.sp_insertarGasto @idExpensa, 0, 0, @idGasto OUTPUT;

                IF @idGasto IS NOT NULL
                BEGIN
                    -----------------------------------------------------------------
                    -- Función para limpiar importe
                    -----------------------------------------------------------------
                    DECLARE @LimpiarCastearImporte AS TABLE (importe DECIMAL(12,2));

                    -----------------------------------------------------------------
                    -- A. Gasto Bancario
                    -----------------------------------------------------------------
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
                        SET @subTipo = '';
                        SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'mantenimiento', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1;
                    END

                    -----------------------------------------------------------------
                    -- B. Gasto Limpieza
                    -----------------------------------------------------------------
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
                        SET @subTipo = '';
                        SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'limpieza', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1;
                    END

                    -----------------------------------------------------------------
                    -- C. Gasto Administración
                    -----------------------------------------------------------------
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
                        SET @subTipo = '';
                        SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'administracion', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1;
                    END

                    -----------------------------------------------------------------
                    -- D. Gasto Seguros
                    -----------------------------------------------------------------
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
                        SET @subTipo = '';
                        SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'seguros', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1;
                    END

                    -----------------------------------------------------------------
                    -- E. Gasto Generales
                    -----------------------------------------------------------------
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
                        SET @subTipo = '';
                        SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'generales', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1;
                    END

                    -----------------------------------------------------------------
                    -- F. Servicios Públicos - Agua
                    -----------------------------------------------------------------
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
                        SET @subTipo = 'agua';
                        SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'servicios publicos', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1;
                    END

                    -----------------------------------------------------------------
                    -- G. Servicios Públicos - Luz
                    -----------------------------------------------------------------
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
                        SET @subTipo = 'luz';
                        SET @nomEmpresa = '-';
                        EXEC consorcio.sp_insertarGastoOrdinario @idGasto, 'servicios publicos', @subTipo, @nomEmpresa, @nroFactura, @importe, @idGastoOrdCreado OUTPUT;
                        SET @nroFactura += 1;
                    END

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

    BEGIN TRY
        BEGIN TRANSACTION;

        -------------------------------------------------------------------------
        -- 1. Crear tabla temporal de staging
        -------------------------------------------------------------------------
        IF OBJECT_ID('tempdb..#stg_gastosProcesados') IS NOT NULL
            DROP TABLE #stg_gastosProcesados;

        SELECT 
            go.idGastoOrd,
            go.idGasto,
            go.tipoGasto,
            CASE 
                WHEN CHARINDEX(' - ', p.nomEmpresa) > 0 THEN
                    TRIM(SUBSTRING(p.nomEmpresa, CHARINDEX(' - ', p.nomEmpresa) + 3, LEN(p.nomEmpresa)))
                WHEN go.tipoGasto = 'servicios publicos' AND p.nomEmpresa LIKE '%Luz%' THEN 'Luz'
                WHEN go.tipoGasto = 'servicios publicos' AND p.nomEmpresa LIKE '%Agua%' THEN 'Agua'
                ELSE NULL
            END AS subTipoGasto,
            CASE 
                WHEN CHARINDEX(' - ', p.nomEmpresa) > 0 THEN
                    TRIM(LEFT(p.nomEmpresa, CHARINDEX(' - ', p.nomEmpresa) - 1))
                ELSE
                    TRIM(p.nomEmpresa)
            END AS nomEmpresa,
            go.nroFactura,
            go.importe
        INTO #stg_gastosProcesados
        FROM consorcio.gasto_ordinario AS go
        JOIN consorcio.gasto AS g ON go.idGasto = g.idGasto
        JOIN consorcio.expensa AS e ON g.idExpensa = e.idExpensa
        JOIN consorcio.proveedor AS p
            ON e.idConsorcio = p.idConsorcio
            AND UPPER(p.tipoGasto) LIKE
                CASE
                    WHEN go.tipoGasto = 'mantenimiento' THEN '%BANCARIOS%'
                    ELSE '%' + UPPER(go.tipoGasto) + '%'
                END;

        -------------------------------------------------------------------------
        -- 2. Caso especial: mantenimiento -> Banco Credicoop
        -------------------------------------------------------------------------
        UPDATE #stg_gastosProcesados
        SET 
            subTipoGasto = 'Gastos bancario',
            nomEmpresa = 'BANCO CREDICOOP'
        WHERE tipoGasto = 'mantenimiento';

        -------------------------------------------------------------------------
        -- 3. Crear tabla numerada para iterar
        -------------------------------------------------------------------------
        IF OBJECT_ID('tempdb..#stg_gastosNumerados') IS NOT NULL
            DROP TABLE #stg_gastosNumerados;

        SELECT 
            ROW_NUMBER() OVER (ORDER BY idGastoOrd) AS rn,
            idGastoOrd, idGasto, tipoGasto, subTipoGasto, nomEmpresa, nroFactura, importe
        INTO #stg_gastosNumerados
        FROM #stg_gastosProcesados;

        -------------------------------------------------------------------------
        -- 4. Iterar sobre los registros y actualizar
        -------------------------------------------------------------------------
        DECLARE @i INT = 1;
        DECLARE @max INT;
        SELECT @max = MAX(rn) FROM #stg_gastosNumerados;

        DECLARE 
            @idGastoOrd INT,
            @idGasto INT,
            @tipoGasto VARCHAR(20),
            @subTipoGasto VARCHAR(30),
            @nomEmpresa VARCHAR(40),
            @nroFactura VARCHAR(20),
            @importe DECIMAL(12,2);

        WHILE @i <= @max
        BEGIN
            SELECT 
                @idGastoOrd = idGastoOrd,
                @idGasto = idGasto,
                @tipoGasto = tipoGasto,
                @subTipoGasto = subTipoGasto,
                @nomEmpresa = nomEmpresa,
                @nroFactura = nroFactura,
                @importe = importe
            FROM #stg_gastosNumerados
            WHERE rn = @i;

            BEGIN TRY
                EXEC consorcio.sp_modificarGastoOrdinario 
                    @idGastoOrd = @idGastoOrd,
                    @idGasto = @idGasto,
                    @tipoGasto = @tipoGasto,
                    @subTipoGasto = @subTipoGasto,
                    @nomEmpresa = @nomEmpresa,
                    @nroFactura = @nroFactura,
                    @importe = @importe;
            END TRY
            BEGIN CATCH
                PRINT 'Error al actualizar gasto ordinario con ID: ' + CAST(@idGastoOrd AS VARCHAR);
            END CATCH;

            SET @i += 1;
        END;

        -------------------------------------------------------------------------
        -- 5. Limpieza de tablas temporales
        -------------------------------------------------------------------------
        DROP TABLE #stg_gastosNumerados;
        DROP TABLE #stg_gastosProcesados;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error en SP_procesa_actualizacion_gastos: %s', 16, 1, @ErrorMessage);
    END CATCH;
END;
GO


--------------------------------------------------------------------------------
-- NÚMERO: 9
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
            FROM consorcio.expensa AS e
            LEFT JOIN consorcio.gasto AS g ON e.idExpensa = g.idExpensa
            GROUP BY e.idConsorcio, TRIM(e.periodo), e.anio
        ),
        CteIngresos AS (
            SELECT
                c.idConsorcio,
                CASE MONTH(p.fecha)
                    WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
                    WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo' WHEN 6 THEN 'junio'
                    WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto' WHEN 9 THEN 'septiembre'
                    WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
                END AS periodo,
                YEAR(p.fecha) AS anio,
                SUM(ISNULL(p.importe, 0)) AS totalIngresos
            FROM consorcio.pago AS p
            JOIN consorcio.unidad_funcional AS uf ON p.cuentaOrigen = uf.cuentaOrigen
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
                    WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3
                    WHEN 'abril' THEN 4 WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6
                    WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 WHEN 'septiembre' THEN 9
                    WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
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
                SUM(ingresosEnTermino + ingresosAdeudados - egresos)
                    OVER (PARTITION BY idConsorcio ORDER BY anio, mesNumero) AS saldoCierre
            FROM CteCombinado
        )
        SELECT
            idConsorcio             AS stg_idConsorcio,
            ISNULL(LAG(saldoCierre, 1, 0)
                   OVER (PARTITION BY idConsorcio ORDER BY anio, mesNumero), 0) AS stg_saldoAnterior,
            ingresosEnTermino       AS stg_ingresosEnTermino,
            ingresosAdeudados       AS stg_ingresosAdeudados,
            egresos                 AS stg_egresos,
            saldoCierre             AS stg_saldoCierre,
            periodo                 AS stg_periodo,
            anio                    AS stg_anio
        INTO #stg_estado_financiero
        FROM CteSaldos
        ORDER BY idConsorcio, anio, mesNumero;

        -------------------------------------------------------------------------
        -- 3. Crear tabla numerada para iterar
        -------------------------------------------------------------------------
        IF OBJECT_ID('tempdb..#stg_estado_financiero_num', 'U') IS NOT NULL
            DROP TABLE #stg_estado_financiero_num;

        SELECT 
            ROW_NUMBER() OVER (ORDER BY stg_idConsorcio, stg_anio, stg_periodo) AS rn,
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

        -------------------------------------------------------------------------
        -- 5. Limpieza de staging
        -------------------------------------------------------------------------
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