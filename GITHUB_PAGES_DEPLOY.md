# Deploy to GitHub Pages - Step by Step

This is the **simplest and most reliable** method for Flutter web apps!

## ⚠️ IMPORTANT: Change GitHub Pages Source Setting!

Before anything else, you need to change your GitHub Pages source:

1. Go to your repository → **Settings** → **Pages**
2. Under "Source", change from **"Deploy from a branch"** with `/docs` folder
3. To: **"GitHub Actions"** (this will use the workflow file)
4. Click **Save**

This will stop the Jekyll build error!

---

## Step 1: Create GitHub Repository

1. Go to **https://github.com/new**
2. Repository name: `spotto-prototype` (or any name)
3. Make it **PUBLIC** (required for free GitHub Pages)
4. **Don't** check "Add a README file"
5. Click "Create repository"

## Step 2: Upload Your Files

You have two options:

### Option A: Using GitHub Web Interface (Easiest!)

1. After creating the repo, you'll see a page with upload instructions
2. Click **"uploading an existing file"**
3. **Drag and drop ALL files from `build/web` folder** into the upload area
   - Select all files: `index.html`, `main.dart.js`, `flutter.js`, `assets/`, `canvaskit/`, `icons/`, etc.
   - Make sure to include the `_redirects` file too!
4. Scroll down, add commit message: "Deploy Spotto app"
5. Click "Commit changes"

### Option B: Using Git (If you have Git installed)

```bash
cd build/web
git init
git add .
git commit -m "Deploy Spotto"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/spotto-prototype.git
git push -u origin main
```

## Step 3: Enable GitHub Pages

1. Go to your repository on GitHub
2. Click **Settings** (top menu)
3. Scroll down to **Pages** (left sidebar)
4. Under "Source":
   - Select **"Deploy from a branch"**
   - Branch: **main** (or master)
   - Folder: **/ (root)**
5. Click **Save**

## Step 4: Get Your Live URL

1. Wait 1-2 minutes for GitHub to build
2. Go back to **Settings > Pages**
3. You'll see: **"Your site is published at https://YOUR_USERNAME.github.io/spotto-prototype/"**
4. **Copy that URL** - that's your live prototype link!

## That's it! 🎉

Your app should be live in about 2 minutes. GitHub Pages handles Flutter routing automatically.

---

**Note:** If you see a 404 initially, wait a few minutes - GitHub needs time to process the deployment.

