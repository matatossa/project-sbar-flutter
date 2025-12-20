package com.example.e_learn.service;

import com.example.e_learn.model.Lesson;
import com.example.e_learn.model.Video;
import com.example.e_learn.repository.VideoRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
public class VideoService {
    @Autowired
    private VideoRepository videoRepository;

    @Autowired
    private LessonService lessonService;

    public List<Video> getVideosByLessonId(Long lessonId) {
        return videoRepository.findByLessonIdOrderByOrderIndexAsc(lessonId);
    }

    public Optional<Video> getVideo(Long id) {
        return videoRepository.findById(id);
    }

    @Transactional
    public Video saveVideo(Video video) {
        return videoRepository.save(video);
    }

    @Transactional
    public void deleteVideo(Long id) {
        videoRepository.deleteById(id);
    }

    @Transactional
    public void deleteVideosByLessonId(Long lessonId) {
        videoRepository.deleteByLessonId(lessonId);
    }

    @Transactional
    public Video createVideoForLesson(Long lessonId, String title, String videoUrl, int durationSec, int orderIndex) {
        Optional<Lesson> lessonOpt = lessonService.getLesson(lessonId);
        if (lessonOpt.isEmpty()) {
            throw new IllegalArgumentException("Lesson not found: " + lessonId);
        }
        
        Video video = new Video();
        video.setTitle(title);
        video.setVideoUrl(videoUrl);
        video.setDurationSec(durationSec);
        video.setOrderIndex(orderIndex);
        video.setLesson(lessonOpt.get());
        
        return videoRepository.save(video);
    }
}






