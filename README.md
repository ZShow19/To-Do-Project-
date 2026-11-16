# Свой день

Локальное desktop-приложение для задач, продуктивности и питания.

## Структура

- `frontend/` — Flutter/Dart приложение для Windows с адаптивной оболочкой.
- `backend/Todo.Api/` — ASP.NET Core Web API на .NET 8.
- `backend/TodoApp.sln` — solution backend.
- SQLite используется по умолчанию; провайдер меняется через `DatabaseProvider` в `backend/Todo.Api/appsettings.json`.

## Запуск backend

```powershell
$env:DOTNET_CLI_HOME = "$pwd/.dotnet_home"
$env:APPDATA = "$pwd/.appdata"
$env:NUGET_PACKAGES = "$pwd/.nuget_packages"
dotnet run --project backend/Todo.Api/Todo.Api.csproj --urls http://localhost:5107
```

## Запуск Flutter

В отдельном терминале из `frontend/`:

```powershell
$env:APPDATA = "$pwd/../.appdata"
../flutter/bin/flutter.bat pub get
../flutter/bin/flutter.bat run -d windows
```

Frontend подключается к API по адресу `http://localhost:5107/api`.

## Скрипты запуска

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-backend.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\run-frontend.ps1
```

## Требования для Windows-сборки

Для `flutter build windows` нужен Visual Studio Build Tools с компонентом `Microsoft.VisualStudio.Workload.NativeDesktop` и Windows 10/11 SDK.
