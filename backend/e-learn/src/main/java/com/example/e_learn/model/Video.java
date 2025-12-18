package com.example.e_learn.model;

import com.fasterxml.jackson.annotation.JsonBackReference;
import com.fasterxml.jackson.annotation.JsonIdentityInfo;
import com.fasterxml.jackson.annotation.ObjectIdGenerators;
import jakarta.persistence.*;

@Entity
@JsonIdentityInfo(
        generator = ObjectIdGenerators.PropertyGenerator.class,
        property = "id"
)
public class Video {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String title;

    @Column(length = 2048)
    private String url;

    // Utiliser Integer au lieu de int pour accepter les nulls et éviter les erreurs JSON
    @Column(nullable = false)
    private Integer durationSec = 0;

    @ManyToOne
    @JoinColumn(name = "lesson_id")
    @JsonBackReference("lesson-video")
    private Lesson lesson;

    // Getters
    public Long getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getUrl() {
        return url;
    }

    public Integer getDurationSec() {
        return durationSec;
    }

    public Lesson getLesson() {
        return lesson;
    }

    // Setters
    public void setId(Long id) {
        this.id = id;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public void setUrl(String url) {
        this.url = url;
    }

    public void setDurationSec(Integer durationSec) {
        this.durationSec = durationSec;
    }

    public void setLesson(Lesson lesson) {
        this.lesson = lesson;
    }
}
