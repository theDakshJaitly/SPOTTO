# GitHub Pages Deployment Checklist ✅

Follow these steps **IN ORDER**:

## ✅ Step 1: Verify Workflow File is in Repository

- [ ] Go to your GitHub repository
- [ ] Check if `.github/workflows/deploy.yml` exists
- [ ] If NOT, create it:
  1. Click "Add file" → "Create new file"
  2. Type: `.github/workflows/deploy.yml`
  3. Copy the entire content from your local file
  4. Commit

## ✅ Step 2: Set GitHub Pages Source to "GitHub Actions"

- [ ] Go to: **Repository → Settings → Pages**
- [ ] Under "Source", select **"GitHub Actions"** (NOT "Deploy from a branch")
- [ ] Click **Save**
- [ ] This is CRITICAL - it stops the Jekyll error!

## ✅ Step 3: Set Workflow Permissions

- [ ] Go to: **Repository → Settings → Actions → General**
- [ ] Scroll to "Workflow permissions"
- [ ] Select **"Read and write permissions"**
- [ ] Check **"Allow GitHub Actions to create and approve pull requests"**
- [ ] Click **Save**

## ✅ Step 4: Push Your Code (If Not Already Done)

If you haven't pushed the workflow file yet:

```bash
cd C:\Users\yasha\SPOTTO
git add .github/workflows/deploy.yml
git commit -m "Add GitHub Pages deployment"
git push
```

## ✅ Step 5: Trigger the Workflow

- [ ] Go to: **Repository → Actions** tab
- [ ] You should see "Deploy Flutter Web to GitHub Pages" workflow
- [ ] If it hasn't run automatically, click on it → **"Run workflow"** → **"Run workflow"** button
- [ ] Wait 2-3 minutes for it to complete

## ✅ Step 6: Verify Deployment

- [ ] Go to: **Repository → Settings → Pages**
- [ ] You should see: **"Your site is published at https://..."**
- [ ] Click the URL to test your app
- [ ] If it shows 404, wait 5-10 minutes and try again

## ✅ Step 7: Check for Errors

- [ ] Go to: **Repository → Actions** tab
- [ ] Click on the latest workflow run
- [ ] Check all steps have green checkmarks ✅
- [ ] If any step failed (red X), click on it to see the error message

---

## Common Mistakes to Avoid ❌

1. ❌ **Don't** set Pages source to "Deploy from a branch" - this causes Jekyll errors
2. ❌ **Don't** upload files manually to `/docs` folder
3. ❌ **Don't** forget to set workflow permissions to "Read and write"
4. ❌ **Don't** use `master` branch - use `main` branch

---

## If Still Not Working

Share these screenshots:
1. Screenshot of **Settings → Pages** (showing the source setting)
2. Screenshot of **Actions** tab (showing workflow status)
3. Screenshot of any error messages

