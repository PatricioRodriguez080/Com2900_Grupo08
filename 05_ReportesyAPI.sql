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

    ;WITH PagosPivot AS (
        SELECT
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
    SELECT
        Mes AS [@nombre],
        (
            SELECT
                Departamento.nombre AS [Departamento/@nombre],
                Departamento.Monto AS [Departamento/Monto]
            FROM (
                SELECT 'A' AS nombre, A AS Monto
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

SELECT
    c.nombre AS NombreConsorcio,
    uf.departamento AS Departamento,
    SUM(p.importe) AS TotalRecaudado
FROM
    consorcio.unidad_funcional AS uf JOIN consorcio.consorcio AS c ON uf.idConsorcio = c.idConsorcio
    JOIN consorcio.pago AS p ON p.cuentaOrigen = uf.cuentaOrigen
WHERE
    uf.departamento = 'A'
    AND c.idConsorcio = 1
    AND UF.piso='2'
GROUP BY
    c.nombre,
    uf.departamento;


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
        PRINT 'Error: La fecha de fin no puede ser anterior a la fecha de inicio.';
        RETURN;
    END

    -- TOP 5 MESES CON MAS INGRESOS
    SELECT TOP 5
        YEAR(p.fecha) AS Anio,
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
        END AS Mes,
        SUM(p.importe) AS TotalIngresos
    FROM
        consorcio.pago AS p JOIN consorcio.unidad_funcional AS uf ON p.cuentaOrigen = uf.cuentaOrigen
    WHERE
        p.fecha BETWEEN @FechaInicio AND @FechaFin
    GROUP BY
        YEAR(p.fecha), MONTH(p.fecha)
    ORDER BY
        TotalIngresos DESC;


    -- TOP 5 MESES CON MAS GASTOS
    SELECT TOP 5
        e.anio AS Anio,
        e.periodo AS Mes,
        SUM(g.subTotalOrdinarios + g.subTotalExtraOrd) AS TotalGastos
    FROM
        consorcio.gasto AS g JOIN consorcio.expensa AS e ON g.idExpensa = e.idExpensa
    WHERE
        DATEFROMPARTS(e.anio,
            CASE e.periodo
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
            END,
        1) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY
        e.anio, e.periodo
    ORDER BY
        TotalGastos DESC;
END;
GO

EXEC consorcio.SP_reporte_4
    @FechaInicio = '2025-04-01',
    @FechaFin = '2025-06-30';
GO