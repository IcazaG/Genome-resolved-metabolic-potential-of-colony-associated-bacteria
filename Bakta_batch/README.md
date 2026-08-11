# Bakta API Batch Annotation Script

Script en PowerShell para anotar genomas (archivos FASTA) en lotes mediante la API web de Bakta. Automatiza la subida, el seguimiento y la descarga de resultados, organizando cada genoma en su propia carpeta.

## Requisitos

- PowerShell 5.1+ (Windows) o PowerShell Core (Linux/macOS)
- Acceso a Internet para comunicarse con la API de Bakta
- Archivos de entrada con extensión `.fa` (FASTA nucleotídico)
- No se necesitan credenciales para el uso básico de la API

## ⚙️ Configuración

Antes de ejecutar, edita las siguientes variables en la sección `# -------------------- Configuration --------------------` del script:

| Variable               | Descripción                                                                                                           |
|------------------------|-----------------------------------------------------------------------------------------------------------------------|
| `$MAGsDir`             | Ruta al directorio que contiene tus archivos `.fa`.                                                                   |
| `$OutputRoot`          | Directorio raíz donde se crearán las carpetas de resultados. Por defecto: `$MAGsDir\bakta_results`.                   |
| `$BatchSize`           | Número de genomas procesados simultáneamente (por defecto 10).                                                        |
| `$PollIntervalSeconds` | Segundos entre comprobaciones de estado (por defecto 60).                                                             |
| `$ApiBaseUrl`          | URL de la API de Bakta (no modificar a menos que cambie el endpoint).                                                 |

```powershell
$MAGsDir = "C:\MisGenomas"
$BatchSize = 5
$PollIntervalSeconds = 30
