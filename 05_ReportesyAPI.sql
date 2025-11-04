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
Enunciado:        "05 - Creación de Reportes y APIs"
===============================================================================
*/


--------------------------------------------------------------------------------
-- Configuracion 
-- Permite interactuar con las APIs
--------------------------------------------------------------------------------

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO

--------------------------------------------------------------------------------
-- REPORTE 2
-- Total de recaudación por mes y departamento en formato de tabla cruzada
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_reporte_2
    @idConsorcio INT,
    @Anio INT,
    @Piso CHAR(2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------------------------------------
    -- 1. OBTENER LA COTIZACIÓN DEL DÓLAR EN TIEMPO REAL CON MANEJO DE ERRORES
    --------------------------------------------------------------------------------
    DECLARE @url NVARCHAR(256) = 'https://dolarapi.com/v1/dolares/oficial'
    DECLARE @Object INT
    DECLARE @json TABLE(DATA NVARCHAR(MAX))
    DECLARE @respuesta NVARCHAR(MAX)
    DECLARE @venta DECIMAL(18, 2) = 0.00

    BEGIN TRY
        EXEC sp_OACreate 'MSXML2.XMLHTTP', @Object OUT
        EXEC sp_OAMethod @Object, 'OPEN', NULL, 'GET', @url, 'FALSE'
        EXEC sp_OAMethod @Object, 'SEND'
        EXEC sp_OAMethod @Object, 'RESPONSETEXT', @respuesta OUTPUT
        
        INSERT INTO @json 
            EXEC sp_OAGetProperty @Object, 'RESPONSETEXT'
        
        IF @Object IS NOT NULL
            EXEC sp_OADestroy @Object
        
        SELECT @venta = [venta]
        FROM OPENJSON((SELECT DATA FROM @json))
        WITH
        (
            [venta] DECIMAL(18, 2) '$.venta'
        );

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'Error al comunicarse con la API: ' + @ErrorMessage;
    END CATCH
    
    --------------------------------------------------------------------------------
    -- 2. CTE: CALCULO DE PAGOS POR MES Y DEPARTAMENTO
    --------------------------------------------------------------------------------
    ;WITH PagosPivot AS (
        SELECT
            CASE MONTH(p.fecha)
                WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
                WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo' WHEN 6 THEN 'junio'
                WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto' WHEN 9 THEN 'septiembre'
                WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
            END AS Mes,
            MONTH(p.fecha) AS MesNumero,
            ISNULL(SUM(CASE WHEN uf.departamento = 'A' THEN p.importe END), 0) AS A,
            ISNULL(SUM(CASE WHEN uf.departamento = 'B' THEN p.importe END), 0) AS B,
            ISNULL(SUM(CASE WHEN uf.departamento = 'C' THEN p.importe END), 0) AS C,
            ISNULL(SUM(CASE WHEN uf.departamento = 'D' THEN p.importe END), 0) AS D,
            ISNULL(SUM(CASE WHEN uf.departamento = 'E' THEN p.importe END), 0) AS E
        FROM consorcio.pago AS p
        JOIN consorcio.unidad_funcional AS uf ON p.cuentaOrigen = uf.cuentaOrigen
        WHERE
            uf.idConsorcio = @idConsorcio
            AND YEAR(p.fecha) = @Anio
            AND (@Piso IS NULL OR uf.piso = @Piso)
        GROUP BY MONTH(p.fecha)
    )
    
    --------------------------------------------------------------------------------
    -- 3. FORMATO XML con estructura ARS/USD
    --------------------------------------------------------------------------------
    SELECT
        Mes AS [@nombre],
        @venta AS [TipoCambioVenta], 
        (
            SELECT
                Departamento.nombre AS [Departamento/@nombre],
                (
                    SELECT
                        Departamento.Monto_ARS AS [ARS],
                        CASE WHEN @venta > 0 THEN CAST(Departamento.Monto_ARS / @venta AS DECIMAL(18, 2)) ELSE 0.00 END AS [USD]
                    FOR XML PATH('Monto'), TYPE
                )
            FROM (
                SELECT 'A' AS nombre, A AS Monto_ARS
                UNION ALL SELECT 'B', B
                UNION ALL SELECT 'C', C
                UNION ALL SELECT 'D', D
                UNION ALL SELECT 'E', E
            ) AS Departamento
            FOR XML PATH(''), ROOT('Departamentos'), TYPE
        )
    FROM PagosPivot
    ORDER BY MesNumero
    FOR XML PATH('Mes'), ROOT('ReportePagos');
END;
GO


EXEC consorcio.SP_reporte_2
    @idConsorcio = 1,
    @Anio = 2025,
    @Piso='2';


--------------------------------------------------------------------------------
-- REPORTE 4
-- Obtener los 5 (cinco) meses de mayores gastos y los 5 (cinco) de mayores ingresos
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_reporte_4
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaFin < @FechaInicio
    BEGIN
        RAISERROR('Error: La fecha de fin no puede ser anterior a la fecha de inicio.', 16, 1);
        RETURN;
    END

    --------------------------------------------------------------------------------
    -- 1. OBTENER LA COTIZACIÓN DEL DÓLAR EN TIEMPO REAL CON MANEJO DE ERRORES
    --------------------------------------------------------------------------------
    DECLARE @url NVARCHAR(256) = 'https://dolarapi.com/v1/dolares/oficial'
    DECLARE @Object INT
    DECLARE @json TABLE(DATA NVARCHAR(MAX))
    DECLARE @respuesta NVARCHAR(MAX)
    DECLARE @venta DECIMAL(18, 2) = 0.00

    BEGIN TRY
        EXEC sp_OACreate 'MSXML2.XMLHTTP', @Object OUT
        EXEC sp_OAMethod @Object, 'OPEN', NULL, 'GET', @url, 'FALSE'
        EXEC sp_OAMethod @Object, 'SEND'
        EXEC sp_OAMethod @Object, 'RESPONSETEXT', @respuesta OUTPUT
        
        INSERT INTO @json 
            EXEC sp_OAGetProperty @Object, 'RESPONSETEXT'

        SELECT @venta = [venta]
        FROM OPENJSON((SELECT DATA FROM @json))
        WITH
        (
            [venta] DECIMAL(18, 2) '$.venta'
        );
    END TRY
      BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'Error al comunicarse con la API: ' + @ErrorMessage;
    END CATCH

    --------------------------------------------------------------------------------
    -- 2. ALMACENAR DATOS EN TABLAS TEMPORALES PARA EL XML
    --------------------------------------------------------------------------------
    DECLARE @TopIngresos TABLE (
        Anio INT,
        Mes NVARCHAR(20),
        TotalIngresos_ARS DECIMAL(18, 2)
    );

    DECLARE @TopGastos TABLE (
        Anio INT,
        Mes NVARCHAR(20),
        TotalGastos_ARS DECIMAL(18, 2)
    );

    INSERT INTO @TopIngresos (Anio, Mes, TotalIngresos_ARS)
    SELECT TOP 5
        YEAR(p.fecha),
        CASE MONTH(p.fecha)
            WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo' WHEN 4 THEN 'abril' 
            WHEN 5 THEN 'mayo' WHEN 6 THEN 'junio' WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto' 
            WHEN 9 THEN 'septiembre' WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre' 
        END,
        SUM(p.importe)
    FROM consorcio.pago AS p JOIN consorcio.unidad_funcional AS uf ON p.cuentaOrigen = uf.cuentaOrigen
    WHERE p.fecha BETWEEN @FechaInicio AND @FechaFin
    GROUP BY YEAR(p.fecha), MONTH(p.fecha)
    ORDER BY SUM(p.importe) DESC;

    INSERT INTO @TopGastos (Anio, Mes, TotalGastos_ARS)
    SELECT TOP 5
        e.anio,
        e.periodo,
        SUM(g.subTotalOrdinarios + g.subTotalExtraOrd)
    FROM consorcio.gasto AS g JOIN consorcio.expensa AS e ON g.idExpensa = e.idExpensa
    WHERE DATEFROMPARTS(e.anio, 
        CASE e.periodo
            WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3 WHEN 'abril' THEN 4 
            WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6 WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 
            WHEN 'septiembre' THEN 9 WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12 
        END, 1) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY e.anio, e.periodo
    ORDER BY SUM(g.subTotalOrdinarios + g.subTotalExtraOrd) DESC;


    --------------------------------------------------------------------------------
    -- 3. GENERACIÓN DEL XML ÚNICO
    --------------------------------------------------------------------------------
    SELECT
        @venta AS [TipoCambioVenta], 
        (
            SELECT 
                i.Anio AS [Mes/@anio],
                i.Mes AS [Mes/@nombre],
                (
                    SELECT 
                        i.TotalIngresos_ARS AS [ARS],
                        CASE WHEN @venta > 0 THEN CAST(i.TotalIngresos_ARS / @venta AS DECIMAL(18, 2)) ELSE 0.00 END AS [USD]
                    FOR XML PATH('Monto'), TYPE
                )
            FROM @TopIngresos i
            FOR XML PATH('Ingreso'), ROOT('Top5Ingresos'), TYPE
        ),
        (
            SELECT 
                g.Anio AS [Mes/@anio],
                g.Mes AS [Mes/@nombre],
                (
                    SELECT 
                        g.TotalGastos_ARS AS [ARS],
                        CASE WHEN @venta > 0 THEN CAST(g.TotalGastos_ARS / @venta AS DECIMAL(18, 2)) ELSE 0.00 END AS [USD]
                    FOR XML PATH('Monto'), TYPE
                )
            FROM @TopGastos g
            FOR XML PATH('Gasto'), ROOT('Top5Gastos'), TYPE
        )
    FOR XML PATH('ReporteEconomico'), ROOT('Resultados');

END;
GO


EXEC consorcio.SP_reporte_4
    @FechaInicio = '2025-04-01',
    @FechaFin = '2025-06-30';
GO