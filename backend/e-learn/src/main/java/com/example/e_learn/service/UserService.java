package com.example.e_learn.service;

import com.example.e_learn.model.Lesson;
import com.example.e_learn.model.User;
import com.example.e_learn.repository.UserRepository;
import com.example.e_learn.security.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.util.Optional;

@Service
public class UserService {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PasswordEncoder passwordEncoder;
    @Autowired
    private JwtUtil jwtUtil;

    public User signup(String email, String password, String fullName, String specialization) {
        boolean isFirstUser = userRepository.count() == 0;
        User.Role role = isFirstUser ? User.Role.ADMIN : User.Role.USER;

        // 🔍 Debug log for role assignment
        System.out.println("🟢 Signup: assigning role " + role + " to " + email);

        User user = new User();
        user.setEmail(email);
        user.setPassword(passwordEncoder.encode(password));
        user.setFullName(fullName);
        user.setSpecialization(specialization);
        user.setRegistrationDate(LocalDateTime.now());
        user.setRole(role);
        return userRepository.save(user);
    }

    public Optional<User> login(String email, String password) {
        Optional<User> user = userRepository.findByEmail(email);
        if (user.isPresent()) {
            User u = user.get();
            boolean match = passwordEncoder.matches(password, u.getPassword());
            System.out.println("🟡 Login attempt for: " + email +
                    " | role: " + u.getRole() +
                    " | password match: " + match);
            if (match) return Optional.of(u);
        } else {
            System.out.println("🔴 Login failed: user not found for " + email);
        }
        return Optional.empty();
    }

    public boolean existsByEmail(String email) {
        return userRepository.findByEmail(email).isPresent();
    }

    public Optional<User> getByEmail(String email) {
        return userRepository.findByEmail(email);
    }

    public void markLessonWatched(User user, Lesson lesson) {
        user.markWatched(lesson);
        userRepository.save(user);
        System.out.println("📘 Marked lesson as watched for: " + user.getEmail());
    }

    public boolean hasWatched(User user, Lesson lesson) {
        return user.hasWatched(lesson);
    }

    public void enrollInLesson(User user, Lesson lesson) {
        user.getLessons().add(lesson);
        userRepository.save(user);
        System.out.println("📗 Enrolled " + user.getEmail() + " in lesson " + lesson.getId());
    }

    public boolean isEnrolled(User user, Lesson lesson) {
        return user.getLessons() != null && user.getLessons().contains(lesson);
    }
}
