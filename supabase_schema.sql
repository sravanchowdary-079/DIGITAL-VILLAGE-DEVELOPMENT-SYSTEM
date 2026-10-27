-- =====================================================================
-- DIGITAL VILLAGE DEVELOPMENT SYSTEM
-- Complete Database Migration & RLS Policies
-- Compatible with Supabase PostgreSQL & Supabase Auth
-- =====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. ENUMS & DOMAINS
DO $$ BEGIN
    CREATE TYPE user_role_type AS ENUM ('admin', 'officer', 'farmer', 'villager');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE complaint_status_type AS ENUM (
        'Submitted',
        'Under Review',
        'Assigned',
        'In Progress',
        'Resolution Submitted',
        'Resolved',
        'Rejected'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE complaint_priority_type AS ENUM ('Low', 'Medium', 'High', 'Urgent');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. VILLAGES TABLE
CREATE TABLE IF NOT EXISTS public.villages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    name_te VARCHAR(100),
    name_hi VARCHAR(100),
    name_ta VARCHAR(100),
    mandal VARCHAR(100) NOT NULL,
    district VARCHAR(100) NOT NULL,
    state VARCHAR(100) DEFAULT 'Andhra Pradesh',
    pin_code VARCHAR(10),
    population INT DEFAULT 1500,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. PROFILES TABLE (Linked to auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    user_type VARCHAR(20) DEFAULT 'farmer' CHECK (user_type IN ('farmer', 'villager', 'officer', 'admin')),
    village VARCHAR(100),
    mandal VARCHAR(100),
    district VARCHAR(100),
    state VARCHAR(100) DEFAULT 'Andhra Pradesh',
    preferred_language VARCHAR(10) DEFAULT 'te' CHECK (preferred_language IN ('te', 'en', 'hi', 'ta')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. USER ROLES TABLE (Protected server-verified role store)
CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'officer', 'farmer', 'villager')),
    is_active BOOLEAN DEFAULT TRUE,
    assigned_by UUID REFERENCES auth.users(id),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. COMPLAINTS TABLE
CREATE TABLE IF NOT EXISTS public.complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id VARCHAR(30) UNIQUE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    farmer_name VARCHAR(150),
    farmer_phone VARCHAR(20),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    language VARCHAR(10) DEFAULT 'te' CHECK (language IN ('te', 'en', 'hi', 'ta')),
    category VARCHAR(50) NOT NULL CHECK (category IN (
        'Roads',
        'Water Supply',
        'Electricity',
        'Agriculture',
        'Drainage',
        'Sanitation',
        'Government Services',
        'Other'
    )),
    priority VARCHAR(20) DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
    status VARCHAR(30) DEFAULT 'Submitted' CHECK (status IN (
        'Submitted',
        'Under Review',
        'Assigned',
        'In Progress',
        'Resolution Submitted',
        'Resolved',
        'Rejected'
    )),
    rejection_reason TEXT,
    village_id UUID REFERENCES public.villages(id) ON DELETE SET NULL,
    village_name VARCHAR(100),
    mandal VARCHAR(100),
    district VARCHAR(100),
    location_details TEXT,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Sequence for unique human-readable Complaint IDs (e.g. DVD-2026-0001)
CREATE SEQUENCE IF NOT EXISTS complaint_id_seq START WITH 1001;

CREATE OR REPLACE FUNCTION generate_complaint_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.complaint_id IS NULL OR NEW.complaint_id = '' THEN
        NEW.complaint_id := 'DVD-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(nextval('complaint_id_seq')::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_complaint_id ON public.complaints;
CREATE TRIGGER trg_set_complaint_id
BEFORE INSERT ON public.complaints
FOR EACH ROW
EXECUTE FUNCTION generate_complaint_id();

-- 7. COMPLAINT ASSIGNMENTS TABLE
CREATE TABLE IF NOT EXISTS public.complaint_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
    officer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    officer_phone VARCHAR(20) NOT NULL,
    officer_name VARCHAR(150),
    assigned_by UUID REFERENCES auth.users(id),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    status VARCHAR(20) DEFAULT 'Active' CHECK (status IN ('Active', 'Reassigned', 'Completed'))
);

-- 8. COMPLAINT ATTACHMENTS TABLE
CREATE TABLE IF NOT EXISTS public.complaint_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT,
    file_type VARCHAR(100),
    uploaded_by UUID REFERENCES auth.users(id),
    attachment_type VARCHAR(30) DEFAULT 'problem_evidence' CHECK (
        attachment_type IN ('problem_evidence', 'document', 'before_photo', 'after_photo', 'resolution_report')
    ),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. RESOLUTION REPORTS TABLE
CREATE TABLE IF NOT EXISTS public.resolution_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID UNIQUE NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
    officer_id UUID NOT NULL REFERENCES auth.users(id),
    solution_description TEXT NOT NULL,
    investigation_remarks TEXT,
    before_photo_path TEXT,
    after_photo_path TEXT,
    report_file_path TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES auth.users(id),
    admin_feedback TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. COMPLAINT STATUS HISTORY TABLE
CREATE TABLE IF NOT EXISTS public.complaint_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
    changed_by UUID REFERENCES auth.users(id),
    changed_by_name VARCHAR(150),
    old_status VARCHAR(30),
    new_status VARCHAR(30) NOT NULL,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    complaint_id UUID REFERENCES public.complaints(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'status_update',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id VARCHAR(100),
    details JSONB,
    ip_address VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- HELPER FUNCTIONS FOR ROLE AND PERMISSION VALIDATION
-- =====================================================================

-- Get current authenticated user's role
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS VARCHAR AS $$
DECLARE
    v_role VARCHAR;
    v_phone VARCHAR;
BEGIN
    -- Check if user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN 'anon';
    END IF;

    -- Lookup user in user_roles by user_id
    SELECT role INTO v_role
    FROM public.user_roles
    WHERE user_id = auth.uid() AND is_active = TRUE
    LIMIT 1;

    IF v_role IS NOT NULL THEN
        RETURN v_role;
    END IF;

    -- Fallback: check by authenticated user phone if not linked yet
    SELECT phone INTO v_phone
    FROM auth.users
    WHERE id = auth.uid();

    IF v_phone IS NOT NULL THEN
        -- Normalize phone: strip +91 or match standard 10-digit
        SELECT role INTO v_role
        FROM public.user_roles
        WHERE (phone = v_phone OR phone = REPLACE(v_phone, '+91', '') OR ('+91' || phone) = v_phone)
          AND is_active = TRUE
        LIMIT 1;
        
        IF v_role IS NOT NULL THEN
            -- Link user_id to user_roles
            UPDATE public.user_roles SET user_id = auth.uid() WHERE (phone = v_phone OR phone = REPLACE(v_phone, '+91', ''));
            RETURN v_role;
        END IF;
    END IF;

    RETURN 'farmer'; -- Default fallback role
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.get_current_user_role() = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if current user is officer
CREATE OR REPLACE FUNCTION public.is_officer()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.get_current_user_role() = 'officer';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.villages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaint_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaint_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resolution_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaint_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 1. PROFILES POLICIES
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
CREATE POLICY "Users can read own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id OR public.is_admin() OR public.is_officer());

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id OR public.is_admin());

-- 2. USER ROLES POLICIES (Protected, admin only can edit)
DROP POLICY IF EXISTS "Users can view roles" ON public.user_roles;
CREATE POLICY "Users can view roles" ON public.user_roles
    FOR SELECT USING (auth.uid() = user_id OR public.is_admin() OR public.is_officer());

DROP POLICY IF EXISTS "Only admin can insert roles" ON public.user_roles;
CREATE POLICY "Only admin can insert roles" ON public.user_roles
    FOR INSERT WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Only admin can update roles" ON public.user_roles;
CREATE POLICY "Only admin can update roles" ON public.user_roles
    FOR UPDATE USING (public.is_admin());

-- 3. VILLAGES POLICIES
DROP POLICY IF EXISTS "Everyone can view villages" ON public.villages;
CREATE POLICY "Everyone can view villages" ON public.villages
    FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Only admin can modify villages" ON public.villages;
CREATE POLICY "Only admin can modify villages" ON public.villages
    FOR ALL USING (public.is_admin());

-- 4. COMPLAINTS POLICIES
DROP POLICY IF EXISTS "Admin full access to complaints" ON public.complaints;
CREATE POLICY "Admin full access to complaints" ON public.complaints
    FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "Officers can view assigned complaints" ON public.complaints;
CREATE POLICY "Officers can view assigned complaints" ON public.complaints
    FOR SELECT USING (
        public.is_officer() AND (
            id IN (SELECT complaint_id FROM public.complaint_assignments WHERE officer_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Officers can update assigned complaints status" ON public.complaints;
CREATE POLICY "Officers can update assigned complaints status" ON public.complaints
    FOR UPDATE USING (
        public.is_officer() AND (
            id IN (SELECT complaint_id FROM public.complaint_assignments WHERE officer_id = auth.uid())
        )
    ) WITH CHECK (
        -- Officers cannot approve as Resolved, only move to In Progress or Resolution Submitted
        status IN ('In Progress', 'Resolution Submitted')
    );

DROP POLICY IF EXISTS "Farmers can view own complaints" ON public.complaints;
CREATE POLICY "Farmers can view own complaints" ON public.complaints
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Farmers can insert complaints" ON public.complaints;
CREATE POLICY "Farmers can insert complaints" ON public.complaints
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND status = 'Submitted'
    );

-- 5. COMPLAINT ASSIGNMENTS POLICIES
DROP POLICY IF EXISTS "Admin full access to assignments" ON public.complaint_assignments;
CREATE POLICY "Admin full access to assignments" ON public.complaint_assignments
    FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "Officers can view own assignments" ON public.complaint_assignments;
CREATE POLICY "Officers can view own assignments" ON public.complaint_assignments
    FOR SELECT USING (officer_id = auth.uid());

-- 6. COMPLAINT ATTACHMENTS POLICIES
DROP POLICY IF EXISTS "Admin full access to attachments" ON public.complaint_attachments;
CREATE POLICY "Admin full access to attachments" ON public.complaint_attachments
    FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "Officers can view and insert attachments for assigned" ON public.complaint_attachments;
CREATE POLICY "Officers can view and insert attachments for assigned" ON public.complaint_attachments
    FOR ALL USING (
        public.is_officer() AND (
            complaint_id IN (SELECT complaint_id FROM public.complaint_assignments WHERE officer_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Farmers can view own attachments" ON public.complaint_attachments;
CREATE POLICY "Farmers can view own attachments" ON public.complaint_attachments
    FOR SELECT USING (
        complaint_id IN (SELECT id FROM public.complaints WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "Farmers can insert attachments for own complaints" ON public.complaint_attachments;
CREATE POLICY "Farmers can insert attachments for own complaints" ON public.complaint_attachments
    FOR INSERT WITH CHECK (
        complaint_id IN (SELECT id FROM public.complaints WHERE user_id = auth.uid())
    );

-- 7. RESOLUTION REPORTS POLICIES
DROP POLICY IF EXISTS "Admin full access to resolution reports" ON public.resolution_reports;
CREATE POLICY "Admin full access to resolution reports" ON public.resolution_reports
    FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "Officers can insert and update assigned resolution reports" ON public.resolution_reports;
CREATE POLICY "Officers can insert and update assigned resolution reports" ON public.resolution_reports
    FOR ALL USING (
        public.is_officer() AND (
            complaint_id IN (SELECT complaint_id FROM public.complaint_assignments WHERE officer_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Farmers can view resolution reports for their complaints" ON public.resolution_reports;
CREATE POLICY "Farmers can view resolution reports for their complaints" ON public.resolution_reports
    FOR SELECT USING (
        complaint_id IN (
            SELECT id FROM public.complaints 
            WHERE user_id = auth.uid() AND status = 'Resolved'
        )
    );

-- 8. STATUS HISTORY POLICIES
DROP POLICY IF EXISTS "Admin can view all status history" ON public.complaint_status_history;
CREATE POLICY "Admin can view all status history" ON public.complaint_status_history
    FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "Officers can view status history for assigned" ON public.complaint_status_history;
CREATE POLICY "Officers can view status history for assigned" ON public.complaint_status_history
    FOR SELECT USING (
        public.is_officer() AND (
            complaint_id IN (SELECT complaint_id FROM public.complaint_assignments WHERE officer_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Farmers can view non-internal status history for own" ON public.complaint_status_history;
CREATE POLICY "Farmers can view non-internal status history for own" ON public.complaint_status_history
    FOR SELECT USING (
        complaint_id IN (SELECT id FROM public.complaints WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "Staff can insert status history" ON public.complaint_status_history;
CREATE POLICY "Staff can insert status history" ON public.complaint_status_history
    FOR INSERT WITH CHECK (public.is_admin() OR public.is_officer() OR auth.uid() IS NOT NULL);

-- 9. NOTIFICATIONS POLICIES
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (user_id = auth.uid());

-- 10. AUDIT LOGS POLICIES
DROP POLICY IF EXISTS "Admin can view audit logs" ON public.audit_logs;
CREATE POLICY "Admin can view audit logs" ON public.audit_logs
    FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_logs;
CREATE POLICY "System can insert audit logs" ON public.audit_logs
    FOR INSERT WITH CHECK (TRUE);

-- =====================================================================
-- SEED DATA: STAFF ROLES, VILLAGES, SAMPLE DATA
-- =====================================================================

-- Pre-seed authorized staff accounts
-- Admin: 9701853520 (+919701853520)
-- Officer 1: 8341144896 (+918341144896)
-- Officer 2: 9705007232 (+919705007232)

INSERT INTO public.user_roles (phone, role, is_active)
VALUES
    ('+919701853520', 'admin', TRUE),
    ('9701853520', 'admin', TRUE),
    ('+918341144896', 'officer', TRUE),
    ('8341144896', 'officer', TRUE),
    ('+919705007232', 'officer', TRUE),
    ('9705007232', 'officer', TRUE)
ON CONFLICT (phone) DO UPDATE 
SET role = EXCLUDED.role, is_active = EXCLUDED.is_active;

-- Pre-seed Andhra Pradesh & Telangana Villages
INSERT INTO public.villages (name, name_te, name_hi, name_ta, mandal, district, state, pin_code, population)
VALUES
    ('Pedda Waltair', 'పెద్ద వాల్తేరు', 'पेद्दा वाल्टेयर', 'பெத்தா வால்டேர்', 'Visakhapatnam Urban', 'Visakhapatnam', 'Andhra Pradesh', '530017', 4200),
    ('Anandapuram', 'ఆనందపురం', 'आनंदपुरम', 'ஆனந்தபுரம்', 'Anandapuram', 'Visakhapatnam', 'Andhra Pradesh', '530052', 3100),
    ('Kankipadu', 'కంకిపాడు', 'कंकीपाडु', 'கங்கிபாடு', 'Kankipadu', 'Krishna', 'Andhra Pradesh', '521151', 5400),
    ('Vuyyuru', 'వుయ్యూరు', 'वुय्यूर', 'உய்யூரு', 'Vuyyuru', 'Krishna', 'Andhra Pradesh', '521165', 8200),
    ('Tenali Rural', 'తెనాలి రూరల్', 'तेनाली ग्रामीण', 'தெனாலி ஊரகம்', 'Tenali', 'Guntur', 'Andhra Pradesh', '522201', 6100),
    ('Mangalagiri Green', 'మంగళగిరి గ్రీన్', 'मंगलगिरि ग्रीन', 'மங்களகிரி கிரீன்', 'Mangalagiri', 'Guntur', 'Andhra Pradesh', '522503', 7300),
    ('Chittoor Rural', 'చిత్తూరు రూరల్', 'चित्तूर ग्रामीण', 'சித்தூர் ஊரகம்', 'Chittoor', 'Chittoor', 'Andhra Pradesh', '517001', 3900),
    ('Chandragiri', 'చంద్రగిరి', 'चंद्रगिरि', 'சந்திரகிரி', 'Tirupati', 'Tirupati', 'Andhra Pradesh', '517101', 4800)
ON CONFLICT DO NOTHING;

-- Storage buckets creation query (Run in Supabase SQL editor):
-- INSERT INTO storage.buckets (id, name, public) VALUES ('complaint-attachments', 'complaint-attachments', false) ON CONFLICT DO NOTHING;
-- INSERT INTO storage.buckets (id, name, public) VALUES ('resolution-evidence', 'resolution-evidence', false) ON CONFLICT DO NOTHING;
