package com.example.e_learn.controller;

import com.example.e_learn.model.Lesson;
import com.example.e_learn.model.User;
import com.example.e_learn.model.Video;
import com.example.e_learn.repository.VideoRepository;
import com.example.e_learn.service.LessonService;
import com.example.e_learn.service.MinioService;
import com.example.e_learn.service.TranscriptService;
import com.example.e_learn.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/api/lessons")
@CrossOrigin(origins = "*")
public class LessonController {

    @Autowired
    private LessonService lessonService;

    @Autowired
    private MinioService minioService;

    @Autowired
    private TranscriptService transcriptService;

    @Autowired
    private UserService userService;

    @Autowired
    private VideoRepository videoRepository;

    // ===================== LESSON =====================

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
    public ResponseEntity<Lesson> update(
            @PathVariable Long id,
            @RequestBody Lesson lessonUpdate) {

        return lessonService.getLesson(id)
                .map(lesson -> {
                    lesson.setTitle(lessonUpdate.getTitle());
                    lesson.setDescription(lessonUpdate.getDescription());
                    lesson.setTranscript(lessonUpdate.getTranscript());
                    lesson.setDurationSec(lessonUpdate.getDurationSec());
                    lesson.setSpecialization(lessonUpdate.getSpecialization());
                    // ❌ PAS de setVideos ici (dangereux)
                    return ResponseEntity.ok(lessonService.saveLesson(lesson));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        if (lessonService.getLesson(id).isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        lessonService.deleteLesson(id);
        return ResponseEntity.ok().build();
    }

    // ===================== VIDEO =====================

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/{lessonId}/video")
    public ResponseEntity<?> uploadVideo(
            @PathVariable Long lessonId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "title", required = false) String title) {

        return lessonService.getLesson(lessonId)
                .map(lesson -> {
                    try {
                        String videoUrl = minioService.uploadVideo(file);

                        Video video = new Video();
                        video.setUrl(videoUrl);
                        video.setTitle(
                                (title != null && !title.isBlank())
                                        ? title
                                        : file.getOriginalFilename()
                        );
                        video.setDurationSec(0);
                        video.setLesson(lesson);

                        // gestion bidirectionnelle correcte
                        lesson.getVideos().add(video);

                        // UN SEUL save (cascade)
                        Lesson savedLesson = lessonService.saveLesson(lesson);

                        return ResponseEntity.ok(savedLesson);

                    } catch (Exception e) {
                        e.printStackTrace();
                        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                .body("Error uploading video: " + e.getMessage());
                    }
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{lessonId}/videos")
    public ResponseEntity<List<Video>> getLessonVideos(@PathVariable Long lessonId) {
        if (lessonService.getLesson(lessonId).isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(videoRepository.findByLessonId(lessonId));
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/videos/{videoId}")
    public ResponseEntity<Void> deleteVideo(@PathVariable Long videoId) {
        if (videoRepository.findById(videoId).isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        videoRepository.deleteById(videoId);
        return ResponseEntity.ok().build();
    }

    // ===================== STREAMING =====================

    @GetMapping("/{lessonId}/videos/{videoId}/stream")
    public ResponseEntity<?> streamVideo(
            @PathVariable Long lessonId,
            @PathVariable Long videoId,
            @RequestHeader(value = "Range", required = false) String rangeHeader,
            HttpServletRequest request) {

        if (lessonService.getLesson(lessonId).isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        return videoRepository.findById(videoId)
                .filter(video -> video.getLesson().getId().equals(lessonId))
                .map(video -> {
                    try {
                        String videoUrl = video.getUrl();
                        long fileSize = minioService.getObjectSize(videoUrl);

                        HttpHeaders headers = new HttpHeaders();
                        headers.setContentType(MediaType.valueOf("video/mp4"));
                        headers.set(HttpHeaders.ACCEPT_RANGES, "bytes");

                        InputStream stream;
                        long start = 0;
                        long end = fileSize - 1;

                        if (rangeHeader != null && rangeHeader.startsWith("bytes=")) {
                            String[] ranges = rangeHeader.substring(6).split("-");
                            if (!ranges[0].isEmpty()) start = Long.parseLong(ranges[0]);
                            if (ranges.length > 1 && !ranges[1].isEmpty())
                                end = Long.parseLong(ranges[1]);

                            long length = end - start + 1;
                            stream = minioService.getVideoStream(videoUrl, start, length);

                            headers.set(HttpHeaders.CONTENT_RANGE,
                                    "bytes " + start + "-" + end + "/" + fileSize);
                            headers.setContentLength(length);

                            return ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
                                    .headers(headers)
                                    .body(new InputStreamResource(stream));
                        }

                        stream = minioService.getVideoStream(videoUrl);
                        headers.setContentLength(fileSize);

                        return ResponseEntity.ok()
                                .headers(headers)
                                .body(new InputStreamResource(stream));

                    } catch (Exception e) {
                        e.printStackTrace();
                        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                .body("Error streaming video: " + e.getMessage());
                    }
                })
                .orElse(ResponseEntity.notFound().build());
    }

    // ===================== USER ACTIONS =====================

    @PostMapping("/{id}/watched")
    public ResponseEntity<Void> markAsWatched(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {

        if (userDetails == null) return ResponseEntity.status(401).build();

        var lessonOpt = lessonService.getLesson(id);
        var userOpt = userService.getByEmail(userDetails.getUsername());

        if (lessonOpt.isEmpty() || userOpt.isEmpty())
            return ResponseEntity.notFound().build();

        userService.markLessonWatched(userOpt.get(), lessonOpt.get());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/enroll")
    public ResponseEntity<Void> enroll(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {

        if (userDetails == null) return ResponseEntity.status(401).build();

        var lessonOpt = lessonService.getLesson(id);
        var userOpt = userService.getByEmail(userDetails.getUsername());

        if (lessonOpt.isEmpty() || userOpt.isEmpty())
            return ResponseEntity.notFound().build();

        if (userService.isEnrolled(userOpt.get(), lessonOpt.get()))
            return ResponseEntity.badRequest().build();

        userService.enrollInLesson(userOpt.get(), lessonOpt.get());
        return ResponseEntity.ok().build();
    }

    @GetMapping("/my-courses")
    public ResponseEntity<List<Lesson>> getMyCourses(
            @AuthenticationPrincipal UserDetails userDetails) {

        if (userDetails == null) return ResponseEntity.status(401).build();

        var userOpt = userService.getByEmail(userDetails.getUsername());
        if (userOpt.isEmpty()) return ResponseEntity.notFound().build();

        User user = userOpt.get();
        return ResponseEntity.ok(new ArrayList<>(user.getLessons()));
    }
}
