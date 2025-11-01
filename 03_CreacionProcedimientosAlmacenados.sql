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
    -- 1. Crear tabla temporal con nombres consistentes (camelCase)
    -------------------------------------------------------------------------
    IF OBJECT_ID('consorcio.consorcio_temp', 'U') IS NOT NULL
        DROP TABLE consorcio.consorcio_temp;

    CREATE TABLE consorcio.consorcio_temp (
        id_consorcio_temp INT IDENTITY (1,1) PRIMARY KEY,
        nro_consorcio_excel VARCHAR(20),
        nombre VARCHAR(50) NOT NULL,
        direccion VARCHAR(50) NOT NULL,
        cantidadUnidadesFuncionales INT NOT NULL,
        metrosCuadradosTotales INT NOT NULL
    );

    -------------------------------------------------------------------------
    -- 2. Insertar en tabla temporal desde Excel (SQL dinámico)
    -------------------------------------------------------------------------
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'
    INSERT INTO consorcio.consorcio_temp (
        nro_consorcio_excel, nombre, direccion, cantidadUnidadesFuncionales, metrosCuadradosTotales
    )
    SELECT 
        LTRIM(RTRIM(CAST([Consorcio] AS VARCHAR(20)))) AS nro_consorcio_excel,
        LTRIM(RTRIM([Nombre del consorcio])) AS nombre,
        LTRIM(RTRIM([Domicilio])) AS direccion,
        TRY_CAST([Cant unidades funcionales] AS INT) AS cantidadUnidadesFuncionales,
        TRY_CAST([m2 totales] AS INT) AS metrosCuadradosTotales
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
    -- 3. Insertar en tabla final usando el ABM
    -------------------------------------------------------------------------
    DECLARE 
        @idConsorcio INT,
        @nombre VARCHAR(50),
        @direccion VARCHAR(50),
        @cantidadUnidadesFuncionales INT,
        @metrosCuadradosTotales INT,
        @i INT = 1,
        @max INT;

    SELECT @max = COUNT(*) FROM consorcio.consorcio_temp;

    WHILE @i <= @max
    BEGIN
        SELECT 
            @idConsorcio = CAST(REPLACE(nro_consorcio_excel, 'Consorcio ', '') AS INT),
            @nombre = nombre,
            @direccion = direccion,
            @cantidadUnidadesFuncionales = cantidadUnidadesFuncionales,
            @metrosCuadradosTotales = metrosCuadradosTotales
        FROM consorcio.consorcio_temp
        WHERE id_consorcio_temp = @i;

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
    -- 4. Limpiar
    -------------------------------------------------------------------------
    DROP TABLE consorcio.consorcio_temp;
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
        -- Creamos tabla temporal
        IF OBJECT_ID('tempdb..#TempUF') IS NOT NULL
            DROP TABLE #TempUF;

        CREATE TABLE #TempUF (
            nombreConsorcio VARCHAR(100),
            numeroUnidadFuncional VARCHAR(10),
            piso CHAR(2),
            departamento CHAR(1),
            coeficiente VARCHAR(10),
            metrosCuadrados VARCHAR(10),
            bauleras VARCHAR(2),
            cochera VARCHAR(2),
            m2_baulera VARCHAR(10),
            m2_cochera VARCHAR(10)
        );

        -- Cargamos datos del archivo con BULK INSERT
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

        -- Variables para iterar
        DECLARE @RowCount INT, @Index INT = 1;

        SELECT @RowCount = COUNT(*) FROM #TempUF;

        WHILE @Index <= @RowCount
        BEGIN
            -- Variables para la fila
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

            -- Obtener fila actual
            SELECT 
                @nombreConsorcio = nombreConsorcio,
                @numeroUnidadFuncional = TRY_CAST(numeroUnidadFuncional AS INT),
                @piso = piso,
                @departamento = departamento,
                @coeficiente = TRY_CAST(REPLACE(coeficiente, ',', '.') AS DECIMAL(5,2)),
                @metrosCuadrados = TRY_CAST(metrosCuadrados AS INT),
                @bauleras = bauleras,
                @cochera = cochera,
                @m2_baulera = TRY_CAST(REPLACE(m2_baulera, ',', '.') AS INT),
                @m2_cochera = TRY_CAST(REPLACE(m2_cochera, ',', '.') AS INT)
            FROM #TempUF
            ORDER BY nombreConsorcio, numeroUnidadFuncional
            OFFSET @Index - 1 ROWS FETCH NEXT 1 ROWS ONLY;

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

            SET @Index = @Index + 1;
        END

        DROP TABLE #TempUF;
    END TRY
    BEGIN CATCH
        PRINT 'Error en el procedimiento de importación: ' + ERROR_MESSAGE();
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

    -- 3. Crear tabla temporal numerada para iterar con WHILE y preparar los datos para el update
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

    -- 4. Iterar con WHILE
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

        -- Llamada al SP de modificación
        EXEC consorcio.sp_modificarUnidadFuncional
            @idUnidadFuncional = @idUF,
            @cuentaOrigen = @cuentaOrigen;

        SET @i = @i + 1;
    END

    -- 5. Limpiar temporales
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

    DECLARE @sqlBulkInsert NVARCHAR(MAX);
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @idPersonaCreada INT;
    DECLARE @i INT = 1;
    DECLARE @max INT;

    -- 1. Crear tabla temporal
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

    -- 2. Cargar CSV
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

    -- 3. Tabla temporal numerada con limpieza de datos
    IF OBJECT_ID('tempdb..#temporal_Num', 'U') IS NOT NULL
        DROP TABLE #temporal_Num;

    SELECT 
        ROW_NUMBER() OVER (ORDER BY Col3_DNI) AS rn,

       -- Limpieza de Nombre
        RTRIM((
            SELECT UPPER(LEFT(s.value,1)) + LOWER(SUBSTRING(s.value,2,LEN(s.value))) + ' '
            FROM STRING_SPLIT(
                REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(t.Col1_Nombre)), '‚','é'), '¥','ñ'), '¡','í'), ' '
            ) s
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)')) AS nombre,

        -- Limpieza de Apellido
        RTRIM((
            SELECT UPPER(LEFT(s.value,1)) + LOWER(SUBSTRING(s.value,2,LEN(s.value))) + ' '
            FROM STRING_SPLIT(
                REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(t.Col2_Apellido)), '‚','é'), '¥','ñ'), '¡','í'), ' '
            ) s
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)')) AS apellido,

        -- DNI como INT
        CAST(LTRIM(RTRIM(t.Col3_DNI)) AS INT) AS dni,

        -- Email limpiado
        LOWER(
        REPLACE(
            REPLACE(
                REPLACE(LTRIM(RTRIM(t.Col4_Email)), '‚', 'é'), 
                    '¥', 'ñ'
                ), 
                '¡', 'í'
            )
        ) AS email,

        LTRIM(RTRIM(t.Col5_Telefono)) AS telefono,
        LTRIM(RTRIM(t.Col6_CuentaOrigen)) AS cuentaOrigen,
        t.Col7_Inquilino
    INTO #temporal_Num
    FROM #temporal t
    WHERE ISNUMERIC(LTRIM(RTRIM(t.Col3_DNI))) = 1 AND LTRIM(RTRIM(t.Col3_DNI)) <> '';

    SELECT @max = MAX(rn) FROM #temporal_Num;

    -- 4. Iterar con WHILE y llamar a los SP de ABM
    WHILE @i <= @max
    BEGIN
        DECLARE @nombre VARCHAR(100),
                @apellido VARCHAR(100),
                @dni INT,
                @email VARCHAR(100),
                @telefono VARCHAR(50),
                @cuentaOrigen CHAR(22),
                @rol VARCHAR(15),
                @idUF INT;

        SELECT 
            @nombre = nombre,
            @apellido = apellido,
            @dni = dni,
            @email = email,
            @telefono = telefono,
            @cuentaOrigen = cuentaOrigen,
            @rol = CASE WHEN Col7_Inquilino = 1 THEN 'inquilino' ELSE 'propietario' END
        FROM #temporal_Num
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
                @idPersonaCreada = @idPersonaCreada OUTPUT;
        END TRY
        BEGIN CATCH
            PRINT 'Persona ya existente o error en dni: ' + CAST(@dni AS VARCHAR);
        END CATCH

        -- Obtener idUnidadFuncional
        SELECT @idUF = idUnidadFuncional
        FROM consorcio.unidad_funcional
        WHERE cuentaOrigen = @cuentaOrigen AND fechaBaja IS NULL;

        IF @idUF IS NOT NULL
        BEGIN
            BEGIN TRY
                EXEC consorcio.sp_insertarPersonaUF
                    @idPersona = @idPersonaCreada,
                    @idUnidadFuncional = @idUF,
                    @rol = @rol;
            END TRY
            BEGIN CATCH
                PRINT 'Error al asignar persona a UF: ' + CAST(@idPersonaCreada AS VARCHAR) + ' -> ' + CAST(@idUF AS VARCHAR);
            END CATCH
        END
        ELSE
        BEGIN
            PRINT 'No se encontró UF para cuentaOrigen: ' + @cuentaOrigen;
        END

        SET @i = @i + 1;
    END

    -- 5. Limpiar temporales
    DROP TABLE #temporal_Num;
    DROP TABLE #temporal;

    PRINT 'Importación de personas y relaciones completada.';
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

    -- 1. Crear tabla staging
    CREATE TABLE #pago_staging (
        stg_idPago      NVARCHAR(50),
        stg_fecha       NVARCHAR(50),
        stg_cvu_cbu     NVARCHAR(50),
        stg_valor       NVARCHAR(50)
    );

    -- 2. Cargar CSV
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

    -- 3. Crear tabla numerada para iterar
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

    -- 4. Iterar y llamar a SP de inserción
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

    -- 5. Limpiar temporales
    DROP TABLE #pago_Num;
    DROP TABLE #pago_staging;

    PRINT 'Importación de pagos completada.';
END;
GO
