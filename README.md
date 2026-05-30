# accounting

[![Firebase Deploy](https://github.com/[username]/accounting/actions/workflows/firebase-deploy.yml/badge.svg)](https://github.com/[username]/accounting/actions/workflows/firebase-deploy.yml)

Flutter web accounting application configured for Firebase Hosting deployment.

## Project status

- GitHub Actions deploy: pending setup
- Firebase Hosting target: `namsor-99e7d`

## Local setup

1. Install Flutter and confirm `flutter --version`
2. Install dependencies:

```bash
flutter pub get
```

3. Create `.env` from `.env.example`:

```bash
copy .env.example .env
```

4. Update `.env` values if needed.

5. Build and preview locally:

```bash
flutter build web --release
```

## Environment variables

Use `.env` for local development. Do not commit `.env`.

Required values:

- `APP_BASE_URL` — production web base URL
- `API_BASE_URL` — API endpoint base URL
- `FIREBASE_PROJECT` — Firebase project ID for deployment

## GitHub Actions deployment

A workflow is configured to run on push to `main` or `master`. It performs:

- checkout
- setup Flutter stable
- `flutter pub get`
- `flutter build web --release`
- deploy to Firebase Hosting with `FIREBASE_PROJECT`

The workflow uses `.env.example` as the template for CI build.

## GitHub repository setup

Replace `[username]` with your GitHub username in the repository URL below.

```bash
git remote add origin https://github.com/[username]/accounting.git
```

## GitHub Secrets

Create the following secrets in your repository settings:

- `FIREBASE_TOKEN`
- `FIREBASE_PROJECT`

Generate the Firebase token with:

```bash
firebase login:ci
```

## Push to GitHub

```bash
git init
git add .
git commit -m "Initial Flutter web Firebase project"
git branch -M main
git remote add origin https://github.com/[username]/accounting.git
git push -u origin main
```

## Manual deploy

If you need to deploy manually, run:

```bash
firebase deploy --only hosting --project <your-firebase-project>
```
