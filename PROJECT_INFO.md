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
  5.1. Модульне (Unit) та інтеграційне тестування компонентів (XCTest / Swift Testing)
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
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                      Domain Layer                      │
│     (Use Cases / Interactors, Domain Entities,         │
│          Assertion Engine, Variable Resolver)          │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
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
   * Декларативне управління станом без бійлерплейту;
   * Ідеально підходить для динамічних списків параметрів (Headers, Query, Form-data).
2. **URLSession:**
   * Повна відмова від зовнішніх бібліотек (Alamofire тощо);
   * Низькорівневий контроль над `URLRequest`, потоками, SSL Pinning та збором метрик `URLSessionTaskMetrics` (TCP handshake, TLS negotiation, DNS lookup time).
3. **SwiftData:**
   * Сучасний стандарт персистентності від Apple;
   * Пряма робота з моделями у Swift через макрос `@Model`, типізовані предикати `#Predicate`, спрощена міграція.

### 3.3. Структура файлової системи та модулів

```text
APICraft/
├── App/
│   ├── APICraftApp.swift
│   └── AppConfiguration.swift
├── Domain/
│   ├── Models/                     # Чисті доменні структури (без залежності від SwiftData)
│   │   ├── HTTPMethod.swift
│   │   ├── TestAssertion.swift
│   │   └── NetworkMetrics.swift
│   ├── UseCases/                   # Бізнес-сценарії
│   │   ├── ExecuteRequestUseCase.swift
│   │   ├── ValidateAssertionsUseCase.swift
│   │   └── ResolveEnvironmentUseCase.swift
│   └── Engine/                     # Рушій тестування
│       ├── AssertionEngine.swift
│       └── VariableResolver.swift
├── Data/
│   ├── Storage/                    # SwiftData @Model сутності
│   │   ├── Entities/
│   │   │   ├── SDCollection.swift
│   │   │   ├── SDRequest.swift
│   │   │   ├── SDEnvironment.swift
│   │   │   └── SDTestResult.swift
│   │   └── Repositories/
│   │       ├── RequestRepository.swift
│   │       └── EnvironmentRepository.swift
│   └── Network/                    # Мережевий шар
│       ├── NativeNetworkClient.swift
│       ├── NetworkLogger.swift
│       └── MetricsCollector.swift
├── Presentation/
│   ├── Common/                     # Перевикористовувані компоненти UI
│   │   ├── KeyValueRowView.swift
│   │   ├── SyntaxHighlightedText.swift
│   │   └── StatusBadgeView.swift
│   ├── RequestBuilder/             # Конструктор запиту
│   │   ├── RequestBuilderView.swift
│   │   └── RequestBuilderViewModel.swift
│   ├── ResponseViewer/             # Перегляд та аналіз відповіді
│   │   ├── ResponseViewerView.swift
│   │   ├── JSONFormattingView.swift
│   │   └── ResponseHeadersView.swift
│   ├── Collections/                # Керування колекціями
│   │   ├── CollectionsListView.swift
│   │   └── CollectionDetailView.swift
│   ├── Environments/               # Змінні оточення
│   │   ├── EnvironmentListView.swift
│   │   └── EnvironmentEditView.swift
│   └── TestRunner/                 # Запуск тестів та перегляд статусів
│       ├── TestRunnerView.swift
│       └── TestRunnerViewModel.swift
└── Utilities/
    ├── JSONParser.swift
    ├── Extensions/
    └── Mocks/
```

---

## 4. Roadmap розробки (Feature-лист)

### Етап 1: MVP для курсової роботи
*Ціль: Автономний, стабільний HTTP-клієнт з локальним збереженням, редактором запитів та базовою перевіркою відповідей.*

* [ ] **Request Builder:**
  * Вибір методів: `GET`, `POST`, `PUT`, `DELETE`, `PATCH`.
  * Редагування URL, Query Parameters та Headers (key-value інтерфейс з перемикачами активності).
  * Редагування Body: `none`, `raw JSON`, `x-www-form-urlencoded`.
* [ ] **Response Inspector:**
  * Відображення HTTP-статусу, часу відгуку (ms) та розміру (bytes/KB).
  * Перегляд заголовків відповіді (Response Headers) та Cookies.
  * Форматування JSON (Prettify) та синтаксичне підсвічування.
* [ ] **Локальне сховище (SwiftData):**
  * Історія останніх виконаних запитів.
  * Створення та структурування колекцій/папок.
  * Збереження запитів з історії у колекції.
* [ ] **Змінні середовища (Environments):**
  * Створення та перемикання активного оточення (`Dev`, `Stage`, `Prod`).
  * Підстановка змінних виду `{{base_url}}` у URL, Headers, Body.
* [ ] **Базовий Assertion Engine:**
  * Валідація коду статусу (`Status == 200`).
  * Валідація часу виконання (`Latency < 500ms`).
  * Перевірка наявності кореневого ключа в JSON.

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

## 5. Схема бази даних (SwiftData Entities)

```swift
import Foundation
import SwiftData

// MARK: - Enums

public enum HTTPMethodType: String, Codable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
}

public enum BodyType: String, Codable {
    case none
    case json
    case formData
    case urlEncoded
}

public enum AssertionComparison: String, Codable {
    case equals
    case notEquals
    case contains
    case greaterThan
    case lessThan
    case regexMatch
}

public enum AssertionTarget: String, Codable {
    case statusCode
    case responseTime
    case header
    case jsonBodyPath
}

public enum ParameterLocation: String, Codable {
    case header
    case query
    case formField
}

// MARK: - Entities

@Model
final class SDCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var details: String?
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \SDRequest.collection)
    var requests: [SDRequest] = []
    
    init(name: String, details: String? = nil) {
        self.id = UUID()
        self.name = name
        self.details = details
        self.createdAt = Date()
        self.updatedAt = Date()
        self.requests = []
    }
}

@Model
final class SDRequest {
    @Attribute(.unique) var id: UUID
    var title: String
    var urlTemplate: String
    var method: HTTPMethodType
    var bodyType: BodyType
    var rawBodyContent: String?
    var isHistoryItem: Bool
    var createdAt: Date
    
    var collection: SDCollection?
    
    @Relationship(deleteRule: .cascade)
    var keyValues: [SDRequestParameter] = []
    
    @Relationship(deleteRule: .cascade)
    var assertions: [SDTestAssertion] = []
    
    @Relationship(deleteRule: .cascade, inverse: \SDExecutionResult.request)
    var executionHistory: [SDExecutionResult] = []
    
    init(
        title: String,
        urlTemplate: String,
        method: HTTPMethodType = .get,
        bodyType: BodyType = .none,
        rawBodyContent: String? = nil,
        isHistoryItem: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.urlTemplate = urlTemplate
        self.method = method
        self.bodyType = bodyType
        self.rawBodyContent = rawBodyContent
        self.isHistoryItem = isHistoryItem
        self.createdAt = Date()
    }
}

@Model
final class SDRequestParameter {
    @Attribute(.unique) var id: UUID
    var key: String
    var value: String
    var isEnabled: Bool
    var location: ParameterLocation
    
    init(key: String, value: String, isEnabled: Bool = true, location: ParameterLocation) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
        self.location = location
    }
}

@Model
final class SDTestAssertion {
    @Attribute(.unique) var id: UUID
    var target: AssertionTarget
    var keyPath: String?
    var comparison: AssertionComparison
    var expectedValue: String
    var isEnabled: Bool
    
    init(
        target: AssertionTarget,
        keyPath: String? = nil,
        comparison: AssertionComparison,
        expectedValue: String,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.target = target
        self.keyPath = keyPath
        self.comparison = comparison
        self.expectedValue = expectedValue
        self.isEnabled = isEnabled
    }
}

@Model
final class SDExecutionResult {
    @Attribute(.unique) var id: UUID
    var statusCode: Int
    var responseDurationMs: Double
    var responseBodySize: Int
    var responseBody: String?
    var responseHeadersData: Data?
    var executedAt: Date
    var isAllAssertionsPassed: Bool
    
    var request: SDRequest?
    
    @Relationship(deleteRule: .cascade)
    var assertionLogs: [SDAssertionLog] = []
    
    init(
        statusCode: Int,
        responseDurationMs: Double,
        responseBodySize: Int,
        responseBody: String? = nil,
        responseHeadersData: Data? = nil,
        isAllAssertionsPassed: Bool
    ) {
        self.id = UUID()
        self.statusCode = statusCode
        self.responseDurationMs = responseDurationMs
        self.responseBodySize = responseBodySize
        self.responseBody = responseBody
        self.responseHeadersData = responseHeadersData
        self.executedAt = Date()
        self.isAllAssertionsPassed = isAllAssertionsPassed
    }
}

@Model
final class SDAssertionLog {
    @Attribute(.unique) var id: UUID
    var assertionDescription: String
    var isPassed: Bool
    var failureReason: String?
    
    init(assertionDescription: String, isPassed: Bool, failureReason: String? = nil) {
        self.id = UUID()
        self.assertionDescription = assertionDescription
        self.isPassed = isPassed
        self.failureReason = failureReason
    }
}

@Model
final class SDEnvironment {
    @Attribute(.unique) var id: UUID
    var name: String
    var isSelected: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \SDEnvironmentVariable.environment)
    var variables: [SDEnvironmentVariable] = []
    
    init(name: String, isSelected: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isSelected = isSelected
    }
}

@Model
final class SDEnvironmentVariable {
    @Attribute(.unique) var id: UUID
    var key: String
    var value: String
    var isSecret: Bool
    
    var environment: SDEnvironment?
    
    init(key: String, value: String, isSecret: Bool = false) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.isSecret = isSecret
    }
}
```

---

## 6. Стратегічні рекомендації для успішного захисту

1. **Для курсової роботи:**
   * Продемонструвати безпомилкову роботу нативних фреймворків (`SwiftUI` + `URLSession` + `SwiftData`).
   * Показати роботу з живим відкритим API (наприклад, GitHub REST API або JSONPlaceholder).
   * Продемонструвати підстановку змінних (наприклад, `{{host}}/users`) та спрацьовування асерта статусу відповіді `200 OK`.
2. **Для дипломної роботи:**
   * Підкреслити алгоритмічну новизну: фаззинг, мутаційні тести, ланцюжки залежних запитів (Request Chaining).
   * Показати експериментальні дані: графіки споживання пам'яті (Instruments) та швидкості порівняно з іншими інструментами.
   * Надати звіти у форматах JUnit XML та інтеграцію зі специфікацією OpenAPI 3.0.

