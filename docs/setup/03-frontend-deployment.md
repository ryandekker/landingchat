# Frontend Deployment Guide

This guide covers deploying the React frontend to Cloudflare Pages.

## Prerequisites

- Completed [Infrastructure Setup](./01-infrastructure.md)
- Completed [Backend Deployment](./02-backend-deployment.md)
- Backend worker deployed and accessible
- Cloudflare account
- Git repository (GitHub, GitLab, or Bitbucket)

---

## Step 1: Install Dependencies

From the repository root:

```bash
# Install all dependencies
pnpm install
```

---

## Step 2: Configure Environment

### 2.1 Development Environment

Create `.env` file in `packages/frontend/`:

```bash
cd packages/frontend
cp .env.example .env
```

Edit `.env`:

```bash
# Point to your local worker during development
VITE_API_URL=http://localhost:8787
```

### 2.2 Production Environment

For production, you'll configure this in Cloudflare Pages settings.

---

## Step 3: Test Locally

### 3.1 Start Development Server

Make sure your worker is running first (in another terminal):

```bash
# Terminal 1 - Start worker
cd packages/worker
pnpm dev
```

Then start the frontend:

```bash
# Terminal 2 - Start frontend
cd packages/frontend
pnpm dev
```

The frontend will be available at `http://localhost:5173`.

### 3.2 Test the Application

1. Open browser to `http://localhost:5173`
2. You should see the chat interface
3. Type a message and verify:
   - Message appears in chat
   - Assistant responds
   - Radar chart updates (if data available)
   - Profile summary updates

### 3.3 Test Email Capture

1. Continue conversation
2. Enter email in right panel
3. Verify email is saved (check DynamoDB)

---

## Step 4: Build for Production

```bash
cd packages/frontend
pnpm build
```

This creates an optimized production build in `dist/`.

### 4.1 Preview Production Build

```bash
pnpm preview
```

Test at `http://localhost:4173` to verify the production build works.

---

## Step 5: Deploy to Cloudflare Pages

### 5.1 Option A: Deploy via Git Integration (Recommended)

This method automatically deploys on every push.

**Setup:**

1. Push your code to GitHub/GitLab/Bitbucket
2. Go to Cloudflare Dashboard
3. Navigate to Pages
4. Click "Create a project"
5. Connect to your Git provider
6. Select your repository
7. Configure build settings:
   - **Build command:** `pnpm --filter @landingchat/frontend build`
   - **Build output directory:** `packages/frontend/dist`
   - **Root directory:** `/` (leave as root)
   - **Environment variables:**
     - `VITE_API_URL`: `https://api.yourdomain.com` (your worker URL)

8. Click "Save and Deploy"

Cloudflare will:
- Install dependencies
- Build the frontend
- Deploy to a `*.pages.dev` URL

**For Monorepo Setup:**

If using pnpm workspaces, you may need to add a `build.sh` script:

Create `packages/frontend/build.sh`:
```bash
#!/bin/bash
cd ../.. # Go to repo root
pnpm install
pnpm --filter @landingchat/frontend build
```

Then set build command to: `cd packages/frontend && sh build.sh`

### 5.2 Option B: Deploy via Wrangler CLI

**Install Wrangler:**
```bash
pnpm add -g wrangler
```

**Login:**
```bash
wrangler login
```

**Deploy:**
```bash
cd packages/frontend
pnpm deploy
```

This uploads the `dist/` directory to Cloudflare Pages.

---

## Step 6: Configure Custom Domain

### 6.1 Add Custom Domain

In Cloudflare Pages:
1. Go to your project
2. Click "Custom domains"
3. Click "Set up a custom domain"
4. Enter your domain: `app.yourdomain.com`
5. Cloudflare will automatically configure DNS

### 6.2 Verify DNS

Check DNS has propagated:
```bash
dig app.yourdomain.com
```

You should see a CNAME record pointing to your Pages deployment.

---

## Step 7: Configure Production Environment Variables

### 7.1 Update Backend CORS

Update your worker's `ALLOWED_ORIGINS` secret:

```bash
cd packages/worker
wrangler secret put ALLOWED_ORIGINS
# Enter: https://app.yourdomain.com
```

Re-deploy worker:
```bash
pnpm deploy
```

### 7.2 Update Frontend API URL

In Cloudflare Pages settings:
1. Go to Settings > Environment variables
2. Add variable:
   - **Name:** `VITE_API_URL`
   - **Value:** `https://api.yourdomain.com`
   - **Environment:** Production

3. Trigger a new deployment to pick up the change

---

## Step 8: Verify Production Deployment

### 8.1 Test All Features

Visit your production URL and test:

**Basic Chat:**
- [ ] Page loads without errors
- [ ] Can send a message
- [ ] Receives assistant response
- [ ] Messages display correctly

**Profile Tracking:**
- [ ] Radar chart appears and updates
- [ ] Profile summary shows captured info
- [ ] Progress indicator updates

**Recommendations:**
- [ ] Recommendations appear when relevant
- [ ] Can click links to recommended apps

**Email Capture:**
- [ ] Can enter email
- [ ] Email is saved (check DynamoDB)
- [ ] Confirmation shows

**Session Persistence:**
- [ ] Refresh page keeps session
- [ ] Clear localStorage resets session

### 8.2 Test Cross-Browser

Test on:
- Chrome
- Firefox
- Safari
- Edge
- Mobile browsers

---

## Step 9: Performance Optimization

### 9.1 Enable Caching

Cloudflare Pages automatically caches static assets.

For custom caching, add a `_headers` file in `public/`:

```
/*
  Cache-Control: public, max-age=31536000, immutable

/*.html
  Cache-Control: public, max-age=0, must-revalidate

/index.html
  Cache-Control: public, max-age=0, must-revalidate
```

### 9.2 Optimize Bundle Size

Check bundle size:
```bash
pnpm build
```

Review the output for large dependencies. Consider:
- Code splitting
- Lazy loading components
- Tree-shaking unused code

### 9.3 Add Analytics (Optional)

Add Cloudflare Web Analytics:

1. Go to Cloudflare Dashboard > Web Analytics
2. Create a new site
3. Get the beacon script
4. Add to `packages/frontend/index.html`:

```html
<script defer src='https://static.cloudflareinsights.com/beacon.min.js'
        data-cf-beacon='{"token": "your-token"}'></script>
```

---

## Step 10: Set Up Preview Deployments

Cloudflare Pages automatically creates preview deployments for:
- Pull requests
- Non-production branches

Access them at:
- `https://<branch-name>.<project-name>.pages.dev`

Configure different environment variables for preview deployments if needed.

---

## CI/CD Configuration

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Cloudflare Pages

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      deployments: write
    steps:
      - uses: actions/checkout@v3

      - uses: pnpm/action-setup@v2
        with:
          version: 8

      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install

      - name: Build frontend
        run: pnpm --filter @landingchat/frontend build
        env:
          VITE_API_URL: ${{ secrets.VITE_API_URL }}

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/pages-action@v1
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          projectName: landingchat
          directory: packages/frontend/dist
          gitHubToken: ${{ secrets.GITHUB_TOKEN }}
```

Add secrets to GitHub:
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `VITE_API_URL`

---

## Troubleshooting

### Build Fails

**Error: Cannot find module**
- Ensure all dependencies are in `package.json`
- Run `pnpm install` in monorepo root
- Check workspace configuration in `pnpm-workspace.yaml`

**Error: Build command failed**
- Test build locally first
- Check build logs in Cloudflare Pages
- Verify Node version compatibility

### API Connection Issues

**Error: Failed to fetch**
- Check `VITE_API_URL` is set correctly
- Verify CORS is configured in worker
- Check browser console for specific error
- Test API endpoint directly with curl

**Error: CORS policy**
- Update worker `ALLOWED_ORIGINS`
- Re-deploy worker
- Clear browser cache

### Session Not Persisting

**Issue: Session resets on refresh**
- Check localStorage is enabled in browser
- Verify `sessionId` is being saved
- Check browser console for errors

### Radar Chart Not Showing

**Issue: Chart doesn't render**
- Check if `recharts` is installed
- Verify profile data has `radar` array
- Check browser console for errors

---

## Monitoring and Maintenance

### Monitor Performance

1. **Cloudflare Analytics:**
   - Track page views
   - Monitor load times
   - Check error rates

2. **Web Vitals:**
   - Use Lighthouse for audits
   - Monitor Core Web Vitals
   - Set up alerts for regressions

### Update Dependencies

Regularly update packages:

```bash
cd packages/frontend
pnpm update --latest
pnpm build
pnpm typecheck
```

Test thoroughly before deploying updates.

---

## Rollback Procedure

### Via Cloudflare Dashboard

1. Go to Pages > Your Project
2. Click "Deployments" tab
3. Find previous successful deployment
4. Click "..." menu
5. Select "Rollback to this deployment"

### Via Git

```bash
git revert HEAD
git push
```

This triggers a new deployment with previous code.

---

## Security Best Practices

1. **Environment Variables:**
   - Never commit `.env` files
   - Use Cloudflare's environment variable management
   - Rotate API keys regularly

2. **Dependencies:**
   - Audit regularly: `pnpm audit`
   - Update vulnerable packages
   - Use lock file (`pnpm-lock.yaml`)

3. **HTTPS:**
   - Always use HTTPS in production
   - Cloudflare Pages enforces HTTPS by default

4. **Content Security Policy:**
   - Add CSP headers via `_headers` file
   - Restrict script sources
   - Monitor violations

---

## Next Steps

- [Getting Started Guide](./04-getting-started.md)
- Review [Architecture Documentation](../architecture.md)

## Support

For issues:
- Check Cloudflare Pages build logs
- Review browser console errors
- Verify environment variables
- Test API endpoints independently
