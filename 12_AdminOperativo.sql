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
Enunciado:        "12 - Pruebas Administativos Operativos"
================================================================================
*/

----------------------------------------------------------------------------------------------------------------------------
----------------------								                Acciones                                              --
----------------------------------------------------------------------------------------------------------------------------
-- 	     Rol	    -- Actualización de datos de UF  --  Importación de información bancaria  --  Generación de reportes  --
----------------------------------------------------------------------------------------------------------------------------
--  Admin Operativo --             Si                --                 No                    --            Si            --
----------------------------------------------------------------------------------------------------------------------------

-- USUARIOS ADMINISTRATIVO OPERATIVO  :
-- * Camila 
-- * Pilar
-- * Sofia

USE Com2900G08
GO
PRINT '--- PRUEBAS: Administrativo operativo (user_camila) ---';
EXECUTE AS LOGIN = 'login_camila';

-- PRUEBA DE ÉXITO: Actualización del coeficiente de la UF id = 1
-- Resultado Esperado: 1 fila afectada
BEGIN TRANSACTION;
UPDATE consorcio.unidad_funcional
SET coeficiente = 0.47 
WHERE idUnidadFuncional = 1;
ROLLBACK TRANSACTION;
GO


-- PRUEBA DE ÉXITO: Ejecución de reporte_4
-- Resultado Esperado: Reporte generado con éxito
EXEC consorcio.SP_reporte_4
    @idConsorcio = 1,
    @FechaInicio = '2025-04-01',
    @FechaFin = '2025-06-30';
GO


-- PRUEBA DE FALLO: Intentar INSERT en la tabla 'pago' (Tarea de Admin Bancario)
-- Resultado Esperado: ERROR (Msg 229: The INSERT permission was denied...)
INSERT INTO consorcio.pago (idPago, fecha, cuentaOrigen, importe, estaAsociado)
VALUES (999002, GETDATE(), '3333333333333333333333', 500.00, 0);