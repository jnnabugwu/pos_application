# CLAUDE.md — Starter Architecture Guide

> A guide for starting a mobile app project with this stack: **Flutter** (app) + **Python API** (custom logic) + **Firebase** (accounts & data) + **Railway** (hosting the Python API).
>
> This is a *template* — it describes a shape for a project you haven't built yet, based on patterns that have worked well on a real, shipped app with this same stack. It's written assuming you've never written code before, so technical terms are explained the first time they show up, and there's a glossary at the bottom you can jump to any time something is unfamiliar.

---

## 1. What this is, in plain English

Every app like this needs to answer four questions:

1. **What does the user actually see and tap?** → an app built in **Flutter**, a toolkit that lets you write one app that runs on both iPhone and Android.
2. **Where do user accounts and everyday data live?** → **Firebase**, a service made by Google that gives you "sign up / log in" and a database, without you having to build or run either one yourself.
3. **Who does the "smart" work the app can't do on its own** — talking to other companies' services, doing calculations, running scheduled jobs? → a small custom **Python API** (a program that sits on the internet waiting for the app to ask it to do something, and sends back an answer). Built with a Python tool called **FastAPI**.
4. **Where does that Python program actually run, 24/7, on the internet?** → **Railway**, a hosting service. You give it your code; it keeps a computer running it for you so it's reachable from anywhere.

Put simply: **Firebase handles "who is this user and what's their data." The Python API handles "do this specific piece of work the app needs done." Railway is just the address where that Python API lives.**

You do *not* need a separate traditional database (like Postgres or MySQL) in this setup — Firebase's database (called **Firestore**) covers that. You only reach for the Python API when Firebase alone can't do the job — see [Section 7](#7-why-this-shape-the-reasoning-behind-each-choice) for exactly when that is.

---

## 2. System diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                          Flutter App                              │
│                     (iPhone / Android / Web)                      │
│                                                                    │
│   Screens & buttons  →  talk to two different places:            │
└───────────┬───────────────────────────────────┬───────────────────┘
            │                                   │
            │  1. Directly, for accounts        │  2. Through the API,
            │     & simple data                 │     for custom work
            ▼                                   ▼
┌────────────────────────────┐     ┌─────────────────────────────────┐
│          Firebase           │     │        Python API (FastAPI)      │
│  ┌────────────────────────┐ │     │        hosted on Railway         │
│  │  Firebase Auth          │ │     │                                   │
│  │  (sign up / log in /    │ │◀────│  Verifies the user's Firebase    │
│  │   log out)               │ │     │  login before doing any work     │
│  └────────────────────────┘ │     │                                   │
│  ┌────────────────────────┐ │     │  Talks to:                       │
│  │  Cloud Firestore         │ │◀────│   - Firestore (read/write data)  │
│  │  (the database)          │ │     │   - Outside services (e.g. an   │
│  └────────────────────────┘ │     │     external API, a payment      │
└────────────────────────────┘     │     provider, a scheduled job)    │
                                    └─────────────────────────────────┘
```

Two arrows leave the app on purpose:

- **Straight to Firebase** for anything simple: "log this person in," "save this note," "read this list." Firebase's own toolkit (called an **SDK** — see glossary) does this directly from the app, no custom backend involved.
- **To the Python API** only for anything Firebase can't do alone: calling another company's service, running a calculation too heavy for a phone, doing something on a schedule, or enforcing a business rule that shouldn't live on the user's device (where it could be tampered with).

---

## 3. How the project folders are organized (a monorepo)

"Monorepo" just means: **the app and the API live in the same repository (the same project folder tracked by Git), instead of two separate ones.** The benefit for a small project: when you build one feature, you can see the phone side and the server side of it in the same place, without switching between two projects.

```
your-project/
├── app/                    ← the Flutter app
│   └── lib/
│       ├── features/
│       │   └── journal/    ← example feature (see Section 4)
│       ├── core/
│       └── di/
├── backend/                ← the Python API
│   └── app/
│       ├── api/
│       ├── services/
│       └── schemas/
└── docs/                   ← notes, decisions, diagrams like this one
```

(A monorepo isn't the only option — plenty of real projects, including the app this guide is drawn from, keep the app and the API in two separate repositories instead, mainly so each side can be deployed independently. For a first solo project, one repo is simpler to reason about, so that's the default here.)

---

## 4. The Flutter app: how a feature is structured

Every feature in the app (e.g., "journal entries," "user profile," "settings") is split into three layers. This is called **clean architecture**, and the reason for splitting it up is in [Section 7](#7-why-this-shape-the-reasoning-behind-each-choice).

```
features/journal/
├── presentation/     ← what the user sees and taps
│   ├── view/          (the actual screens)
│   ├── bloc/           (see below — manages what state the screen is in)
│   └── widgets/        (reusable pieces of UI)
├── domain/            ← the "rules," with zero dependency on Flutter itself
│   ├── entities/        (plain data: a JournalEntry has text, a date, etc.)
│   └── repositories/    (a promise: "something can fetch/save entries," no detail on how)
└── data/              ← how those rules are actually fulfilled
    ├── models/           (turns raw JSON from Firestore/the API into an entity)
    ├── datasources/      (the actual Firestore or HTTP call)
    └── repositories/     (implements the promise from domain/, using the datasource)
```

**State management** uses a pattern called **Bloc**: each screen has one class describing everything about "what's going on right now" (loading? loaded? error?), and the screen listens to that class and rebuilds itself automatically when it changes. This keeps "what the button does" separate from "what's drawn on screen."

**Navigation** between screens uses a package called `go_router`, and **wiring the pieces together** (so a screen can reach a repository without constructing it by hand) uses a package called `get_it`. Both are set up once, in a single startup file, and used everywhere else.

**Error handling**: instead of a function crashing or throwing when something goes wrong (a lost connection, a bad server response), functions in `data/` and `domain/` return a value that's *either* "here's your data" *or* "here's what went wrong" (a pattern called `Result`, or `Either` in the Dart package that implements it — `dartz`). The screen then always has to explicitly handle both cases, which avoids surprise crashes.

---

## 5. The Python API: how a feature is structured

The Python side follows the same "each piece has one job" idea, just laid out as files instead of folders-per-feature:

```
backend/app/
├── api/v1/
│   └── journal.py        ← the actual URL routes (e.g. POST /journal/entries)
├── services/
│   └── journal_service.py ← the actual logic: what happens when that route is called
└── schemas/
    └── journal.py          ← the exact shape of the data going in and out
```

The rule of thumb when adding something new: **route → service → schema**, in that order. The route is deliberately "dumb" — it just receives the request and calls the service. All the real thinking happens in the service. The schema defines exactly what shape of data is allowed in and out, which is what makes the API predictable and catches mistakes early (send the wrong shape of data, and the API rejects it before any code runs).

Example — "generate a weekly summary of journal entries using an outside AI service" (something Firestore alone can't do):

```
Flutter                          Python API                  Firestore / Outside service
  │                                  │                               │
  │── POST /journal/summary ────────▶│                               │
  │   (with Firebase login token)    │── verify the token ─────────▶ │ (Firebase)
  │                                  │◀── confirmed: real user ───── │
  │                                  │── read this week's entries ─▶ │ (Firestore)
  │                                  │◀── entries ─────────────────  │
  │                                  │── send entries to the ──────▶ │ (outside AI service)
  │                                  │   outside AI service          │
  │                                  │◀── summary text ────────────  │
  │◀── {summary: "..."} ─────────────│                               │
```

---

## 6. How login works

```
Flutter App                         Python API                    Firebase
    │                                    │                            │
    │── user taps "Log in" ─────────────────────────────────────────▶│
    │◀── Firebase confirms + hands the app a token ──────────────────│
    │    (a signed, temporary proof of "this is really this user")   │
    │                                    │                            │
    │── calls the Python API, ─────────▶ │                            │
    │   attaching that token             │                            │
    │                                    │── asks Firebase: ────────▶ │
    │                                    │   "is this token real      │
    │                                    │    and unexpired?"         │
    │                                    │◀── yes, and here's ─────── │
    │                                    │    which user it is        │
    │                                    │                            │
    │◀── the API does the work and ──────│                            │
    │    replies                         │                            │
```

The app never sends a password to the Python API — only the short-lived token Firebase already issued. The Python API never stores passwords either; Firebase is the only thing that ever sees one.

---

## 7. Why this shape? (the reasoning behind each choice)

**Why Flutter for the app?**
One codebase written once runs on iPhone and Android (and web, if needed later), instead of building and maintaining two separate native apps.

**Why Firebase instead of building your own accounts + database?**
Building secure login yourself (password storage, resets, session handling) is a lot of surface area to get wrong, and a database needs a server to run on and someone to keep it backed up and secure. Firebase does both, is free at small scale, and is a managed service — meaning someone else keeps it running.

**Why have a separate Python API at all, instead of just Firebase?**
Firebase is great at storing data and knowing who's logged in, but it's not built for arbitrary custom logic: calling another company's service, doing a calculation too heavy to trust to a phone, running something on a timer, or enforcing a rule that must not be something a user could bypass by editing the app on their own device. Anything like that needs code running somewhere you control — that's what the Python API is for. If a feature is truly just "save this, read that," it can talk to Firebase directly and skip the API entirely.

**Why Railway to host the Python API?**
The API needs to run on a computer that's on all the time, reachable over the internet. Railway takes a folder of Python code and keeps it running, without needing to configure a server from scratch.

**Why split the Flutter app into presentation / domain / data layers?**
So the "business rules" (domain) don't know or care whether data comes from Firestore, the Python API, or a test double — they just describe *what* should happen. That makes the core logic testable without needing a real network connection, and makes it possible to change *how* data is fetched later without rewriting *what* the screen does with it.

**Why Bloc for state management, specifically?**
It forces "what happened" (an event, like "user tapped save") and "what's true right now" (a state, like "saving... " → "saved") to be explicit and separate from the UI code. That separation makes bugs easier to reproduce, because the whole state of a screen is one describable value at any moment.

**Why return `Result`/`Either` instead of letting errors throw?**
An uncaught error crashes the screen or leaves it stuck. Returning a value that's explicitly "success" or "failure" forces every screen to decide what the user sees in the failure case, instead of that decision being skipped by accident.

---

## 8. Glossary

- **API** — "Application Programming Interface." A way for one program to ask another program to do something and get an answer back — in this guide, the way the Flutter app asks the Python program to do work.
- **SDK** — "Software Development Kit." A ready-made toolkit a company (like Firebase) provides so you can use their service from your code without building the plumbing yourself.
- **Backend** — the part of an app that runs on a server somewhere, rather than on the user's phone. Here, that's the Python API.
- **Frontend** — the part the user directly sees and touches. Here, that's the Flutter app.
- **Repository (as in Git)** — a project folder tracked by Git, a tool that records every change made to the code over time, so nothing is ever truly lost and changes can be undone.
- **Repository (as an architecture term)** — unrelated to the Git meaning above; a class in the app whose job is "fetch or save this kind of data," hiding whether it came from Firestore, the API, or somewhere else.
- **Monorepo** — one repository containing more than one project (here, the app and the API together) instead of one repository per project.
- **State management** — the general problem of "what is true on this screen right now, and how does the screen know to update when it changes." Bloc is one way of solving it.
- **Dependency injection (DI)** — instead of a piece of code creating the things it depends on itself, those things are handed to it from the outside, from one central place. Makes it possible to swap what's handed in (e.g., a real network call vs. a fake one for testing).
- **Token / JWT** — a piece of text, cryptographically signed, that proves "this request really is from this logged-in user" without sending a password along with every request.
- **Deploy / deployment** — the act of putting code onto a real, running server (like Railway) so it's reachable from the internet, instead of only running on your own computer.
- **Environment variables** — settings (like API keys or which Firebase project to talk to) kept outside the code itself, so the same code can run in a "test" setup and a "real" setup without editing it.
