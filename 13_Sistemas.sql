----------------------------------------------------------------------------------------------------------------------------
----------------------								                Acciones                                              --
----------------------------------------------------------------------------------------------------------------------------
-- 	     Rol	    -- Actualización de datos de UF  --  Importación de información bancaria  --  Generación de reportes  --
----------------------------------------------------------------------------------------------------------------------------
--     Sistemas     --             No                --                 No                    --            Si            --
----------------------------------------------------------------------------------------------------------------------------

-- USUARIOS SISTEMAS :
-- * Alan 
-- * Bruno

USE Com2900G08
GO
PRINT '--- PRUEBAS: Sistemas (user_alan_sys) ---';
EXECUTE AS LOGIN = 'login_alan_sys';

-- PRUEBA DE ÉXITO: Ejecución de reporte_5
-- Resultado Esperado: Reporte generado con éxito
EXEC consorcio.SP_reporte_5;
GO

-- PRUEBA DE FALLO: Intentar leer la tabla gasto
-- Resultado Esperado: ERROR (Msg 229: The SELECT permission was denied...)
SELECT * FROM gasto;

CORRECTO