# Content packs

Esta carpeta queda reservada para separar contenido tematico del motor del juego.

La estructura objetivo es:

```text
content/
  medieval/
    data/
    images/
    audio/
  scifi/
    data/
    images/
    audio/
```

Por ahora el juego sigue leyendo desde `res://data`. No moveremos datos reales a `content/medieval` hasta tener una capa de carga preparada.

Primer objetivo:

```text
Agregar una locacion nueva debe requerir editar datos, no scripts.
```
