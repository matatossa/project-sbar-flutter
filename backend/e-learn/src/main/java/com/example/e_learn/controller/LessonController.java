package com.example.e_learn.controller;

import com.example.e_learn.model.Lesson;
import com.example.e_learn.service.LessonService;
import com.example.e_learn.service.MinioService;
import com.example.e_learn.service.TranscriptService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.io.InputStream;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import com.example.e_learn.service.UserService;

@RestController
@RequestMapping("/api/lessons")
public class LessonController {
    @Autowired
    private LessonService lessonService;

    @Autowired
    private MinioService minioService;

    @Autowired
    private TranscriptService transcriptService;

    @Autowired
    private UserService userService;

    @GetMapping
    public List<Lesson> getAll() {
        return lessonService.getAllLessons();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Lesson> getById(@PathVariable Long id) {
        return lessonService.getLesson(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping
    public Lesson create(@RequestBody Lesson lesson) {
        return lessonService.saveLesson(lesson);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PutMapping("/{id}")
    public ResponseEntity<Lesson> update(@PathVariable Long id, @RequestBody Lesson lessonUpdate) {
        return lessonService.getLesson(id)
            .map(lesson -> {
                lesson.setTitle(lessonUpdate.getTitle());
                lesson.setDescription(lessonUpdate.getDescription());
                lesson.setVideoUrl(lessonUpdate.getVideoUrl());
                lesson.setTranscript(lessonUpdate.getTranscript());
                lesson.setDurationSec(lessonUpdate.getDurationSec());
                lesson.setSpecialization(lessonUpdate.getSpecialization());
                return ResponseEntity.ok(lessonService.saveLesson(lesson));
            })
            .orElse(ResponseEntity.notFound().build());
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/{id}/video")
    public ResponseEntity<?> uploadVideo(@PathVariable Long id, @RequestParam("file") MultipartFile file) {
        try {
            return lessonService.getLesson(id)
                .map(lesson -> {
                    try {
                        String videoUrl = minioService.uploadVideo(file);
                        lesson.setVideoUrl(videoUrl);
                        lessonService.saveLesson(lesson);
                        return ResponseEntity.ok(lesson);
                    } catch (Exception e) {
                        return ResponseEntity.internalServerError().build();
                    }
                })
                .orElse(ResponseEntity.notFound().build());
        } catch (Exception e) {
            return ResponseEntity.internalServerError().build();
        }
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/{id}/transcript")
    public ResponseEntity<?> triggerTranscript(@PathVariable Long id) {
        return lessonService.getLesson(id)
            .map(lesson -> {
                if (lesson.getVideoUrl() == null) {
                    return ResponseEntity.badRequest().build();
                }
                String transcript = transcriptService.transcribeVideo(lesson.getVideoUrl());
                lesson.setTranscript(transcript);
                lessonService.saveLesson(lesson);
                return ResponseEntity.ok(lesson);
            })
            .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/watched")
    public ResponseEntity<Void> markAsWatched(@PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) return ResponseEntity.status(401).build();
        var lessonOpt = lessonService.getLesson(id);
        var userOpt = userService.getByEmail(userDetails.getUsername());
        if (lessonOpt.isEmpty() || userOpt.isEmpty()) return ResponseEntity.notFound().build();
        userService.markLessonWatched(userOpt.get(), lessonOpt.get());
        return ResponseEntity.ok().build();
    }
    
    @PostMapping("/{id}/enroll")
    public ResponseEntity<Void> enrollInLesson(@PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) return ResponseEntity.status(401).build();
        var lessonOpt = lessonService.getLesson(id);
        var userOpt = userService.getByEmail(userDetails.getUsername());
        if (lessonOpt.isEmpty() || userOpt.isEmpty()) return ResponseEntity.notFound().build();
        if (userService.isEnrolled(userOpt.get(), lessonOpt.get())) {
            return ResponseEntity.status(400).build(); // Already enrolled
        }
        userService.enrollInLesson(userOpt.get(), lessonOpt.get());
        return ResponseEntity.ok().build();
    }
    
    @GetMapping("/my-courses")
    public ResponseEntity<List<Lesson>> getMyCourses(@AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) return ResponseEntity.status(401).build();
        var userOpt = userService.getByEmail(userDetails.getUsername());
        if (userOpt.isEmpty()) return ResponseEntity.status(404).build();
        return ResponseEntity.ok(new java.util.ArrayList<>(userOpt.get().getLessons()));
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        lessonService.deleteLesson(id);
        return ResponseEntity.ok().build();
    }

    // Handle OPTIONS preflight for CORS
    @RequestMapping(value = "/{id}/stream", method = RequestMethod.OPTIONS)
    public ResponseEntity<Void> streamVideoOptions(@PathVariable Long id) {
        HttpHeaders headers = new HttpHeaders();
        headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
        headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, "GET, HEAD, OPTIONS");
        headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_HEADERS, "Range, Content-Type, Authorization");
        headers.set(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, "Content-Range, Content-Length, Accept-Ranges");
        headers.set(HttpHeaders.ACCESS_CONTROL_MAX_AGE, "3600");
        return ResponseEntity.ok().headers(headers).build();
    }

    // Stream video through backend to avoid CORS and ensure proper headers
    @GetMapping("/{id}/stream")
    public ResponseEntity<?> streamVideo(
            @PathVariable Long id, 
            @RequestHeader(value = "Range", required = false) String rangeHeader,
            HttpServletRequest request) {
        System.out.println("=== VIDEO STREAM REQUEST ===");
        System.out.println("Lesson ID: " + id);
        System.out.println("Range header: " + rangeHeader);
        System.out.println("Request method: " + request.getMethod());
        System.out.println("Request URI: " + request.getRequestURI());
        
        return lessonService.getLesson(id)
            .map(lesson -> {
                try {
                    if (lesson.getVideoUrl() == null || lesson.getVideoUrl().isEmpty()) {
                        System.err.println("Lesson " + id + " has no video URL");
                        return ResponseEntity.notFound().build();
                    }
                    
                    System.out.println("Video URL: " + lesson.getVideoUrl());
                    
                    long fileSize = minioService.getObjectSize(lesson.getVideoUrl());
                    System.out.println("File size: " + fileSize);
                    
                    if (fileSize < 0) {
                        System.err.println("Could not determine file size for lesson " + id);
                        // Try to stream anyway without size
                        fileSize = 0;
                    }
                    
                    HttpHeaders headers = new HttpHeaders();
                    // Set content type - try to detect from filename, default to mp4
                    String contentType = "video/mp4";
                    if (lesson.getVideoUrl().toLowerCase().endsWith(".webm")) {
                        contentType = "video/webm";
                    } else if (lesson.getVideoUrl().toLowerCase().endsWith(".ogg")) {
                        contentType = "video/ogg";
                    }
                    headers.setContentType(MediaType.parseMediaType(contentType));
                    
                    // CORS headers for video streaming
                    headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
                    headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, "GET, HEAD, OPTIONS");
                    headers.set(HttpHeaders.ACCESS_CONTROL_ALLOW_HEADERS, "Range, Content-Type, Authorization");
                    headers.set(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, "Content-Range, Content-Length, Accept-Ranges");
                    headers.set(HttpHeaders.ACCEPT_RANGES, "bytes");
                    headers.set(HttpHeaders.CACHE_CONTROL, "public, max-age=3600");
                    
                    InputStream videoStream;
                    long start = 0;
                    long end = fileSize > 0 ? fileSize - 1 : 0;
                    long contentLength = fileSize;
                    
                    // Parse Range header if present
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
                                // If only start is provided, end is fileSize - 1
                                end = fileSize - 1;
                            }
                            if (fileSize > 0 && end >= fileSize) {
                                end = fileSize - 1;
                            }
                            if (start < 0) start = 0;
                            if (end < start) end = start;
                            
                            contentLength = end - start + 1;
                            
                            System.out.println("Range request: bytes " + start + "-" + end + "/" + fileSize);
                            
                            // Use range request
                            videoStream = minioService.getVideoStream(lesson.getVideoUrl(), start, contentLength);
                            headers.set(HttpHeaders.CONTENT_RANGE, 
                                String.format("bytes %d-%d/%d", start, end, fileSize > 0 ? fileSize : "*"));
                            headers.setContentLength(contentLength);
                            
                            System.out.println("Returning 206 Partial Content");
                            return ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
                                .headers(headers)
                                .body(new InputStreamResource(videoStream));
                        } catch (NumberFormatException e) {
                            System.err.println("Invalid range header: " + rangeHeader + " - " + e.getMessage());
                            // Fall through to full file
                        }
                    }
                    
                    // Full file request
                    System.out.println("Full file request");
                    videoStream = minioService.getVideoStream(lesson.getVideoUrl());
                    if (fileSize > 0) {
                        headers.setContentLength(fileSize);
                    }
                    System.out.println("Returning 200 OK with full video");
                    return ResponseEntity.ok()
                        .headers(headers)
                        .body(new InputStreamResource(videoStream));
                } catch (Exception e) {
                    System.err.println("Error streaming video for lesson " + id + ": " + e.getMessage());
                    e.printStackTrace();
                    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                        .header(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                        .body("Error streaming video: " + e.getMessage());
                }
            })
            .orElse(ResponseEntity.notFound()
                .header(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                .build());
    }
}
