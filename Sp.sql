--Creacion SP para archivo .txt

--modificar tipo de archivo atributo PISO ya que existe "PB"

--El idPago en detalle_expensa no puede ser NOT NULL
--Problema: Definiste idPago INT NOT NULL. Esto te obliga a asignar un pago en el mismo momento en que creas la expensa. Lógicamente, una expensa se crea primero y se paga después.
--Solución: La columna idPago debe permitir valores nulos (NULL) hasta que el pago se realice.
--??


USE Com2900G08

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')
    EXEC('CREATE SCHEMA stg');
GO

DROP TABLE IF EXISTS stg.consorcio;

CREATE TABLE stg.consorcio (
    auxNombre NVARCHAR(200),
    auxDireccion NVARCHAR(200),
    auxCantidadUF NVARCHAR(100),
    auxMetrosTotales NVARCHAR(100)
);
GO

CREATE OR ALTER PROCEDURE sp_consorcio_ImportarConsorcio
    @rutaArchivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);

    -- Limpiar staging
    TRUNCATE TABLE stg.consorcio;

    -- Comando dinámico para importar el CSV
    SET @sql = N'
        BULK INSERT stg.consorcio
        FROM ''' + @rutaArchivo + '''
        WITH (
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            FIRSTROW = 2,       -- omite encabezado
            CODEPAGE = ''65001'',  -- UTF-8 (usa ''RAW'' si da error)
            TABLOCK
        );';

    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT ERROR_MESSAGE();
        RETURN -1;
    END CATCH;

    UPDATE stg.consorcio
    SET
        auxNombre = LTRIM(RTRIM(auxNombre)),
        auxDireccion = LTRIM(RTRIM(auxDireccion)),
        auxCantidadUF = ISNULL(NULLIF(auxCantidadUF, ''), '0'),
        auxMetrosTotales = ISNULL(NULLIF(auxMetrosTotales, ''), '0');

    DELETE FROM stg.consorcio WHERE auxNombre IS NULL OR auxNombre = '';

    -- Integración con tabla final
    MERGE INTO consorcio.consorcio AS destino
    USING (
        SELECT
            auxNombre AS nombre,
            auxDireccion AS direccion,
            TRY_CAST(auxCantidadUF AS INT) AS cantidadUnidadesFuncionales,
            TRY_CAST(auxMetrosTotales AS INT) AS metrosCuadradosTotales
        FROM stg.consorcio
        WHERE TRY_CAST(auxCantidadUF AS INT) IS NOT NULL
          AND TRY_CAST(auxMetrosTotales AS INT) IS NOT NULL
    ) AS origen
    ON destino.nombre = origen.nombre
    WHEN MATCHED THEN
        UPDATE SET
            destino.direccion = origen.direccion,
            destino.cantidadUnidadesFuncionales = origen.cantidadUnidadesFuncionales,
            destino.metrosCuadradosTotales = origen.metrosCuadradosTotales
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (nombre, direccion, cantidadUnidadesFuncionales, metrosCuadradosTotales)
        VALUES (origen.nombre, origen.direccion, origen.cantidadUnidadesFuncionales, origen.metrosCuadradosTotales);

    SET NOCOUNT OFF;
END;
GO


EXEC sp_consorcio_ImportarConsorcio @rutaArchivo = 'C:\Users\Leo\Desktop\Archivos-para-el-TP\Archivos para el TP\datos varios.xlsx'

SELECT * FROM consorcio.consorcio

















DROP TABLE IF EXISTS stg.unidad_funcional;

--para cargar los datos sucios para luego pasarlos en limpios
CREATE TABLE stg.unidad_funcional (
    auxNombreConsorcio NVARCHAR(200),
    auxNroUnidadFuncional NVARCHAR(100),
    auxPiso NVARCHAR(100),
    auxDepartamento NVARCHAR(100),
    auxCoeficiente NVARCHAR(100),
    auxM2UnidadFuncional NVARCHAR(100),
    auxBauleras NVARCHAR(50),
    auxCochera NVARCHAR(50),
    auxM2Baulera NVARCHAR(100),
    auxM2Cochera NVARCHAR(100)
);

DROP TABLE IF EXISTS stg.pago;

CREATE TABLE stg.pago (
    auxFecha NVARCHAR(100),
    auxCuentaOrigen NVARCHAR(100),
    auxImporte NVARCHAR(100)
);
GO

-------------------------
CREATE OR ALTER PROCEDURE sp_consorcio_ImportarUnidadesFuncionales
    @rutaArchivo NVARCHAR(1000) -- Req. 7: Ruta por parámetro
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(1000);

    TRUNCATE TABLE stg.unidad_funcional;

    SET @sql = N'
        BULK INSERT stg.unidad_funcional
        FROM ''' + @rutaArchivo + '''
        WITH (
            FIELDTERMINATOR = ''\t'',  -- Separador de Tabulación del TXT 
            ROWTERMINATOR = ''\n'',  
            FIRSTROW = 2,        -- La fila 1 es de encabezados 
            CODEPAGE = ''RAW''      
        );';
    
    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT 'Error Crítico: No se pudo cargar el archivo. Verifique la ruta y permisos.';
        PRINT ERROR_MESSAGE();
        RETURN -1;
    END CATCH

    UPDATE stg.unidad_funcional

    SET
        auxCoeficiente = REPLACE(auxCoeficiente, ',', '.'),
        auxM2UnidadFuncional = REPLACE(auxM2UnidadFuncional, ',', '.'),
        auxM2Baulera = ISNULL(NULLIF(REPLACE(auxM2Baulera, ',', '.'),''),'0'),
        auxM2Cochera = ISNULL(NULLIF(REPLACE(auxM2Cochera, ',', '.'),''),'0'),
        auxBauleras = UPPER(LTRIM(RTRIM(auxBauleras))),
        auxCochera = UPPER(LTRIM(RTRIM(auxCochera))),
        auxPiso = LTRIM(RTRIM(auxPiso)),
        auxNombreConsorcio = LTRIM(RTRIM(auxNombreConsorcio));

    INSERT INTO consorcio.consorcio (nombre, direccion, cantidadUnidadesFuncionales, metrosCuadradosTotales)
    SELECT DISTINCT auxNombreConsorcio, 'SIN DIRECCION', 8, 8
    FROM stg.unidad_funcional s
    WHERE NOT EXISTS (
    SELECT 1 FROM consorcio.consorcio c WHERE c.nombre = s.auxNombreConsorcio
    );

    MERGE INTO consorcio.unidad_funcional AS destino 
    USING (
        
        SELECT 
            c.idConsorcio,
            s.auxNroUnidadFuncional AS numeroUnidadFuncional,
            TRY_CAST (s.auxPiso AS CHAR (2)) AS piso, 
            '0000000000000000000000' AS cuentaOrigenTemporal, --arreglar esto
            TRY_CAST(s.auxCoeficiente AS DECIMAL(5,2)) AS coeficiente,
            TRY_CAST(s.auxM2UnidadFuncional AS INT) AS metrosCuadrados
            
        FROM stg.unidad_funcional AS s
        JOIN consorcio.consorcio AS c ON s.auxNombreConsorcio = c.nombre
     ) AS origen
    ON (destino.idConsorcio = origen.idConsorcio AND destino.numeroUnidadFuncional = origen.numeroUnidadFuncional)
    
    WHEN MATCHED THEN
        UPDATE SET
            destino.piso = origen.piso,
            destino.coeficiente = origen.coeficiente, 
            destino.metrosCuadrados = origen.metrosCuadrados
    
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (idConsorcio, cuentaOrigen, numeroUnidadFuncional, piso, coeficiente, metrosCuadrados)
        VALUES (origen.idConsorcio, origen.cuentaOrigenTemporal, origen.numeroUnidadFuncional, origen.piso, origen.coeficiente, origen.metrosCuadrados);

    DELETE c
    FROM consorcio.cochera AS c
    JOIN consorcio.unidad_funcional uf ON c.idUnidadFuncional = uf.idUnidadFuncional
    JOIN consorcio.consorcio co ON uf.idConsorcio = co.idConsorcio
    WHERE co.nombre IN (SELECT DISTINCT auxNombreConsorcio FROM stg.unidad_funcional);

    INSERT INTO consorcio.cochera (idUnidadFuncional, metrosCuadrados, coeficiente)
    SELECT 
        uf.idUnidadFuncional,
        TRY_CAST(s.auxM2Cochera AS INT),
        TRY_CAST(s.auxCoeficiente AS DECIMAL(5,2))
    
    FROM stg.unidad_funcional AS s
    JOIN consorcio.consorcio c ON s.auxNombreConsorcio = c.nombre
    JOIN consorcio.unidad_funcional uf ON c.idConsorcio = uf.idConsorcio AND s.auxNroUnidadFuncional = uf.numeroUnidadFuncional
    
    WHERE s.auxCochera = 'SI';

    DELETE b
    FROM consorcio.baulera AS b
    JOIN consorcio.unidad_funcional uf ON b.idUnidadFuncional = uf.idUnidadFuncional
    JOIN consorcio.consorcio co ON uf.idConsorcio = co.idConsorcio
    WHERE co.nombre IN (SELECT DISTINCT auxNombreConsorcio FROM stg.unidad_funcional);

    INSERT INTO consorcio.baulera (idUnidadFuncional, metrosCuadrados, coeficiente)
    SELECT 
        uf.idUnidadFuncional,
        TRY_CAST(s.auxM2Baulera AS INT),
        TRY_CAST(s.auxCoeficiente AS DECIMAL(5,2))
    
    FROM stg.unidad_funcional AS s
    JOIN consorcio.consorcio c ON s.auxNombreConsorcio = c.nombre
    JOIN consorcio.unidad_funcional uf ON c.idConsorcio = uf.idConsorcio AND s.auxNroUnidadFuncional = uf.numeroUnidadFuncional
    
    WHERE s.auxBauleras = 'SI';

    SET NOCOUNT OFF;
END;

EXEC sp_consorcio_ImportarUnidadesFuncionales @rutaArchivo = N'C:\Users\Leo\Desktop\Archivos-para-el-TP\Archivos para el TP\UF por consorcio.txt';

EXEC sp_help 'consorcio.unidad_funcional';

SELECT * FROM stg.unidad_funcional;

SELECT * FROM consorcio.unidad_funcional uf
join consorcio.consorcio c on c.idConsorcio=uf.idConsorcio
where c.nombre='Azcuenaga'

SELECT * FROM consorcio.consorcio;

SELECT * FROM consorcio.baulera;
SELECT * FROM consorcio.cochera;




















--------------------------
CREATE OR ALTER PROCEDURE sp_consorcio_importarPago
    @rutaArchivo nvarchar(1000)
AS
BEGIN
	SET NOCOUNT ON; 
    DECLARE @sql nvarchar (1000);

    TRUNCATE TABLE stg.pago

    SET @sql = N'
        BULK INSERT stg.pago
        FROM ''' + @rutaArchivo + '''
        WITH (
            FIELDTERMINATOR = '','',  -- CORREGIDO: Separador de Coma (,) 
            ROWTERMINATOR = ''\n'',  
            FIRSTROW = 2,        -- VALIDADO: El archivo tiene encabezado
            CODEPAGE = ''RAW''      
        );';
    
    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT 'Error Crítico: No se pudo cargar el archivo CSV. Verifique la ruta y permisos.';
        PRINT ERROR_MESSAGE();
        RETURN -1;
    END CATCH

    UPDATE stg.pago
    SET 
       
        auxImporte = ISNULL(NULLIF(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(auxImporte)), '$', ''),'.',''),',','.'),''),'0'),
        auxCuentaOrigen = LTRIM(RTRIM(auxCuentaOrigen));

    DELETE FROM stg.pago
    WHERE ISNUMERIC(auxCuentaOrigen) = 0;

    INSERT INTO consorcio.pago (
        fecha,
        cuentaOrigen,
        importe
    )

    SELECT
        TRY_CAST(s.auxFecha AS DATE),
        s.auxCuentaOrigen,
        TRY_CAST(s.auxImporte AS DECIMAL(12, 2))
    FROM 
        stg.pago AS s
    WHERE
        NOT EXISTS (
            SELECT 1 
            FROM consorcio.pago p
            WHERE p.cuentaOrigen = s.auxCuentaOrigen
              AND p.importe = TRY_CAST(s.auxImporte AS DECIMAL(12, 2))
              AND p.fecha = TRY_CAST(s.auxFecha AS DATE)
        );

    UPDATE p
    SET
        p.estaAsociado = 1
    FROM
        consorcio.pago AS p
    INNER JOIN
        consorcio.unidad_funcional AS uf ON p.cuentaOrigen = uf.cuentaOrigen -- El "Match"
    WHERE
        p.estaAsociado = 0; -- Solo procesa los pagos nuevos

    -- 5.2: Vincular los pagos ya asociados a las deudas (detalle_expensa)
    UPDATE de
    SET
        de.idPago = p.idPago, -- Asigna la FK del pago
        de.pagoRecibido = p.importe
        -- Aquí puedes agregar más lógica (ej: de.deuda = de.totalAPagar - p.importe)
    FROM
        consorcio.detalle_expensa AS de
    INNER JOIN
        consorcio.expensa AS e ON de.idExpensa = e.idExpensa
    INNER JOIN
        consorcio.unidad_funcional AS uf ON e.idUnidadFuncional = uf.idUnidadFuncional
    INNER JOIN
        consorcio.pago AS p ON uf.cuentaOrigen = p.cuentaOrigen
    WHERE
        p.estaAsociado = 1         -- El pago fue encontrado
        AND de.idPago IS NULL;     -- La deuda AÚN no tiene un pago asignado

    SELECT 
        cuentaOrigen,
        importe,
        fecha,
        estaAsociado
    FROM 
        consorcio.pago
    WHERE 
        estaAsociado = 0; 

    SET NOCOUNT OFF;
END;

EXEC sp_consorcio_importarPago @rutaArchivo = 'C:\Users\Leo\Desktop\Archivos-para-el-TP\Archivos para el TP\pagos_consorcios.csv';

