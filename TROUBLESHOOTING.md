# GitHub Pages Deployment Troubleshooting

## Common Issues and Solutions

### Issue 1: "Page not found" or 404 Error

**Solution:**
1. Make sure GitHub Pages source is set to **"GitHub Actions"** (not "Deploy from a branch")
2. Go to: Repository → Settings → Pages → Source → Select "GitHub Actions"
3. Wait 2-3 minutes after the workflow completes

### Issue 2: Workflow Fails with "Permission denied" or "403"

**Solution:**
1. Go to: Repository → Settings → Actions → General
2. Under "Workflow permissions", select **"Read and write permissions"**
3. Check **"Allow GitHub Actions to create and approve pull requests"**
4. Click **Save**
5. Re-run the workflow (Actions tab → Click on failed workflow → Re-run)

### Issue 3: Workflow Runs But Site Shows "404"

**Solution:**
1. Check the Actions tab - make sure the workflow completed successfully (green checkmark)
2. Go to Settings → Pages - you should see a green checkmark and a URL
3. The URL format should be: `https://YOUR_USERNAME.github.io/REPO_NAME/`
4. Wait 5-10 minutes for DNS propagation
5. Try opening in incognito/private browsing mode

### Issue 4: "Jekyll build error" Still Appears

**Solution:**
The workflow should automatically add `.nojekyll` file. If you still see this:
1. Make sure the workflow file (`.github/workflows/deploy.yml`) is in your repository
2. Make sure you changed the Pages source to "GitHub Actions"
3. The old "Deploy from a branch" method will still try to use Jekyll

### Issue 5: App Loads But Shows Blank Page

**Solution:**
1. Open browser Developer Tools (F12)
2. Check the Console tab for errors
3. Common issues:
   - Missing assets (check Network tab)
   - CORS errors
   - JavaScript errors

### Issue 6: Workflow Doesn't Trigger

**Solution:**
1. Make sure you pushed to the `main` branch (not `master`)
2. Check if the workflow file is at: `.github/workflows/deploy.yml`
3. Go to Actions tab - you should see the workflow listed
4. You can manually trigger it: Actions → "Deploy Flutter Web to GitHub Pages" → "Run workflow"

## Step-by-Step Verification

1. ✅ **Workflow file exists**: Check `.github/workflows/deploy.yml` is in your repo
2. ✅ **Pages source is correct**: Settings → Pages → Source = "GitHub Actions"
3. ✅ **Workflow permissions**: Settings → Actions → General → "Read and write permissions"
4. ✅ **Workflow ran successfully**: Actions tab shows green checkmark
5. ✅ **Pages is deployed**: Settings → Pages shows green checkmark and URL

## Still Not Working?

Share these details:
1. What error message do you see? (screenshot if possible)
2. What does the Actions tab show? (screenshot of the workflow run)
3. What does Settings → Pages show?
4. What's your repository name?

