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
Enunciado:        "08 - Ejecucion de Reportes"
================================================================================
*/

USE Com2900G08;
GO

--------------------------------------------------------------------------------
-- REPORTE 1
-- Flujo de caja en forma semanal
--------------------------------------------------------------------------------
EXEC consorcio.SP_reporte_1
    @idConsorcio = 1,
    @FechaInicio = '2025-05-01',
    @FechaFin = '2025-05-31';
GO

--------------------------------------------------------------------------------
-- REPORTE 2
-- Total de recaudación por mes y departamento en formato de tabla cruzada
--------------------------------------------------------------------------------
EXEC consorcio.SP_reporte_2
    @idConsorcio = 1,
    @Anio = 2025,
    @Piso='2';

--------------------------------------------------------------------------------
-- REPORTE 3
-- Presente un cuadro cruzado con la recaudación total desagregada según su procedencia
-- (ordinario, extraordinario, etc.) según el periodo.
--------------------------------------------------------------------------------
EXEC consorcio.SP_reporte_3
    @idConsorcio = 1,
    @Anio = 2025,
    @PeriodoInicio = 'abril',
    @PeriodoFin = 'junio';
GO

--------------------------------------------------------------------------------
-- REPORTE 4
-- Obtener los 5 (cinco) meses de mayores gastos y los 5 (cinco) de mayores ingresos
--------------------------------------------------------------------------------
EXEC consorcio.SP_reporte_4
    @idConsorcio = 1,
    @FechaInicio = '2025-04-01',
    @FechaFin = '2025-06-30';
GO

--------------------------------------------------------------------------------
-- REPORTE 5
-- Obtenga los 3 (tres) propietarios con mayor morosidad. Presente información de contacto y DNI de los propietarios 
-- para que la administración los pueda contactar o remitir el trámite al estudio jurídico.
--------------------------------------------------------------------------------
EXEC consorcio.SP_reporte_5
    @idConsorcio = 5
GO

--------------------------------------------------------------------------------
-- REPORTE 6
-- Fechas de pagos de expensas ordinarias de cada UF y la cantidad de días que
-- pasan entre un pago y el siguiente, para el conjunto examinado
--------------------------------------------------------------------------------
EXEC consorcio.SP_reporte_6
    @idConsorcio = 1,
    @FechaDesde = '2025-04-01',
    @FechaHasta = '2025-04-30';
GO