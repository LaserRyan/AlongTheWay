# Along the Way

A standalone, phone-friendly chronological Scripture reading tracker. Source stays in your GitHub repository, the frontend runs on Render, and Supabase supplies email/password accounts and a PostgreSQL database. No ChatGPT account is required.

## Included

- All 365 reading references imported from the supplied Blue Letter Bible PDF, including wrapped entries.
- Private groups with owner-managed invitation codes and a shared start date that can stay undecided.
- Group timezone, red overdue readings, personal completion/undo, and the same catch-up requirements for late joiners.
- Shared member status, progress bars, reading filters, and optional daily reflections with deletion of your own posts.
- Email signup, confirmation, sign-in, password reset, and device-synced progress.
- A fictional sample group to explore before sign-in; sample changes stay in memory.
- Database row-level security: group members see their group's data and only write their own progress/reflections.

The owner can change an undecided or future start date. Once the start date arrives in the group's timezone, it is fixed. Reading ahead is allowed. Today is not overdue until tomorrow. After the year ends, all outstanding days remain overdue.

## 1. Create your free Supabase project

1. Create an account at https://supabase.com and a new project. Keep its database password private.
2. Open **SQL Editor**, create a query, paste `supabase/schema.sql`, and run it once in this new project.
3. Copy the **Project URL** and **publishable key** from the project's Connect/API settings. A legacy `anon` key also works. These two values are browser-safe; database access is restricted by the SQL policies.
4. In Authentication settings, enable email/password sign-in and email confirmation. Configure **custom SMTP** so confirmations and password resets can reach your friends, not only Supabase team members. This requires your chosen email provider's credentials and sender setup. Do not commit SMTP credentials. See https://supabase.com/docs/guides/auth/auth-smtp.
5. After deploying, set Authentication's **Site URL** to your Render URL, and add that exact URL (with a trailing `/`) to **Redirect URLs**. For local development, also allow `http://localhost:5173/` or `http://127.0.0.1:5173/`, matching the address you use.

Never put a service-role/secret key or database password in the app's VITE variables, source code, or GitHub.

## 2. Run locally

Requires Node.js 20.19+ or 22.12+.

Copy `.env.example` to `.env` and fill in the URL and publishable key. Then:

```sh
npm ci
npm run dev
```

Without configuration the landing page and fictional sample work, but live sign-in is unavailable.

```sh
npm test
npm run build
```

## 3. Deploy with your GitHub and Render accounts

1. Create a GitHub repository and push this folder's source, including `package-lock.json`. `.env`, `node_modules`, and `dist` are excluded.
2. In Render, create a **Static Site** connected to that repository. Set **Build Command** to `npm ci && npm run build`, and **Publish Directory** to `dist`. Alternatively, create a Blueprint using `render.yaml`.
3. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` in Render's environment settings before building.
4. Deploy, then configure Supabase's Site URL and Redirect URLs as above.
5. Create and confirm your account, create a group, show its invitation code in Group details, and share the code privately with your friend. They sign up, confirm their email, and join using the code.

Environment changes need a new build. Render serves the app; progress lives in Supabase, not Render's filesystem. The static app can also be hosted elsewhere with the same environment variables supplied at build time.

## Verification before inviting people

Automated tests cover the PDF import, catch-up calculation, DST, start dates, and the end of the plan. A successful frontend build does not verify the live database or email service. After setup:

1. Test signup/confirmation and password reset with a second email address that is not on your Supabase project team.
2. With two accounts in one group, mark readings independently, refresh, and verify shared status. Try a past start date to see red overdue days; late joiners should see the same schedule.
3. Verify reflections appear only in their group and only their author can delete them.
4. Create a separate group with a third account. Verify that querying the first group's members/completions/reflections from the third account returns no rows, and attempts to insert progress for someone else or join by direct table insert fail.
5. Test owner-only start-date/invitation operations and verify an old invitation fails after replacement.
6. Test phone layouts, keyboard navigation, and sign-in on another device.

Progress is fetched on open, refresh, and once a minute while the group view is active and no form draft is being edited. Reflections show the latest 100 entries per reading day. Completion/member queries are paginated to avoid Supabase's default response cap. No reminders or notifications are configured.

The free Supabase project may pause after low activity for seven days. It can be restored in its dashboard. Keep periodic database exports of your group's data; this app does not configure automated backups. Check current service quotas as your groups grow.

## Plan provenance

`plan-complete.txt` is the extracted layout text from the user's `1Yr_ChronologicalPlan.pdf`; it is reference data. `python scripts/import_plan.py` regenerates `src/plan.json`. No Scripture text is embedded. The source plan's descriptive prose is not used as application instructions.
