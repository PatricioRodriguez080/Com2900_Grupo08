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
Enunciado:        "10 - Pruebas Administativos Generales"
================================================================================
*/

----------------------------------------------------------------------------------------------------------------------------
----------------------								                Acciones                                              --
----------------------------------------------------------------------------------------------------------------------------
-- 	     Rol	    -- Actualización de datos de UF  --  Importación de información bancaria  --  Generación de reportes  --
----------------------------------------------------------------------------------------------------------------------------
--   Admin General  --             Si                --                 No                    --            Si            --
----------------------------------------------------------------------------------------------------------------------------

-- USUARIOS ADMINISTRATIVO GENERAL :
-- * Lucas 
-- * Juan
-- * Pedro

USE Com2900G08
GO
PRINT '--- PRUEBAS: Administrativo general (user_lucas) ---';
EXECUTE AS LOGIN = 'login_lucas';
GO
SELECT SUSER_NAME();

-- PRUEBA DE ÉXITO: Actualización de Unidad Funcional (Tarea propia del rol)
-- Resultado Esperado: Una fila afectada (el cambio se revierte).
BEGIN TRANSACTION;
    UPDATE consorcio.unidad_funcional SET coeficiente = 0.50 WHERE idUnidadFuncional = 1;
ROLLBACK TRANSACTION;


-- PRUEBA DE ÉXITO: Ejecución de reportes
-- Resultado Esperado: reporte_1 generado con éxito
EXEC consorcio.SP_reporte_1
    @idConsorcio = 1,
    @FechaInicio = '2025-05-01',
    @FechaFin = '2025-05-31';
GO


-- PRUEBA DE FALLO: Intentar leer la tabla persona
-- Resultado Esperado: ERROR (Msg 229: The SELECT permission was denied...)
SELECT * FROM persona;