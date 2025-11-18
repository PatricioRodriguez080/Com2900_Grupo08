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
Enunciado:        "06 - Testing de Procedimientos Almacenados"
================================================================================
*/

USE Com2900G08;
GO

--------------------------------------------------------------------------------
-- NUMERO: 1
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Muestra de tabla consorcio con datos cargados desde archivo maestro
--------------------------------------------------------------------------------
SELECT * FROM consorcio.consorcio;
GO

--------------------------------------------------------------------------------
-- NUMERO: 2
-- ARCHIVO: UF por consorcio.txt
-- PROCEDIMIENTO: Muestra de tablas unidad_funcional, baulera y cochera con datos cargados desde archivo maestro
--------------------------------------------------------------------------------
SELECT * FROM consorcio.unidad_funcional;
SELECT * FROM consorcio.baulera;
SELECT * FROM consorcio.cochera;
GO

--------------------------------------------------------------------------------
-- NUMERO: 3
-- ARCHIVO: inquilino-propietarios-UF.csv
-- PROCEDIMIENTO: Muestra de todos los datos cargados del archivo maestro
--------------------------------------------------------------------------------
SELECT
    uf.cuentaOrigen,
    c.nombre AS nombre_consorcio,
    uf.numeroUnidadFuncional,
    uf.piso,
    uf.departamento
FROM
    consorcio.unidad_funcional AS uf
JOIN
    consorcio.consorcio AS c ON uf.idConsorcio = c.idConsorcio;
GO

--------------------------------------------------------------------------------
-- NUMERO: 4
-- ARCHIVO: inquilino-propietarios-datos.csv
-- PROCEDIMIENTO: Muestra de tabla persona y persona_unidad_funcional con datos cargados desde archivo maestro
--------------------------------------------------------------------------------
SELECT * FROM consorcio.persona;
SELECT * FROM consorcio.persona_unidad_funcional;
GO

--------------------------------------------------------------------------------
-- NUMERO: 5
-- ARCHIVO: pagos_consorcios.csv
-- PROCEDIMIENTO: Muestra de tabla pago con datos cargados desde archivo maestro
--------------------------------------------------------------------------------
SELECT * FROM consorcio.pago;
GO

--------------------------------------------------------------------------------
-- NUMERO: 6
-- ARCHIVO: Servicios.Servicios.json
-- PROCEDIMIENTO: Importar expensas y gastos
-- CONSIDERACIONES: Muestra de tablas expensa, gasto y gasto_ordinario con datos cargados desde archivo maestro
--------------------------------------------------------------------------------
SELECT * FROM consorcio.expensa;
SELECT * FROM consorcio.gasto;
SELECT * FROM consorcio.gasto_ordinario;
GO

--------------------------------------------------------------------------------
-- NUMERO: 7
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Muestra de tabla proveedor con datos cargados desde archivo maestro
--------------------------------------------------------------------------------
SELECT * FROM consorcio.proveedor
GO

--------------------------------------------------------------------------------
-- NUMERO: 8
-- ARCHIVO: -
-- PROCEDIMIENTO: Muestra la actualizacion de tabla gasto_ordinario con los datos de los proveedores previamente cargados
--------------------------------------------------------------------------------
SELECT 
    gasOrd.*, 
    e.idConsorcio
FROM 
    consorcio.gasto_ordinario AS gasOrd
INNER JOIN 
    consorcio.gasto AS g ON gasOrd.idGasto = g.idGasto
INNER JOIN 
    consorcio.expensa AS e ON g.idExpensa = e.idExpensa
ORDER BY 
    gasOrd.idGastoOrd;
GO

--------------------------------------------------------------------------------
-- NUMERO: 9
-- ARCHIVO: -
-- PROCEDIMIENTO: Muestra la de tabla gasto_extraOrdinario con los datos cargados mediante el sp
--------------------------------------------------------------------------------
SELECT
    E.idExpensa,
    C.nombre AS Consorcio,
    E.periodo,
    GXO.nroCuota,
    GXO.totalCuotas,
    GXO.nomEmpresa,
    GXO.nroFactura,
    GXO.importe AS ImporteCuota,
    GXO.descripcion,
    G.subTotalExtraOrd AS TotalExtraordinarioGasto
FROM
    consorcio.gasto_extra_ordinario GXO
INNER JOIN
    consorcio.gasto G ON GXO.idGasto = G.idGasto
INNER JOIN
    consorcio.expensa E ON G.idExpensa = E.idExpensa
INNER JOIN
    consorcio.consorcio C ON E.idConsorcio = C.idConsorcio
WHERE
    E.periodo = 'junio' AND E.anio = 2025;
GO

--------------------------------------------------------------------------------
-- NUMERO: 10
-- ARCHIVO: -
-- PROCEDIMIENTO: Muestra de la tabla detalle_expensa con los datos relacionados de Abril, Mayo y Junio
--------------------------------------------------------------------------------
SELECT * FROM consorcio.detalle_expensa

--------------------------------------------------------------------------------
-- NUMERO: 11
-- ARCHIVO: -
-- PROCEDIMIENTO: Muestra de la tabla estado_financiero con los datos relacionados de Abril, Mayo y Junio
--------------------------------------------------------------------------------
SELECT * FROM consorcio.estado_financiero;
GO

--------------------------------------------------------------------------------
-- NUMERO: 12
-- ARCHIVO: -
-- PROCEDIMIENTO: Muestra de expensa generada posterior a los ultimos pagos recibidos de Junio
--------------------------------------------------------------------------------
SELECT
    UF.idUnidadFuncional AS [Uf],
    CAST(UF.coeficiente AS VARCHAR(5)) AS [%],
    UF.piso + '- ' + UF.departamento AS [Piso-Depto.],
    P.nombre + ' ' + P.apellido AS [Propietario],
    DE.saldoAnterior AS [Saldo anterior],
    DE.pagoRecibido AS [Pagos recibidos],
    DE.deuda AS [Deuda],
    DE.interesPorMora AS [Interés por mora],
    DE.expensasOrdinarias AS [Expensas ordinarias],
    COALESCE(C.TotalCocheras, 0.00) * 50000.00 AS [Cocheras],
    DE.expensasExtraordinarias AS [Expensas extraordinarias],
    DE.totalAPagar AS [Total a Pagar]
FROM
    consorcio.detalle_expensa AS DE
INNER JOIN
    consorcio.unidad_funcional AS UF ON DE.idUnidadFuncional = UF.idUnidadFuncional
INNER JOIN
    consorcio.persona_unidad_funcional AS PUF ON UF.idUnidadFuncional = PUF.idUnidadFuncional AND PUF.rol = 'propietario'
INNER JOIN
    consorcio.persona AS P ON PUF.idPersona = P.idPersona
LEFT JOIN (
    -- Subconsulta para contar el número de cocheras por Unidad Funcional
    SELECT 
        idUnidadFuncional,
        COUNT(idCochera) AS TotalCocheras
    FROM 
        consorcio.cochera
    GROUP BY 
        idUnidadFuncional
) AS C ON UF.idUnidadFuncional = C.idUnidadFuncional
WHERE
    DE.fechaEmision = '2025-07-05' 
ORDER BY
    UF.idUnidadFuncional;