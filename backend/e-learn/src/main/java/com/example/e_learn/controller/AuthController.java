package com.example.e_learn.controller;

import com.example.e_learn.dto.AuthResponse;
import com.example.e_learn.dto.UserSignupRequest;
import com.example.e_learn.dto.UserLoginRequest;
import com.example.e_learn.model.User;
import com.example.e_learn.service.UserService;
import com.example.e_learn.security.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    @Autowired
    private UserService userService;
    @Autowired
    private JwtUtil jwtUtil;

    @PostMapping("/signup")
    public ResponseEntity<?> signup(@RequestBody UserSignupRequest req) {
        if (userService.existsByEmail(req.email)) {
            return ResponseEntity.badRequest().body("Email already in use");
        }
        User user = userService.signup(req.email, req.password, req.fullName, req.specialization);
        String jwt = jwtUtil.generateToken(user.getEmail(), user.getRole().name());
        return ResponseEntity.ok(new AuthResponse(jwt, user.getRole().name(), user.getEmail(), user.getFullName()));
    }

    @PostMapping("/login")
    @CrossOrigin(origins = "*")
    public ResponseEntity<?> login(@RequestBody UserLoginRequest req) {
        try {
            System.out.println("=== LOGIN REQUEST RECEIVED ===");
            System.out.println("Login attempt for email: " + req.email);
            var userOpt = userService.login(req.email, req.password);
            if (userOpt.isPresent()) {
                var user = userOpt.get();
                System.out.println("Login successful for: " + user.getEmail());
                return ResponseEntity.ok(
                    new AuthResponse(
                        jwtUtil.generateToken(user.getEmail(), user.getRole().name()),
                        user.getRole().name(),
                        user.getEmail(),
                        user.getFullName()
                    )
                );
            } else {
                System.out.println("Login failed: Invalid credentials for " + req.email);
                return ResponseEntity.status(401).body("Invalid email/password");
            }
        } catch (Exception e) {
            System.err.println("Login error: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(500).body("Internal server error: " + e.getMessage());
        }
    }
}

