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
Enunciado:        "04 - Ejecución de Procedimientos Almacenados"
================================================================================
*/
-- Todos los archivos utilizados se encontrarán en "C:\Archivos para el TP" ----
--------------------------------------------------------------------------------
-- NUMERO: 1
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Importar consorcios
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_consorcios_excel @path = 'C:\Archivos para el TP\datos varios.xlsx';

SELECT * FROM consorcio.consorcio;

--------------------------------------------------------------------------------
-- NUMERO: 2
-- ARCHIVO: UF por consorcio.txt
-- PROCEDIMIENTO: Importar unidades funcionales, cocheras y bauleras
-- CONSIDERACIONES: Sin cuenta origen asociada (se carga en el siguiente)
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_unidades_funcionales @path = 'C:\Archivos para el TP\UF por consorcio.txt';

SELECT * FROM consorcio.unidad_funcional;
SELECT * FROM consorcio.baulera;
SELECT * FROM consorcio.cochera;

--------------------------------------------------------------------------------
-- NUMERO: 3
-- ARCHIVO: inquilino-propietarios-UF.csv
-- PROCEDIMIENTO: Importar cuentas origen para las UF ya creadas
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_unidades_funcionales_csv @path = 'C:\Archivos para el TP\Inquilino-propietarios-UF.csv';

SELECT * FROM consorcio.unidad_funcional;

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

--------------------------------------------------------------------------------
-- NUMERO: 4
-- ARCHIVO: inquilino-propietarios-datos.csv
-- PROCEDIMIENTO: Importar personas y su relacion con las unidades funcionales (persona_unidad_funcional)
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_personas @path = 'C:\Archivos para el TP\Inquilino-propietarios-datos.csv';

SELECT * FROM consorcio.persona;
SELECT * FROM consorcio.persona_unidad_funcional;

--------------------------------------------------------------------------------
-- NUMERO: 5
-- ARCHIVO: pagos_consorcios.csv
-- PROCEDIMIENTO: Importar pagos
--------------------------------------------------------------------------------
EXEC consorcio.SP_carga_pagos @path = 'C:\Archivos para el TP\pagos_consorcios.csv';

SELECT * FROM consorcio.pago;

--------------------------------------------------------------------------------
-- NUMERO: 6
-- ARCHIVO: Servicios.Servicios.json
-- PROCEDIMIENTO: Importar expensas y gastos
--------------------------------------------------------------------------------
EXEC consorcio.SP_carga_expensas @path = 'C:\Archivos para el TP\Servicios.Servicios.json'

SELECT * FROM consorcio.expensa;
SELECT * FROM consorcio.gasto;
SELECT * FROM consorcio.gasto_ordinario;

--------------------------------------------------------------------------------
-- NUMERO: 7
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Importar Proveedores
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_proveedores_excel @path = 'C:\Archivos para el TP\datos varios.xlsx';

SELECT * FROM consorcio.proveedor

--------------------------------------------------------------------------------
-- NUMERO: 8
-- ARCHIVO: -
-- PROCEDIMIENTO: Actualizacion de tabla gasto_ordinario con los datos de los proveedores
--------------------------------------------------------------------------------
EXEC consorcio.sp_procesa_actualizacion_gastos;

SELECT * FROM consorcio.gasto_ordinario;

SELECT 
    go.*, 
    e.idConsorcio  -- El campo clave para la depuración
FROM 
    consorcio.gasto_ordinario AS go
INNER JOIN 
    consorcio.gasto AS g ON go.idGasto = g.idGasto
INNER JOIN 
    consorcio.expensa AS e ON g.idExpensa = e.idExpensa
ORDER BY 
    go.idGastoOrd;
--------------------------------------------------------------------------------
-- NUMERO: 9
-- ARCHIVO: -
-- PROCEDIMIENTO: Insercion de datos a la tabla estado_financiero
--------------------------------------------------------------------------------
EXEC consorcio.SP_cargar_estado_financiero;

SELECT * FROM consorcio.estado_financiero;

--------------------------------------------------------------------------------
-- NUMERO: 10
-- ARCHIVO: -
-- PROCEDIMIENTO: Modificacion de tablas para cifrado de datos sensibles
--------------------------------------------------------------------------------
EXEC consorcio.SP_MigrarEsquemaACifradoReversible_Seguro 
    @FraseClave = 'Migradoantihackers';
GO

--------------------------------------------------------------------------------
-- NUMERO: 11
-- ARCHIVO: -
-- PROCEDIMIENTO: Modificacion de tablas para descifrado de datos sensibles
--------------------------------------------------------------------------------
EXEC consorcio.SP_RevertirEsquemaADatosClaros_Seguro 
    @FraseClave = 'Migradoantihackers';
