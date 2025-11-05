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


CREATE NONCLUSTERED INDEX IDX_expensa_filtro_periodo
ON consorcio.expensa (idConsorcio, anio, periodo)
INCLUDE (idExpensa);
GO


CREATE NONCLUSTERED INDEX IDX_detalleExpensa_expensa_montos
ON consorcio.detalle_expensa (idExpensa, idDetalleExpensa)
INCLUDE (totalAPagar, expensasOrdinarias, expensasExtraordinarias, interesPorMora, idUnidadFuncional);
GO


CREATE NONCLUSTERED INDEX IDX_pago_detalleExpensa_fecha
ON consorcio.pago (idDetalleExpensa, fecha)
INCLUDE (importe);
GO


CREATE NONCLUSTERED INDEX IDX_pago_cuenta_fecha
ON consorcio.pago (cuentaOrigen, fecha)
INCLUDE (importe);
GO


CREATE NONCLUSTERED INDEX IDX_expensa_periodo_id
ON consorcio.expensa (anio, periodo)
INCLUDE (idExpensa);
GO


CREATE NONCLUSTERED INDEX IDX_puf_rol_uf_persona
ON consorcio.persona_unidad_funcional (rol, idUnidadFuncional)
INCLUDE (idPersona);
GO


CREATE NONCLUSTERED INDEX IDX_detalleExpensa_uf_deuda
ON consorcio.detalle_expensa (idUnidadFuncional)
INCLUDE (deuda);
GO


CREATE NONCLUSTERED INDEX IDX_persona_salida
ON consorcio.persona (idPersona)
INCLUDE (nombre, apellido, dni, email, telefono);
GO


CREATE NONCLUSTERED INDEX IDX_uf_consorcio_output
ON consorcio.unidad_funcional (idConsorcio, idUnidadFuncional)
INCLUDE (piso, departamento);
GO