-- ============================================
-- SUPABASE STORAGE SETUP FOR RIDER DOCUMENTS
-- ============================================

-- 1. Create storage bucket (if not exists)
-- Run this in Supabase SQL Editor or via Dashboard > Storage > New Bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 2. Storage Policies
-- ============================================

-- Policy 1: Allow authenticated users to upload documents
CREATE POLICY "Authenticated users can upload documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = 'rider_documents'
);

-- Policy 2: Allow public read access to documents
CREATE POLICY "Public can view documents"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'documents');

-- Policy 3: Allow authenticated users to update their own documents
CREATE POLICY "Authenticated users can update documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = 'rider_documents'
);

-- Policy 4: Allow authenticated users to delete their own documents
CREATE POLICY "Authenticated users can delete documents"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = 'rider_documents'
);

-- ============================================
-- 3. Verify Bucket and Policies
-- ============================================

-- Check if bucket exists
SELECT * FROM storage.buckets WHERE id = 'documents';

-- Check policies
SELECT * FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage';

-- ============================================
-- 4. Test Upload (Optional)
-- ============================================

-- After setup, test upload from Flutter app:
-- 1. Open Verification Documents screen
-- 2. Select an image
-- 3. Upload
-- 4. Check Supabase Dashboard > Storage > documents > rider_documents

-- ============================================
-- 5. Storage Structure
-- ============================================

-- Expected folder structure:
-- documents/
--   └── rider_documents/
--       └── {rider_id}/
--           ├── rider_{rider_id}_orcr_{timestamp}.jpg
--           └── rider_{rider_id}_license_{timestamp}.jpg

-- ============================================
-- 6. Check Uploaded Files
-- ============================================

-- View all uploaded documents
SELECT 
    name,
    bucket_id,
    created_at,
    updated_at,
    last_accessed_at,
    metadata
FROM storage.objects
WHERE bucket_id = 'documents'
ORDER BY created_at DESC;

-- ============================================
-- 7. Check Rider Documents in Database
-- ============================================

-- View riders with uploaded documents
SELECT 
    rider_id,
    first_name,
    last_name,
    orcr_file_path,
    driver_license_file_path,
    CASE 
        WHEN orcr_file_path IS NOT NULL THEN '✅ Uploaded'
        ELSE '❌ Not Uploaded'
    END as orcr_status,
    CASE 
        WHEN driver_license_file_path IS NOT NULL THEN '✅ Uploaded'
        ELSE '❌ Not Uploaded'
    END as license_status
FROM riders
ORDER BY rider_id;

-- ============================================
-- 8. Cleanup (Optional - Use with Caution!)
-- ============================================

-- Remove all policies (if you need to recreate them)
-- DROP POLICY IF EXISTS "Authenticated users can upload documents" ON storage.objects;
-- DROP POLICY IF EXISTS "Public can view documents" ON storage.objects;
-- DROP POLICY IF EXISTS "Authenticated users can update documents" ON storage.objects;
-- DROP POLICY IF EXISTS "Authenticated users can delete documents" ON storage.objects;

-- Delete all files in bucket (DANGEROUS!)
-- DELETE FROM storage.objects WHERE bucket_id = 'documents';

-- Delete bucket (DANGEROUS!)
-- DELETE FROM storage.buckets WHERE id = 'documents';

-- ============================================
-- NOTES:
-- ============================================

-- 1. The bucket is set to PUBLIC (public = true)
--    This means anyone with the URL can view the documents
--    
-- 2. Only authenticated users can upload/update/delete
--    This prevents anonymous uploads
--
-- 3. Files are organized by rider_id for easy management
--
-- 4. File naming includes timestamp to prevent conflicts
--    and allow version history
--
-- 5. The app uses FileOptions(upsert: true) which means
--    uploading a file with the same name will replace it
--
-- 6. Public URLs are generated automatically and stored
--    in the riders table (orcr_file_path, driver_license_file_path)
--
-- 7. To view files in Supabase Dashboard:
--    Dashboard > Storage > documents > rider_documents
--
-- 8. To get public URL format:
--    https://{project_ref}.supabase.co/storage/v1/object/public/documents/{file_path}

