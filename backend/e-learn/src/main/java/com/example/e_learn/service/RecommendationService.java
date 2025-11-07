package com.example.e_learn.service;

import com.example.e_learn.model.Lesson;
import com.example.e_learn.model.User;
import com.example.e_learn.repository.LessonRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class RecommendationService {
    @Autowired
    private LessonRepository lessonRepository;

    public List<Lesson> recommendFor(User user) {
        Set<Long> watchedIds = user.getWatchedLessons().stream().map(Lesson::getId).collect(Collectors.toSet());
        String spec = user.getSpecialization() != null ? user.getSpecialization().toLowerCase(Locale.ROOT) : "";
        return lessonRepository.findAll().stream()
            .filter(l -> !watchedIds.contains(l.getId()))
            .sorted(Comparator.comparingInt((Lesson l) -> score(l, spec)).reversed())
            .limit(10)
            .collect(Collectors.toList());
    }

    private int score(Lesson lesson, String spec) {
        int s = 0;
        if (!spec.isEmpty()) {
            String t = (lesson.getTitle() + " " + lesson.getDescription()).toLowerCase(Locale.ROOT);
            if (t.contains(spec)) s += 10;
        }
        // Future: add popularity, recency, user history similarity, etc.
        s += Math.max(0, 120 - lesson.getDurationSec()); // prefer shorter micro-lessons
        return s;
    }
}
