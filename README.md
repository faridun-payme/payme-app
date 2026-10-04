## 6. Как устроен гибридный граф (5 мин)

**Главная мысль:** в приложении сейчас два контейнера. Koin **владеет** мигрированными зависимостями, Hilt их только **одалживает** через мост. Зависимости передаются только в одну сторону: **Koin → Hilt**.

### 6.1. Общая картина

```mermaid
flowchart LR
    subgraph KOIN["🟢 Koin — владелец"]
        direction TB
        KCore["Core<br/>network, storage, navigation…"]
        KData["Feature Data<br/>(мигрированные)"]
        KDomain["Feature Domain<br/>(мигрированные)"]
        KDomain --> KData --> KCore
    end

    subgraph BRIDGE["🌉 *HiltBridge (генерирует KSP)"]
        B["@Provides fun provideX(): X =<br/>KoinJavaComponent.get(X::class.java)"]
    end

    subgraph HILT["🟠 Hilt — потребитель"]
        direction TB
        HVM["@HiltViewModel<br/>Presentation"]
        HAct["@AndroidEntryPoint<br/>Activity / Fragment"]
        HOld["Немигрированные<br/>Data/Domain фич"]
        HSkip["Отложенные в Core<br/>(ActionHandler и т.п.)"]
    end

    KOIN -- "@KoinHiltBridge" --> BRIDGE
    BRIDGE -- "инжект как обычно" --> HILT
    HILT -. "❌ Koin НЕ берёт из Hilt" .-> KOIN
```

- Koin ничего не знает о Hilt. Hilt не знает, что объект пришёл из Koin.
- Объект существует **в одном экземпляре**: Hilt не создаёт свою копию, а получает объект из Koin.
- Обратного моста (Hilt → Koin) нет. Поэтому миграция идёт снизу вверх: Core → Data → Domain → Presentation.

### 6.2. Что происходит при старте и инжекте

```mermaid
sequenceDiagram
    autonumber
    participant OS as Android
    participant KS as KoinStartupInitializer<br/>(App Startup)
    participant K as Koin
    participant H as Hilt
    participant BR as ServermodeDomainHiltBridge
    participant VM as ServerModesSelectionVm (@HiltViewModel)

    OS->>KS: старт процесса (до Application.onCreate)
    KS->>K: startKoin { core + feature + app modules }
    Note over K: граф уже проверен compiler plugin<br/>на этапе сборки
    OS->>H: Application.onCreate → Hilt готов
    VM->>H: нужен GetCurrentServerModeUseCase
    H->>BR: @Provides provideGetCurrentServerModeUseCase()
    BR->>K: KoinJavaComponent.get(GetCurrentServerModeUseCase::class.java)
    K-->>BR: factory → новый экземпляр (с репозиторием из Koin)
    BR-->>H: экземпляр
    H-->>VM: инжект в конструктор (VM не изменилась)
```

Koin стартует через App Startup **раньше** любого Hilt-инжекта, поэтому к первому запросу из Hilt граф Koin уже есть.

### 6.3. Как это выглядит в коде (на примере ServerMode)

```kotlin
// domain — класс мигрирован: @Inject убран, мост поставлен
@KoinHiltBridge
class GetCurrentServerModeUseCase(
    private val repository: ServerModeRepository,
)

// domain/di — Koin владеет
val serverModeDomainModule = module {
    factoryOf(::GetCurrentServerModeUseCase)
}

// build/generated/ksp — генерируется сам, руками не трогаем
@Module @InstallIn(SingletonComponent::class)
object ServermodeDomainHiltBridge {
    @Provides
    fun provideGetCurrentServerModeUseCase(): GetCurrentServerModeUseCase =
        KoinJavaComponent.get(GetCurrentServerModeUseCase::class.java)
}

// presentation — НЕ трогаем, работает как раньше
@HiltViewModel
class ServerModesSelectionVm @Inject constructor(
    private val getCurrentServerModeUseCase: GetCurrentServerModeUseCase,
) : BaseVm<...>()
```

Это реальный формат: так выглядит `DomainHiltBridge` в `core-domain` (7 use cases) и `NavigationHiltBridge` в `core-navigation`.

### 6.4. Почему основной тип в Koin — класс, а не интерфейс

```mermaid
flowchart LR
    A["@KoinHiltBridge(expose = Repo::class)<br/>class RepoImpl : Repo"] --> G["Генерируется:<br/>fun provideRepo(): Repo =<br/>get(RepoImpl::class.java)"]
    G --> OK{"Как объявлено в Koin?"}
    OK -- "singleOf(::RepoImpl) bind Repo::class" --> Y["✅ находит RepoImpl"]
    OK -- "single&lt;Repo&gt; { RepoImpl() }" --> N["💥 NoDefinitionFoundException<br/>при первом инжекте"]
```

Hilt-потребитель получает тип `expose` (интерфейс). Сам мост при этом ищет в Koin **конкретный класс**.

### 6.5. Как граф меняется по ходу миграции

```mermaid
flowchart LR
    subgraph S1["Сейчас"]
        direction TB
        a1["Presentation — Hilt"]
        a2["Data/Domain — 🟠 Hilt<br/>(кроме ServerMode, Identity…)"]
        a3["Core — 🟢 Koin + мосты"]
    end
    subgraph S2["После Фазы 3 (ваши задачи)"]
        direction TB
        b1["Presentation — Hilt"]
        b2["Data/Domain — 🟢 Koin + мосты"]
        b3["Core — 🟢 Koin"]
    end
    subgraph S3["После Фазы 6"]
        direction TB
        c1["Presentation — 🟢 Koin"]
        c2["Data/Domain — 🟢 Koin"]
        c3["Core — 🟢 Koin<br/>мостов 0, Hilt удалён"]
    end
    S1 --> S2 --> S3
```

Мосты — **временные строительные леса**. Их число растёт в Фазе 3, падает в Фазах 4–5 и обнуляется в Фазе 6.

### 6.6. Кто ловит ошибки

| Где | Что проверяет | Что ловит |
|---|---|---|
| Компиляция модуля (Koin compiler plugin) | Koin-граф | Нет определения для зависимости в Koin |
| `:app:hiltJavaCompileGoogleDebug` (Dagger) | Hilt-граф и мосты | `MissingBinding` (нет моста / не тот `expose`), `DuplicateBindings` (остался `@Inject`/`@Binds`) |
| Запуск приложения | Связка мост → Koin | `NoDefinitionFoundException`: модуль не зарегистрирован в `FeatureDiModules`, `single<Iface>` вместо класса или feature-PR смержен без root-PR |

