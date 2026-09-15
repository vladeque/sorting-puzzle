# Level Time Extension

When an eligible attempt reaches `00:00`, `scripts/level.gd` pauses the existing board immediately,
plays `scenes/ui/time_up_transition.tscn`, and then opens
`scenes/ui/time_up_extension_modal.tscn` before entering terminal Failure. The transition blocks
input for its 660 ms lead-in, enlarges and shakes the HUD timer, expands a red alarm ring from the
timer, and deepens the board shade. The modal then fades/pops from 90% through a 102% overshoot to
its fitted scale while the transition shade releases, avoiding a bright frame between the two.

The supplied `assets/audio/time_up/times_up2.mp3` cue begins on the `00:00` snap and ends around the
modal settle. Terminal later expiries still proceed directly to Failure and use the failure cue;
they do not replay this recoverable-offer transition.

The modal composes the shared gameplay shell and owns only its presentation, signals, responsive
fitting, and transitions; `scripts/level.gd` owns attempt state, Shop routing, payment, timer
mutation, and Failure.

The modal's extra-time illustration is the dedicated transparent production asset
`assets/ui/time_extension_continue_icon_256x256.png`: a golden stopwatch wrapped by a green
continuation arrow. It is intentionally distinct from the Freezer ability's ice-clock artwork.

The launch-default policy lives in `configs/time_extension.json` and matches the versioned backend
economy configuration: grant 60 seconds for 500 coins, with at most one coin extension and one
rewarded-ad extension per attempt. Per-attempt counters reset when a new attempt is configured, not
when Shop or another overlay opens.

The coin action remains enabled while its attempt slot is unused. If the saved balance is below the
price, pressing it opens `scenes/ui/in_level_shop_screen.tscn` above the still-paused Time Up modal;
closing Shop restores the offer and never automatically spends newly purchased coins. A successful
request calls `PlayerProgress.spend_coins(500, "time_extension")`, grants exactly 60 seconds, and
resumes the same board. Rapid duplicate requests are locked, so payment and the offline journal are
committed once.

Rewarded ads have no provider integration yet. The approved production design intentionally keeps
the ad action visible, disabled, and labeled `Coming Soon`. Configuration alone cannot enable it:
`scripts/level.gd` also requires a separate hard integration-capability flag. Once both extension
slots are unavailable, a later timeout proceeds directly to Failure.

Verification ownership:

- `tests/gameplay/test_time_extension.gd`: offer-before-Failure, decline/life spend, paid continue,
  input-blocking transition-before-offer, duplicate-use protection, dedicated journal reason,
  second timeout, and insufficient-coins Shop round trip.
- `scripts/tools/captures/time_up_transition_setup.gd`: rendered transition keyframe at the
  supported responsive portrait resolutions.
- `scripts/tools/captures/time_up_extension_setup.gd`: rendered modal review over an active board at
  the supported responsive portrait resolutions.
