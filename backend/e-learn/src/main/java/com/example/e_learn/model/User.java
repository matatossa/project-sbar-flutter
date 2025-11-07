package com.example.e_learn.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "app_user")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String email;

    @Column(nullable = false)
    @JsonIgnore // never serialize password
    private String password;

    @Column(nullable = false)
    private String fullName;

    @Enumerated(EnumType.STRING)
    private Role role;

    private String specialization;

    private LocalDateTime registrationDate;

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "user_lessons",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "lesson_id")
    )
    @JsonIgnore // avoid cycles when serializing user
    private Set<Lesson> lessons = new HashSet<>();

    // Watched progress (simple mapping)
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "user_watched_lessons",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "lesson_id")
    )
    @JsonIgnore // avoid cycles when serializing user
    private Set<Lesson> watchedLessons = new HashSet<>();

    public enum Role {ADMIN, USER}
    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }
    public Role getRole() { return role; }
    public void setRole(Role role) { this.role = role; }
    public String getSpecialization() { return specialization; }
    public void setSpecialization(String specialization) { this.specialization = specialization; }
    public LocalDateTime getRegistrationDate() { return registrationDate; }
    public void setRegistrationDate(LocalDateTime registrationDate) { this.registrationDate = registrationDate; }
    public Set<Lesson> getLessons() { return lessons; }
    public void setLessons(Set<Lesson> lessons) { this.lessons = lessons; }

    public Set<Lesson> getWatchedLessons() { return watchedLessons; }
    public void setWatchedLessons(Set<Lesson> watchedLessons) { this.watchedLessons = watchedLessons; }
    public boolean hasWatched(Lesson lesson) { return watchedLessons != null && watchedLessons.contains(lesson); }
    public void markWatched(Lesson lesson) { watchedLessons.add(lesson); }
}
