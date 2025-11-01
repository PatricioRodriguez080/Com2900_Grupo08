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
CREATE OR ALTER PROCEDURE consorcio.SP_importar_personas_csv
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
END;
GO
