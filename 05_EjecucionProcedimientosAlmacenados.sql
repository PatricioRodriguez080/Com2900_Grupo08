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

USE Com2900G08;
GO

--------------------------------------------------------------------------------
-- NUMERO: 1
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Importar consorcios
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_consorcios_excel @path = 'C:\Archivos para el TP\datos varios.xlsx';
GO

--------------------------------------------------------------------------------
-- NUMERO: 2
-- ARCHIVO: UF por consorcio.txt
-- PROCEDIMIENTO: Importar unidades funcionales, cocheras y bauleras
-- CONSIDERACIONES: Sin cuenta origen asociada (se carga en el siguiente)
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_unidades_funcionales @path = 'C:\Archivos para el TP\UF por consorcio.txt';
GO

--------------------------------------------------------------------------------
-- NUMERO: 3
-- ARCHIVO: inquilino-propietarios-UF.csv
-- PROCEDIMIENTO: Importar cuentas origen para las UF ya creadas
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_unidades_funcionales_csv @path = 'C:\Archivos para el TP\Inquilino-propietarios-UF.csv';
GO

--------------------------------------------------------------------------------
-- NUMERO: 4
-- ARCHIVO: inquilino-propietarios-datos.csv
-- PROCEDIMIENTO: Importar personas y su relacion con las unidades funcionales (persona_unidad_funcional)
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_personas @path = 'C:\Archivos para el TP\Inquilino-propietarios-datos.csv';
GO

--------------------------------------------------------------------------------
-- NUMERO: 5
-- ARCHIVO: pagos_consorcios.csv
-- PROCEDIMIENTO: Importar pagos
--------------------------------------------------------------------------------
EXEC consorcio.SP_carga_pagos @path = 'C:\Archivos para el TP\pagos_consorcios.csv';
GO

--------------------------------------------------------------------------------
-- NUMERO: 6
-- ARCHIVO: Servicios.Servicios.json
-- PROCEDIMIENTO: Importar expensas y gastos
-- CONSIDERACIONES: Gasto ordinario es creado sin los datos de la empresa (son cargados en el numero 8)
--------------------------------------------------------------------------------
EXEC consorcio.SP_carga_expensas @path = 'C:\Archivos para el TP\Servicios.Servicios.json'
GO

--------------------------------------------------------------------------------
-- NUMERO: 7
-- ARCHIVO: datos varios.xlsx
-- PROCEDIMIENTO: Importar Proveedores
--------------------------------------------------------------------------------
EXEC consorcio.SP_importar_proveedores_excel @path = 'C:\Archivos para el TP\datos varios.xlsx';
GO

--------------------------------------------------------------------------------
-- NUMERO: 8
-- ARCHIVO: -
-- PROCEDIMIENTO: Actualizacion de tabla gasto_ordinario con los datos de los proveedores
--------------------------------------------------------------------------------
EXEC consorcio.sp_procesa_actualizacion_gastos;
GO

--------------------------------------------------------------------------------
-- NUMERO: 9
-- ARCHIVO: -
-- PROCEDIMIENTO: Actualizacion de tabla gasto_extraOrdinario
--------------------------------------------------------------------------------
EXEC consorcio.sp_crearGastosExtraordinariosJunio;
GO

--------------------------------------------------------------------------------
-- NUMERO: 10
-- ARCHIVO: -
-- PROCEDIMIENTO: Generar detalles de expensas de Abril, Mayo y Junio
--------------------------------------------------------------------------------
-- Abril
EXEC consorcio.sp_orquestarFlujoParaTodosLosConsorcios 
    @periodoExpensa = 'abril', 
    @anioExpensa = 2025,
    @fechaEmision = '2025-04-05',
    @fechaPrimerVenc = '2025-04-10',
    @fechaSegundoVenc = '2025-04-25';
GO

--Mayo
EXEC consorcio.sp_orquestarFlujoParaTodosLosConsorcios 
    @periodoExpensa = 'mayo', 
    @anioExpensa = 2025,
    @fechaEmision = '2025-05-05',
    @fechaPrimerVenc = '2025-05-10',
    @fechaSegundoVenc = '2025-05-25';
GO

--Junio
EXEC consorcio.sp_orquestarFlujoParaTodosLosConsorcios 
    @periodoExpensa = 'junio', 
    @anioExpensa = 2025,
    @fechaEmision = '2025-06-05',
    @fechaPrimerVenc = '2025-06-10',
    @fechaSegundoVenc = '2025-06-25';
GO

--------------------------------------------------------------------------------
-- NUMERO: 11
-- ARCHIVO: -
-- PROCEDIMIENTO: Insercion de datos a la tabla estado_financiero
--------------------------------------------------------------------------------
EXEC consorcio.SP_cargar_estado_financiero;
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