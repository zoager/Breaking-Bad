# Development Guide for AI Agents

## 1. Purpose and verified starting state

This repository is intended for **Laboratory of Chemical Experiments**, an educational Windows desktop game developed as a fourth-year Software Engineering course project for Architecture and Software Design. The intended GitHub repository is `zoager/Breaking-Bad`.

The developer is new to Godot. Explain architectural choices simply, connect each choice to a concrete problem, and provide beginner-friendly verification steps. Communicate plans, explanations, and completion reports in Ukrainian. Keep this guide and code identifiers in English; player-facing UI must be Ukrainian.

At the initial local inspection on 2026-11-06:

- The workspace was empty, including no `.git` directory, `project.godot`, scenes, scripts, data, tests, or documentation.
- Git and Godot were not found among available commands; Git was also absent from the two checked standard Program Files paths. No remote repository state was verified and no Godot tests were run.
- This guide is the only file introduced by the initial task.

These are historical observations, not permanent assumptions. Inspect the current workspace before every task. All features, module boundaries, file layout suggestions, and checks below are **requirements for future work**, not claims that they already exist.

The initial task authorizes creation of `AGENTS.md` only. Do not initialize the game, add dependencies, create other files, or begin implementation until the user gives a separate task.

## 2. Product scope and technology

- Use a stable **Godot 4** release and statically typed **GDScript**.
- When project setup is authorized, choose and record the exact stable Godot version in repository documentation. Use matching export templates. Do not silently upgrade the engine or assume that a version has already been pinned.
- Target Windows desktop with stylized cartoon 2D graphics and a side view.
- Store substance, reaction, and level definitions in JSON; validate them before use.
- Store local player saves in `user://`, never in packaged `res://` resources.
- Use Git for version control once repository setup is available and authorized.
- Keep gameplay fully local: no server, accounts, runtime network dependencies, or required online services.

There are two modes:

1. **Campaign:** five teaching levels with explicit objectives and gradual knowledge and equipment unlocks.
2. **Sandbox:** free experimentation with the substances and equipment available in that mode.

Both modes must use one shared interactive laboratory and the same mixture and chemistry rules. Mode-specific availability and objectives must be explicit data or policies, not duplicated simulation logic.

## 3. Interaction and laboratory behavior

The player must perform experiments manually: pick up and move vessels, place equipment in working zones, measure substances, pour liquids, mix components, adjust heating, measure temperature, and observe results.

- Use free dragging with appropriate Godot 2D facilities, such as `Node2D`, `Area2D`, `CollisionShape2D`, input events, and explicit drop-zone validation. Select the simplest suitable implementation when the task is authorized.
- Separate pointer movement and visual feedback from validated domain commands.
- Validate placement and transfer rules before committing state; show understandable Ukrainian feedback for rejected actions.
- Do not replace the experiment with a universal “Perform reaction” button.
- A visual animation must reflect committed simulation state. It must not independently determine quantities or reaction outcomes.

## 4. Architecture: modular monolith

Use one Godot application with clear logical module boundaries. Do not introduce separate services or a generic framework. A logical subsystem does not require an autoload, an interface hierarchy, or a directory full of empty classes.

| Subsystem | Responsibility |
| --- | --- |
| Interaction System | Interpret input, dragging, placement, and player action requests. |
| Equipment System | Represent vessels, capacity, working zones, heaters, thermometers, and equipment constraints. |
| Mixture System | Own authoritative mixture contents, solution volume, temperature, transfers, and derived concentration. |
| Chemistry Engine | Evaluate catalog-defined conditions and calculate validated reaction outcomes. |
| Reaction Catalog | Load, validate, and expose substance and reaction definitions with stable IDs and source references. |
| Campaign System | Manage five level definitions, objectives, unlocks, and campaign completion. |
| Sandbox System | Configure free experimentation and available inventory without completing campaign objectives. |
| Handbook System | Present discovered reactions and maintain discovery records separate from catalog definitions. |
| Save System | Serialize, validate, migrate when supported, and restore local player progress. |
| Visual Effects System | Translate simulation events into permitted animations, color changes, gas, precipitate, and other feedback. |

### Boundaries and dependencies

- Keep domain calculations independent of scene trees, UI widgets, mouse input, visual effects, and disk access. Plain typed GDScript classes, including `RefCounted` where useful, are sufficient.
- Let scenes and controllers adapt input into explicit domain operations. UI must not contain chemical equations, stoichiometric calculations, or reaction eligibility rules.
- Pass required collaborators explicitly. Create reusable abstractions only when they solve an actual problem.
- Use Godot signals for event notification. Emit events after a successful state change and connect them explicitly at a scene/controller composition point.
- Keep dependencies acyclic: controllers call domain modules; the chemistry engine reads validated catalog definitions and mixture snapshots; mixture ownership controls commits; effects and progress listeners consume resulting events.
- Neither chemistry nor mixture calculations may depend on campaign, sandbox, handbook, or effects. Shared progress services must not depend on UI.
- Do not add global singletons/autoloads without explaining their lifetime, ownership, and why explicit references are insufficient. Do not use them as global mutable storage by default.
- Apply SOLID pragmatically: clear responsibility and replaceable boundaries matter more than layers or design-pattern counts.

Use English `PascalCase` class names and `snake_case` method, variable, signal, and file names. Follow established Godot conventions. Once files exist, follow their verified structure; any new layout must be justified by the current task rather than treated as already present.

## 5. Chemistry model and state invariants

Build a **controlled simulator driven by a catalog of verified reactions**, not an unrestricted chemistry predictor.

### Definitions and units

- Give substances, reactions, equipment, and levels stable IDs. Resolve references during validation, not opportunistically inside UI code.
- Represent substance properties, component amounts in moles, solution volume, molar concentration, and temperature explicitly.
- Choose and document canonical units, such as mol, L, and degrees Celsius, and convert at boundaries. Concentration is `c = n / V` in mol/L for a supported solution model.
- Store component amounts and mixture volume as authoritative state; derive concentration to avoid contradictory copies. Define behavior for zero volume, undissolved components, and unsupported phases; do not divide by zero or invent a concentration.
- Document volume-additivity, mixing, heating, and phase assumptions as educational simplifications. Never silently treat them as universal physical laws.
- Use named tolerances with documented units for floating-point comparisons. Reject non-finite values and materially negative values; only clamp negligible rounding residuals under a documented policy.

### Mixture ownership and transfers

- Maintain one authoritative owner for each mixture. Views, equipment, and UI may reference it or read snapshots; they must not maintain competing mutable copies.
- Validate operations before applying them. A transfer or reaction must either commit its complete valid result or leave all affected mixtures unchanged.
- For a supported homogeneous liquid transfer, move component amounts in proportion to transferred volume. Preserve the total amount of every transferred component across source and destination when no reaction occurs.
- Define behavior for empty sources, invalid amounts, self-transfers, and insufficient capacity. Reject an invalid transfer or explicitly limit it before committing; never silently lose material.
- Never allow negative amounts, negative volume, or vessel contents above capacity. Recheck resulting capacity for any supported operation that changes volume.
- Define how pouring, mixing, and heating determine temperature using the supported model. Do not invent heat capacities, reaction enthalpies, or boiling behavior.

### Reaction evaluation and application

- Store verified balanced equations, stoichiometric coefficients, required conditions, supported phases, outputs, and permitted visual events in data. Conditions can include temperature ranges, concentrations, equipment, or catalysts only where supported and sourced.
- For each candidate reaction, validate conditions and calculate the limiting reagent from supported reactant amounts. For coefficients `nu_i`, the maximum extent is `min(n_i / nu_i)` over consumed reactants. Apply consumption and production consistently with that extent.
- Treat catalysts separately from consumed reactants. Apply the selected model's minimum quantities and comparison tolerances explicitly.
- Distinguish unsupported catalog combinations, unmet conditions, invalid data, and successful reactions. “Not supported by this simulator” must not be presented as “impossible in real chemistry.”
- Make reaction application atomic and resistant to repeated callbacks. Revalidate current state before commit, consume reactants exactly once, and emit one committed reaction event per application. Do not prevent a legitimate later experiment with fresh reactants.
- Define deterministic behavior for multiple eligible reactions. Do not rely on incidental JSON order or allow unbounded automatic reaction loops.
- Hand off validated results and semantic events to presentation code; visual effects must never mutate reaction amounts.

### Scientific integrity

- Do not invent chemical equations, physical properties, temperature thresholds, or hazardous effects. Verify proposed catalog content against credible chemistry references and record sources with the data or accompanying documentation.
- Check atom balance, and charge balance where applicable, plus coefficient positivity, references, units, and supported conditions before accepting reaction definitions.
- Explosions, smoke, and other hazardous effects are allowed only for explicitly defined scenarios. Label game-specific or educational simplifications clearly in Ukrainian.
- Do not fabricate numerical values merely to make an experiment look plausible. Surface uncertainty and leave unsupported behavior explicitly unsupported.

## 6. Catalogs, discoveries, and campaign progress

The complete reaction catalog is immutable game content. Player discoveries and campaign completion are separate mutable progress records referencing stable IDs.

- A successfully committed discovery in either mode adds its reaction to the handbook. Discovery recording must be idempotent.
- Merely attempting a reaction, previewing an eligible reaction, or playing an effect must not unlock a discovery.
- A sandbox discovery must not automatically complete a campaign level.
- Campaign completion requires the active level's objectives to be satisfied in campaign context. Record relevant mode and level context explicitly with experiment events.
- Do not use handbook membership as the sole proof that a campaign objective was completed.
- Save discoveries, campaign progress, and unlocks as distinct fields with explicit relationships.

## 7. Data validation and local saves

- Validate JSON root shapes, schema versions, required fields, types, finite numeric values, allowed ranges, unique IDs, references, and subsystem-specific invariants before use.
- Typed GDScript does not make parsed JSON trustworthy. Convert validated `Variant` values into typed domain objects at the boundary.
- Report invalid entries with a useful file/entry/field explanation. Reject invalid required content and show a clear failure state instead of running a partially broken catalog silently.
- Version the save format. Validate loaded progress and define supported migrations; do not overwrite an incompatible or corrupt save silently.
- Prefer safe replacement through a temporary file and a recoverable previous save when implementing writes. Handle I/O errors explicitly.
- Persist player state in `user://`. Do not modify shipped catalogs to store discoveries. Persist an in-progress laboratory only if a later task explicitly requires it.
- Never commit machine-local saves, credentials, generated import caches, or export binaries by accident.

## 8. Code standards

- Use typed GDScript variables, members, collections where supported by the pinned engine, function parameters, and return values, including `-> void` when appropriate.
- Keep methods small and focused; extract repeated domain logic instead of copying it between modes or scenes.
- Avoid unexplained magic numbers. Use named constants or validated data fields with clear units.
- Do not hide errors with empty handlers or silent fallbacks. Explain recoverable failures to the player and preserve actionable diagnostics for the developer.
- Comment non-obvious algorithms, equations, numerical assumptions, and educational simplifications. Avoid comments that simply restate code.
- Use Ukrainian player-facing text and English identifiers. Explain new concepts to the developer in Ukrainian without assuming prior Godot experience.
- Avoid unnecessary libraries and plugins. Explain the problem and tradeoff before proposing one; do not install dependencies outside the authorized task.

## 9. Verification and testing

Plan meaningful automated tests for each important domain module and integration checks for subsystem boundaries. Choose a test approach compatible with the pinned Godot version; do not assume a framework exists or add a plugin without justification.

Prioritize these cases:

| Area | Required checks |
| --- | --- |
| Transfers | Component conservation without reaction, proportional transfer, empty source, invalid volume, self-transfer, and no partial mutation on failure. |
| Capacity | Exact capacity boundary, overflow rejection or explicit limiting, and capacity after other volume-changing operations. |
| Concentration | Unit conversion, dilution/mixing under the supported model, zero volume, and non-finite input rejection. |
| Stoichiometry | Correct limiting reagent, exact stoichiometric amounts, excess reactant, insufficient/zero reactants, and non-negative results. |
| Reaction lifecycle | Unmet conditions, duplicate callbacks, stale evaluation, legitimate later repetition, and deterministic candidate selection. |
| Catalog | Malformed JSON, missing fields, unknown IDs, invalid coefficients/units, unbalanced equations, and unsupported schema versions. |
| Persistence | Save/load round trip, missing/corrupt/incompatible files, I/O failure, and preservation of valid progress. |
| Progress | Discoveries from both modes, repeated discovery, campaign-specific objectives, and sandbox discovery not completing campaign. |

Use small, deterministic fixtures and assertions about behavior and invariants. During reactions, test stoichiometric and elemental conservation as appropriate; individual reactant amounts are expected to change. Test transfer conservation separately from reaction consumption.

For interaction changes, also verify dragging, valid/invalid working zones, pouring, heating controls, temperature display, and Ukrainian feedback in Godot. Before delivery, verify a complete experiment in the shared lab and a Windows export when the environment supports it.

Run checks appropriate to the actual change. Report exact commands or manual steps and observed results. Never claim tests, editor checks, or Windows export succeeded unless actually performed. If Godot is unavailable, say so explicitly and identify what remains unverified; a static review is not a runtime test.

## 10. Coursework documentation

Keep the implemented design understandable enough to produce:

- A UML use-case diagram.
- A UML class diagram reflecting actual classes and relationships.
- An algorithm flowchart for a representative experiment or reaction evaluation.
- A program structure description and data model descriptions.
- A programmer guide covering setup, engine version, architecture, data editing, checks, and export.
- An operator guide covering launch, modes, controls, experiments, handbook, and saves.

Create documentation only within an authorized task. Clearly distinguish proposed design from implemented behavior. Never claim that documents, diagrams, classes, tests, or features exist without inspecting them. When documentation exists, keep affected explanations aligned with code changes.

## 11. MVP priorities and delivery planning

Target a working demonstration within 14 days of the agreed project start; no start date is assumed here. The MVP includes:

- Main menu and one shared interactive laboratory.
- Basic laboratory vessels, manual pouring, and heating.
- A catalog of 8–10 verified reactions.
- Five campaign levels and sandbox mode.
- A discovery handbook and local saves.
- A working Windows build.

Prioritize one stable, complete experiment before expanding catalog coverage and campaign content. Prefer reuse of the shared laboratory and reliable domain rules over decorative features. Split large requests into reviewable stages, each with a clear result and verification steps; do not treat this roadmap as authorization to implement it.

## 12. AI-agent workflow

1. Inspect relevant files, current instructions, and project state before each task. Inspect Git status and existing changes when Git is available; do not assume this folder is already a clone of the intended remote.
2. State a short plan in Ukrainian before making changes. Distinguish verified facts from assumptions.
3. Implement one small, complete functionality at a time within the user's scope. For a large request, propose stages and identify the current stage.
4. Preserve working modules and user changes. Do not rewrite code simply to impose a preferred style.
5. Do not add files, libraries, plugins, services, or unrelated functionality beyond what the task requires. Explain any necessary dependency proposal.
6. Do not delete user files or run destructive Git operations without confirmation. Do not publish, push, or change remotes unless authorized.
7. Validate data and enforce domain invariants at module boundaries, not just through UI restrictions.
8. Run available relevant checks. Report unavailable tools, especially Godot, and never invent successful test results.
9. After changes, explain in Ukrainian which files changed, how the result works, how to verify it in Godot where applicable, and any remaining limitations. Give exact scene names and commands only after verifying they exist.
10. Recommend the next concrete step, but do not begin a new stage outside the user's authorization.

For the initial guide-only task, inspect and verify `AGENTS.md` without creating a Godot project, scaffolding tests, or installing tools. The next proposed task is to establish the exact stable Godot version and initialize a minimal project after a separate user request.
