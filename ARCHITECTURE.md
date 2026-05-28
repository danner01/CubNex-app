# Arquitectura movil

La app queda preparada con Clean Architecture por modulos:

```text
lib/app/
  config/
    environment/
    http/
    injection/
    routes/
    theme/
  common/
    blocs/
    entities/
    presentation/
  modules/
    auth/
    home/
    search/
    scanner/
    profile/
    business/
    wizard/
    product/
    service/
    business_directory/
    advertising/
    favorites/
    notifications/
    review_rating/
    address/
    properties/
    transport/
    personalization/
    gamification/
```

Cada modulo debe mantener:

- `presentation`: pantallas y widgets.
- `blocs`: Cubit/BLoC, eventos y estados.
- `domain`: entidades, repositorios abstractos y casos de uso.
- `data`: modelos, datasources y repositorios concretos.

El flujo recomendado es:

```text
Screen -> Cubit/BLoC -> UseCase -> Repository -> DataSource -> ApiClient -> /api/v1
```

Reglas:

- No llamar `Dio` directamente desde pantallas.
- No poner logica de negocio dentro de widgets.
- Los modelos API viven en `data/models`; las entidades limpias viven en `domain/entities`.
- Toda ruta nueva se declara en `config/routes/app_routes.dart` y `config/routes/app_router.dart`.
- Todo servicio/repositorio nuevo se registra en `config/injection/injection.dart`.
