# Digital Village Development System (డిజిటల్ గ్రామీణాభివృద్ధి వ్యవస్థ)

A complete, responsive, multilingual web application built with **React**, **Tailwind CSS**, and **Supabase** for authentication, PostgreSQL database, and private file storage.

The platform empowers farmers and villagers to report civic, water, agricultural, electrical, and infrastructure problems, while authorized village officers resolve them on the ground and district administrators maintain transparent oversight and certification.

---

## 🌟 Key Features

### 1. Multilingual Support (4 Languages)
- **Telugu (తెలుగు)**
- **English**
- **Hindi (हिंदी)**
- **Tamil (தமிழ்)**
- Interactive language selector on header, home page, and login modal.
- Native script rendering (Noto Sans Telugu, Devanagari, Tamil, and Inter fonts).
- Allows farmers to report grievances in their native language and officers to write resolution reports accordingly.

### 2. Phone OTP Authentication & Secure Role Resolution
- OTP-based phone authentication with India country code `+91`.
- **Intended Staff Accounts:**
  - **👑 Administrator:** `+91 9701853520`
  - **🛠️ Village Officer 1:** `+91 8341144896` (Civil & Irrigation PDO)
  - **🛠️ Village Officer 2:** `+91 9705007232` (Water Supply & Sanitation EO)
- **Security Protections:**
  - Phone numbers are intended assignments, not authentication credentials by themselves.
  - Verification of OTP is strictly enforced.
  - User roles are stored in a protected database table (`user_roles`) and verified on the server.
  - Ordinary users **cannot** choose Admin or Officer roles during registration (only Farmer or Villager).
  - Supabase service-role keys are never exposed in frontend code.
  - Automatic role-based routing upon login:
    - Admin → **Admin Dashboard** (`/admin`)
    - Officer → **Officer Dashboard** (`/officer`)
    - Farmer/Villager → **Citizen Dashboard** (`/farmer`)
  - Clear SMS gateway status indicator: If an external SMS provider (Twilio/MessageBird) is not yet linked in Supabase, the application displays clear setup guidance with test verification (`123456`) instead of pretending an SMS was sent.

### 3. Farmer & Villager Access (Mobile-First Android Friendly)
- Clean, high-contrast, large-button UI tailored for Android mobile phones.
- Profile registration: Name, Mobile, Village, Mandal, District, User Type (Farmer / Villager).
- Problem reporting with:
  - Title and detailed description in chosen language.
  - 8 Categories: *Roads, Water Supply, Electricity, Agriculture, Drainage, Sanitation, Government Services, Other*.
  - Priority selection (*Low, Medium, High, Urgent*).
  - Exact landmark / location details.
  - One-click **GPS Location Detection**.
  - Photo & document uploads (JPG, PNG, PDF, DOC up to 10MB).
- Unique sequential Complaint IDs (e.g. `DVD-2026-1001`).
- **Enforced Restrictions:** Farmers can view and track only their own complaints. They cannot access administrative dashboards, assign officers, or alter statuses.

### 4. Officer Dashboard
- Assigned complaints workspace for verified officers (`8341144896`, `9705007232`).
- Field inspection remarks and work plans.
- Update status to **In Progress**.
- **Before-and-After Evidence Submission**:
  - Solution description in citizen's language.
  - Upload before photo (initial problem).
  - Upload after photo (completed rectification).
  - Upload official sign-off report / PDF certificate.
  - Submit for Administrative Verification (**Resolution Submitted**).
- Feedback alert if an administrator returns the resolution for rework.
- **Enforced Restrictions:** Officers cannot self-approve cases as finally *Resolved*; final approval requires the Administrator. Officers cannot access other officers' unassigned cases.

### 5. Admin Dashboard
- Complete operational oversight for verified administrator (`9701853520`).
- Search by Complaint ID, village, citizen, phone, or title.
- Filters by Status, Category, and District.
- **Assign / Reassign Officer** with administrative directives.
- Change grievance priority.
- **Audit & Verify Evidence:** Review side-by-side before/after photos and engineer reports.
- **Approve Resolution:** Marks status as **Resolved**, recording certification timestamp and feedback.
- **Return Resolution:** Returns complaint to officer as *In Progress* with mandatory feedback reason.
- **Reject Complaint:** Rejects invalid grievances with mandatory recorded reason.
- **Village Master Directory:** Add and manage villages, mandals, and populations.
- **Officer Directory:** View active workload and completed resolutions per officer.
- **Export CSV:** One-click download of all complaint records for district reporting.
- **Audit Trail:** Immutable activity log tracking all status transitions and staff actions.

### 6. Complaint Status Workflow
```
[Submitted] 
    │
    ▼
[Under Review] 
    │
    ▼
[Assigned] 
    │
    ▼
[In Progress] 
    │
    ▼
[Resolution Submitted] 
    │
    ├─────────────► [Resolved] (Approved by Admin)
    │
    └─────────────► Returned to [In Progress] (Needs rework)

* Any invalid complaint can be [Rejected] with a mandatory recorded reason.
```

---

## 🛠️ Project Structure

```
Digital village/
├── index.html                   # HTML entry point with Noto Sans fonts & SVG favicon
├── package.json                 # React 18, Vite, Tailwind CSS, Lucide icons, Supabase JS
├── postcss.config.js            # PostCSS configuration
├── tailwind.config.js           # Modern green & blue palette configuration
├── vite.config.js               # Vite build config with optimized chunking
├── supabase_schema.sql          # Complete PostgreSQL migration, RLS policies, seeds
├── .env.example                 # Sample Supabase environment variables
├── .env                         # Local environment configuration
└── src/
    ├── main.jsx                 # React root renderer
    ├── App.jsx                  # Main application router & role guardian
    ├── index.css                # Tailwind directives & responsive styles
    ├── assets/                  # Logos and vector icons
    ├── components/
    │   ├── Logo.jsx             # Digital Village SVG emblem & title
    │   ├── Navbar.jsx           # Multilingual header, role pills, notification bell
    │   ├── Footer.jsx           # Government portal footer & toll-free helpline
    │   ├── LanguageSelector.jsx # Language switcher (Telugu, English, Hindi, Tamil)
    │   ├── NotificationCenter.jsx # In-app notification center with read states
    │   ├── StatusBadge.jsx      # Color-coded workflow badges
    │   ├── PriorityBadge.jsx    # Low, Medium, High, Urgent badges
    │   ├── OtpModal.jsx         # OTP login & profile registration modal
    │   ├── ComplaintTimeline.jsx # Visual stepper & status change history
    │   ├── BeforeAfterViewer.jsx# Side-by-side before/after evidence comparer
    │   └── FileUploader.jsx     # Validated file uploader (JPG, PNG, PDF, DOC)
    ├── context/
    │   ├── AuthContext.jsx      # OTP auth, trusted role resolution, session handling
    │   ├── LanguageContext.jsx  # Multilingual state & t(key) translation helper
    │   └── ComplaintContext.jsx # Complaints, assignments, resolutions, audit logs
    ├── data/
    │   ├── translations.js      # Complete multilingual dictionary (TE, EN, HI, TA)
    │   └── initialData.js       # Seed staff accounts, villages, realistic sample grievances
    ├── pages/
    │   ├── HomePage.jsx         # Hero, impact stats, workflow steps, categories
    │   ├── TrackComplaintPage.jsx # Public & authenticated grievance tracking
    │   ├── NewComplaintPage.jsx # Citizen complaint submission form with GPS & uploads
    │   ├── FarmerDashboard.jsx  # Citizen dashboard with personal complaints
    │   ├── OfficerDashboard.jsx # Assigned grievances, investigation notes & proof upload
    │   ├── AdminDashboard.jsx   # Administrative control center, assignments & audits
    │   ├── AboutUsPage.jsx      # Rural governance mission & citizen charter
    │   ├── ContactUsPage.jsx    # Helplines, mandal offices & citizen feedback
    │   └── SmsSetupGuide.jsx    # Supabase SMS setup & architecture manual
    └── services/
        ├── supabaseClient.js    # Supabase initialization & fallback detection
        └── storageService.js    # Private bucket uploader, signed URLs, validation
```

---

## 🚀 Getting Started

### 1. Prerequisites
- Node.js (v18 or higher)
- npm or yarn

### 2. Installation
```bash
# Clone or navigate to the directory
cd "Digital village"

# Install dependencies
npm install
```

### 3. Running Locally
```bash
# Start development server
npm run dev

# Or build and preview production build
npm run build
npm run preview
```
Open [http://localhost:3000](http://localhost:3000) (or the port indicated in terminal).

---

## 🗄️ Supabase Database & Auth Setup

### 1. Create a Supabase Project
1. Log in to [supabase.com](https://supabase.com) and create a new project.
2. Under **Project Settings** → **API**, copy your:
   - **Project URL**
   - **Anon / Public Key**
3. Create or update your `.env` file:
   ```env
   VITE_SUPABASE_URL=https://your-project-id.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJhbGciOi...your-anon-key-here
   ```

### 2. Run Database Migration
Open your Supabase **SQL Editor** and run the contents of [`supabase_schema.sql`](./supabase_schema.sql).

This creates:
- `profiles` table (linked to `auth.users`)
- `user_roles` table (protected server-verified role store)
- `villages` master directory
- `complaints` table with auto-generating sequential IDs (`DVD-2026-XXXX`)
- `complaint_assignments`
- `complaint_attachments`
- `resolution_reports`
- `complaint_status_history`
- `notifications`
- `audit_logs`
- Full **Row Level Security (RLS)** policies for all tables.
- Pre-seeded staff accounts and Andhra Pradesh / Telangana villages.

### 3. Create Storage Buckets
In your Supabase Dashboard under **Storage**:
1. Create private bucket: `complaint-attachments`
2. Create private bucket: `resolution-evidence`
3. The policies in `supabase_schema.sql` govern access to these buckets using signed short-lived URLs.

### 4. Configure SMS Provider (Twilio / MessageBird)
1. In Supabase Dashboard, navigate to **Authentication** → **Providers** → **Phone**.
2. Enable the **Phone** provider.
3. Select your SMS Gateway (e.g. **Twilio**).
4. Enter your Twilio Account SID, Auth Token, and Twilio Phone Number.
5. Save settings.

> **Note on Testing / Development:**  
> If an external SMS gateway is not yet linked in your Supabase project, the app clearly displays an SMS gateway notice and provides demo verification code `123456` so that all workflows, assignments, before/after evidence uploads, and certifications can be thoroughly tested.

---

## 🧪 Testing All 3 Roles

You can test all three roles by clicking **Sign In** and using the quick-select buttons or entering the phone numbers:

| Role | Mobile Number | Capabilities |
|---|---|---|
| **👑 System Admin** | `9701853520` | View all village complaints, assign officers, change priorities, review before/after proof, approve as Resolved, return with remarks, reject invalid complaints, view audit logs, export CSV. |
| **🛠️ Village Officer 1** | `8341144896` | View assigned complaints, inspect citizen details, add investigation remarks, update to In Progress, upload solution description, before & after photos, upload PDF report, submit for Admin approval. |
| **🛠️ Village Officer 2** | `9705007232` | View assigned water supply complaints, add field inspection remarks, upload resolution evidence, submit for certification. |
| **🌾 Farmer / Villager** | Any 10-digit number (e.g. `9848011223`) | Complete profile (Village, Mandal, District), submit new village problem with photos, detect GPS, track own complaints, view official progress and before/after resolution photos. Cannot access admin/officer features. |

---

## 🔒 Security Summary

1. **Role Protection:** User roles are stored in a dedicated `user_roles` table protected by PostgreSQL Row Level Security. Role checks are executed server-side.
2. **Citizen Privacy:** Citizens can only read and write their own complaints.
3. **Officer Isolation:** Officers can only update complaints assigned to them, and can only move them to *In Progress* or *Resolution Submitted*.
4. **Resolution Certification:** Only an authenticated Administrator can verify evidence and transition complaints to *Resolved*.
5. **Private Storage:** Attachments are stored in private buckets and accessed via short-lived signed URLs.
6. **No Secret Keys in Frontend:** Frontend only uses the Supabase Anon key; privileged actions are guarded by database RLS and triggers.

---

## 📜 License
Developed for the **Digital Village Development Initiative** (AP & National Rural Governance). Open-source under the MIT License.
