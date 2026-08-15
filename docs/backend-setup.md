# Backend Setup — Quotes Reading Platform

## Prerequisites

- Firebase CLI: `npm install -g firebase-tools` (v15+ recommended)
- Node.js 20+
- A Google account with Firebase access

---

## Step 1 — Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com) → **Add project**.
2. Name it (e.g. `quotes-prod`) and disable Analytics if not needed.
3. Note the **Project ID** (e.g. `quotes-prod-a1b2c`).

---

## Step 2 — Enable Firebase Services

In the Firebase Console for your project:

### Authentication
- Go to **Authentication** → **Get started**.
- Enable **Apple** sign-in (required for iOS) and optionally **Email/Password** for testing.

### Firestore Database
- Go to **Firestore Database** → **Create database**.
- Choose **Production mode** (rules are deployed separately).
- Select a region close to your users (e.g. `asia-northeast3` for Korea).

### Cloud Functions
- Functions are enabled automatically when you deploy.
- Requires the **Blaze (pay-as-you-go)** billing plan for outbound network calls (Anthropic API).

---

## Step 3 — Set the Anthropic API Key Secret

Cloud Functions read the LLM key from Firebase Secret Manager:

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
# paste your key when prompted
```

Verify it was stored:
```bash
firebase functions:secrets:access ANTHROPIC_API_KEY
```

---

## Step 4 — Log In and Select Project

```bash
firebase login
cd main/
firebase use --add          # choose your project and give it an alias, e.g. "prod"
firebase use prod           # activate the alias
```

---

## Step 5 — Deploy

```bash
cd main/

# Deploy Firestore rules + indexes first (no billing required)
firebase deploy --only firestore

# Deploy Cloud Functions (requires Blaze plan)
firebase deploy --only functions
```

The `predeploy` hook in `firebase.json` automatically runs `npm run build` in `functions/` before deploying.

### Deploy everything at once
```bash
firebase deploy
```

---

## Step 6 — Seed Sample Content

> **Requires:** the iOS worker to have created `main/Quotes/Resources/SampleContent/`.

1. Create a service account with **Firestore → Firebase Admin SDK** role in the GCP console, download the JSON key.
2. Run the seed script:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
node main/scripts/seed.mjs --project <your-project-id>
```

The script:
- Writes collections, books, and chunks to Firestore.
- Extracts embedded per-sentence `"translations"` maps from chunk files and writes them to `translations/{bookId}/chunks/{chunkId}_{lang}` with `model: "human-sample"`.
- Exits clearly if the sample content directory is missing.

---

## Step 6b — Validate Sample Content (optional, pre-seed check)

Before seeding, confirm the JSON files conform to the schema and all sentence IDs are unique:

```bash
node main/scripts/validate-schema.mjs
```

Exits 0 on success, 1 if any schema error is found. Safe to re-run anytime.

---

## Step 7 — Verify Deployment

```bash
# Tail function logs
firebase functions:log --limit 50

# Check deployed functions
firebase functions:list
```

Call `translateChunk` from the Firebase Console **Functions → Dashboard → Test** panel or from the iOS app with a signed-in user.

---

## Environment Variables Reference

| Variable                      | Where set          | Purpose                          |
|-------------------------------|--------------------|----------------------------------|
| `ANTHROPIC_API_KEY`           | Firebase Secret Manager | Anthropic LLM API key       |
| `GOOGLE_APPLICATION_CREDENTIALS` | Shell env (seed script only) | Path to service account JSON |

---

## Local Development (optional)

```bash
cd main/functions
npm run build:watch          # recompile on change

# In another terminal:
cd main/
firebase emulators:start --only functions,firestore
```

Note: the emulator cannot access `ANTHROPIC_API_KEY` from Secret Manager by default. Set it locally:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
firebase emulators:start --only functions,firestore
```
