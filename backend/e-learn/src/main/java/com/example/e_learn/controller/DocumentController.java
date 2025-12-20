package com.example.e_learn.controller;

import com.example.e_learn.model.Document;
import com.example.e_learn.service.DocumentService;
import com.example.e_learn.service.MinioService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletRequest;
import java.io.InputStream;
import org.springframework.web.multipart.MultipartFile;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/documents")
public class DocumentController {
    @Autowired
    private DocumentService documentService;

    @Autowired
    private MinioService minioService;

    @GetMapping("/lesson/{lessonId}")
    public ResponseEntity<List<Document>> getDocumentsByLesson(@PathVariable Long lessonId) {
        return ResponseEntity.ok(documentService.getDocumentsByLessonId(lessonId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Document> getDocument(@PathVariable Long id) {
        return documentService.getDocument(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/lesson/{lessonId}")
    public ResponseEntity<?> uploadDocument(
            @PathVariable Long lessonId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "title", required = false, defaultValue = "") String title,
            @RequestParam(value = "description", required = false, defaultValue = "") String description) {
        try {
            // Validate file type - check both content type and file extension
            String contentType = file.getContentType();
            String originalFilename = file.getOriginalFilename();
            boolean isPdf = false;
            
            // Check content type
            if (contentType != null && contentType.equals("application/pdf")) {
                isPdf = true;
            }
            // Check file extension as fallback (browsers may not send correct content type)
            else if (originalFilename != null && originalFilename.toLowerCase().endsWith(".pdf")) {
                isPdf = true;
            }
            
            if (!isPdf) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "Only PDF files are allowed"));
            }

            // Upload PDF to MinIO
            String fileUrl = minioService.uploadDocument(file);
            
            // Get existing documents to determine order index
            List<Document> existingDocuments = documentService.getDocumentsByLessonId(lessonId);
            int orderIndex = existingDocuments.size();
            
            // Use filename as title if not provided
            String documentTitle = title != null && !title.isEmpty() 
                ? title 
                : file.getOriginalFilename();
            
            // Create document entity
            Document document = documentService.createDocumentForLesson(
                lessonId, documentTitle, fileUrl, description, orderIndex);
            
            return ResponseEntity.ok(document);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "Failed to upload document: " + e.getMessage()));
        }
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteDocument(@PathVariable Long id) {
        documentService.deleteDocument(id);
        return ResponseEntity.ok().build();
    }

    // Handle OPTIONS requests for CORS preflight
    @RequestMapping(value = "/{id}/download", method = RequestMethod.OPTIONS)
    public ResponseEntity<Void> handleOptions(@PathVariable Long id) {
        HttpHeaders headers = new HttpHeaders();
        headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
        headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, "GET, HEAD, OPTIONS");
        headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_HEADERS, "Range, Content-Type, Authorization");
        headers.set(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, "Content-Range, Content-Length, Accept-Ranges");
        headers.set(HttpHeaders.ACCESS_CONTROL_MAX_AGE, "3600");
        return ResponseEntity.ok().headers(headers).build();
    }

    // Download PDF file - supports inline viewing and range requests
    // No @PreAuthorize - public endpoint for viewing PDFs
    @GetMapping("/{id}/download")
    public ResponseEntity<?> downloadDocument(
            @PathVariable Long id,
            @RequestParam(value = "inline", defaultValue = "true") boolean inline,
            HttpServletRequest request) {
        System.out.println("Document download request: ID=" + id + ", inline=" + inline + ", URI=" + request.getRequestURI());
        return documentService.getDocument(id)
            .map(document -> {
                try {
                    System.out.println("Found document: " + document.getTitle() + ", fileUrl: " + document.getFileUrl());
                    if (document.getFileUrl() == null || document.getFileUrl().isEmpty()) {
                        System.err.println("Document fileUrl is null or empty");
                        return ResponseEntity.notFound().build();
                    }
                    
                    String rangeHeader = request.getHeader("Range");
                    System.out.println("Range header: " + rangeHeader);
                    long fileSize = minioService.getDocumentSize(document.getFileUrl());
                    System.out.println("File size: " + fileSize);
                    
                    HttpHeaders headers = new HttpHeaders();
                    headers.setContentType(MediaType.APPLICATION_PDF);
                    // Set to inline for viewing in browser, attachment for download
                    if (inline) {
                        headers.setContentDispositionFormData("inline", document.getTitle() + ".pdf");
                    } else {
                        headers.setContentDispositionFormData("attachment", document.getTitle() + ".pdf");
                    }
                    // CORS headers for PDF viewing
                    headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
                    headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, "GET, HEAD, OPTIONS");
                    headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_HEADERS, "Range, Content-Type, Authorization");
                    headers.set(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, "Content-Range, Content-Length, Accept-Ranges");
                    headers.set(HttpHeaders.ACCEPT_RANGES, "bytes");
                    headers.set(HttpHeaders.CACHE_CONTROL, "public, max-age=3600");
                    // Allow iframe embedding (X-Frame-Options is disabled globally in SecurityConfig)
                    headers.set("Content-Security-Policy", "frame-ancestors *");
                    
                    InputStream pdfStream;
                    long start = 0;
                    long end = fileSize > 0 ? fileSize - 1 : 0;
                    long contentLength = fileSize;
                    
                    // Parse Range header if present (for PDF viewers that use range requests)
                    if (rangeHeader != null && !rangeHeader.isBlank() && rangeHeader.startsWith("bytes=")) {
                        String range = rangeHeader.substring(6);
                        String[] ranges = range.split("-");
                        try {
                            if (ranges.length > 0 && !ranges[0].isEmpty()) {
                                start = Long.parseLong(ranges[0]);
                            }
                            if (ranges.length > 1 && !ranges[1].isEmpty()) {
                                end = Long.parseLong(ranges[1]);
                            } else if (fileSize > 0) {
                                end = fileSize - 1;
                            }
                            if (fileSize > 0 && end >= fileSize) {
                                end = fileSize - 1;
                            }
                            if (start < 0) start = 0;
                            if (end < start) end = start;
                            
                            contentLength = end - start + 1;
                            
                            // Use range request
                            pdfStream = minioService.getDocumentStream(document.getFileUrl(), start, contentLength);
                            headers.set(HttpHeaders.CONTENT_RANGE,
                                String.format("bytes %d-%d/%d", start, end, fileSize > 0 ? fileSize : "*"));
                            headers.setContentLength(contentLength);
                            
                            return ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
                                .headers(headers)
                                .body(new InputStreamResource(pdfStream));
                        } catch (NumberFormatException e) {
                            System.err.println("Invalid range header: " + rangeHeader);
                            // Fall through to full file response
                        }
                    }
                    
                    // Full file response (no range request)
                    pdfStream = minioService.getDocumentStream(document.getFileUrl());
                    if (fileSize > 0) {
                        headers.setContentLength(fileSize);
                    } else {
                        System.out.println("Warning: File size unknown, not setting Content-Length header");
                    }
                    
                    System.out.println("Returning PDF file response (200 OK)");
                    return ResponseEntity.ok()
                        .headers(headers)
                        .body(new InputStreamResource(pdfStream));
                } catch (Exception e) {
                    System.err.println("Error downloading document " + id + ": " + e.getMessage());
                    e.printStackTrace();
                    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                        .header(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                        .body("Error downloading document: " + e.getMessage());
                }
            })
            .orElse(ResponseEntity.notFound()
                .header(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                .build());
    }
}


