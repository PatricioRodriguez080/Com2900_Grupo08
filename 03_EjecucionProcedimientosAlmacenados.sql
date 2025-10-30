/*
---------------------------------------------------------------------------
Materia:         Bases de Datos Aplicadas
Comisión:        Com 01-2900
Grupo:           G08
Fecha de Entrega: 04/11/2025
Integrantes:
    Bentancur Suarez, Ismael 45823439
    Rodriguez Arrien, Juan Manuel 44259478
    Rodriguez, Patricio 45683229
    Ruiz, Leonel Emiliano 45537914
Enunciado:       "03 - Ejecución de Procedimientos Almacenados"
---------------------------------------------------------------------------
*/
USE Com2900G08
------------ Archivo datos varios.xlsx ------------------------------------
EXEC consorcio.SP_importar_consorcios_excel @path = 'C:\Archivos para el TP\datos varios.xlsx';

SELECT * FROM consorcio.consorcio;

------------ Archivo inquilino-propietarios-datos.csv ---------------------
EXEC consorcio.SP_importar_personas @path = 'C:\Archivos para el TP\Inquilino-propietarios-datos.csv';

SELECT * FROM consorcio.persona;

------------ Archivo UF por consorcio.txt ------------------------------------
EXEC consorcio.SP_importar_unidades_funcionales @path = 'C:\Archivos para el TP\UF por consorcio.txt';

SELECT * FROM consorcio.unidad_funcional;
SELECT * FROM consorcio.baulera;
SELECT * FROM consorcio.cochera;

------------ Archivo inquilino-propietarios-UF.csv ------------------------
EXEC consorcio.SP_importar_unidades_funcionales_csv @path = 'C:\Archivos para el TP\Inquilino-propietarios-UF.csv';

SELECT * FROM consorcio.unidad_funcional;

------------ Archivo pagos_consorcios.csv ---------------------------------
EXEC consorcio.SP_carga_pagos @path = 'C:\Archivos para el TP\pagos_consorcios.csv';

SELECT * FROM consorcio.pago;