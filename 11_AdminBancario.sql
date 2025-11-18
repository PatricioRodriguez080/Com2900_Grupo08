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
Enunciado:        "11 - Pruebas Administativos Bancarios"
================================================================================
*/

----------------------------------------------------------------------------------------------------------------------------
----------------------								                Acciones                                              --
----------------------------------------------------------------------------------------------------------------------------
-- 	     Rol	    -- Actualización de datos de UF  --  Importación de información bancaria  --  Generación de reportes  --
----------------------------------------------------------------------------------------------------------------------------
--  Admin Bancario  --             No                --                 Si                    --            Si            --
----------------------------------------------------------------------------------------------------------------------------

-- USUARIOS ADMINISTRATIVO BANCARIO :
-- * Axel 
-- * Maria
-- * Martina

USE Com2900G08
GO
PRINT '--- PRUEBAS: Administrativo Bancario (user_axel) ---';
EXECUTE AS LOGIN = 'login_axel';
GO


-- PRUEBA DE ÉXITO: Importar pagos
-- Resultado Esperado: 1 fila afectada
BEGIN TRANSACTION
INSERT INTO consorcio.pago 
    (idPago, fecha, cuentaOrigen, importe, estaAsociado, idDetalleExpensa)
VALUES 
    (
        999991,
        GETDATE(),
        '1234567890123456789012',
        15500.50,   
        0,                           
        NULL                                        
    );
ROLLBACK TRANSACTION;
GO


-- PRUEBA DE ÉXITO: Ejecución de reporte_2
-- Resultado Esperado: Reporte generado con éxito
EXEC consorcio.SP_reporte_2
    @idConsorcio = 1,
    @Anio = 2025,
    @Piso = '2';
GO


-- PRUEBA DE FALLO: Intentar UPDATE en 'unidad_funcional' (Tarea de Admin General/Operativo)
-- Resultado Esperado: ERROR (Msg 229: The UPDATE permission was denied... y Msg 229: The SELECT permission was denied...)
UPDATE consorcio.unidad_funcional SET coeficiente = 0.10 WHERE idUnidadFuncional = 1;
