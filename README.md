# TeideSpiders: Diversidad de Arañas en el Parque Nacional del Teide (1995–2024)

Este repositorio contiene el código y los análisis para el estudio de la diversidad taxonómica (TD), filogenética (PD) y funcional (FD) de las comunidades de arañas en el Parque Nacional del Teide, comparando datos de muestreos de 1995 y 2024.

## Estructura del Proyecto

El proyecto está diseñado para ser modular y reproducible, facilitando la integración continua y la generación automática de informes.

```text
TeideSpiders/
├── setup.R                          # Script de inicialización (ejecutar UNA vez para configurar 'renv' y mover datos)
├── config.R                         # Configuración global (rutas, paletas, semillas)
├── R/
│   ├── data_prep.R                  # Funciones comunes para carga y limpieza de datos
│   ├── model_utils.R                # Funciones comunes de modelado estadístico y exportación
│   └── plot_utils.R                 # Configuraciones gráficas y visualizaciones combinadas
├── analysis/
│   ├── 01_taxo.R                    # Script de análisis de diversidad taxonómica
│   ├── 02_fun.R                     # Script de análisis de diversidad funcional
│   └── 03_filo.R                    # Script de análisis de diversidad filogenética
├── reports/
│   ├── _quarto.yml                  # Configuración de Quarto
│   └── diversity_report.Qmd         # Documento Quarto para generar el informe final
├── data/                            # Directorio para los datos brutos (no versionado si contiene datos sensibles)
├── output/                          # Directorio para resultados (gráficos, tablas, caché)
├── .github/workflows/               # Flujos de trabajo de CI/CD para GitHub Actions
└── renv.lock                        # Archivo de bloqueo de dependencias para garantizar la reproducibilidad
```

## Requisitos y Reproducibilidad

Este proyecto utiliza `renv` para gestionar las dependencias de R. Para asegurar que los análisis se ejecutan con las mismas versiones de paquetes, sigue estos pasos:

1. Clona el repositorio:
   ```bash
   git clone https://github.com/lobatojorge/TeideSpiders.git
   cd TeideSpiders
   ```

2. Abre R o RStudio en el directorio raíz del proyecto.

3. Restaura el entorno (esto descargará e instalará las versiones exactas de los paquetes necesarios):
   ```R
   renv::restore()
   ```

## Ejecución de los Análisis

1. Asegúrate de tener los archivos de datos necesarios en la carpeta `data/` (`arañas.xlsx`, `matrizTraits.xlsx`, `zonas.xlsx`, `RAxML_bestTree.result`). Si es la primera vez que configuras el proyecto localmente, puedes usar el script `setup.R` que te guiará en este proceso.
2. Puedes ejecutar los scripts de análisis individualmente en la consola de R:
   ```R
   source("config.R"); source("analysis/01_taxo.R")
   source("config.R"); source("analysis/02_fun.R")
   source("config.R"); source("analysis/03_filo.R")
   ```
3. Para compilar el informe final con todos los resultados integrados:
   ```R
   quarto::quarto_render("reports/diversity_report.Qmd")
   ```

## Integración Continua (CI/CD)

El repositorio incluye un flujo de trabajo de GitHub Actions (`.github/workflows/render-report.yml`). Cada vez que se realizan cambios en los datos o en los scripts de análisis y se suben a la rama principal, se ejecutan automáticamente los análisis y se renderiza el informe Quarto. El informe generado está disponible como un *artifact* en la pestaña "Actions" de GitHub.

## Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo `LICENSE` para más detalles.
