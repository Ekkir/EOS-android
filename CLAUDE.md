# EOS — Android App

## Общее
- Название приложения: **EOS** (в интерфейсе: EOS / SYSTEM)
- Пакет: `com.traffic.app`
- Язык: Kotlin, View-based (AppCompatActivity + Fragments, без Compose)
- Min SDK: совместим с современными Android
- ADB: `M:\sdk\platform-tools\adb.exe`
- Java: `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`
- Сборка: `.\gradlew.bat assembleDebug` из `M:\Project vscode\TrafficApp`

## Сервер
- Flask, Ubuntu MacBook (сервер = MacBook Pro), SSH: `ekkir@192.168.0.15`
- Адрес: `http://192.168.0.15:5000` (локальная сеть) / `http://2.61.59.197:5000` (внешний, дефолт в prefs)
- Файл сервера: `~/traffic_server/server.py`
- Эндпоинты:
  - `GET /lights` — текущие состояния светофоров
  - `POST /reset` — сброс цикла на нужную дорогу
  - `GET /config` / `POST /config` — тайминги, порядок фаз
  - `GET /messages?since=N` — сообщения мессенджера (с ID > N)
  - `POST /messages` — отправить сообщение `{sender, text}`

## Разделы приложения
| ID | Иконка | Название | Класс |
|----|--------|----------|-------|
| home | 🏠 | Главная | HomeFragment |
| traffic | 🚦 | Светофоры | TrafficFragment |
| map | 🗺 | Карта | MapFragment |
| cameras | 📷 | Камеры | PlaceholderFragment |
| calib | 🔧 | Настройки | CalibrationFragment |
| — | 💬 | Мессенджер | MessengerFragment (через drawer) |

## Навигация
- **Нижняя панель** (BottomNav): 5 основных разделов
- **Боковой ящик** (DrawerLayout): открывается кнопкой ☰ в шапке; содержит профиль, все разделы, мессенджер
- **Профиль**: открывается по тапу на аватар (верхний левый угол)
- **Мессенджер**: только через drawer, не в bottom nav

## Темы оформления (NeuralApp-стиль)
Файл: `AppTheme.kt`, SharedPrefs ключ: `theme_id`

| ID | Название | Фон | Акцент | isGlass |
|----|----------|-----|--------|---------|
| glass | Glass | #04091C | #56D4FF | true |
| glassneon | Glass+Neon | #030010 | #CC00FF | true |
| neon | Neon | #000000 | #00FFFF | false |
| minimal | Minimal | #0C0C0C | #DDDDDD | false |

- Дефолтная тема: `glass`
- `ThemeDef` содержит: `bg, surface, nav, accent, textPrimary, textSecondary, cardBorder, isGlass`
- `hexAlpha(hex, alpha)` — цвет с прозрачностью
- `cardDrawable(theme, cornerDp, density)` — glass (LayerDrawable) или solid (GradientDrawable)
- `accentBox(theme, density, cornerDp)` — акцентный бокс для иконок

## SharedPreferences
Файл: `traffic_prefs`
- `server_url` — адрес сервера
- `theme_id` — текущая тема
- `profile_name` — имя пользователя
- `cross_{key}_lat/lon` — координаты перекрёстков на карте

## Светофоры (RoadMapView)
- Три направления: `pereval` (Перевал), `abaza` (Абаза), `zarechka` (Заречка)
- Viewpoint: с какой дороги едет пользователь
- **Офлайн-режим**: при потере связи таймер продолжает считать по `elapsed()` (секунды с последнего ответа сервера); показывает префикс `~` и баннер "● нет связи — время расчётное"
- Опрос сервера каждые 1 сек (TrafficFragment)

## Мессенджер (MessengerFragment)
- Чат между пользователями приложения
- Опрос `/messages?since=lastId` каждые 2 сек
- Пузыри: свои — справа (accent bg), чужие — слева (surface bg)
- Идентификация по `profile_name` из prefs

## Профиль (ProfileFragment)
- Аватар сохраняется в `filesDir/avatar.jpg`
- Имя сохраняется в `traffic_prefs → profile_name`

## Карта (MapFragment)
- OSMDroid (офлайн-тайлы поддерживаются)
- Долгое нажатие → установить перекрёсток
- Кнопки: центровать по GPS, скачать тайлы

## Важные особенности кода
- Фрагменты создаются один раз при старте, потом hide/show (не пересоздаются при переключении вкладок)
- `ProfileFragment` и `MessengerFragment` — через `addToBackStack`, кнопка назад закрывает их
- В `CalibrationFragment`: `renderRoads()` всегда пересоздаёт `redDisplays[key]`; EditText открепляется от старого родителя перед переиспользованием; `handler.post` блоки начинаются с `if (!isAdded) return@post`
- `DrawerLayout` — из `appcompat:1.6.1`, дополнительная зависимость не нужна

## Иконка приложения
- Генерируется скриптом: `C:\Users\razzo\AppData\Local\Temp\claude\...\scratchpad\gen_icon.py`
- Источник: `M:\Project vscode\TrafficApp\EOS.png`
- bbox кадрирования: `(40, 128, 576, 472)`
