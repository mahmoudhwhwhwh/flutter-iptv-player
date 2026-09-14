# LIVE STREAM PRO - Cloudflare Backend

This is the central Cloudflare Worker and D1 Database backend for LIVE STREAM PRO.

## Architecture

- **Worker**: Handles all API requests from the Flutter App and the Admin Dashboard.
- **D1 Database**: Stores Subscriptions, Devices, Plans, and Configurations securely.

## Setup Instructions

1. Install dependencies:
   ```bash
   npm install
   ```

2. Authenticate with Cloudflare:
   ```bash
   npx wrangler login
   ```

3. Create a D1 Database:
   ```bash
   npx wrangler d1 create iptv-prod
   ```
   *Copy the `database_id` output and paste it into `wrangler.toml`.*

4. Apply the initial Database Schema:
   ```bash
   npx wrangler d1 migrations apply iptv-prod --remote
   ```

5. Deploy the Worker:
   ```bash
   npx wrangler deploy
   ```

6. Open the Admin Dashboard:
   The `dashboard/index.html` file is a standalone web panel. You can host it on Cloudflare Pages or any static host.
