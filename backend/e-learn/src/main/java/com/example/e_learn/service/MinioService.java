package com.example.e_learn.service;

import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.StatObjectArgs;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import java.io.InputStream;
import java.util.UUID;

@Service
public class MinioService {
    @Autowired
    private MinioClient minioClient;

    @Value("${data.mediaBucket}")
    private String bucketName;

    @Value("${minio.publicUrl:http://localhost:9000}")
    private String publicUrl;

    public String uploadVideo(MultipartFile file) throws Exception {
        if (!minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucketName).build())) {
            minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucketName).build());
        }
        String filename = UUID.randomUUID() + "_" + file.getOriginalFilename();
        String contentType = file.getContentType();
        if (contentType == null || contentType.equals("application/octet-stream")) {
            contentType = "video/mp4"; // sensible default for browser playback
        }
        try (InputStream is = file.getInputStream()) {
            minioClient.putObject(PutObjectArgs.builder()
                .bucket(bucketName)
                .object(filename)
                .stream(is, file.getSize(), -1)
                .contentType(contentType)
                .build());
        }
        // direct URL (HTTP, for dev)
        String url = minioClient.getPresignedObjectUrl(
            io.minio.GetPresignedObjectUrlArgs.builder()
                .bucket(bucketName)
                .object(filename)
                .method(io.minio.http.Method.GET)
                .build());
        // Rewrite internal hostname to public one for the browser
        try {
            java.net.URI u = new java.net.URI(url);
            java.net.URI pub = new java.net.URI(publicUrl);
            url = new java.net.URI(pub.getScheme(), u.getUserInfo(), pub.getHost(), pub.getPort(), u.getPath(), u.getQuery(), u.getFragment()).toString();
        } catch (Exception ignore) {}
        return url;
    }

    /**
     * Extract object name from a MinIO URL.
     * Handles both direct URLs and presigned URLs with query parameters.
     * URL formats:
     *   - http://host:port/bucket/object-name
     *   - http://host:port/bucket/object-name?X-Amz-Algorithm=...
     */
    private String extractObjectName(String videoUrl) {
        System.out.println("Extracting object name from URL: " + videoUrl);
        try {
            java.net.URI uri = new java.net.URI(videoUrl);
            String path = uri.getPath();
            System.out.println("Parsed path: " + path);
            
            // Remove leading slash
            if (path.startsWith("/")) {
                path = path.substring(1);
            }
            
            // Remove bucket name if present
            if (path.startsWith(bucketName + "/")) {
                path = path.substring(bucketName.length() + 1);
            }
            
            System.out.println("Extracted object name: " + path);
            return path;
        } catch (Exception e) {
            System.err.println("Error parsing URI, trying fallback: " + e.getMessage());
            // Fallback: extract from path after last slash, before query params
            try {
                int queryIndex = videoUrl.indexOf('?');
                String urlWithoutQuery = queryIndex > 0 ? videoUrl.substring(0, queryIndex) : videoUrl;
                
                int lastSlash = urlWithoutQuery.lastIndexOf('/');
                if (lastSlash >= 0 && lastSlash < urlWithoutQuery.length() - 1) {
                    String filename = urlWithoutQuery.substring(lastSlash + 1);
                    // Remove bucket name if it's the first part
                    if (filename.startsWith(bucketName + "/")) {
                        filename = filename.substring(bucketName.length() + 1);
                    }
                    System.out.println("Fallback extracted object name: " + filename);
                    return filename;
                }
            } catch (Exception e2) {
                System.err.println("Fallback extraction also failed: " + e2.getMessage());
            }
            System.err.println("Could not extract object name, using full URL as fallback");
            return videoUrl;
        }
    }

    /**
     * Get video stream directly from MinIO.
     * Supports range requests for video seeking.
     */
    public InputStream getVideoStream(String videoUrl) throws Exception {
        String objectName = extractObjectName(videoUrl);
        return minioClient.getObject(GetObjectArgs.builder()
            .bucket(bucketName)
            .object(objectName)
            .build());
    }

    /**
     * Get video stream with range support.
     */
    public InputStream getVideoStream(String videoUrl, long offset, long length) throws Exception {
        String objectName = extractObjectName(videoUrl);
        return minioClient.getObject(GetObjectArgs.builder()
            .bucket(bucketName)
            .object(objectName)
            .offset(offset)
            .length(length)
            .build());
    }

    /**
     * Get object size for Content-Length header.
     */
    public long getObjectSize(String videoUrl) throws Exception {
        String objectName = extractObjectName(videoUrl);
        try {
            io.minio.StatObjectResponse stat = minioClient.statObject(
                io.minio.StatObjectArgs.builder()
                    .bucket(bucketName)
                    .object(objectName)
                    .build());
            return stat.size();
        } catch (Exception e) {
            return -1; // Unknown size
        }
    }
}

