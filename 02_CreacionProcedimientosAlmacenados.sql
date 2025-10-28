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
    @ruta_archivo NVARCHAR(255)
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
        ''Excel 12.0;Database=' + @ruta_archivo + ';HDR=YES;IMEX=1;'',
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

-- Ejemplo de ejecución:
EXEC consorcio.SP_importar_consorcios_excel 
    @ruta_archivo = 'C:\Archivos para el TP\datos varios.xlsx';

SELECT * FROM consorcio.consorcio;

------- Archivo inquilino-propietarios-datos.csv -----------------
-- La ruta debe ser ABSOLUTA y ACCESIBLE por el servicio de SQL Server, por eso elegimos alojar los docs en la raíz del disco C

IF OBJECT_ID('consorcio.ImportarPersonas') IS NOT NULL
    DROP PROCEDURE consorcio.ImportarPersonas;
GO

CREATE PROCEDURE consorcio.ImportarPersonas
    @path NVARCHAR(255) -- Parámetro para la ruta del archivo CSV
AS
BEGIN
    -- Se declara una sola variable para la ejecución completa
    DECLARE @sqlQuery NVARCHAR(MAX); 

    BEGIN TRY
        
        -- Combinar la creación de la tabla, el BULK INSERT y el INSERT final en una sola cadena
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
            
            -- 2. BULK INSERT (Carga de datos)
            BULK INSERT #temporal
            FROM ''' + @path + ''' 
            WITH (
                FIELDTERMINATOR = '';'', -- Delimitador correcto
                ROWTERMINATOR = ''0x0A'',
                FIRSTROW = 2, -- Omitir encabezado
                CODEPAGE = ''65001'' 
            );

            -- 3. INSERTAR EN LA TABLA FINAL consorcio.persona
            INSERT INTO consorcio.persona (
                nombre,
                apellido,
                dni,
                email,
                telefono,
                cuentaOrigen
            )
            SELECT
                LTRIM(RTRIM(Col1_Nombre)) AS nombre,
                LTRIM(RTRIM(Col2_Apellido)) AS apellido,
                CAST(LTRIM(RTRIM(Col3_DNI)) AS INT) AS dni, 
                LTRIM(RTRIM(Col4_Email)) AS email,
                LTRIM(RTRIM(Col5_Telefono)) AS telefono,
                LTRIM(RTRIM(Col6_CuentaOrigen)) AS cuentaOrigen
            FROM #temporal; -- ¡Ahora en el mismo ámbito de ejecución!

            -- 4. LIMPIEZA
            IF OBJECT_ID(''tempdb..#temporal'') IS NOT NULL
                DROP TABLE #temporal;
        ';

        -- Ejecutar todo el proceso en una sola llamada
        EXEC sp_executesql @sqlQuery; 

        SELECT 'Importación de datos de persona completada con éxito.' AS Resultado;

    END TRY
    BEGIN CATCH
        -- Manejo de errores
        SELECT
            'Error al importar los datos. La tabla temporal fue limpiada.' AS Resultado,
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;
            
        -- Limpieza de emergencia, en caso de que la tabla haya llegado a existir
        SET @sqlQuery = 'IF OBJECT_ID(''tempdb..#temporal'') IS NOT NULL DROP TABLE #temporal;';
        EXEC sp_executesql @sqlQuery;
            
        THROW; 
        RETURN 1;
    END CATCH
    
    RETURN 0; 
END
GO

EXEC consorcio.ImportarPersonas 
    @path = 'C:\Archivos-para-el-TP\Archivos para el TP\Inquilino-propietarios-datos.csv';

SELECT * FROM consorcio.persona


---------- pagos_consorcios.csv ------------

CREATE OR ALTER PROCEDURE consorcio.sp_cargaPagos
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

EXEC consorcio.sp_cargaPagos @path = 'C:\Archivos-para-el-TP\Archivos para el TP\pagos_consorcios.csv';

SELECT * FROM consorcio.pago



---------- UF por consorcio.txt ------------

CREATE OR ALTER PROCEDURE consorcio.SP_CargarUnidadesDesdeArchivo
    @path NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1?? Crear tabla temporal
    IF OBJECT_ID('tempdb..#UnidadFuncionalTemp') IS NOT NULL
        DROP TABLE #UnidadFuncionalTemp;

    CREATE TABLE #UnidadFuncionalTemp (
        NombreConsorcio NVARCHAR(100),
        nroUnidadFuncional INT,
        Piso NVARCHAR(10),
        Departamento NVARCHAR(10),
        Coeficiente DECIMAL(5,2),
        m2_unidad_funcional INT,
        Bauleras NVARCHAR(3),
        Cochera NVARCHAR(3),
        m2_baulera INT,
        m2_cochera INT
    );

    -- 2?? Importar archivo con SQL dinámico (tabulado)
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
        BULK INSERT #UnidadFuncionalTemp
        FROM ''' + @path + '''
        WITH
        (
            FIELDTERMINATOR = ''\t'',
            ROWTERMINATOR = ''\n'',
            FIRSTROW = 2
        );';

    BEGIN TRY
        EXEC(@sql);
    END TRY
    BEGIN CATCH
        RAISERROR('Error al importar el archivo. Verifique la ruta y el formato.', 16, 1);
        RETURN;
    END CATCH;

    -- 3?? Insertar en unidad_funcional
    INSERT INTO consorcio.unidad_funcional
    (
        idConsorcio,
        cuentaOrigen,
        numeroUnidadFuncional,
        piso,
        coeficiente,
        metrosCuadrados
    )
    SELECT
        c.idConsorcio,
        CAST(t.nroUnidadFuncional AS VARCHAR(22)),
        t.nroUnidadFuncional,
        CASE 
            WHEN UPPER(LTRIM(RTRIM(t.Piso))) = 'PB' THEN 0
            WHEN ISNUMERIC(t.Piso) = 1 THEN CAST(t.Piso AS INT)
            ELSE 0
        END,
        t.Coeficiente,
        t.m2_unidad_funcional
    FROM #UnidadFuncionalTemp t
    INNER JOIN consorcio.consorcio c
        ON LTRIM(RTRIM(c.nombre)) = LTRIM(RTRIM(t.NombreConsorcio));

    -- 4?? Insertar en baulera
    INSERT INTO consorcio.baulera (idUnidadFuncional, metrosCuadrados, coeficiente)
    SELECT uf.idUnidadFuncional, t.m2_baulera, t.Coeficiente
    FROM #UnidadFuncionalTemp t
    INNER JOIN consorcio.unidad_funcional uf
        ON uf.idConsorcio = (SELECT idConsorcio FROM consorcio.consorcio WHERE LTRIM(RTRIM(nombre)) = LTRIM(RTRIM(t.NombreConsorcio)))
       AND uf.numeroUnidadFuncional = t.nroUnidadFuncional
    WHERE t.Bauleras = 'SI' AND t.m2_baulera > 0;

    -- 5?? Insertar en cochera
    INSERT INTO consorcio.cochera (idUnidadFuncional, metrosCuadrados, coeficiente)
    SELECT uf.idUnidadFuncional, t.m2_cochera, t.Coeficiente
    FROM #UnidadFuncionalTemp t
    INNER JOIN consorcio.unidad_funcional uf
        ON uf.idConsorcio = (SELECT idConsorcio FROM consorcio.consorcio WHERE LTRIM(RTRIM(nombre)) = LTRIM(RTRIM(t.NombreConsorcio)))
       AND uf.numeroUnidadFuncional = t.nroUnidadFuncional
    WHERE t.Cochera = 'SI' AND t.m2_cochera > 0;

    PRINT 'Importación completada correctamente.';
END;
GO



EXEC consorcio.SP_CargarUnidadesDesdeArchivo @path = 'C:\Archivos para el TP\UF por consorcio.txt';
SELECT * FROM consorcio.unidad_funcional;



--Prueba para ver los datos (FUNCIONA)
CREATE TABLE #UF (
    NombreConsorcio NVARCHAR(100),
    nroUnidadFuncional NVARCHAR(10),
    Piso NVARCHAR(10),
    Departamento NVARCHAR(10),
    Coeficiente NVARCHAR(10),
    m2_unidad_funcional NVARCHAR(10),
    Bauleras NVARCHAR(3),
    Cochera NVARCHAR(3),
    m2_baulera NVARCHAR(10),
    m2_cochera NVARCHAR(10)
);

BULK INSERT #UF
FROM 'C:\Archivos para el TP\UF por consorcio.txt'
WITH (
    FIELDTERMINATOR = '\t',  -- TAB
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);

SELECT * FROM #UF;