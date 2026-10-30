# Employee Attendance & Payroll System

React + Supabase app with JWT authentication, Admin/HR/Employee roles, employee management, attendance, leave requests, payroll PDF slips, document uploads, notifications storage, dashboard analytics, and audit logs.

## Required Commands

```powershell
npm install
Copy-Item .env.example .env.local
npm run dev
```

Open the local URL shown by Vite, usually `http://localhost:5173`.

## Supabase Setup

1. Go to your Supabase project: `https://supabase.com/dashboard/project/iurdsnaefmzhlysoxqwo`
2. Open `SQL Editor`.
3. Paste and run everything from `supabase/schema.sql`.
4. Create your first account from the app signup screen.
5. Promote that first user to admin in Supabase SQL Editor:

```sql
update public.profiles
set role = 'admin'
where email = 'your-email@example.com';
```

After that admin users can manage employees, approve leaves, generate salary slips, and view audit logs.

## Environment

The app reads these variables from `.env.local`:

```env
VITE_SUPABASE_URL=https://iurdsnaefmzhlysoxqwo.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

The anon key is safe to use in frontend code because Supabase protects data with Row Level Security. Never put a Supabase service role key in this React app.

## Code Logic

- `src/lib/supabase.js` creates one Supabase client using the project URL and anon key.
- `src/App.jsx` checks the current Supabase Auth session, loads the logged-in profile, then loads data allowed by the user's role.
- `profiles.role` controls access. Admin and HR can see management screens. Employees see only their own employee-linked records.
- `attendance` uses one row per employee per date. Employees can check in and check out for the current day.
- `leave_requests` lets employees submit leave and lets Admin/HR approve or reject pending requests.
- `salary_slips` stores monthly salary calculations. The PDF button creates a salary slip in the browser using `jsPDF`.
- `employee_documents` stores metadata while Supabase Storage bucket `employee-documents` stores the actual uploaded files.
- `notifications` stores app notifications. `fcm_tokens` stores device/browser FCM tokens so you can later send Firebase push notifications from a server or Supabase Edge Function.
- `audit_logs` are written by database triggers whenever key tables change.

## Suggested Next Commands

```powershell
npm run build
```

Use this to verify the production build after dependencies are installed.
