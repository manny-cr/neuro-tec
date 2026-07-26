# Neurotech

An AI-powered **second brain** built for Jac Hacks — capture thoughts, watch them wire into a living knowledge graph, and see skills form from what you remember.

Mobile-first UI with a desktop iPhone preview. Brain hero art, cinematic graph map, skills, and profile.

## Features

| Tab | What it does |
|-----|----------------|
| **Brain** | Hero brain visual + recent thoughts. Tap the brain to open the graph. |
| **Graph** | Force-directed knowledge map — thoughts as nodes, skills as hubs, typed edges. |
| **Capture** | Quick-add a thought (optional category). Auto-links related memories. |
| **Skills** | Mastery emerges from thoughts that feed each skill — nothing entered by hand. |
| **Profile** | Identity snapshot, brain stats, erase. |

## Stack

- **[Jac](https://www.jaseci.org/)** — fullstack language (server walkers + React client)
- React 18 + Vite
- Object-spatial graph on the server (`Thought`, `Link`, `Builds` edges)

## Run locally

Requires the Jac CLI (`jac` on your `PATH`).

```bash
cd neurotech_
jac start --dev main.jac
```

Open the **App** URL printed in the terminal (often `http://localhost:8010/` if lower ports are busy).

Useful commands:

```bash
jac check .          # type-check
jac guide            # list language guides
```

## Project layout

```
main.jac              # entry — mounts client app, registers server
endpoints.sv.jac      # graph model, LoadBrain, create/delete/seed
frontend.cl.jac       # app shell + tabs
frontend.impl.jac     # async handlers
components/           # BrainHome, Graph, Skills, Composer, …
assets/brain.png      # Brain-tab hero (replace with teammate art anytime)
global.css            # design system + iPhone frame
```

## Brain hero asset

Place or replace the visual at:

```
assets/brain.png
```

Served as `/static/assets/brain.png`. Dark background works best in the void stage.

## Demo data

From an empty Brain tab, use **Load demo data** to seed a sample graph (thoughts, links, skills).

## License

Jac Hacks project — team use.
