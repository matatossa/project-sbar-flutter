package com.example.e_learn.model;

import com.fasterxml.jackson.annotation.JsonIdentityInfo;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonManagedReference;
import com.fasterxml.jackson.annotation.ObjectIdGenerators;
import jakarta.persistence.*;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Entity
@JsonIdentityInfo(
        generator = ObjectIdGenerators.PropertyGenerator.class,
        property = "id"
)
public class Lesson {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String title;
    private String description;

    @OneToMany(mappedBy = "lesson", cascade = CascadeType.ALL, orphanRemoval = true)
    @JsonManagedReference("lesson-video")  // AJOUTÉ
    private List<Video> videos = new ArrayList<>();

    @Column(length = 8192)
    private String transcript;

    private int durationSec;

    @Column(length = 128)
    private String specialization;

    @ManyToMany(mappedBy = "lessons")
    @JsonIgnore
    private Set<User> users = new HashSet<>();


    public Long getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getDescription() {
        return description;
    }

    public List<Video> getVideos() {
        return videos;
    }

    public String getTranscript() {
        return transcript;
    }

    public int getDurationSec() {
        return durationSec;
    }

    public String getSpecialization() {
        return specialization;
    }

    public Set<User> getUsers() {
        return users;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public void setVideos(List<Video> videos) {
        this.videos = videos;
    }

    public void setTranscript(String transcript) {
        this.transcript = transcript;
    }

    public void setDurationSec(int durationSec) {
        this.durationSec = durationSec;
    }

    public void setSpecialization(String specialization) {
        this.specialization = specialization;
    }

    public void setUsers(Set<User> users) {
        this.users = users;
    }
}