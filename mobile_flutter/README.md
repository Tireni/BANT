# BANT Mobile (Flutter / Android first)

This is a separate Flutter application. It does not replace the existing BANT web app.

## Separation
- Existing web app remains unchanged.
- Android app lives only in `mobile_flutter/`.
- Mobile business traffic uses `mobile-api`.
- Mobile voice credentials use `mobile-livekit-token`.
- Web and Android share the same Supabase database so rooms, users, messages, friendships and moderation stay synchronized.

## Run
```powershell
cd mobile_flutter
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Google OAuth redirect for Android:
```
bant://auth-callback
```

Deploy mobile-only Edge Functions:
```powershell
npx supabase functions deploy mobile-api
npx supabase functions deploy mobile-livekit-token
```
