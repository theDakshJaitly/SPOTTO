# Quick Deployment Guide for Spotto

Your web build is ready in `build/web` folder! Here are the easiest ways to get a live link:

## Option 1: Vercel (RECOMMENDED - Works best with Flutter!)

1. Go to **https://vercel.com** and sign up/login (free, takes 30 seconds)
2. Click **"Add New Project"**
3. Drag and drop the `build/web` folder onto the page
4. Wait ~1 minute for deployment
5. You'll get a live URL like: `https://your-project.vercel.app`
6. Copy that URL and use it for your submission!

**Vercel handles Flutter routing automatically!** The `vercel.json` file is already configured.

## Option 1b: Netlify Drop (Alternative)

1. Go to **https://app.netlify.com/drop** in your browser
2. Simply **drag and drop** the `build/web` folder onto the page
3. Wait ~30 seconds for deployment
4. You'll get a live URL like: `https://random-name-123.netlify.app`
5. Copy that URL and use it for your submission!

**Note:** Make sure the `_redirects` file is in the `build/web` folder (it should be there already).

---

## Option 2: Firebase Hosting (More permanent)

If you want a more permanent solution:

1. **Install Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase:**
   ```bash
   firebase login
   ```

3. **Create a Firebase project:**
   - Go to https://console.firebase.google.com
   - Click "Add project"
   - Name it "spotto-prototype" (or any name)
   - Follow the setup wizard

4. **Initialize and deploy:**
   ```bash
   firebase init hosting
   # When asked:
   # - Use existing project: Yes
   # - Select your project
   # - Public directory: build/web
   # - Single-page app: Yes
   # - Overwrite index.html: No
   
   firebase deploy --only hosting
   ```

5. Your app will be live at: `https://your-project-id.web.app`

---

## Option 3: Vercel (Also very easy)

1. Go to **https://vercel.com** and sign up/login
2. Click "Add New Project"
3. Drag and drop the `build/web` folder
4. Deploy!
5. Get your live URL

---

## Recommended: Use Netlify Drop

For a quick submission, **Option 1 (Netlify Drop)** is the fastest - just drag and drop!

