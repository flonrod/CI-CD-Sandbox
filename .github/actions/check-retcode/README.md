# GitHub Action — Check RETCODE

Esta acción valida un **código de retorno** (`retcode`) comparándolo con una lista de códigos definidos en un archivo JSON.  
Está diseñada para flujos de CI/CD donde una ejecución (por ejemplo, una compilación, validación o análisis de datos) devuelve un código que debe interpretarse como **éxito, advertencia o error**, según una configuración flexible.

---

## Descripción general

`check-retcode` interpreta códigos numéricos devueltos por scripts o programas, aplicando reglas definidas en un archivo JSON (`codes.json`).  
Esto permite controlar el comportamiento del pipeline con distintos niveles de severidad.

---

## Entradas (`inputs`)

| Nombre | Requerido | Descripción | Valor por defecto |
|:--------|:-----------:|:-------------|:------------------|
| `retcode` | ✅ | Código de retorno a evaluar. | — |
| `config_file` | ✅ | Ruta al archivo JSON con la configuración de rangos, estados y mensajes. | `./.github/actions/check-retcode/codes.json` |

---

## Salidas (`outputs`)

| Nombre | Descripción |
|:--------|:-------------|
| `status` | Estado resultante (`success`, `warning`, `failure`, `severe`, `critical`). |
| `message` | Descripción textual asociada al código. |

---

## Ejemplo de configuración (`codes.json`)

```json
[
  {
    "range": "0-3",
    "status": "success",
    "message": "Compilación exitosa.",
    "should-fail": false
  },
  {
    "range": "4",
    "status": "warning",
    "message": "Compilación exitosa con advertencia: límite de respuesta próximo a alcanzarse.",
    "should-fail": false
  },
  {
    "range": "5",
    "status": "failure",
    "message": "Compilación fallida: límite de código excedido. Se requiere revisión.",
    "should-fail": true
  },
  {
    "range": "6-8",
    "status": "severe",
    "message": "Compilación fallida por error severo. Revisión inmediata recomendada.",
    "should-fail": true
  },
  {
    "range": "9",
    "status": "critical",
    "message": "Compilación fallida por error crítico. Ejecución detenida.",
    "should-fail": true
  }
]
```

> 🔹 El campo `"range"` puede ser un número (`"5"`) o un rango (`"0-3"`).  
> 🔹 El campo `"should-fail"` determina si el workflow debe fallar (`true`) o continuar (`false`) cuando se encuentra este código.  
> 🔹 Si el código recibido no coincide con ningún rango definido, se genera un error crítico automáticamente.  
> 🔹 Los códigos alfanuméricos o no válidos son rechazados inmediatamente con un mensaje de error.

---

## Ejemplo de uso en un workflow

```yaml
      - name: Check return code
        uses: ./.github/actions/check-retcode
        with:
          retcode: ${{ steps.compile.outputs.retcode }}
          config_file: './.github/actions/check-retcode/codes.json'
```

---

## Flujo interno de ejecución

La acción se compone de **dos scripts Bash** que se ejecutan en secuencia dentro del `runs.using: composite` del `action.yml`:

---

### 1. `validate-config.sh`

**Propósito:** Validar la existencia y estructura del archivo JSON de configuración antes de procesarlo.

**Principales validaciones:**
- Verifica que el archivo existe (`-f`).
- Comprueba que el contenido sea JSON válido (`jq empty`).
- Asegura que el JSON sea un array en la raíz.
- Valida que el array no esté vacío.
- Verifica que cada elemento contenga los campos obligatorios:
  - `range` (string)
  - `status` (string)
  - `message` (string)
  - `should-fail` (boolean)

**Si alguna verificación falla**, la acción emite un error de GitHub Actions con el formato `::error::` y termina con `exit 1`.

Ejemplo de log:
```
::error::Archivo JSON inválido: ./codes.json
::error::El archivo JSON debe ser un array en la raíz
::error::El campo 'should-fail' en índice 0 es obligatorio y debe ser booleano (true/false)
```

---

### 2. `check-retcode.sh`

**Propósito:** Determinar el resultado final del código de retorno según los rangos configurados.

**Lógica interna:**
1. Valida que el código recibido sea numérico (`^[0-9]+$`). Códigos alfanuméricos son rechazados inmediatamente.
2. Ejecuta `validate-config.sh` para asegurar que el archivo JSON es válido.
3. Itera sobre el array usando `jq -c '.[]'`.
4. Usa la función `in_range()` para determinar si el código está dentro del rango (`0-3`, `6-8`, etc.).
5. Si encuentra coincidencia:
   - Muestra el resultado en consola.
   - Escribe `status` y `message` en `$GITHUB_OUTPUT`.
   - Lee el valor de `should-fail` para determinar el exit code:
     - `should-fail: false` → retorna `exit 0` (workflow continúa)
     - `should-fail: true` → retorna `exit 1` (workflow falla)
6. Si no hay coincidencia, genera un mensaje de "código inesperado" con status `critical` y retorna `exit 1`.

**Ejemplo de salida en logs:**
```
------------------------------------
  Resultado encontrado:
  Status : failure
  Message: Compilación fallida: límite de código excedido. Se requiere revisión.
------------------------------------
```

---

## Ejemplo de resultados esperados

| Código | Estado (`status`) | Mensaje | `should-fail` | Exit Code |
|:------:|:------------------|:---------|:-------------:|:---------:|
| 0 | success | Compilación exitosa. | false | 0 |
| 4 | warning | Compilación exitosa con advertencia... | false | 0 |
| 5 | failure | Compilación fallida... | true | 1 |
| 7 | severe | ...Error severo. Revisión inmediata... | true | 1 |
| 9 | critical | ...Ejecución detenida. | true | 1 |
| 99 | critical | Código de retorno inesperado (99)... | — | 1 |
| abc | — | Error: código alfanumérico rechazado | — | 1 |

---

## Características principales

✅ **Configuración flexible:** Define tus propios rangos y mensajes vía JSON  
✅ **Control explícito de fallo:** El campo `should-fail` determina si el workflow debe continuar o fallar  
✅ **Validación robusta:** Verifica estructura JSON y campos obligatorios antes de procesar  
✅ **Manejo de códigos inesperados:** Cualquier código fuera de los rangos definidos genera un error crítico  
✅ **Mensajes personalizables:** Usa placeholders como `{code}` para incluir el código en los mensajes  
✅ **Soporte para rangos:** Define códigos individuales (`"4"`) o rangos (`"0-3"`, `"6-8"`)

---