# Design QA — Inigo

Reference: selected-design.png (first displayed concept, renamed Inigo).

Observed the running native app through macOS UI automation. Onboarding renders with the intended centered title, native symbol, short explanation and primary setup button. Processing settings preserve the selected concept's sidebar structure, typography hierarchy, segmented Local/Cloud choice, model row and understated privacy footer. The system is in dark mode; the implementation uses semantic materials and colors rather than hard-coded light colors.

Exercised: onboarding completion, General/Processing/Privacy navigation, Local/Cloud switching, shortcut recording and restoring Control–Option–Space, opening Accessibility settings, loading the downloaded model. No clipping observed at the fixed 790×570 window size.

Remaining verification: a same-state light-mode comparison and the HUD/fallback/undo views during a live external-editor operation. Do not label this a completed visual QA pass until those states are observed.

final result: blocked
