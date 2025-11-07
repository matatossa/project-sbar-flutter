package com.example.e_learn.service;

import com.example.e_learn.model.Lesson;
import com.example.e_learn.repository.LessonRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Optional;
import org.springframework.transaction.annotation.Transactional;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

@Service
public class LessonService {
    @Autowired
    private LessonRepository lessonRepository;

    @PersistenceContext
    private EntityManager entityManager;

    public Lesson saveLesson(Lesson lesson) { return lessonRepository.save(lesson); }

    public List<Lesson> getAllLessons() { return lessonRepository.findAll(); }

    public Optional<Lesson> getLesson(Long id) { return lessonRepository.findById(id); }

    @Transactional
    public void deleteLesson(Long id) {
        // Remove join table links first to avoid FK violation
        entityManager.createNativeQuery("DELETE FROM user_lessons WHERE lesson_id = :id")
            .setParameter("id", id)
            .executeUpdate();
        entityManager.createNativeQuery("DELETE FROM user_watched_lessons WHERE lesson_id = :id")
            .setParameter("id", id)
            .executeUpdate();
        lessonRepository.deleteById(id);
    }
}

