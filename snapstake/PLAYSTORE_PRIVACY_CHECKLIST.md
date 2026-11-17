# Play Store Privacy Checklist (Android)

Use this before submitting a production release.

## Current declared runtime-sensitive permissions

From [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml):

- CAMERA
- RECORD_AUDIO

Legacy external storage permissions were removed to reduce policy surface.

## App behavior to disclose accurately

- User-created video moments are recorded in-app.
- Recorded media is uploaded to backend storage (Supabase) when creating a moment.
- App can save a created video to the user's gallery (best effort).
- Deep links are supported for moment URLs.
- Google Sign-In is used for authentication.

## Play Console sections to align

- App content > Data safety
- Privacy policy URL
- Permissions declaration

## Quick verification before release

1. Confirm no unexpected permissions in merged release manifest:
   - `cd snapstake && ./gradlew :app:processReleaseMainManifest`
   - Inspect `build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml`
2. Confirm only expected dangerous permissions remain.
3. Ensure in-app user messaging matches actual data behavior.
4. Ensure privacy policy text matches backend usage and retention behavior.

## Notes

- Supabase anon key is publishable by design; backend RLS and rate limiting remain the core controls.
- If you add media picker or file import in future, re-review required permissions before release.
