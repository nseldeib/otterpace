---
title: "More Human Coach Voice"
mode: ui
createdAt: "2026-06-26T00:00:00Z"
source: manual
---

## Summary

Retune the AI coach's voice so it reads like a sharp, caring human running coach instead of an AI assistant. Across both coach surfaces — the live model prompt in `api/coach.ts` and the deterministic on-device mock in `CoachEngine.swift` — we cut the em dashes, ask more genuine questions, and lead with kind, constructive, *direct* coaching statements. The safety rules, structured-output shape, moods, and safety flags are untouched; this is a voice change, not a behavior change.

## Key Decisions

- **Both surfaces, one voice.** The live coach (`SYSTEM_PROMPT`) and the offline/preview/scenario mock (`CoachEngine`) must sound the same, so a user never feels a tone seam between "real" and offline replies. Updating only one leaves the coach inconsistent.
- **Em dashes out, not just reduced.** Replace em dashes with periods, commas, or two shorter sentences. Em dashes are the single biggest "AI tell" in the current copy. Prefer short, declarative sentences.
- **More questions, but earned ones.** A human coach checks in: "How do the legs feel today?" / "What's the goal for this block?" Add a genuine question to most replies, but never to the injury reply (there we stay directive and safe, not inquisitive).
- **Direct + kind, not hedgy.** Lead with the call ("Take today easy."), then the why, then a check-in question. Drop filler softeners and AI-isms ("I got a little tangled", "let's keep it to…").
- **Preserve everything the tests and decoder depend on.** Keep the substrings and structure the existing tests assert on (see below) so this lands as a pure voice change with green tests.

## Implementation

### 1. Rewrite the live coach system prompt + fallback copy

**File**: `api/coach.ts`

- Rewrite the `Style` section of `SYSTEM_PROMPT` (lines ~30–32) to encode the new voice explicitly. New guidance to include:
  - Sound like a real, experienced human coach, not an AI. Never say you are an AI, never narrate your own process.
  - **Do not use em dashes (—).** Use periods or commas. Keep sentences short and declarative.
  - Lead with a clear, direct recommendation, then a short reason, then usually one genuine check-in question (e.g. how the legs feel, how sleep was, what the week's goal is). Skip the question when the moment calls for caution (pain/injury) — there, be calm and directive.
  - Kind and constructive, never hedgy or filler-heavy. No "let's keep it to", no over-apologizing.
  - Keep it to 2–4 sentences and make it specific using the provided context.
- Keep the `Hard rules` block and `mood` guidance intact (safety behavior must not change). The existing rule "Never shame the user" stays.
- Rewrite the two hardcoded fallback strings to match the new voice and drop their em dashes:
  - Refusal fallback (line ~134): currently `"I can't help with that one — let's keep it to your running and movement. What would you like to work on today?"` → something direct and warm with no em dash, e.g. `"That one's outside what I coach. Let's put it toward your running instead. What do you want to work on today?"`
  - Malformed-JSON fallback (line ~156): currently `"I got a little tangled forming that answer — mind asking again, maybe a bit more specifically?"` → e.g. `"That didn't come out right on my end. Ask me again, and try to be a little more specific?"`
- The rate-limit message (line ~70) also contains an em dash; rewrite it for consistency (e.g. `"One sec. Too many requests just now. Try again in a moment."`).
- Do **not** change `FORMAT`, the schema, moods, `safetyFlag` semantics, status codes, or any control flow. `test/api/coach.test.ts` asserts on status codes and moods, not prose, so these copy changes are test-safe.

### 2. Rewrite the mock coach reply strings

**File**: `Sources/AppCore/CoachEngine.swift`

Rewrite the `text` strings in each intent reply method to the new voice: no em dashes, direct lead, a check-in question where natural, human and warm. Keep every method's `intent`, `mood`, `safetyFlag`, and the interpolated values exactly as they are. Specifics per method:

- `injuryReply` — stays directive and calm, **no question**. Must still say it can't diagnose and must keep the word **"clinician"** (test `testInjuryReplyIsSafetyFlagged` asserts `text.lowercased().contains("clinician")` and the can't-diagnose phrasing). Remove em dashes; tighten to short sentences.
- `mileageReply` (spiking branch) — keep the interpolated `miles(l.weeklyMileage)` value. Direct caution, add a check-in question (e.g. about how recovery feels). No em dashes.
- `mileageReply` (steady branch) — reassuring and direct, end on a question. No em dashes.
- `stepsReply` (goal reached) — celebrate directly, optional light question. No em dashes.
- `stepsReply` (below goal) — keep the interpolated `formatted(remaining)`, `formatted(c.goalSteps)`, and `minutes`. Test `testStepsReplyBelowGoal` asserts the text contains **"3,600"** (the remaining-steps value), so the remaining count must stay rendered via `formatted(remaining)`. No em dashes.
- `runOrRestReply` (both branches) — lead with the call (recover today / easy run is fine), then a "how do the legs feel?" style question. No em dashes.
- `reflectionReply` (with workout) — keep the interpolated `miles(w.distanceMiles)` so the text still contains **"8.1"** in the hard-run state (test `testReflectionWithWorkout` asserts `text.contains("8.1")`). Reflective, ends on a question. No em dashes.
- `reflectionReply` (no workout) — direct and inviting, ask them to log a run and come back. No em dashes.
- `generalReply` (all three branches) — keep interpolated `formatted(remaining)` where present. Direct, human, with a check-in question. Avoid the third-person "Buddy suggests"; speak in first person like a coach. No em dashes.

Leave `CoachIntent.classify`, the structs, `ranHardRecently`, and all helpers untouched — classification and routing behavior must not change.

## Reused existing code

- `CoachEngine.reply(to:context:)` and the per-intent reply methods from `Sources/AppCore/CoachEngine.swift` (glossary entry: `CoachEngine`) — rewritten in place, same signatures and return shapes.
- `CoachIntent` from `Sources/AppCore/CoachEngine.swift` (glossary entry: `CoachIntent`) — unchanged; routing stays as-is.
- `handler` from `api/coach.ts` (glossary entry: `handler`, test `test/api/coach.test.ts`) — only `SYSTEM_PROMPT` and fallback/message copy change.
- The interpolation helpers already used in the mock (`miles`, `formatted`) — keep using them so test substrings (`3,600`, `8.1`) stay intact.
- Existing test suites `Tests/AppCoreTests/CoachEngineTests.swift` and `test/api/coach.test.ts` — both should stay green unchanged after the rewrite; they pin intent/mood/safetyFlag and a few value substrings, all of which we preserve.

## Scenarios to Demonstrate

- **Run-or-rest, fresh legs** — direct "easy run is on the table" with a how-do-the-legs-feel check-in, no em dashes, `mood: ready`.
- **Run-or-rest, after a hard run / spiking load** — directive recovery call plus a check-in question, `mood: recovery`, no safety shame.
- **Injury / pain question** — calm, directive, no question, keeps "clinician", `safetyFlag: true`, `mood: concerned`.
- **Mileage ramping too fast, spiking load** — direct caution with the weekly-mileage value and a recovery check-in, `safetyFlag: true`.
- **Steps below goal** — direct nudge naming the remaining steps (e.g. 3,600) and minutes, ends on a light question.
- **Post-run reflection with a logged run** — reflective, cites the 8.1 mi run, ends on a question, `mood: cheering`.
- **Empty / no run logged** — inviting and direct, asks them to log a run and return.
- **General check-in, goal already met** — warm, direct, first-person (no "Buddy suggests"), with a forward-looking question.
