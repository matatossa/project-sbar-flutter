package com.example.e_learn.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.Map;

@Service
public class TranscriptService {

    @Value("${asr.url}")
    private String asrUrl;

    public String transcribeVideo(String videoUrl) {
        try {
            RestTemplate rest = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<Map<String, String>> req =
                    new HttpEntity<>(Map.of("videoUrl", videoUrl), headers);

            String response = rest.postForObject(asrUrl, req, String.class);

            if (response == null || response.isBlank()) {
                return "Transcription non disponible.";
            }

            ObjectMapper mapper = new ObjectMapper();
            JsonNode root = mapper.readTree(response);

            // Check if response has a "words" array
            if (root.has("words") && root.get("words").isArray()) {
                StringBuilder transcript = new StringBuilder();
                for (JsonNode wordNode : root.get("words")) {
                    if (wordNode.has("word")) {
                        transcript.append(wordNode.get("word").asText()).append(" ");
                    }
                }
                return transcript.toString().trim();
            }

            // If response contains a direct text field (fallback)
            if (root.has("text")) {
                return root.get("text").asText();
            }

        } catch (Exception e) {
            e.printStackTrace();
        }
        return "Erreur lors de la transcription.";
    }
}
