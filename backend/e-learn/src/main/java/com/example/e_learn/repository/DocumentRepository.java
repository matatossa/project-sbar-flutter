package com.example.e_learn.repository;

import com.example.e_learn.model.Document;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface DocumentRepository extends JpaRepository<Document, Long> {
    List<Document> findByLessonIdOrderByOrderIndexAsc(Long lessonId);
}




