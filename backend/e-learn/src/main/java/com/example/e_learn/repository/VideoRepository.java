package com.example.e_learn.repository;

import com.example.e_learn.model.Video;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface VideoRepository extends JpaRepository<Video, Long> {
    List<Video> findByLessonIdOrderByOrderIndexAsc(Long lessonId);
    void deleteByLessonId(Long lessonId);
}






