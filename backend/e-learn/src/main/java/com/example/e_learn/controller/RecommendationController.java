package com.example.e_learn.controller;

import com.example.e_learn.model.Lesson;
import com.example.e_learn.service.RecommendationService;
import com.example.e_learn.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.List;

@RestController
@RequestMapping("/api/recommendations")
public class RecommendationController {
    @Autowired
    private RecommendationService recommendationService;
    @Autowired
    private UserService userService;

    @GetMapping
    public ResponseEntity<List<Lesson>> getRecommendations(@AuthenticationPrincipal UserDetails principal) {
        if (principal == null) return ResponseEntity.status(401).build();
        return userService.getByEmail(principal.getUsername())
            .map(user -> ResponseEntity.ok(recommendationService.recommendFor(user)))
            .orElse(ResponseEntity.status(404).build());
    }
}
