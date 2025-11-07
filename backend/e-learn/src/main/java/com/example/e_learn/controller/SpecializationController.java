package com.example.e_learn.controller;

import com.example.e_learn.model.Lesson;
import com.example.e_learn.repository.LessonRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/specializations")
public class SpecializationController {
    @Autowired
    private LessonRepository lessonRepository;

    // Return distinct specializations derived from existing lessons
    @GetMapping
    public List<String> getAll() {
        return lessonRepository.findAll().stream()
            .map(Lesson::getSpecialization)
            .filter(s -> s != null && !s.isBlank())
            .distinct()
            .sorted(String::compareToIgnoreCase)
            .collect(Collectors.toList());
    }
}

