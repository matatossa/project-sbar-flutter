package com.example.e_learn.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class HealthController {
    
    @GetMapping("/health")
    @CrossOrigin(origins = "*")
    public ResponseEntity<String> health() {
        System.out.println("=== HEALTH CHECK REQUEST RECEIVED ===");
        return ResponseEntity.ok("Backend is running!");
    }
}

