# Replaceable onboarding illustrations

This directory is intentionally separate from the existing login, registration,
and post-registration onboarding assets.

Export the four illustration frames from the supplied Figma design as PNG files:

- intro_01.png
- intro_02.png
- intro_03.png
- intro_04.png

Recommended: transparent background, portrait illustration, 2x resolution.
Do not export text into images: editable text lives in
`lib/features/auth/presentation/pages/intro_content.dart`.

Until you add those PNGs the intro screens show built-in icon illustrations.
The actual Figma imagery is **not** included in this branch because only a
view/embed link was supplied, not exported image files.

Current flow for first-time signed-out users:
Introduction (4 slides, skippable) -> existing Welcome ->
existing pre-auth questions -> existing Register.
The "Already have an account" route still goes to existing Login.
Returning authenticated users bypass the introduction.
