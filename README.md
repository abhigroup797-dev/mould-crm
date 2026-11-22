# Mould CRM

A CRM for an injection mould shop. It runs as a website on GitHub Pages and keeps its data, files and logins in your own Supabase project.

What it does:

- Product, mould, sub mould, parts and punches, with work options on each part (EDM design, EDM, Wire cut, Order, VMC and more)
- Stage tracking from Enquiry to Dispatched, due dates and overdue moulds
- File upload on each mould (drawings, CAD files, photos, videos, Excel), up to 50 MB per file
- A photo for each product, shown on the dashboard and inside each mould
- Urgent moulds with a live countdown timer to the due date and time
- Each mould and sub mould can have its own photo
- Mould type list: pick a type when you add a mould, or choose **Add new type** to put your own in the list
- Outside job work with vendor and status
- Task pad: the admin assigns tasks to an employee or a panel, and the employee marks them done
- Notifications: the admin sends a message or voice note to an employee, a panel or everyone, and sees who has read it
- Dashboard settings for the admin: shop name, process stages, extra work options, mould types and what the dashboard shows
- Admin panel, Designer panel, VMC operator panel and a panel for every other work
- Each employee logs in with an email and password and gets only their own panel: their own work, their tasks and a view of all moulds
- Roles: the admin does everything, a designer adds and updates moulds, parts, work and stages and follows up the processes set in Settings (Shaping and Grinding to start with), an operator marks only their own process done

## Files

| File | What it is |
|---|---|
| `index.html` | The CRM website |
| `config.js` | Your Supabase project URL and publishable key |
| `supabase-setup.sql` | Creates the database, login rules and file storage |

## Setup (one time)

### 1. Create the database

1. Open https://supabase.com and create a free account.
2. Click **New project**. Give it a name, set a database password and pick the region closest to you (Mumbai for India).
3. When the project is ready, open **SQL Editor**, click **New query**, paste everything from `supabase-setup.sql` and click **Run**.
4. Open **Authentication**, then **Sign In / Providers**, then **Email**. Turn **Confirm email** off and save. Without this, employees you add cannot log in until they click a link in an email.

### 2. Connect the website to the database

1. In Supabase open **Project Settings**. Copy the **Project URL** (under Data API) and the **Publishable key** (under API Keys).
2. In your GitHub repository open `config.js`, click the pencil icon, paste the two values between the quotes and commit.

Use only the publishable key. Never put the secret or service_role key in this repository.

### 3. Turn on the website

1. In the GitHub repository open **Settings**, then **Pages**.
2. Under **Build and deployment** choose **Deploy from a branch**, branch **main**, folder **/ (root)**, and save.
3. After a minute or two the site is live at `https://YOUR-USERNAME.github.io/YOUR-REPO/`.

On a free GitHub account the repository must be public for Pages to work.

### 4. Create the admin account

Open the site. The first time it asks you to create the admin account. Do this yourself straight away: the first account that is created becomes the admin.

### 5. Add employees

In the Admin panel open **Employees and panels**, click **Add employee**, and give a name, email, password and panel. Tell the employee the site link, their email and their password.

- To change a panel, pick another one in the list.
- To block someone, set their panel to **No access**.
- To change a password, click **Set password**. Passwords are never shown; they are stored encrypted by Supabase.

## Good to know

- **Free plan limits:** about 500 MB of data and 1 GB of files. A free Supabase project pauses if nobody uses it for 7 days; open the Supabase dashboard and click Restore to wake it.
- **Phone shortcut:** open the site in Chrome, tap the three dots and choose **Add to Home screen**.
- **Panel links:** add `#designer`, `#vmc`, `#edm`, `#edm-design` or `#wire-cut` to the end of the site link to open a panel directly (for the admin).
- **Data is separate:** moulds entered in the earlier Claude version are not copied here. This site starts empty.
