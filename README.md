# Proyecto de Base de Datos para un E-commerce

## Descripción Breve
Este proyecto implementa el diseño, la arquitectura y la lógica avanzada del núcleo relacional de base de datos para una plataforma de comercio electrónico (*E-commerce*). El sistema gestiona con alta eficiencia, seguridad y escalabilidad el catálogo de productos, inventario multi-almacén, relaciones comerciales con proveedores, perfiles de clientes, transacciones de venta multi-sucursal y control de auditoría integral. Ha sido diseñado siguiendo las mejores prácticas de la industria en normalización, integridad referencial mediante restricciones `CHECK` y claves foráneas, aislamiento de transacciones ACID, control de acceso basado en roles (RBAC) y automatización programada.

---

## Integrantes del Equipo
* **Estudiante / Desarrollador Principal:** Seveck
* *[Opcional: Agregar aquí los nombres de otros integrantes del equipo si aplica]*

---

## Estructura de Archivos del Repositorio
El repositorio contiene todos los scripts en la raíz del proyecto, debidamente segmentados e independientes para facilitar su revisión y ejecución secuencial:

| Archivo | Contenido y Propósito |
| :--- | :--- |
| **`README.md`** | Portada del proyecto, descripción, integrantes e instrucciones de ejecución. |
| **`01_Esquema_y_Datos.sql`** | Definición completa de la estructura DDL (tablas, restricciones y relaciones) y carga del conjunto de datos de prueba estandarizado (DML). |
| **`02_Consultas_Avanzadas.sql`** | 20 consultas analíticas y de Business Intelligence (Top 10, RFM, Cohortes, Cesta de compra, Rotación, etc.). |
| **`03_Funciones.sql`** | 20 funciones definidas por el usuario (UDFs) para cálculos y validaciones reutilizables. |
| **`04_Seguridad.sql`** | 20 directivas de seguridad, RBAC, vistas de privacidad, cuotas de consulta y hardening. |
| **`05_Triggers.sql`** | Creación de tabla de auditoría de precios y 20 disparadores de integridad y auditoría automática. |
| **`06_Eventos.sql`** | Activación del motor `event_scheduler`, tablas de agregación y 20 tareas programadas de mantenimiento y KPIs. |
| **`07_Procedimientos_Almacenados.sql`** | 20 procedimientos almacenados transaccionales, operativos y analíticos con control de excepciones. |
| **`08_Auditoria_Clientes.sql`** | Auditoría de datos sensibles de clientes (email y dirección), tabla `customer_audit_logs`, vista de compatibilidad `Auditoria_Clientes` y trigger automatizado. |

---

## Instrucciones de Ejecución Secuencial

Para recrear y validar el sistema en su totalidad, ejecute los archivos en el orden numérico estricto del **01 al 08**.

### Opción A: Ejecución desde la Terminal / Línea de Comandos (CLI)

Abra una terminal en la raíz del repositorio y ejecute los siguientes comandos (reemplazando `root` o agregando `-p` según su configuración de acceso):

```bash
# 1. Crear base de datos, esquema de tablas y cargar datos iniciales
mysql -u root -p < 01_Esquema_y_Datos.sql

# 2. Ejecutar las 20 consultas analíticas avanzadas
mysql -u root -p < 02_Consultas_Avanzadas.sql

# 3. Compilar las 20 funciones definidas por el usuario (UDFs)
mysql -u root -p < 03_Funciones.sql

# 4. Implementar roles, usuarios, permisos y vistas de seguridad
mysql -u root -p < 04_Seguridad.sql

# 5. Registrar los 20 triggers de integridad y auditoría
mysql -u root -p < 05_Triggers.sql

# 6. Activar event_scheduler y programar los 20 eventos automatizados
mysql -u root -p < 06_Eventos.sql

# 7. Compilar los 20 procedimientos almacenados transaccionales
mysql -u root -p < 07_Procedimientos_Almacenados.sql

# 8. Implementar módulo de auditoría de seguridad y trazabilidad de clientes
mysql -u root -p < 08_Auditoria_Clientes.sql
```

> **Nota:** También es posible utilizar el cliente interactivo `mariadb` de la misma manera:  
> `mariadb -u root < 01_Esquema_y_Datos.sql`

### Opción B: Ejecución desde Interfaces Gráficas (MySQL Workbench / DBeaver / phpMyAdmin)
1. Conéctese a su servidor de base de datos como usuario con privilegios de administrador (`root`).
2. Abra y ejecute el script **`01_Esquema_y_Datos.sql`**.
3. Abra y ejecute sucesivamente los scripts del **`02`** al **`08`** en orden numérico.

---

## Resumen de Módulos Implementados

### 1. Esquema y Datos (`01_Esquema_y_Datos.sql`)
* **Entidades Principales:** `branches`, `categories`, `suppliers`, `products`, `customers`, `orders`, `order_details`.
* **Entidades de Soporte y Analítica:** `promotions`, `shopping_carts`, `cart_items`, `product_reviews`, `stock_alerts`, `price_change_logs`, `customer_logs`, `order_status_logs`, `security_logs`, `archived_orders`, `archived_order_details`, `weekly_sales_reports`, `daily_sales_summary`, `monthly_kpis`, `reorder_list`, etc.
* **Integridad de Datos:** Restricciones `CHECK` para precios, costos, stock no negativo y calificaciones de reseñas entre 1 y 5; unicidad (`UNIQUE`) de SKUs, correos y nombres; relaciones foráneas con `ON UPDATE CASCADE` y reglas de eliminación seguras (`RESTRICT` / `SET NULL` / `CASCADE`).

### 2. Consultas Analíticas (`02_Consultas_Avanzadas.sql`)
Las 20 consultas resuelven interrogantes clave de inteligencia de negocios:
1. **Top 10 Productos Más Vendidos** por facturación bruta acumulada.
2. **Productos con Bajas Ventas** identificando el decil inferior (10%) con `NTILE(10)`.
3. **Clientes VIP** (Top 5 con mayor *Customer Lifetime Value* - LTV y ticket promedio).
4. **Análisis de Ventas Mensuales** cronológico con items y ticket promedio.
5. **Crecimiento de Clientes por Trimestre** con total acumulado móvil (`SUM() OVER`).
6. **Tasa de Compra Repetida** (% de clientes recurrentes vs. compradores únicos).
7. **Análisis de Cesta de la Compra** (*Market Basket Analysis* con auto-uniones).
8. **Rotación de Inventario** por categoría (Relación COGS / Valor de stock).
9. **Productos que Requieren Reabastecimiento** con cálculo de cantidad sugerida.
10. **Análisis de Carritos Abandonados** con valor monetario potencial no concretado.
11. **Rendimiento de Proveedores** ranqueados con `DENSE_RANK()`.
12. **Análisis Geográfico de Ventas** por ciudad y porcentaje de contribución.
13. **Ventas por Hora del Día** clasificadas en franjas horarias operativas.
14. **Impacto de Promociones** comparando desempeño antes, durante y después.
15. **Análisis de Cohortes** de retención mensual de clientes desde su primer mes de compra.
16. **Margen de Beneficio por Producto** (ganancia unitaria, margen % y beneficio histórico).
17. **Tiempo Promedio Entre Compras** utilizando función de ventana `LAG()`.
18. **Ratio de Conversión de Vistas vs. Compras Efectivas**.
19. **Segmentación RFM** (Recencia, Frecuencia, Monetario) en cohortes (*Champions*, *Loyal*, *At Risk*).
20. **Predicción de Demanda Simple** usando medias móviles de 3 meses (`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`).

### 3. Funciones Definidas por el Usuario (`03_Funciones.sql`)
20 funciones modulares (`DETERMINISTIC`, `READS SQL DATA`, `NO SQL`) con prefijo `fn_`:
* `fn_calculate_sale_total`, `fn_check_stock_availability`, `fn_get_product_price`, `fn_calculate_customer_age`, `fn_format_full_name`, `fn_is_new_customer`, `fn_calculate_shipping_cost`, `fn_apply_discount`, `fn_get_last_purchase_date`, `fn_validate_email_format`, `fn_get_category_name`, `fn_count_customer_orders`, `fn_days_since_last_purchase`, `fn_determine_loyalty_tier`, `fn_generate_sku`, `fn_calculate_vat`, `fn_get_total_stock_by_category`, `fn_estimate_delivery_date`, `fn_convert_currency`, `fn_validate_password_complexity`.

### 4. Seguridad y Permisos (`04_Seguridad.sql`)
20 requerimientos de hardening y gobierno de datos:
* **Roles RBAC:** `role_system_admin`, `role_marketing_manager`, `role_data_analyst`, `role_inventory_clerk`, `role_customer_support`, `role_financial_auditor`, `role_guest`.
* **Usuarios Operativos:** `admin_user`, `marketing_user`, `inventory_user`, `support_user`, `analyst_user`.
* **Políticas Implementadas:** Principio de menor privilegio (sin permisos destructivos para analistas), permisos a nivel de columnas (`UPDATE (stock, warehouse_location)` exclusivo para inventario sin tocar precios), vista con enmascaramiento de PII `v_basic_customer_info`, cuota horaria `MAX_QUERIES_PER_HOUR 1000`, aislamiento por sucursal `v_branch_scoped_orders`, bloqueo de accesos remotos al usuario `root` y auditoría de logins fallidos en `security_logs`.

### 5. Disparadores de Integridad (`05_Triggers.sql`)
20 triggers automáticos para blindar la base de datos:
* Auditoría automática de cambios de precio en `price_change_logs`.
* Verificación previa de stock con interrupción mediante `SIGNAL SQLSTATE '45000'`.
* Descuento automático de stock tras registrar líneas de pedido.
* Bloqueo de eliminación de categorías con productos existentes.
* Auditoría de nuevos clientes en `customer_logs`.
* Recálculo en tiempo real del gasto acumulado del cliente y su categoría de lealtad.
* Actualización automática de `updated_at`.
* Bloqueo de stock negativo y precios menores o iguales a cero.
* Capitalización automática de nombres de clientes.
* Recálculo automático del total de la orden al modificar detalles.
* Registro de cambios de estado del pedido en `order_status_logs`.
* Alertas automáticas en `stock_alerts` cuando el stock cae por debajo del umbral mínimo.
* Archivo automático de ventas eliminadas en `archived_orders`.
* Validación sintáctica de correos electrónicos.
* Actualización de fecha del último pedido.
* Prevención de auto-referidos en programas de lealtad.
* Asignación automática de categoría por defecto `'General'`.
* Sincronización del contador de productos por categoría.

### 6. Eventos Programados (`06_Eventos.sql`)
20 tareas automatizadas en segundo plano mediante `event_scheduler`:
* Consolidación semanal en `weekly_sales_reports`.
* Limpieza diaria de carritos de compra vacíos o abandonados.
* Archivado mensual de logs con más de 180 días.
* Desactivación horaria de promociones y cupones expirados.
* Recálculo nocturno de niveles de lealtad de clientes.
* Generación diaria de la lista de reabastecimiento en `reorder_list`.
* Optimización semanal de almacenamiento e índices con `ANALYZE TABLE`.
* Suspensión trimestral de cuentas inactivas por más de 1 año.
* Cierre contable diario en `daily_sales_summary`.
* Control nocturno de consistencia e integridad de datos.
* Emisión diaria de cupones de cumpleaños en `customer_birthday_coupons`.
* Actualización horaria del ranking de productos más vendidos en `product_rankings`.
* Checkpoints diarios de respaldo lógico en `backup_snapshot_logs`.
* Cálculo mensual de KPIs en `monthly_kpis`.
* Refresco nocturno de tablas agregadas `mat_category_summary`.
* Monitoreo semanal del tamaño físico de la base de datos en `database_size_logs`.
* Detección horaria de patrones sospechosos de pedidos rápidos.
* Consolidación mensual del rendimiento de proveedores.
* Purga semanal de alertas resueltas y cupones redimidos antiguos.

### 7. Procedimientos Almacenados (`07_Procedimientos_Almacenados.sql`)
20 procedimientos operacionales con control transaccional completo:
* `sp_place_new_order`: Venta transaccional con validación de stock, congelamiento de precio histórico y cálculo de envío.
* `sp_add_new_product`, `sp_update_customer_address`, `sp_process_product_return`, `sp_get_customer_purchase_history`, `sp_adjust_stock_level`.
* `sp_safely_delete_customer`: Anonimización de datos (GDPR) preservando el histórico contable.
* `sp_apply_discount_by_category`, `sp_generate_monthly_sales_report`, `sp_change_order_status`, `sp_register_new_customer`, `sp_get_full_product_details`.
* `sp_merge_customer_accounts`: Fusión transaccional de cuentas duplicadas de clientes.
* `sp_assign_product_to_supplier`, `sp_search_products`, `sp_get_admin_dashboard_kpis`, `sp_process_payment`.
* `sp_add_product_review`: Calificación y reseña permitida exclusivamente a compradores verificados.
* `sp_get_related_products`: Recomendaciones basadas en co-compras.
* `sp_move_products_between_categories`: Reubicación masiva de productos entre categorías con sincronización de contadores.

### 8. Auditoría de Seguridad de Clientes (`08_Auditoria_Clientes.sql`)
Módulo de cumplimiento y seguridad para trazabilidad de datos personales sensibles alineado con el esquema relacional en inglés:
* **Tabla de Auditoría:** `customer_audit_logs` (`audit_id`, `customer_id`, `changed_field`, `old_value`, `new_value`, `changed_at`).
* **Vista de Compatibilidad:** `Auditoria_Clientes` (mapea directamente a `id_auditoria`, `id_cliente`, `campo_modificado`, `valor_antiguo`, `valor_nuevo`, `fecha_modificacion`).
* **Disparador Reactivo:** `trg_audit_customer_after_update` (`AFTER UPDATE ON customers`), captura y audita cambios atómicos en `email` o `shipping_address`.

---

## Requisitos de Entrega en GitHub
1. **Formato del Repositorio:** El repositorio debe ser **privado** en GitHub y seguir el formato de nombre:
   ```
   Proyecto_BD_Avanzada_[NombreEquipo]
   ```
2. **Invitación al Trainer:** Recuerde invitar al *trainer* como colaborador con permisos de lectura para la revisión y calificación del proyecto.
3. **Ubicación de Archivos:** Todos los scripts SQL (`01_Esquema_y_Datos.sql` al `08_Auditoria_Clientes.sql`) y este archivo `README.md` deben residir en la **raíz** del repositorio para garantizar su correcta ejecución secuencial.

