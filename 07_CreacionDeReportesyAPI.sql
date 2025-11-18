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
Enunciado:        "07 - Creación de Reportes y APIs"
================================================================================
*/

USE Com2900G08;
GO

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
-- REPORTE 1
-- Flujo de caja en forma semanal
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_reporte_1
    @idConsorcio INT,
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        WITH PagosProrrateados AS (
            SELECT
                p.fecha,
                CASE 
                    WHEN ISNULL(de.totalAPagar, 0) <= 0 THEN p.importe 
                    ELSE p.importe * (ISNULL(de.expensasOrdinarias, 0) / de.totalAPagar) 
                END AS PagoOrdinario,
                CASE 
                    WHEN ISNULL(de.totalAPagar, 0) <= 0 THEN 0.00
                    ELSE p.importe * (ISNULL(de.expensasExtraordinarias, 0) / de.totalAPagar) 
                END AS PagoExtraordinario
            FROM
                consorcio.pago p
            JOIN
                consorcio.detalle_expensa de ON p.idDetalleExpensa = de.idDetalleExpensa
            JOIN
                consorcio.expensa e ON de.idExpensa = e.idExpensa
            WHERE
                e.idConsorcio = @idConsorcio
                AND p.fecha BETWEEN @FechaInicio AND @FechaFin
                AND p.idDetalleExpensa IS NOT NULL 
        ),
        
        --Agrupar por semana
        RecaudacionSemanal AS (
            SELECT
                DATEPART(year, pp.fecha) AS Anio,
                DATEPART(week, pp.fecha) AS Semana,
                SUM(pp.PagoOrdinario) AS RecaudadoOrdinario,
                SUM(pp.PagoExtraordinario) AS RecaudadoExtraordinario,
                SUM(pp.PagoOrdinario + pp.PagoExtraordinario) AS TotalSemanal
            FROM
                PagosProrrateados pp
            GROUP BY
                DATEPART(year, pp.fecha),
                DATEPART(week, pp.fecha)
        )

        SELECT
            s.Anio,
            s.Semana,
            CAST(s.RecaudadoOrdinario AS DECIMAL(12, 2)) AS RecaudadoOrdinario,
            CAST(s.RecaudadoExtraordinario AS DECIMAL(12, 2)) AS RecaudadoExtraordinario,
            CAST(s.TotalSemanal AS DECIMAL(12, 2)) AS TotalSemanal,
            
            CAST(AVG(s.TotalSemanal) OVER () AS DECIMAL(12, 2)) AS PromedioPeriodo,
            
            CAST(SUM(s.TotalSemanal) OVER (ORDER BY s.Anio, s.Semana ROWS UNBOUNDED PRECEDING) AS DECIMAL(12, 2)) AS AcumuladoProgresivo
        FROM
            RecaudacionSemanal s
        ORDER BY
            s.Anio, s.Semana;

    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE(), @ErrNo INT = ERROR_NUMBER();
        RAISERROR('Error al generar Reporte 1 (Flujo Semanal): (Err %d) %s', 16, 1, @ErrNo, @ErrMsg);
    END CATCH
END;
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


--------------------------------------------------------------------------------
-- REPORTE 3
-- Presente un cuadro cruzado con la recaudación total desagregada según su procedencia
-- (ordinario, extraordinario, etc.) según el periodo.
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_reporte_3
    @idConsorcio INT,
    @Anio INT,
    @PeriodoInicio VARCHAR(12),
    @PeriodoFin VARCHAR(12)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar y convertir periodos a numero
    DECLARE @mesInicio INT = CASE LOWER(LTRIM(RTRIM(@PeriodoInicio)))
        WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3 WHEN 'abril' THEN 4
        WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6 WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8
        WHEN 'septiembre' THEN 9 WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
        ELSE NULL END;
    DECLARE @mesFin INT = CASE LOWER(LTRIM(RTRIM(@PeriodoFin)))
        WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3 WHEN 'abril' THEN 4
        WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6 WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8
        WHEN 'septiembre' THEN 9 WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
        ELSE NULL END;

    IF @mesInicio IS NULL OR @mesFin IS NULL
    BEGIN
        RAISERROR('Períodos inválidos.', 16, 1);
        RETURN -10;
    END
    
    DECLARE @ColumnList NVARCHAR(MAX);
    
    WITH PeriodosDistintos AS (
        SELECT DISTINCT 
            QUOTENAME(CAST(e.anio AS VARCHAR(4)) + '-' + e.periodo) AS ColumnaPeriodo,
            CASE LOWER(e.periodo)
                WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3 WHEN 'abril' THEN 4
                WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6 WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8
                WHEN 'septiembre' THEN 9 WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
            END AS MesOrden
        FROM consorcio.expensa e
        WHERE e.idConsorcio = @idConsorcio
          AND e.anio = @Anio
          AND CASE LOWER(e.periodo)
                WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3 WHEN 'abril' THEN 4
                WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6 WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8
                WHEN 'septiembre' THEN 9 WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
              END BETWEEN @mesInicio AND @mesFin
    )
    SELECT @ColumnList = STRING_AGG(pd.ColumnaPeriodo, ',') WITHIN GROUP (ORDER BY pd.MesOrden)
    FROM PeriodosDistintos pd;
              
    IF @ColumnList IS NULL
    BEGIN
        RAISERROR('No hay datos de expensas para el período seleccionado.', 16, 1);
        RETURN -11;
    END

    -- Crear la consulta
    DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = N'
    -- 1. CTE para obtener y des-pivotear los datos base
    WITH BaseData AS (
        SELECT 
            CAST(e.anio AS VARCHAR(4)) + ''-'' + e.periodo AS Periodo,
            T.TipoIngreso,
            T.Importe
        FROM consorcio.detalle_expensa de
        JOIN consorcio.expensa e ON de.idExpensa = e.idExpensa
        -- UNPIVOT: Convertimos columnas (Ordinarias, Extra, Interes) en filas
        CROSS APPLY (
            VALUES (''1_ExpensasOrdinarias'', de.expensasOrdinarias),
                   (''2_ExpensasExtraordinarias'', de.expensasExtraordinarias),
                   (''3_InteresPorMora'', de.interesPorMora)
        ) AS T(TipoIngreso, Importe)
        WHERE 
            e.idConsorcio = @idConsorcioParam
            AND e.anio = @anioParam
            -- Volvemos a aplicar el filtro de mes dentro de la consulta dinámica
            AND CASE LOWER(e.periodo)
                  WHEN ''enero'' THEN 1 WHEN ''febrero'' THEN 2 WHEN ''marzo'' THEN 3 WHEN ''abril'' THEN 4
                  WHEN ''mayo'' THEN 5 WHEN ''junio'' THEN 6 WHEN ''julio'' THEN 7 WHEN ''agosto'' THEN 8
                  WHEN ''septiembre'' THEN 9 WHEN ''octubre'' THEN 10 WHEN ''noviembre'' THEN 11 WHEN ''diciembre'' THEN 12
                END BETWEEN @mesInicioParam AND @mesFinParam
    )
    -- 2. Pivotar los datos
    SELECT 
        TipoIngreso,
        ' + @ColumnList + '
    FROM BaseData
    PIVOT (
        SUM(Importe) -- Agregamos los importes
        FOR Periodo IN (' + @ColumnList + ') -- Convertimos los períodos en columnas
    ) AS PivotTable
    ORDER BY TipoIngreso;
    ';

    EXEC sp_executesql @SQL,
        N'@idConsorcioParam INT, @anioParam INT, @mesInicioParam INT, @mesFinParam INT',
        @idConsorcioParam = @idConsorcio,
        @anioParam = @Anio,
        @mesInicioParam = @mesInicio,
        @mesFinParam = @mesFin;

END;
GO

--------------------------------------------------------------------------------
-- REPORTE 4
-- Obtener los 5 (cinco) meses de mayores gastos y los 5 (cinco) de mayores ingresos
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_reporte_4
    @idConsorcio INT,
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

    INSERT INTO @TopGastos (Anio, Mes, TotalGastos_ARS)
    SELECT TOP 5
        e.anio,
        e.periodo,
        SUM(g.subTotalOrdinarios + g.subTotalExtraOrd)
    FROM consorcio.gasto AS g 
    JOIN consorcio.expensa AS e ON g.idExpensa = e.idExpensa
    WHERE 
        e.idConsorcio = @idConsorcio
        AND DATEFROMPARTS(e.anio, 
        CASE e.periodo
            WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3 WHEN 'abril' THEN 4 
            WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6 WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 
            WHEN 'septiembre' THEN 9 WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12 
        END, 1) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY e.anio, e.periodo
    ORDER BY SUM(g.subTotalOrdinarios + g.subTotalExtraOrd) DESC;

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


--------------------------------------------------------------------------------
-- REPORTE 5
-- Obtenga los 3 (tres) propietarios con mayor morosidad. 
-- Filtros: Consorcio (Opcional) y Piso (Opcional).
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_reporte_5
    @idConsorcio INT = NULL,
    @Piso INT = NULL                       
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 3
        p.nombre,
        p.apellido,
        p.dni,
        p.email,
        p.telefono,
        SUM(de.deuda) AS Deuda_Total
    FROM
        consorcio.persona p
    JOIN
        consorcio.persona_unidad_funcional puf ON p.idPersona = puf.idPersona
    JOIN
        consorcio.unidad_funcional uf ON puf.idUnidadFuncional = uf.idUnidadFuncional
    JOIN
        consorcio.detalle_expensa de ON uf.idUnidadFuncional = de.idUnidadFuncional
    JOIN
        consorcio.expensa e ON de.idExpensa = e.idExpensa 
    WHERE
        puf.rol = 'propietario' 
        AND de.deuda > 0
        AND (@idConsorcio IS NULL OR e.idConsorcio = @idConsorcio) 
        AND (@Piso IS NULL OR uf.piso = @Piso)
        
    GROUP BY
        p.idPersona,
        p.nombre,
        p.apellido,
        p.dni,
        p.email,
        p.telefono
    ORDER BY
        Deuda_Total DESC;
END
GO


--------------------------------------------------------------------------------
-- REPORTE 6
-- Fechas de pagos de expensas ordinarias de cada UF y la cantidad de días que
-- pasan entre un pago y el siguiente, para el conjunto examinado
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.SP_reporte_6
    @idConsorcio INT,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    WITH PagosOrdenados AS (
        SELECT
            c.nombre AS Consorcio,
            uf.piso,
            uf.departamento,
            p.fecha AS FechaPago,
            LAG(p.fecha, 1, NULL) OVER (PARTITION BY uf.idUnidadFuncional ORDER BY p.fecha) AS FechaPagoAnterior
        FROM
            consorcio.pago AS p JOIN consorcio.detalle_expensa AS de ON p.idDetalleExpensa = de.idDetalleExpensa
            JOIN consorcio.unidad_funcional AS uf ON de.idUnidadFuncional = uf.idUnidadFuncional
            JOIN consorcio.consorcio AS c ON uf.idConsorcio = c.idConsorcio
        WHERE
            c.idConsorcio = @idConsorcio
            AND de.expensasOrdinarias > 0
            AND (@FechaDesde IS NULL OR p.fecha >= @FechaDesde)
            AND (@FechaHasta IS NULL OR p.fecha <= @FechaHasta)
    )
    SELECT
        Consorcio,
        piso,
        departamento,
        FechaPagoAnterior,
        FechaPago AS FechaPagoSiguiente,
        
        DATEDIFF(DAY, FechaPagoAnterior, FechaPago) AS DiasEntrePagos
    FROM
        PagosOrdenados
    ORDER BY
        piso, 
        departamento, 
        FechaPagoSiguiente;

END;
GO