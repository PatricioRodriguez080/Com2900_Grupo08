/*
-----------------------------------------------------------------
Materia:         Bases de Datos Aplicadas
Comisión:        Com 01-2900
Grupo:           G08
Fecha de Entrega: 04/11/2025
Integrantes:
    Bentancur Suarez, Ismael 45823439
    Rodriguez Arrien, Juan Manuel 44259478
    Rodriguez, Patricio 45683229
    Ruiz, Leonel Emiliano 45537914
Enunciado:       "01 - Creación de Tablas"
-----------------------------------------------------------------
*/


IF NOT EXISTS (SELECT * FROM  sys.schemas WHERE name = 'consorcio')
    EXEC('CREATE SCHEMA consorcio');
go

DROP TABLE IF EXISTS consorcio.gasto_extra_ordinario;
DROP TABLE IF EXISTS consorcio.gasto_ordinario;
DROP TABLE IF EXISTS consorcio.gasto;
DROP TABLE IF EXISTS consorcio.detalle_expensa;
DROP TABLE IF EXISTS consorcio.expensa;
DROP TABLE IF EXISTS consorcio.pago;
DROP TABLE IF EXISTS consorcio.persona_unidad_funcional;
DROP TABLE IF EXISTS consorcio.baulera;
DROP TABLE IF EXISTS consorcio.cochera;
DROP TABLE IF EXISTS consorcio.unidad_funcional;
DROP TABLE IF EXISTS consorcio.estado_financiero;
DROP TABLE IF EXISTS consorcio.persona;
DROP TABLE IF EXISTS consorcio.consorcio;
go

CREATE TABLE consorcio.consorcio (
	idConsorcio INT PRIMARY KEY NOT NULL,
	nombre VARCHAR(20),
	direccion VARCHAR(20) NOT NULL,
	cantidadUnidadesFuncionales INT NOT NULL,
	metrosCuadradosTotales INT NOT NULL,
    fechaBaja DATE NULL DEFAULT NULL,

	CONSTRAINT chk_unidadesFuncionales_min CHECK (cantidadUnidadesFuncionales > 0),
	CONSTRAINT chk_metrosCuadradosTotales_max CHECK (metrosCuadradosTotales > 0)
);

CREATE TABLE consorcio.estado_financiero (
	idEstadoFinanciero INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
	idConsorcio INT NOT NULL, 
	saldoAnterior DECIMAL(12,2),
	ingresosEnTermino DECIMAL(12,2),
	ingresosAdeudados DECIMAL(12,2),
	egresos DECIMAL(12,2),
	saldoCierre DECIMAL(12,2),
	periodo VARCHAR(12) NOT NULL,
    anio int NOT NULL,

	CONSTRAINT fk_estadoFinanciero_consorcio FOREIGN KEY (idConsorcio) REFERENCES consorcio.consorcio(idConsorcio),
	CONSTRAINT chk_estadoFinanciero_periodo CHECK (periodo IN('enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre')),
    CONSTRAINT uq_estadoFinanciero_unico UNIQUE (idConsorcio, periodo, anio)
);

CREATE TABLE consorcio.unidad_funcional (
	idUnidadFuncional INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
	idConsorcio INT NOT NULL,
	cuentaOrigen VARCHAR(22) NOT NULL,
	numeroUnidadFuncional INT NOT NULL,
	piso CHAR (2) NOT NULL,
    departamento CHAR (1) NOT NULL,
	coeficiente DECIMAL(5,2) NOT NULL,
	metrosCuadrados INT NOT NULL,
    fechaBaja DATE NULL DEFAULT NULL,

	CONSTRAINT fk_unidadFuncional_consorcio FOREIGN KEY (idConsorcio) REFERENCES consorcio.consorcio(idConsorcio),
	CONSTRAINT chk_unidadFuncional_cuentaOrigen CHECK (ISNUMERIC(cuentaOrigen) = 1),
	CONSTRAINT chk_coeficiente_max CHECK (coeficiente <= 100),
	CONSTRAINT chk_metrosCuadrados_max CHECK (metrosCuadrados > 0)
);

CREATE TABLE consorcio.cochera (
	idCochera INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
	idUnidadFuncional INT,
	metrosCuadrados INT NOT NULL,
	coeficiente DECIMAL(5,2) NOT NULL,

	CONSTRAINT fk_cochera_unidadFuncional FOREIGN KEY (idUnidadFuncional) REFERENCES consorcio.unidad_funcional(idUnidadFuncional),
	CONSTRAINT chk_cochera_coeficiente_max CHECK (coeficiente <= 100),
	CONSTRAINT chk_metrosCuadrados_min CHECK (metrosCuadrados > 0)
);

CREATE TABLE consorcio.baulera (
	idBaulera INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
	idUnidadFuncional INT,
	metrosCuadrados INT NOT NULL,
	coeficiente DECIMAL(5,2) NOT NULL,

	CONSTRAINT fk_baulera_unidadFuncional FOREIGN KEY (idUnidadFuncional) REFERENCES consorcio.unidad_funcional(idUnidadFuncional),
	CONSTRAINT chk_baulera_coeficiente_max CHECK (coeficiente <= 100),
	CONSTRAINT chk_metrosCuadrados_baulera_min CHECK (metrosCuadrados > 0)
);

CREATE TABLE consorcio.persona (
    idPersona int identity(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    dni int NOT NULL UNIQUE,
    email VARCHAR(100) NULL,
    telefono VARCHAR(20) NULL,
    cuentaOrigen CHAR(22) NOT NULL,
    fechaBaja DATE NULL DEFAULT NULL,

    CONSTRAINT chk_persona_cuentaOrigen CHECK (ISNUMERIC(cuentaOrigen) = 1)
);

CREATE TABLE consorcio.persona_unidad_funcional(
    idPersona int NOT NULL,
    idUnidadFuncional int NOT NULL,
    rol VARCHAR(15) NOT NULL,

    CONSTRAINT pk_personaUnidadFuncional PRIMARY KEY (idUnidadFuncional, rol),
    CONSTRAINT fk_idPersona FOREIGN KEY (idPersona) REFERENCES consorcio.persona (idPersona),
    CONSTRAINT fk_idUnidadFuncional FOREIGN KEY (idUnidadFuncional) REFERENCES consorcio.unidad_funcional (idUnidadFuncional),
    CONSTRAINT chk_rol CHECK (rol IN ('propietario', 'inquilino'))
);

CREATE TABLE consorcio.pago(
    idPago INT PRIMARY KEY NOT NULL,
    fecha DATE,
    cuentaOrigen CHAR(22) NOT NULL,
    importe DECIMAL (13,3) NOT NULL,
    estaAsociado BIT NOT NULL,

    CONSTRAINT chk_pago_cuentaOrigen CHECK (ISNUMERIC(cuentaOrigen) = 1),
    CONSTRAINT chk_pago_importe CHECK (importe > 0)
);

CREATE TABLE consorcio.expensa(
    idExpensa INT IDENTITY (1,1) PRIMARY KEY,
    idConsorcio INT NOT NULL, 
    periodo VARCHAR(12) NOT NULL,
    anio INT NOT NULL,

    CONSTRAINT fk_expensa_consorcio FOREIGN KEY (idConsorcio) REFERENCES consorcio.consorcio (idConsorcio),
    CONSTRAINT chk_expensa_periodo CHECK (periodo IN('enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre')),
    CONSTRAINT uq_expensa_cierre UNIQUE (idConsorcio, periodo, anio)
);

CREATE TABLE consorcio.detalle_expensa (
    idDetalleExpensa INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    idExpensa INT NOT NULL,
    idUnidadFuncional INT NOT NULL,
    idPago INT NULL,
    fechaEmision DATE NOT NULL DEFAULT GETDATE(),
    fechaPrimerVenc DATE NOT NULL,
    fechaSegundoVenc DATE,
    saldoAnterior DECIMAL (12,2) NOT NULL,
    pagoRecibido DECIMAL (12,2) NOT NULL,
    deuda DECIMAL (12,2) NOT NULL,
    interesPorMora DECIMAL (12, 2) NOT NULL,
    expensasOrdinarias DECIMAL (12, 2) NOT NULL,
    expensasExtraordinarias DECIMAL (12, 2) NOT NULL,
    totalAPagar DECIMAL (12, 2) NOT NULL,

    CONSTRAINT fk_detalleExpensa_expensa FOREIGN KEY (idExpensa) REFERENCES consorcio.expensa(idExpensa),
    CONSTRAINT fk_detalleExpensa_unidadFuncional FOREIGN KEY (idUnidadFuncional) REFERENCES consorcio.unidad_funcional(idUnidadFuncional),
    CONSTRAINT fk_detalleExpensa_pago FOREIGN KEY (idPago) REFERENCES consorcio.pago(idPago),
    CONSTRAINT uq_detalle_expensa_unica UNIQUE (idExpensa, idUnidadFuncional),
    CONSTRAINT chk_detalleExpensa_fechaPrimerVenc CHECK (fechaPrimerVenc > fechaEmision),
    CONSTRAINT chk_detalleExpensa_fechaSegundoVenc CHECK (fechaSegundoVenc IS NULL OR fechaSegundoVenc > fechaPrimerVenc),
    CONSTRAINT chk_detalleExpensa_pagoRecibidos CHECK (pagoRecibido >= 0),
    CONSTRAINT chk_detalleExpensa_interesPorMora CHECK (interesPorMora >= 0),
    CONSTRAINT chk_detalleExpensa_expensasOrdinarias CHECK (expensasOrdinarias >= 0),
    CONSTRAINT chk_detalleExpensa_expensasExtraOrdinarias CHECK (expensasExtraOrdinarias >= 0),
    CONSTRAINT chk_detalleExpensa_totalAPagar CHECK (totalAPagar >= 0)
);

CREATE TABLE consorcio.gasto (
    idGasto INT IDENTITY(1,1),
    idExpensa INT NOT NULL,
    subTotalOrdinarios DECIMAL(12,2) NOT NULL,
    subTotalExtraOrd DECIMAL(12,2) NOT NULL,

    CONSTRAINT pk_gasto PRIMARY KEY (idGasto),
    CONSTRAINT chk_subTotalOrd_gasto CHECK (subTotalOrdinarios >= 0),
    CONSTRAINT chk_subTotalExtraOrd_gasto CHECK (subTotalExtraOrd >= 0),
    CONSTRAINT fk_gasto_expensa FOREIGN KEY (idExpensa) REFERENCES consorcio.expensa(idExpensa)
);

CREATE TABLE consorcio.gasto_ordinario (
    idGastoOrd INT IDENTITY(1,1),
    idGasto INT NOT NULL,
    tipoGasto VARCHAR(20) NOT NULL,
    subTipoGasto VARCHAR(30) NOT NULL,
    nomEmpresa VARCHAR(40) NOT NULL,
    nroFactura INT NOT NULL,
    importe DECIMAL(12,2) NOT NULL,

    CONSTRAINT pk_gastoOrd PRIMARY KEY (idGastoOrd),
    CONSTRAINT chk_tipoGasto_ord CHECK (tipoGasto IN ('mantenimiento','limpieza','administracion','seguros','generales','servicios publicos')),
    CONSTRAINT chk_importe_ord CHECK (importe > 0),
    CONSTRAINT uq_factura_ord UNIQUE (nroFactura, nomEmpresa),
    CONSTRAINT fk_gastoOrd_gasto FOREIGN KEY (idGasto) REFERENCES consorcio.gasto(idGasto)
);

CREATE TABLE consorcio.gasto_extra_ordinario (
    idGastoExtraOrd INT IDENTITY(1,1),
    idGasto INT NOT NULL,
    tipoGasto VARCHAR(12) NOT NULL,
    nomEmpresa VARCHAR(40) NOT NULL,
    nroFactura INT NOT NULL,
    descripcion VARCHAR(50) NOT NULL,
    nroCuota INT NOT NULL,
    totalCuotas INT NOT NULL,
    importe DECIMAL(12,2) NOT NULL,

    CONSTRAINT pk_gastoExtraOrd PRIMARY KEY (idGastoExtraOrd),
    CONSTRAINT chk_tipoGasto_extraOrd CHECK (tipoGasto IN ('reparacion','construccion')),
    CONSTRAINT chk_nroCuota CHECK (nroCuota > 0),
    CONSTRAINT chk_totalCuotas CHECK (totalCuotas > 0),
    CONSTRAINT chk_importe_extraOrd CHECK (importe > 0),
    CONSTRAINT chk_cuotas_validas CHECK (nroCuota <= totalCuotas),
    CONSTRAINT uq_factura_extra_ord UNIQUE (nroFactura, nomEmpresa),
    CONSTRAINT fk_gastoExtraOrd_gasto FOREIGN KEY (idGasto) REFERENCES consorcio.gasto(idGasto)
);