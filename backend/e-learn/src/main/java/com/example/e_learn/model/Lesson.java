package com.example.e_learn.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import java.util.HashSet;
import java.util.Set;

@Entity
public class Lesson {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String title;
    private String description;
    @Column(length=2048)
    private String videoUrl;
    /**
     * Transcript in JSON as a string:
     * Example: '[{"word": "Hello", "start": 0.01, "end": 0.22}, ...]'
     * For legacy, can also be just plain text.
     */
    @Column(length=8192)
    private String transcript;
    private int durationSec;

    @Column(length=128)
    private String specialization; // simple denormalized specialization for filtering

    @ManyToMany(mappedBy = "lessons")
    @JsonIgnore // prevent infinite recursion when serializing Lesson -> users -> lessons -> ...
    private Set<User> users = new HashSet<>();

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getVideoUrl() { return videoUrl; }
    public void setVideoUrl(String videoUrl) { this.videoUrl = videoUrl; }
    public String getTranscript() { return transcript; }
    public void setTranscript(String transcript) { this.transcript = transcript; }
    public int getDurationSec() { return durationSec; }
    public void setDurationSec(int durationSec) { this.durationSec = durationSec; }
    public String getSpecialization() { return specialization; }
    public void setSpecialization(String specialization) { this.specialization = specialization; }
    public Set<User> getUsers() { return users; }
    public void setUsers(Set<User> users) { this.users = users; }
}
