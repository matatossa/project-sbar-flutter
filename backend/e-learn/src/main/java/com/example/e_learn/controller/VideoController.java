package com.example.e_learn.controller;

import com.example.e_learn.model.Video;
import com.example.e_learn.service.VideoService;
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
import java.io.InputStream;
import org.springframework.web.multipart.MultipartFile;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/videos")
public class VideoController {
    @Autowired
    private VideoService videoService;

    @Autowired
    private MinioService minioService;

    @Autowired
    private TranscriptService transcriptService;

    @GetMapping("/lesson/{lessonId}")
    public ResponseEntity<List<Video>> getVideosByLesson(@PathVariable Long lessonId) {
        return ResponseEntity.ok(videoService.getVideosByLessonId(lessonId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Video> getVideo(@PathVariable Long id) {
        return videoService.getVideo(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/lesson/{lessonId}")
    public ResponseEntity<?> uploadVideo(
            @PathVariable Long lessonId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "title", required = false, defaultValue = "") String title) {
        try {
            // Upload video to MinIO
            String videoUrl = minioService.uploadVideo(file);
            
            // Get existing videos to determine order index
            List<Video> existingVideos = videoService.getVideosByLessonId(lessonId);
            int orderIndex = existingVideos.size();
            
            // Use filename as title if not provided
            String videoTitle = title != null && !title.isEmpty() 
                ? title 
                : file.getOriginalFilename();
            
            // Estimate duration (default 90 seconds, can be improved later)
            int durationSec = 90;
            
            // Create video entity
            Video video = videoService.createVideoForLesson(lessonId, videoTitle, videoUrl, durationSec, orderIndex);
            
            return ResponseEntity.ok(video);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "Failed to upload video: " + e.getMessage()));
        }
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteVideo(@PathVariable Long id) {
        videoService.deleteVideo(id);
        return ResponseEntity.ok().build();
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/{id}/transcript")
    public ResponseEntity<?> triggerTranscript(@PathVariable Long id) {
        return videoService.getVideo(id)
            .map(video -> {
                if (video.getVideoUrl() == null || video.getVideoUrl().isEmpty()) {
                    return ResponseEntity.badRequest().build();
                }
                try {
                    String transcript = transcriptService.transcribeVideo(video.getVideoUrl());
                    video.setTranscript(transcript);
                    videoService.saveVideo(video);
                    return ResponseEntity.ok(video);
                } catch (Exception e) {
                    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
                }
            })
            .orElse(ResponseEntity.notFound().build());
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
        System.out.println("Video ID: " + id);
        System.out.println("Range header: " + rangeHeader);
        
        return videoService.getVideo(id)
            .map(video -> {
                try {
                    if (video.getVideoUrl() == null || video.getVideoUrl().isEmpty()) {
                        System.err.println("Video " + id + " has no video URL");
                        return ResponseEntity.notFound().build();
                    }
                    
                    System.out.println("Video URL: " + video.getVideoUrl());
                    
                    long fileSize = minioService.getObjectSize(video.getVideoUrl());
                    System.out.println("File size: " + fileSize);
                    
                    if (fileSize < 0) {
                        System.err.println("Could not determine file size for video " + id);
                        fileSize = 0;
                    }
                    
                    HttpHeaders headers = new HttpHeaders();
                    // Set content type - try to detect from filename, default to mp4
                    String contentType = "video/mp4";
                    if (video.getVideoUrl().toLowerCase().endsWith(".webm")) {
                        contentType = "video/webm";
                    } else if (video.getVideoUrl().toLowerCase().endsWith(".ogg")) {
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
                            videoStream = minioService.getVideoStream(video.getVideoUrl(), start, contentLength);
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
                    videoStream = minioService.getVideoStream(video.getVideoUrl());
                    if (fileSize > 0) {
                        headers.setContentLength(fileSize);
                    }
                    System.out.println("Returning 200 OK with full video");
                    return ResponseEntity.ok()
                        .headers(headers)
                        .body(new InputStreamResource(videoStream));
                } catch (Exception e) {
                    System.err.println("Error streaming video " + id + ": " + e.getMessage());
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






