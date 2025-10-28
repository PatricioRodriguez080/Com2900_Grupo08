------------ Archivo datos varios.xlsx --------------------------
EXEC consorcio.SP_importar_consorcios_excel @path = 'C:\Archivos para el TP\datos varios.xlsx';

SELECT * FROM consorcio.consorcio;


------- Archivo inquilino-propietarios-datos.csv -----------------
EXEC consorcio.ImportarPersonas @path = 'C:\Archivos para el TP\Inquilino-propietarios-datos.csv';

SELECT * FROM consorcio.persona;


---------- pagos_consorcios.csv ------------
EXEC consorcio.sp_cargaPagos @path = 'C:\Archivos para el TP\pagos_consorcios.csv';

SELECT * FROM consorcio.pago;