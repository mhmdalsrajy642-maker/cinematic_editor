# Model Refactor Notes

Refactored `lib/core/models/timeline_models.dart` to reduce Flutter UI coupling in domain models.

- Introduced `TextStyleDto` as a serializable text style DTO for `TextLayer.style`.
- Removed `package:flutter/material.dart` dependency from the core timeline model file.
- Kept `Equatable`, `copyWith`, `toJson`, and `fromJson` on all domain models.
- Preserved existing public field names, including `TextLayer.style`.
- Added backward-compatible JSON decoding for `TextLayer` to support both:
  - legacy flat keys: `styleColor`, `styleFontSize`, `styleFontWeight`
  - new nested `style` object.
- Added backward fallback defaults in `TimelineState.fromJson` and `AudioClip.fromJson`.

This refactor keeps editor UI behavior unchanged while allowing a future boundary conversion from `TextStyleDto` to Flutter `TextStyle` in presentation code.
