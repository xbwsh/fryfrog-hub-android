# AGENTS.md - Fryfrog Hub Android

## Project Overview
Android media center client for Fryfrog Hub backend. Displays videos, music, comics, and ebooks.

## Tech Stack
- **Language**: Kotlin 2.0.21
- **UI**: Jetpack Compose + Material3
- **Networking**: Retrofit 2.11 + OkHttp 4.12 + Gson
- **Images**: Coil 2.7
- **Min SDK**: 24 (Android 7.0)
- **Target SDK**: 35

## Build Commands
```bash
./gradlew assembleDebug      # Build debug APK
./gradlew assembleRelease    # Build release APK
./gradlew lint               # Run lint checks
```

## Architecture
```
app/src/main/java/com/fryfrog/hub/
├── data/
│   ├── model/      # API response models (Models.kt)
│   ├── remote/     # Retrofit API interface + client
│   └── repository/ # Data layer (MediaRepository.kt)
├── ui/
│   ├── components/ # Reusable composables (MediaCard.kt)
│   ├── home/       # Home screen + ViewModel
│   ├── login/      # Login screen + ViewModel
│   ├── navigation/ # (reserved)
│   └── theme/      # Colors, Typography, Dimens
├── util/           # PrefsManager
├── FryfrogHubApplication.kt
└── MainActivity.kt
```

## Key Conventions

### Dimensions
All dimensions centralized in `ui/theme/Dimens.kt`. Never hardcode `.dp` or `.sp` values in composables.
```kotlin
// Use Dimens constants
Spacer(modifier = Modifier.height(Dimens.spacingLg))
RoundedCornerShape(Dimens.radiusMd)

// NOT this
Spacer(modifier = Modifier.height(16.dp))
```

### Strings
All user-facing strings in `res/values/strings.xml` (English default) and `res/values-zh/strings.xml` (Chinese). Use `stringResource(R.string.xxx)`.

### Colors & Typography
Always use `MaterialTheme.colorScheme` and `MaterialTheme.typography`. Never hardcode colors or text styles.

### API Response Format
Backend returns paginated responses:
```json
{"success": true, "data": {"content": [...], "page": 0, "size": 20, ...}}
```
Access data via: `api.getVideoSeries().data?.content`

### Image URLs
API returns relative paths (e.g., `/api/v1/video/2/cover`). Repository layer prepends base URL via `fixUrl()`.

## Backend
- **Base URL**: `http://192.168.31.127:20058`
- **Auth**: POST `/api/v1/auth/login` with `{"password": "xxx"}` returns `{"success": true, "token": "..."}`
- **Token**: `Authorization: Bearer <token>` header required for all endpoints
- **API Docs**: `http://192.168.31.127:20058/api-docs`

## Localization
- Default locale: English (`values/strings.xml`)
- Chinese: `values-zh/strings.xml`
- System auto-selects based on device language
