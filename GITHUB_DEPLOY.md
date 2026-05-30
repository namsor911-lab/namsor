# GitHub Deployment for accounting

This project is configured for automatic Firebase Hosting deployment via GitHub Actions.

## 1. Create a GitHub repository

1. Go to https://github.com and sign in.
2. Click **New repository**.
3. Name the repository `accounting`.
4. Choose **Public** or **Private** as desired.
5. Do not add a README, .gitignore, or license if you plan to push an existing repo.

## 2. Add repository secrets

In your GitHub repo, open **Settings > Secrets and variables > Actions** and add:

- `FIREBASE_TOKEN`
- `FIREBASE_PROJECT`

### Generate `FIREBASE_TOKEN`

```bash
firebase login:ci
```

Copy the token output and paste it into `FIREBASE_TOKEN`.

### Set `FIREBASE_PROJECT`

Use the Firebase project ID, for example `namsor-99e7d`.

## 3. Push the project to GitHub

Replace `[username]` with your GitHub user or organization name.

```bash
cd /d d:\accounting
git init
git add .
git commit -m "Initial commit for accounting Flutter web"
git branch -M main
git remote add origin https://github.com/[username]/accounting.git
git push -u origin main
```

If you already have a remote origin, use:

```bash
git remote set-url origin https://github.com/[username]/accounting.git
git push -u origin main
```

## 4. Verify GitHub Actions

After pushing, visit:

`https://github.com/[username]/accounting/actions`

Confirm the `Firebase Deploy` workflow completes successfully.

## 5. Manual deployment

If you need to deploy manually, run:

```bash
firebase deploy --only hosting --project namsor-99e7d
```

## 6. Notes

- The CI workflow uses `.env.example` as the build template.
- Do not store `.env` in Git.
- If `.env` is accidentally tracked, remove it with:

```bash
git rm --cached .env
```
