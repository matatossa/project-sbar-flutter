package com.example.e_learn.dto;

public class AuthResponse {
    public String jwtToken;
    public String userRole;
    public String email;
    public String fullName;
    public AuthResponse(String jwtToken, String userRole, String email, String fullName) {
        this.jwtToken = jwtToken;
        this.userRole = userRole;
        this.email = email;
        this.fullName = fullName;
    }
}

