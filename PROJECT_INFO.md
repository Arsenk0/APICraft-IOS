# APICraft iOS — Документація та архітектурний план проєкту

> **Тема:** Розробка нативного мобільного застосунку для тестування, моніторингу та автоматизованої валідації RESTful API в середовищі iOS  
> **Спеціальність:** 122 «Комп'ютерні науки»  
> **Тип проєкту:** Курсова робота з подальшим масштабуванням у кваліфікаційну (дипломну) роботу бакалавра  
> **Робоча назва застосунку:** `APICraft iOS` (або `RestLab iOS`)

---

## 1. Загальний опис та мета проєкту

### 1.1. Мета
Створення нативного iOS-інструменту інженера з якості (QA) та розробника для конструювання HTTP-запитів, інспекції відповідей (JSON/XML), локального збереження колекцій запитів, керування змінними середовища та виконання автоматизованих перевірок (assertions) виключно системними засобами платформи iOS без обов'язкової прив'язки до хмарних пропрієтарних сервісів.

### 1.2. Технологічний стек
* **Платформа:** iOS 17.0+ (iPhone / iPad)
* **Мова програмування:** Swift 5.9+ / Swift 6
* **UI-фреймворк:** SwiftUI (State-driven, Declarative)
* **Мережевий шар:** `URLSession` + Swift Concurrency (`async/await`, `actor`, `URLSessionTaskDelegate`)
* **База даних / Персистентність:** `SwiftData` (`@Model`, `#Predicate`, `@Query`)
* **Фреймворк тестування:** Swift Testing (`@Suite`, `@Test`, `#expect`)
* **Архітектура:** Clean Architecture + MVVM (Model-View-ViewModel)

---

## 2. Структура академічної пояснювальної записки

Структура оптимізована під вимоги стандартів вищої школи України (ДСТУ) для робіт спеціальності 122 «Комп'ютерні науки»:

```text
ЗМІСТ
ПЕРЕЛІК СКОРОЧЕНЬ ТА УМОВНИХ ПОЗНАЧЕНЬ
ВСТУП
  - Актуальність теми
  - Об'єкт, предмет та мета дослідження
  - Основні завдання дослідження
  - Методи дослідження та науково-практична новизна
РОЗДІЛ 1. АНАЛІЗ ПРЕДМЕТНОЇ ОБЛАСТІ ТА ІСНУЮЧИХ РІШЕНЬ
  1.1. Специфіка та проблеми тестування RESTful API на мобільних платформах
  1.2. Огляд аналогів (Postman, Insomnia, Proxyman, Paw/RapidAPI, HTTPBot)
  1.3. Порівняльний аналіз архітектурних підходів для мобільних тестових клієнтів
  1.4. Обґрунтування створення нативного автономного iOS-застосунку
  1.5. Формулювання вимог до системи (функціональні та нефункціональні)
РОЗДІЛ 2. МАТЕМАТИЧНЕ ТА АЛГОРИТМІЧНЕ ЗАБЕЗПЕЧЕННЯ СИСТЕМИ
  2.1. Формальна модель HTTP-запиту, відповіді та мережевих метрик
  2.2. Алгоритми синтаксичного аналізу та форматування напівструктурованих даних (JSON/XML)
  2.3. Алгоритмічне забезпечення рушія перевірки тверджень (Assertion Engine)
  2.4. Модель динамічної інтерполяції змінних середовища (Environment Resolution)
РОЗДІЛ 3. ПРОЄКТУВАННЯ АРХІТЕКТУРИ ТА БАЗИ ДАНИХ СИСТЕМИ
  3.1. Загальна багаторівнева архітектура системи (Clean Architecture + MVVM)
  3.2. Проєктування реляційної моделі даних для SwiftData
  3.3. Модульна декомпозиція та UML-діаграми (Use Case, Component, Sequence Diagrams)
  3.4. Проєктування призначеного для користувача інтерфейсу за Apple Human Interface Guidelines
РОЗДІЛ 4. ПРОГРАМНА РЕАЛІЗАЦІЯ ЗАСТОСУНКУ
  4.1. Вибір технологічного стеку та середовища розробки
  4.2. Реалізація мережевого шару на базі URLSession та Swift Concurrency
  4.3. Реалізація сховища даних на базі SwiftData
  4.4. Реалізація системи автоматизованої валідації статусів, заголовків та тіла
  4.5. Інтерфейсна реалізація компонентів запиту та перегляду результатів
РОЗДІЛ 5. ТЕСТУВАННЯ, ЕКСПЕРИМЕНТАЛЬНІ ДОСЛІДЖЕННЯ ТА ОЦІНКА ЕФЕКТИВНОСТІ
  5.1. Модульне (Unit) та інтеграційне тестування компонентів (Swift Testing)
  5.2. Навантажувальне тестування швидкодії локального парсингу та валідації
  5.3. Апробація системи на відкритих та тестових RESTful API
ВИСНОВКИ
СПИСОК ВИКОРИСТАНИХ ДЖЕРЕЛ
ДОДАТКИ
```

---

## 3. Архітектурне бачення

### 3.1. Патерн Clean Architecture + MVVM

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│   (SwiftUI Views, ViewModels, Navigation Coordinators) │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│                      Domain Layer                      │
│     (Use Cases / Interactors, Domain Entities,         │
│          Assertion Engine, Variable Resolver)          │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│                       Data Layer                       │
│    (Repositories, NetworkClient [URLSession],          │
│              Local Storage [SwiftData])                │
└────────────────────────────────────────────────────────┘
```

* **Domain:** Повністю незалежний від фреймворків шар бізнес-правил. Містить сутності, протоколи репозиторіїв та Use Cases.
* **Data:** Реалізації репозиторіїв, робота з `URLSession` та `ModelContext` у `SwiftData`.
* **Presentation:** SwiftUI-компоненти та `@Observable` ViewModels (iOS 17+ Observation framework).

### 3.2. Обґрунтування нативного стеку
1. **SwiftUI:**
   * Декларативне управління станом без бойлерплейту;
   * Ідеально підходить для динамічних списків параметрів (Headers, Query, Form-data).
2. **URLSession:**
   * Повна відмова від зовнішніх бібліотек (Alamofire тощо);
   * Низькорівневий контроль над `URLRequest`, потоками, SSL Pinning та збором метрик `URLSessionTaskMetrics` (TCP handshake, TLS negotiation, DNS lookup time).
3. **SwiftData:**
   * Сучасний стандарт персистентності від Apple;
   * Пряма робота з моделями у Swift через макрос `@Model`, типізовані предикати `#Predicate`, спрощена міграція.
4. **Swift Testing:**
   * Сучасний стандарт модульного тестування від Apple (`@Suite`, `@Test`, `#expect`).

---

## 4. Roadmap розробки (Feature-лист)

### Етап 1: MVP для курсової роботи (Виконано 100%)
*Ціль: Автономний, стабільний HTTP-клієнт з локальним збереженням, редактором запитів та базовою перевіркою відповідей.*

* [x] **Request Builder (вкладка "Requests"):**
  * [x] Вибір методів: `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD`, `OPTIONS`.
  * [x] Редагування URL з автоматичним визначенням протоколу (HTTPS/HTTP) та перемикачем схеми.
  * [x] Розширюване URL-поле з підтримкою довгих URL (auto-expand, scroll, char counter).
  * [x] Редагування Query Parameters (key-value інтерфейс з перемикачами активності, двостороння синхронізація URL ↔ Params).
  * [x] Редагування Headers (key-value інтерфейс з перемикачами активності).
  * [x] Редагування Body: `None`, `JSON`, `Form Data`, `x-www-form-urlencoded`.
  * [x] JSON Beautify (prettify) та шаблон JSON-тіла.
  * [x] Генерація та парсинг cURL команд (CURLParser, CURLGenerator) — імпорт/експорт через UI Sheet.
  * [x] 7 вбудованих Quick API Presets (GET Todo, POST JSON, POST Form, PUT Replace, PATCH Update, DELETE Item, HEAD Headers) з готовими assertions.
  * [x] Розпізнавання буферу обміну (Clipboard Preview) — URL, JSON, cURL.
  * [x] Анімований Splash Screen з прогрес-баром та tap-to-dismiss.

* [x] **Authorization Module (вкладка "Auth"):**
  * [x] Підтримка 4 типів авторизації: None, Bearer Token, Basic Auth (Base64), API Key.
  * [x] API Key — додавання до Header або Query Param з налаштуванням ключа та значення.
  * [x] Інтерполяція змінних середовища (`{{token}}`) у токенах та ключах авторизації.
  * [x] Автоматичне вираховування та додавання заголовка `Authorization` під час виконання запиту.
  * [x] Розпізнавання Authorization з cURL-імпорту (Bearer / Basic parsing).

* [x] **Response Inspector (вкладка "Response", з'являється після виконання):**
  * [x] Відображення HTTP-статусу (числовий код + текстовий опис), часу відгуку (ms) та розміру (bytes).
  * [x] Іконки та кольорові бейджі для кодів 2xx/3xx/4xx/5xx.
  * [x] Перегляд заголовків відповіді (Response Headers) у розкривному блоці (`DisclosureGroup`).
  * [x] Перегляд Cookies з атрибутами (Secure, HTTPOnly, Domain, Path, Expires).
  * [x] Форматування JSON (Prettify) та виявлення формату тіла (JSON / XML / HTML / Raw).
  * [x] In-body Search з підсвіткою знайдених фрагментів та лічильником matches.
  * [x] Line Wrap toggle (Wrap: On / Off) для горизонтального скролу.
  * [x] Collapse/Expand для великих відповідей (> 12 рядків або 350 символів) з градієнтним фейдом.
  * [x] Copy Body кнопка з toast-підтвердженням.
  * [x] Відображення помилок мережі (Network Error card) з описом.

* [x] **Assertion Engine (вкладка "Tests"):**
  * [x] Валідація коду статусу (`Status == 200`, `Status != 404`, `Status > 300`, `Status < 500`).
  * [x] Валідація часу виконання (`Latency < 500ms`).
  * [x] Перевірка наявності та вмісту заголовків (Header contains, equals, regex).
  * [x] Перевірка входження підрядка в тіло відповіді (`bodyContains`).
  * [x] Валідація наявності кореневого та вкладеного ключа в JSON (`jsonKeyExists`, підтримка dot-notation та array index syntax).
  * [x] Валідація конкретних значень у JSON за крапковим шляхом (`jsonValue`) — equals, notEquals, contains, greaterThan, lessThan, regexMatch.
  * [x] 6 типів порівнянь (`==`, `!=`, `contains`, `>`, `<`, `matches regex`).
  * [x] Quick-add кнопки для швидкого додавання assertions (Status 200, Key 'title', JSON 'id' == 1, Time < 1000ms, Body contains).
  * [x] Автоматичне заповнення defaults при зміні assertion target.
  * [x] Відображення результатів assertions з passed/failed статусом та failure reason.

* [x] **Локальне сховище (SwiftData):**
  * [x] 8 SwiftData entities: `SDCollection`, `SDRequest`, `SDRequestParameter`, `SDTestAssertion`, `SDExecutionResult`, `SDAssertionLog`, `SDEnvironment`, `SDEnvironmentVariable`.
  * [x] Cascade delete правила для всіх зв'язків.
  * [x] Автоматичний fallback: видалення corrupted SQLite store → retry → in-memory fallback.
  * [x] Seed data при першому запуску: starter Environment + starter Collection з 2 запитами та assertions.

* [x] **Колекції (вкладка "Collections"):**
  * [x] Створення, редагування (назва, опис) та видалення колекцій.
  * [x] Збереження запитів до колекції (з Request Builder, History, або RequestDetailView).
  * [x] Список запитів у колекції з MethodBadge та StatusBadge останнього виконання.
  * [x] Додавання нових запитів безпосередньо в колекцію (New Request sheet).
  * [x] Swipe-to-delete, swipe-to-open-in-builder, context menu.
  * [x] **Collection Runner** — послідовне виконання всіх запитів колекції з прогрес-баром та зведенням (Passed/Failed).
  * [x] **Експорт колекцій** у JSON (копіювання в буфер обміну) з повними headers, params, assertions.
  * [x] **Імпорт колекцій** з JSON (paste або Load Sample) з повною реконструкцією запитів.

* [x] **Історія виконань (вкладка "History"):**
  * [x] Автоматичне збереження кожного виконаного запиту як history item з усіма параметрами.
  * [x] Пошук за назвою та URL.
  * [x] Фільтрація за статусом (All / 2xx Success / Errors 4xx+5xx).
  * [x] Фільтрація за HTTP-методом (All Methods / конкретний).
  * [x] Відображення метрик: latency pill, size pill, test assertions indicator.
  * [x] Open in Builder — завантаження запиту з історії у Request Builder.
  * [x] Save to Collection — збереження запиту з історії у вибрану колекцію.
  * [x] Clear All History з підтвердженням.

* [x] **Змінні середовища (вкладка "Environments"):**
  * [x] Створення та видалення оточень (Environment).
  * [x] Редагування назви та статусу (активне/неактивне) через Edit Sheet.
  * [x] Радіо-кнопка активації (тільки одне активне оточення).
  * [x] Swipe-to-activate, swipe-to-edit, swipe-to-delete, context menu.
  * [x] CRUD для змінних у оточенні (key-value editor, inline editing з auto-save).
  * [x] Підстановка змінних виду `{{base_url}}` у URL, Headers, Body, Auth tokens.
  * [x] Підтримка percent-encoded шаблонів (`%7B%7Bkey%7D%7D`).
  * [x] Банер активного оточення у Request Builder.
  * [x] Auto-seed при створенні — `base_url` зі значенням залежно від назви.

* [x] **Request Execution Service (Centralized Use Case):**
  * [x] Єдина точка виконання запитів для Builder, Collection Runner, RequestDetailView.
  * [x] Резолвінг змінних → побудова URLRequest → виконання через `NativeNetworkClient.shared` (actor) → оцінка assertions → збереження `SDExecutionResult` + `SDAssertionLog` → опціональне створення history copy.

* [x] **Навігація та UX:**
  * [x] 4-tab TabView: Requests, Collections, History, Environments.
  * [x] AppNavigationState (singleton `@Observable`) для cross-tab навігації (openInBuilder).
  * [x] Unsaved changes alerts з опціями Save / Discard / Cancel.
  * [x] Toast notifications для cURL copy, save to collection.
  * [x] Haptic feedback (impact, notification) на ключових діях.
  * [x] Keyboard dismissal: `.scrollDismissesKeyboard(.interactively)`.
  * [x] Locale forced to `en_US` для консистентного форматування.

* [x] **UI-компоненти (Presentation/Common):**
  * [x] `MethodBadgeView` — кольоровий бейдж HTTP-методу (7 кольорів).
  * [x] `StatusBadgeView` — іконка + код статусу + опціональний текстовий опис (17 конкретних кодів + fallback groups).
  * [x] `JSONSyntaxView` — повнофункціональний JSON/XML/HTML viewer з header bar, search, wrap, expand/collapse, copy.
  * [x] `DeselectableURLField` — UITextView-based кастомний URL field з авто-розміром, placeholder, scroll coordination.
  * [x] `TelegramKeyboardPasteBarView` — Telegram-style paste accessory.
  * [x] `ClipboardPreviewInfo` — розпізнавання вмісту буферу обміну (URL, JSON, cURL, plain text) з іконками та субтитрами.

* [x] **Мережевий клієнт (`NativeNetworkClient`):**
  * [x] Swift `actor` для thread safety.
  * [x] Автоматичне додавання `https://` якщо протокол не вказано.
  * [x] Обробка Query Items через `URLComponents`.
  * [x] Auto Content-Type: `application/json`, `application/x-www-form-urlencoded`, `multipart/form-data` (з автоматичним визначенням boundary).
  * [x] Таймаути: request 30s, resource 60s.
  * [x] Парсинг response headers, cookies, body → `NetworkResponse`.
  * [x] Error handling з duration tracking навіть при помилці.

* [x] **Модульне тестування (Swift Testing):**
  * [x] Таргет `APICraftTests` з **28 автоматизованими юніт-тестами** у 11 test suites (100% успішне проходження).

---

### Етап 2: Масштабування для дипломної роботи
*Ціль: Комплексна QA-платформа автоматизованого тестування, моніторингу надійності та стрес-аналізу REST API.*

* [ ] **Розширений Assertion Engine:**
  * Синтаксис **JSONPath** для перевірки вкладених об'єктів (наприклад, `$.users[0].email`).
  * Валідація за схемою **JSON Schema Draft 7/2020-12**.
  * Валідація форматів за допомогою регулярних виразів (RegEx: UUID, ISO Date, Email).
* [ ] **Ланцюжки запитів (Request Chaining & Workflows):**
  * Автоматичний екстракт значень з відповіді (наприклад, JWT-токен) у змінну середовища для наступних запитів.
  * Послідовне або умовне виконання запитів у колекції (Flow / Scenario Runner).
* [ ] **Фаззинг-тестування та генерація даних (Fuzzing Engine):**
  * Генерація мутацій вхідних параметрів (SQLi, XSS, Null-byte, Boundary values, Overflow strings).
  * Синтетичний генератор даних (Faker: імена, телефони, випадкові UUID).
  * Автоматичне виявлення аномальних відповідей сервера (500 Error, Leaks).
* [ ] **Інтеграція та сумісність:**
  * Імпорт специфікацій **OpenAPI 3.0 / Swagger** з автоматичною побудовою колекції запитів.
  * Імпорт/експорт колекцій Postman v2.1 (JSON).
  * Експорт запитів у команду `cURL`.
* [ ] **Аналітика та експорт звітів:**
  * Збір метрик `URLSessionTaskMetrics` (TCP handshake, TLS time) з графіками у **Swift Charts**.
  * Експорт звітів тестування у форматах **JUnit XML** та **HTML Report** (для інтеграції з CI/CD).

---

## 5. Файлова структура проєкту

```text
APICraft/
├── App/
│   ├── APICraftApp.swift               — @main entry point, ModelContainer, SplashScreen
│   └── MainTabView.swift               — 4-tab TabView, AppNavigationState, seed data
├── Data/
│   ├── Network/
│   │   └── NativeNetworkClient.swift   — actor-based URLSession HTTP client
│   └── Storage/
│       └── Entities/
│           ├── SDAssertionLog.swift     — @Model: assertion execution log
│           ├── SDCollection.swift       — @Model: collection of requests
│           ├── SDEnums.swift            — HTTPMethodType, BodyType, AssertionComparison, AssertionTarget, ParameterLocation
│           ├── SDEnvironment.swift      — @Model: environment + SDEnvironmentVariable
│           ├── SDExecutionResult.swift  — @Model: request execution result with metrics
│           ├── SDRequest.swift          — @Model: HTTP request definition
│           ├── SDRequestParameter.swift — @Model: key-value parameter (header/query/form)
│           └── SDTestAssertion.swift    — @Model: test assertion definition
├── Domain/
│   ├── Engine/
│   │   ├── AssertionEngine.swift        — assertion evaluation logic + RequestExecutionService
│   │   └── VariableResolver.swift       — {{variable}} interpolation + CURLParser + CURLGenerator
│   └── Models/
│       └── NetworkResponse.swift        — NetworkResponse, ResponseCookie, ClipboardPreviewInfo
├── Presentation/
│   ├── Collections/
│   │   ├── CollectionsListView.swift    — collections list, import/export, EditCollectionSheet
│   │   ├── CollectionDetailView.swift   — collection detail, CollectionRunnerView
│   │   └── RequestDetailExecutionView.swift — request detail with execution & save-to-collection
│   ├── Common/
│   │   ├── DeselectableURLField.swift   — UIViewRepresentable custom URL text view
│   │   ├── JSONSyntaxView.swift         — JSON viewer + keyboard extensions + paste bar
│   │   ├── MethodBadgeView.swift        — HTTP method color badge
│   │   └── StatusBadgeView.swift        — HTTP status code badge with icons
│   ├── Environments/
│   │   └── EnvironmentListView.swift    — environments list, detail, variables editor
│   ├── History/
│   │   └── HistoryListView.swift        — history list with search, filters, save-to-collection
│   └── RequestBuilder/
│       ├── RequestBuilderView.swift     — main request builder (1917 lines, 7 presets, 6 tabs)
│       └── RequestBuilderViewModel.swift — @Observable VM with auth, cURL, sync, send logic
├── Resources/
│   └── Assets.xcassets/                 — AppIcon, AppLogo, AccentColor
└── APICraftTests/
    └── APICraftTests.swift              — 21 unit tests in 7 @Suite groups
```

---

## 6. Схема бази даних (SwiftData Entities)

```swift
import Foundation
import SwiftData

// MARK: - Enums

public enum HTTPMethodType: String, Codable, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
    
    public var id: String { rawValue }
}

public enum BodyType: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case json = "JSON"
    case formData = "Form Data"
    case urlEncoded = "x-www-form-urlencoded"
    
    public var id: String { rawValue }
}

public enum AssertionComparison: String, Codable, CaseIterable, Identifiable {
    case equals = "=="
    case notEquals = "!="
    case contains = "contains"
    case greaterThan = ">"
    case lessThan = "<"
    case regexMatch = "matches regex"
    
    public var id: String { rawValue }
}

public enum AssertionTarget: String, Codable, CaseIterable, Identifiable {
    case statusCode = "Status Code"
    case responseTime = "Response Time (ms)"
    case header = "Header"
    case bodyContains = "Body Contains"
    case jsonKeyExists = "JSON Key Exists"
    case jsonValue = "JSON Value"
    
    public var id: String { rawValue }
}

public enum ParameterLocation: String, Codable, CaseIterable, Identifiable {
    case header = "Header"
    case query = "Query"
    case formField = "Form Field"
    
    public var id: String { rawValue }
}
```

### 6.1. ER-діаграма (Entity-Relationship)

```
SDEnvironment (1) ──── cascade ────▸ (*) SDEnvironmentVariable
SDCollection  (1) ──── cascade ────▸ (*) SDRequest
SDRequest     (1) ──── cascade ────▸ (*) SDRequestParameter
SDRequest     (1) ──── cascade ────▸ (*) SDTestAssertion
SDRequest     (1) ──── cascade ────▸ (*) SDExecutionResult
SDExecutionResult (1) ─ cascade ───▸ (*) SDAssertionLog
```

---

## 7. Статистика проєкту

| Метрика | Значення |
|---------|----------|
| Мова | Swift 5.9+ |
| Файли `.swift` | 26 |
| Загальна кількість рядків коду | ~6,500+ |
| SwiftData entities | 8 |
| UI-екранів (Views) | 15+ (включно з sheets, alerts, runners) |
| Автоматизованих тестів | 28 юніт-тестів у 11 @Suite |
| HTTP-методів | 7 (GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS) |
| Типів авторизації | 4 (None, Bearer, Basic, API Key) |
| Типів assertions | 6 (StatusCode, ResponseTime, Header, BodyContains, JSONKeyExists, JSONValue) |
| Типів порівнянь | 6 (==, !=, contains, >, <, regex) |
| Вбудованих presets | 7 (з готовими assertions) |
| Body types | 4 (None, JSON, Form Data, URL Encoded) |

---

## 8. Огляд тестового покриття

### 8.1. Test Suites (`APICraftTests.swift`)

| # | Suite | Кількість тестів | Опис |
|---|-------|-----------------|------|
| 1 | `VariableResolverTests` | 4 | Інтерполяція змінних: single, multiple, unmatched placeholder, empty map |
| 2 | `CURLParserTests` | 4 | Парсинг GET/POST cURL (JSON та urlencoded body), генерація cURL з headers та body |
| 3 | `AssertionEngineTests` | 5 | StatusCode, ResponseTime, Header (case-insensitive, regex, notEquals), Body (contains, notEquals, regex), JSON Key (nested, array), JSON Value (string, number, regex) |
| 4 | `HTTPMethodAndModelTests` | 3 | Перевірка всіх 7 HTTP-методів, BodyType rawValues, AssertionComparison cases |
| 5 | `ResponseCookieTests` | 1 | Маппінг властивостей ResponseCookie |
| 6 | `CollectionPersistenceTests` | 1 | In-memory SwiftData: saveToCollection через ViewModel |
| 7 | `RealWorldDataTests` | 4 | Encoded variables, JSONPlaceholder assertions, ClipboardPreviewInfo, SwiftData integration |
| 8 | `URLSyncAndDecodingTests` | 3 | Cyrillic sync, percent-decode, arbitrary paste protection |
| 9 | `AuthCURLExportTests` | 3 | cURL export з Bearer/Basic auth, cURL import Bearer parsing |
| 10 | `FormattingAndTitleTests` | 2 | JSON prettify, resolveTitle host+path extraction |
| 11 | `JSONPathEdgeCaseTests` | 3 | Empty path, whitespace path, root-level array lookup |

**Загалом: 28 тестів у 11 @Suite** (оновлено з 14 до 28).
