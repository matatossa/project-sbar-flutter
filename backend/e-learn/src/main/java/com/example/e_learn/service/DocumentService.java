package com.example.e_learn.service;

import com.example.e_learn.model.Lesson;
import com.example.e_learn.model.Document;
import com.example.e_learn.repository.DocumentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
public class DocumentService {
    @Autowired
    private DocumentRepository documentRepository;

    @Autowired
    private LessonService lessonService;

    public List<Document> getDocumentsByLessonId(Long lessonId) {
        return documentRepository.findByLessonIdOrderByOrderIndexAsc(lessonId);
    }

    public Optional<Document> getDocument(Long id) {
        return documentRepository.findById(id);
    }

    @Transactional
    public Document saveDocument(Document document) {
        return documentRepository.save(document);
    }

    @Transactional
    public void deleteDocument(Long id) {
        documentRepository.deleteById(id);
    }

    @Transactional
    public Document createDocumentForLesson(Long lessonId, String title, String fileUrl, String description, int orderIndex) {
        Optional<Lesson> lessonOpt = lessonService.getLesson(lessonId);
        if (lessonOpt.isEmpty()) {
            throw new IllegalArgumentException("Lesson not found: " + lessonId);
        }
        
        Document document = new Document();
        document.setTitle(title);
        document.setFileUrl(fileUrl);
        document.setDescription(description);
        document.setOrderIndex(orderIndex);
        document.setLesson(lessonOpt.get());
        
        return documentRepository.save(document);
    }
}




