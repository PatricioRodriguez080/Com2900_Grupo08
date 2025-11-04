/*
================================================================================
Materia:         Bases de Datos Aplicadas
Comisión:        Com 01-2900
Grupo:           G08
Fecha de Entrega: 25/10/2025
Integrantes:
    Bentancur Suarez, Ismael 45823439
    Rodriguez Arrien, Juan Manuel 44259478
    Rodriguez, Patricio 45683229
    Ruiz, Leonel Emiliano 45537914
Enunciado:       "00 - Creación de Base de Datos"
================================================================================
*/

IF DB_ID('Com2900G08') IS NOT NULL
BEGIN
    USE tempdb;
	ALTER DATABASE Com2900G08 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE Com2900G08;
END
GO

CREATE DATABASE Com2900G08;
GO

USE Com2900G08;
GO