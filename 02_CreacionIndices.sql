/*
===============================================================================
Materia:          Bases de Datos Aplicadas
Comisión:         01-2900
Grupo:            G08
Fecha de Entrega: 04/11/2025
Integrantes:
    - Bentancur Suarez, Ismael (45823439)
    - Rodriguez Arrien, Juan Manuel (44259478)
    - Rodriguez, Patricio (45683229)
    - Ruiz, Leonel Emiliano (45537914)
Enunciado:        "02 - Creación de indices"
===============================================================================
*/

CREATE NONCLUSTERED INDEX IDX_unidad_funcional_filtro_consorcio_cuenta
ON consorcio.unidad_funcional (cuentaOrigen, idConsorcio, piso, departamento)
INCLUDE (idUnidadFuncional);
GO

CREATE NONCLUSTERED INDEX IDX_pago_fecha_importe
ON consorcio.pago (fecha DESC, cuentaOrigen)
INCLUDE (importe);
GO

CREATE NONCLUSTERED INDEX IDX_expensa_periodo_anio
ON consorcio.expensa (anio DESC, periodo);
GO

CREATE NONCLUSTERED INDEX IDX_gasto_expensa_monto
ON consorcio.gasto (idExpensa)
INCLUDE (subTotalOrdinarios, subTotalExtraOrd);
GO