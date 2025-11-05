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
Enunciado:        "05 - Ejecución de Procedimientos Almacenados"
================================================================================
*/
-- Todos los archivos utilizados se encontrarán en "C:\Archivos para el TP" ----
--------------------------------------------------------------------------------
-- NUMERO: 1
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Importar consorcios
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_consorcios_excel @path = 'C:\Archivos para el TP\datos varios.xlsx';
GO

SELECT * FROM consorcio.consorcio;
GO

--------------------------------------------------------------------------------
-- NUMERO: 2
-- ARCHIVO: UF por consorcio.txt
-- PROCEDIMIENTO: Importar unidades funcionales, cocheras y bauleras
-- CONSIDERACIONES: Sin cuenta origen asociada (se carga en el siguiente)
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_unidades_funcionales @path = 'C:\Archivos para el TP\UF por consorcio.txt';
GO

SELECT * FROM consorcio.unidad_funcional;
SELECT * FROM consorcio.baulera;
SELECT * FROM consorcio.cochera;
GO

--------------------------------------------------------------------------------
-- NUMERO: 3
-- ARCHIVO: inquilino-propietarios-UF.csv
-- PROCEDIMIENTO: Importar cuentas origen para las UF ya creadas
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_unidades_funcionales_csv @path = 'C:\Archivos para el TP\Inquilino-propietarios-UF.csv';
GO

SELECT * FROM consorcio.unidad_funcional;
GO

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
-- PROCEDIMIENTO: Importar personas y su relacion con las unidades funcionales (persona_unidad_funcional)
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_personas @path = 'C:\Archivos para el TP\Inquilino-propietarios-datos.csv';
GO

SELECT * FROM consorcio.persona;
SELECT * FROM consorcio.persona_unidad_funcional;
GO

--------------------------------------------------------------------------------
-- NUMERO: 5
-- ARCHIVO: pagos_consorcios.csv
-- PROCEDIMIENTO: Importar pagos
--------------------------------------------------------------------------------
EXEC consorcio.SP_carga_pagos @path = 'C:\Archivos para el TP\pagos_consorcios.csv';
GO

SELECT * FROM consorcio.pago;
GO

--------------------------------------------------------------------------------
-- NUMERO: 6
-- ARCHIVO: Servicios.Servicios.json
-- PROCEDIMIENTO: Importar expensas y gastos
-- CONSIDERACIONES: Gasto ordinario es creado sin los datos de la empresa (son cargados en el numero 8)
--------------------------------------------------------------------------------
EXEC consorcio.SP_carga_expensas @path = 'C:\Archivos para el TP\Servicios.Servicios.json'
GO

SELECT * FROM consorcio.expensa;
SELECT * FROM consorcio.gasto;
SELECT * FROM consorcio.gasto_ordinario;
GO

--------------------------------------------------------------------------------
-- NUMERO: 7
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Importar Proveedores
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_proveedores_excel @path = 'C:\Archivos para el TP\datos varios.xlsx';
GO

SELECT * FROM consorcio.proveedor
GO

--------------------------------------------------------------------------------
-- NUMERO: 8
-- ARCHIVO: -
-- PROCEDIMIENTO: Actualizacion de tabla gasto_ordinario con los datos de los proveedores
--------------------------------------------------------------------------------
EXEC consorcio.sp_procesa_actualizacion_gastos;
GO

SELECT * FROM consorcio.gasto_ordinario;
GO

SELECT 
    go.*, 
    e.idConsorcio
FROM 
    consorcio.gasto_ordinario AS go
INNER JOIN 
    consorcio.gasto AS g ON go.idGasto = g.idGasto
INNER JOIN 
    consorcio.expensa AS e ON g.idExpensa = e.idExpensa
ORDER BY 
    go.idGastoOrd;
GO

--------------------------------------------------------------------------------
-- NUMERO: 9
-- ARCHIVO: -
-- PROCEDIMIENTO: Actualizacion de tabla gasto_extraOrdinario
--------------------------------------------------------------------------------
EXEC consorcio.sp_crearGastosExtraordinariosJunio;
GO

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
-- PROCEDIMIENTO: Generar detalles de expensas de Abril, Mayo y Junio
--------------------------------------------------------------------------------
-- Abril
EXEC consorcio.sp_OrquestarFlujoParaTodosLosConsorcios 
    @periodoExpensa = 'abril', 
    @anioExpensa = 2025,
    @fechaEmision = '2025-05-05',
    @fechaPrimerVenc = '2025-05-10',
    @fechaSegundoVenc = '2025-05-25';
GO

--Mayo
EXEC consorcio.sp_OrquestarFlujoParaTodosLosConsorcios 
    @periodoExpensa = 'mayo', 
    @anioExpensa = 2025,
    @fechaEmision = '2025-06-05',
    @fechaPrimerVenc = '2025-06-10',
    @fechaSegundoVenc = '2025-06-25';
GO

--Junio
EXEC consorcio.sp_OrquestarFlujoParaTodosLosConsorcios 
    @periodoExpensa = 'junio', 
    @anioExpensa = 2025,
    @fechaEmision = '2025-07-05',
    @fechaPrimerVenc = '2025-07-10',
    @fechaSegundoVenc = '2025-07-25';
GO

SELECT * FROM consorcio.detalle_expensa
SELECT * FROM consorcio.pago
GO

--------------------------------------------------------------------------------
-- NUMERO: 11
-- ARCHIVO: -
-- PROCEDIMIENTO: Insercion de datos a la tabla estado_financiero
--------------------------------------------------------------------------------
EXEC consorcio.SP_cargar_estado_financiero;
GO

SELECT * FROM consorcio.estado_financiero;
GO

--------------------------------------------------------------------------------
-- NUMERO: 12
-- ARCHIVO: -
-- PROCEDIMIENTO: Modificacion de tablas para cifrado de datos sensibles
--------------------------------------------------------------------------------
EXEC consorcio.SP_migrarEsquemaACifradoReversible 
    @FraseClave = 'Migradoantihackers';
GO

--------------------------------------------------------------------------------
-- NUMERO: 13
-- ARCHIVO: -
-- PROCEDIMIENTO: Modificacion de tablas para descifrado de datos sensibles
--------------------------------------------------------------------------------
EXEC consorcio.SP_revertirEsquemaADatosClaros
    @FraseClave = 'Migradoantihackers';
